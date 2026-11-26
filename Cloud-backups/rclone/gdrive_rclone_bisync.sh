#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

# ============================================================
# Rclone Google Drive Bidirectional Sync
# ============================================================

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/rclone"
LOG="$STATE_DIR/gdrive_rclone_bisync.log"
LOCK="$STATE_DIR/gdrive_rclone_bisync.lock"

mkdir -p "$STATE_DIR"

# Prevent overlapping executions
exec 9>"$LOCK"

if ! flock -n 9; then
    echo "Another bisync process is already running. Skipping."
    exit 0
fi

# All script and Rclone output goes into one log
exec >> "$LOG" 2>&1

trap 'rc=$?; printf "\nFinished: %s (exit code: %s)\n" "$(date)" "$rc"' EXIT

echo
echo "=================================================="
echo "Google Drive Bisync Started: $(date)"
echo "PID: $$"
echo "=================================================="

# Verify dependencies
if ! command -v rclone >/dev/null 2>&1; then
    echo "ERROR: rclone is not installed or not in PATH."
    exit 127
fi

if ! command -v flock >/dev/null 2>&1; then
    echo "ERROR: flock is unavailable."
    exit 127
fi

# Verify configured remote
if ! rclone listremotes | grep -Fxq 'gdrive:'; then
    echo "ERROR: Rclone remote 'gdrive:' is not configured."
    exit 1
fi

# ============================================================
# Sync configuration
# ============================================================

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
    --exclude="**/.vscode/.ropeproject/**"
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
)

# ============================================================
# Synchronization
# ============================================================

FAILED=()
SKIPPED=()

for folder in "${FOLDERS[@]}"; do

    LOCAL="$HOME/$folder"
    REMOTE="gdrive:Fedora/$folder"

    echo
    echo "--------------------------------------------------"
    echo "Folder: $folder"
    echo "Started: $(date)"
    echo "--------------------------------------------------"

    # Never interpret a missing local folder as a deletion.
    if [[ ! -d "$LOCAL" ]]; then
        echo "WARNING: Local directory does not exist: $LOCAL"
        echo "Skipping folder."
        SKIPPED+=("$folder")
        continue
    fi

    if rclone bisync \
        "$LOCAL" \
        "$REMOTE" \
        "${EXCLUDES[@]}" \
        --resilient \
        --recover \
        --max-lock=2m \
        --conflict-resolve newer \
        --conflict-suffix conflict \
        --conflict-loser num \
        --compare size,modtime \
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

# ============================================================
# Final report
# ============================================================

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
fi

if ((${#SKIPPED[@]})); then
    echo
    echo "SKIPPED FOLDERS:"
    printf ' - %s\n' "${SKIPPED[@]}"
fi

if ((${#FAILED[@]})); then
    echo
    echo "Sync completed with errors."
    exit 1
fi

echo
echo "All available folders processed."

# ---------------------------------------
# Usage Instructions (for systemd setup)
# --------------------------------------

: <<'END_USAGE'

# 1. Initial --resync setup
nano ~/.config/rclone/bisync-excludes.txt
rclone bisync "$HOME/dir" "gdrive:Fedora/dir" --resync --resync-mode path1 --exclude-from "$HOME/.config/rclone/bisync-excludes.txt"

# 2. Make sync script executable
chmod +x ./gdrive_rclone_bisync.sh

# 3. Create a user service
mkdir -p ~/.config/systemd/user
nano ~/.config/systemd/user/gdrive_rclone_bisync.service

# Paste the following
[Unit]
Description=Rclone Bisync

[Service]
Type=oneshot
ExecStart=%h/Projects/Scripts/Bash-scripts/rclone/gdrive_rclone_bisync.sh

# 4. Create timer
nano ~/.config/systemd/user/gdrive-rclone-bisync.timer

# Paste the following:
[Unit]
Description=Run rclone bisync hourly

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target

# 5. Enable service & timer
systemctl --user daemon-reload
systemctl --user enable --now gdrive_rclone_bisync.timer

# 6. Make it Persistent across boots
sudo loginctl enable-linger ryan
loginctl show-user ryan | grep Linger

# 7. Configure logrotate
sudo nano /etc/logrotate.d/gdrive-rclone-bisync

## Paste:
$HOME/.local/state/rclone/gdrive-rclone-bisync.log {
    size 10M
    rotate 5
    compress
    missingok
    notifempty
    copytruncate
}

# 8. Tests & troubleshoots

systemctl --user start gdrive_rclone_bisync.service
journalctl --user -u gdrive_rclone_bisync.service -f
grep "FAILED:" logs/gdrive_rclone_bisync.log
ls ~/.cache/rclone/bisync/
pgrep -af 'rclone.*bisync'
tail -100 $HOME/.local/state/rclone/gdrive-rclone-bisync.log
systemctl --user list-timers

Add $HOME/.cache/rclone/ to bleachbit whitelist

Watch logs for error messages

END_USAGE
