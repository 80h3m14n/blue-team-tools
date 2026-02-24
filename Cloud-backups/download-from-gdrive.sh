#!/bin/bash
# =============================================================================
# ONE-TIME GOOGLE DRIVE → LOCAL FULL DOWNLOAD (Fresh OS Install)
# Copies everything from cloud backup to local mirror folder
# SAFE: Uses 'copy' → no local deletions, even if something already exists
# Date-aware log + progress + final size check
# =============================================================================
set -u   # exit on undefined variables

PATH=/usr/bin:/bin

LOCKFILE="/tmp/rclone_gdrive_download.lock"
LOGFILE="$HOME/cloud-download.log"
LOCAL_DEST="$HOME/FromCloud"          # ← Change this path if you prefer

REMOTE="gdrive:LinuxCloudBackup"

# Create destination if missing
mkdir -p "$LOCAL_DEST"

# ----------------------------
# Log setup + rotation (5 MB → gzip old, delete >7 days)
# ----------------------------
MAX_LOG=$((5 * 1024 * 1024))
if [ -f "$LOGFILE" ]; then
    size=$(stat -c%s "$LOGFILE" 2>/dev/null || echo 0)
    if (( size >= MAX_LOG )); then
        mv "$LOGFILE" "$LOGFILE.$(date +%Y%m%d_%H%M%S)"
        gzip -f "$LOGFILE."* 2>/dev/null
        find "$(dirname "$LOGFILE")" -name "$(basename "$LOGFILE").*.gz" -mtime +7 -delete
    fi
fi

# ----------------------------
# Single instance lock
# ----------------------------
exec 200>"$LOCKFILE"
flock -n 200 || {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Already running → exiting" >> "$LOGFILE"
    exit 1
}

echo "══════════════════════════════════════════════" >> "$LOGFILE"
echo "Starting full Google Drive → Local copy"       >> "$LOGFILE"
echo "   Date: $(date)"                               >> "$LOGFILE"
echo " Source: $REMOTE"                               >> "$LOGFILE"
echo "   Dest: $LOCAL_DEST"                           >> "$LOGFILE"
echo "══════════════════════════════════════════════" >> "$LOGFILE"

# ----------------------------
# Main download command
#   - copy          → one-time, no delete
#   - fast-list     → much faster listing on Drive
#   - high parallelism for small files
#   - no bwlimit    → max your download speed (unless quota fear)
# ----------------------------
rclone copy "$REMOTE" "$LOCAL_DEST" \
    --drive-acknowledge-abuse \
    --fast-list \
    --transfers=12 \
    --checkers=24 \
    --drive-chunk-size=64M \
    --tpslimit=12 \
    --tpslimit-burst=25 \
    --multi-thread-streams=4 \
    --multi-thread-chunk-size=32M \
    --retries=6 \
    --low-level-retries=15 \
    --timeout=20m \
    --log-level INFO \
    --log-file "$LOGFILE" \
    --progress \
    --stats 1m \
    --stats-one-line

# If you get rate-limit errors → lower --tpslimit to 8–10 and --transfers to 8

exit_code=$?

TIME_END=$(date '+%Y-%m-%d %H:%M:%S')

if [ $exit_code -eq 0 ]; then
    echo "══════════════════════════════════════════════" >> "$LOGFILE"
    echo "Copy FINISHED successfully at $TIME_END"       >> "$LOGFILE"
    echo "" >> "$LOGFILE"

    echo "Cloud side size:" >> "$LOGFILE"
    rclone size "$REMOTE" --fast-list >> "$LOGFILE" 2>&1

    echo "" >> "$LOGFILE"
    echo "Local side size:" >> "$LOGFILE"
    rclone size "$LOCAL_DEST" >> "$LOGFILE" 2>&1

    echo "" >> "$LOGFILE"
    echo "Tip: Compare numbers above. They should be very close." >> "$LOGFILE"
else
    echo "══════════════════════════════════════════════" >> "$LOGFILE"
    echo "Copy FINISHED with ERRORS (code $exit_code) at $TIME_END" >> "$LOGFILE"
    echo "Check log for details." >> "$LOGFILE"
fi

echo "══════════════════════════════════════════════" >> "$LOGFILE"

# Unlock happens automatically on exit


# Usage:
# chmod +x ~/download-from-gdrive.sh
#./download-from-gdrive.sh | tee -a ~/download-progress.txt

# or run in background
# nohup ./download-from-gdrive.sh &
# tail -f ~/cloud-download.log

# Dry run:
# rclone copy gdrive:LinuxCloudBackup ~/FromCloud \
#    --drive-acknowledge-abuse --fast-list --dry-run --progress --log-level INFO
#
