#!/bin/bash
# ==========================================
# HOURLY GOOGLE DRIVE MIRROR BACKUP
# True 1:1 PC <--> Cloud mirror
# Optimized for Low internet speed / 8GB RAM / 256 SSD
# ==========================================

PATH=/usr/bin:/bin

LOCKFILE="/tmp/rclone/rclone_backup.lock"
LOGFILE="$HOME/Scripts/backup.log"

# ----------------------------
# Log Rotation (5MB limit) - Rotated .gz files created directly in /tmp/rclone/
# ----------------------------
MAX_LOG_SIZE=$((5 * 1024 * 1024)) # 5 MiB

# Ensure rotation directory exists
mkdir -p /tmp/rclone

if [ -f "$LOGFILE" ]; then
    FILESIZE=$(stat -c%s "$LOGFILE" 2>/dev/null || echo 0)
    if [ "$FILESIZE" -ge "$MAX_LOG_SIZE" ]; then
        TIMESTAMP=$(/usr/bin/date +%Y%m%d_%H%M%S)
        ROTATED_LOG="/tmp/rclone/backup.log.${TIMESTAMP}"

        echo "[$(/usr/bin/date)] Log size exceeded ${MAX_LOG_SIZE} bytes. Rotating..." >> "$LOGFILE"

        # Create compressed log directly in /tmp/rclone/ (most efficient)
        cat "$LOGFILE" | gzip > "${ROTATED_LOG}.gz"

        # Truncate original log file (starts fresh for next run)
        > "$LOGFILE"

        echo "[$(/usr/bin/date)] ✅ Log rotated: ${ROTATED_LOG}.gz" >> "$LOGFILE"

        # Cleanup old rotated logs (> 7 days)
        find /tmp/rclone -name "backup.log.*.gz" -mtime +7 -delete 2>/dev/null || true
    fi
fi

# ----------------------------
# Prevent overlapping runs
# ----------------------------
exec 200>"$LOCKFILE"
flock -n 200 || {
    echo "[$(/usr/bin/date)] Backup already running. Skipping..." >> "$LOGFILE"
    exit 1
}

echo "=========================================" >> "$LOGFILE"
echo "🔄 Starting Hourly Mirror Sync..." >> "$LOGFILE"
echo "🕐 $(/usr/bin/date)" >> "$LOGFILE"

# ----------------------------
# Folders to backup
# ----------------------------
FOLDERS=(
    "Bug-hunting"
    "CTF"
    "DockerImages"
    "Documents"
    "Malware"
    "Pictures"
    "Projects"
    "Scripts"
    "Vulnerable-labs"
    "wordlists"
)

# ----------------------------
# Optional safety backup for deleted files
# ----------------------------
# SAFETY_BACKUP="--backup-dir=gdrive:LinuxCloudBackup_deleted/$(date +%Y-%m-%d)"
SAFETY_BACKUP=""

# ----------------------------
# Sync each folder
# ----------------------------
for FOLDER in "${FOLDERS[@]}"; do
    SRC="$HOME/$FOLDER"
    DEST="gdrive:LinuxCloudBackup/$FOLDER"

    echo "Checking folder: $SRC" >> "$LOGFILE"
    if [ -d "$SRC" ]; then
        echo "[$(/usr/bin/date)] 🔄 Syncing $FOLDER..." >> "$LOGFILE"
        /usr/bin/rclone sync "$SRC" "$DEST" \
            ${SAFETY_BACKUP:+--backup-dir "$SAFETY_BACKUP"} \
            --fast-list \
            --transfers=4 \
            --checkers=8 \
            --drive-chunk-size=64M \
            --drive-pacer-min-sleep=100ms \
            --exclude=.venv/** \
            --exclude=__pycache__/** \
            --exclude='*.pyc' \
            --exclude=.git/** \
            --exclude=node_modules/** \
            --exclude=.cache/** \
            --exclude=.DS_Store \
            --order-by modtime,desc \
            --retries=5 \
            --low-level-retries=10 \
            --timeout=15m \
            --drive-acknowledge-abuse \
            --log-level INFO \
            --log-file="$LOGFILE"
    else
        echo "[$(/usr/bin/date)] ⚠️ Skipped: $FOLDER not found." >> "$LOGFILE"
    fi
done

TIME_DONE=$(/usr/bin/date)
echo "[$TIME_DONE] ✅ Mirror sync complete" >> "$LOGFILE"
echo "=========================================" >> "$LOGFILE"

# ----------------------------
# Daily Integrity Check (once per day)
# ----------------------------
TODAY_FILE="/tmp/rclone/rclone_last_check"
TODAY=$(/usr/bin/date +%Y-%m-%d)

if [ ! -f "$TODAY_FILE" ] || [ "$(cat "$TODAY_FILE" 2>/dev/null)" != "$TODAY" ]; then
    echo "[$(/usr/bin/date)] 🔎 Running daily integrity check..." >> "$LOGFILE"

    /usr/bin/rclone check "$HOME" "gdrive:LinuxCloudBackup" \
        --one-way \
        --fast-list \
        --log-level INFO \
        --log-file="$LOGFILE"

    echo "$TODAY" > "$TODAY_FILE"
    echo "[$(/usr/bin/date)] ✅ Integrity check complete." >> "$LOGFILE"
fi

# ----------------------------
# Usage Instructions (for systemd setup)
# ----------------------------

: <<'END_USAGE'

# 1️⃣ Copy script to /usr/local/bin/
Edit to omit the usage instructions section (the multi-line comment might cause issues with the script funtionality)

cp "$(pwd)/gdrive_rclone_sync.sh" /usr/local/bin/gdrive_rclone_sync.sh

# 2️⃣ Create Service file
# sudo nano /etc/systemd/system/rclone-backup.service
# Paste below (replace YOUR_USERNAME):

[Unit]
Description=Rclone Google Drive Mirror Backup
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=YOUR_USERNAME
ExecStart=/usr/local/bin/gdrive_rclone_sync.sh
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7

# 3️⃣ Create Timer file
# sudo nano /etc/systemd/system/rclone-backup.timer
# Paste below:

[Unit]
Description=Run Rclone Backup Every Hour

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target

# 4️⃣ Enable timer
# sudo systemctl daemon-reload
# sudo systemctl enable --now rclone-backup.timer

# 5️⃣ Check status
# systemctl list-timers
# journalctl -u rclone-backup.service

END_USAGE
