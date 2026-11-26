#!/usr/bin/env bash
# ==========================================
# HOURLY GOOGLE DRIVE MIRROR BACKUP
# True 1:1 PC <--> Cloud mirror
# ==========================================

set -Eeuo pipefail
umask 077

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/rclone"
LOG="$STATE_DIR/gdrive_rclone_sync.log"
LOCK="$STATE_DIR/gdrive_rclone_sync.lock"

mkdir -p "$STATE_DIR"

# Prevent overlapping runs
exec 9>"$LOCK"
if ! flock -n 9; then
    echo "[$(date)] Another sync is already running. Skipping." >> "$LOG"
    exit 0
fi

# All output into one log
exec >> "$LOG" 2>&1

trap 'rc=$?; printf "\nFinished: %s (exit code: %s)\n" "$(date)" "$rc"' EXIT

echo
echo "=================================================="
echo "Google Drive Sync Started: $(date)"
echo "PID: $$"
echo "=================================================="

# Verify rclone
if ! command -v rclone >/dev/null 2>&1; then
    echo "ERROR: rclone is not installed or not in PATH."
    exit 127
fi

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

REMOTE_ROOT="gdrive:Fedora"

FOLDERS=(
    "Bug-hunting"
    "CTF"
    "Documents"
    "Pictures"
    "Projects"
)

EXCLUDES=(
    --exclude="**/.git/**"
    --exclude="**/.idea/**"
    --exclude="**/.vscode/**"
    --exclude="**/.gradle/**"
    --exclude="**/.svn/**"
    --exclude="**/.hg/**"
    --exclude="**/.terraform/**"

    --exclude="**/build/**"
    --exclude="**/dist/**"
    --exclude="**/target/**"
    --exclude="**/out/**"
    --exclude="**/node_modules/**"
    --exclude="**/vendor/**"
    --exclude="**/Pods/**"

    --exclude="**/.venv/**"
    --exclude="**/venv/**"
    --exclude="**/__pycache__/**"
    --exclude="**/site-packages/**"

    --exclude="**/.pytest_cache/**"
    --exclude="**/.mypy_cache/**"
    --exclude="**/.ruff_cache/**"
    --exclude="**/.tox/**"
    --exclude="**/.next/**"
    --exclude="**/.cache/**"
    --exclude="**/.npm/**"
    --exclude="**/.pnpm-store/**"
    --exclude="**/.phpunit.cache/**"
    --exclude="**/coverage/**"

    --exclude="**/*.pyc"
    --exclude="**/*.tmp"
    --exclude="**/*.swp"
    --exclude="**/*~"
    --exclude="**/.DS_Store"
    --exclude="**/Thumbs.db"
    --exclude="**/*.log"
)

# Optional: keep deleted files for a few days
# SAFETY_BACKUP="--backup-dir=${REMOTE_ROOT}_deleted/$(date +%Y-%m-%d)"
SAFETY_BACKUP=""

# ------------------------------------------------------------
# Sync loop
# ------------------------------------------------------------

FAILED=()
SKIPPED=()

for folder in "${FOLDERS[@]}"; do
    LOCAL="$HOME/$folder"
    REMOTE="${REMOTE_ROOT}/$folder"

    echo
    echo "--------------------------------------------------"
    echo "Folder: $folder"
    echo "Started: $(date)"
    echo "--------------------------------------------------"

    if [[ ! -d "$LOCAL" ]]; then
        echo "WARNING: Local directory does not exist: $LOCAL"
        SKIPPED+=("$folder")
        continue
    fi

    if rclone sync \
        "$LOCAL" \
        "$REMOTE" \
        "${EXCLUDES[@]}" \
        ${SAFETY_BACKUP} \
        --create-empty-src-dirs \
        --fast-list \
        --transfers 4 \
        --checkers 8 \
        --drive-chunk-size 64M \
        --drive-pacer-min-sleep 100ms \
        --retries 5 \
        --low-level-retries 10 \
        --timeout 15m \
        --drive-acknowledge-abuse \
        --log-level INFO
    then
        echo "SUCCESS: $folder"
    else
        rc=$?
        echo "ERROR: $folder failed with exit code $rc"
        FAILED+=("$folder (exit $rc)")
    fi

    echo "Completed: $(date)"
done

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

echo
echo "=================================================="
echo "SYNC SUMMARY"
echo "=================================================="
echo "Total folders: ${#FOLDERS[@]}"
echo "Failed: ${#FAILED[@]}"
echo "Skipped: ${#SKIPPED[@]}"

if ((${#FAILED[@]})); then
    echo
    echo "FAILED FOLDERS:"
    printf ' - %s\n' "${FAILED[@]}"
    exit 1
fi

echo
echo "All available folders processed."

# ----------------------------
# Usage Instructions (for systemd setup)
# ----------------------------

: <<'END_USAGE'

# 1. Initial sync
chmod +x ./gdrive_rclone_sync.sh
./gdrive_rclone_sync.sh

# 2. Create a user service
mkdir -p ~/.config/systemd/user
nano ~/.config/systemd/user/gdrive_rclone_sync.service

# Paste the following (replace YOUR_USERNAME):
[Unit]
Description=Rclone Google Drive Mirror Backup
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=YOUR_USERNAME
ExecStart=%h/Projects/Scripts/Bash-scripts/rclone/gdrive_rclone_sync.sh
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7

# 3. Create Timer
nano ~/.config/systemd/user/gdrive_rclone_sync.timer

# Paste the following:
[Unit]
Description=Run Rclone hourly cloud sync

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target

# 4. Enable systemd service & timer
systemctl --user daemon-reload
systemctl --user enable --now gdrive_rclone_sync.timer


# 5. Make it Persistent across boots
sudo loginctl enable-linger ryan
loginctl show-user ryan | grep Linger


# 6. Tests & troubleshoots
systemctl --user start gdrive_rclone_sync.service
journalctl --user -u gdrive_rclone_sync.service
ls ~/.cache/rclone/sync/
systemctl --user list-timers
systemctl --user status gdrive_rclone_sync.service
systemctl --user status gdrive_rclone_sync.timer
tail -100 $HOME/.local/state/rclone/gdrive_rclone_sync.log

Add $HOME/.cache/rclone/ to bleachbit whitelist

Watch logs for error messages

END_USAGE
