#!/usr/bin/env bash


set -uo pipefail

LOG="$HOME/Scripts/Bash-scripts/rclone/logs/gdrive-rclone-bisync.log"

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

EXCLUDES=(
    --exclude="**/node_modules/**"
    --exclude="**/target/**"
    --exclude="**/.git/**"
    --exclude="**/.venv/**"
    --exclude="**/venv/**"
    --exclude="**/__pycache__/**"
    --exclude="**/.cache/**"
    --exclude="**/dist/**"
    --exclude="**/build/**"
    --exclude="**/.next/**"
    --exclude="**/coverage/**"
)

{
    echo
    echo "====================================="
    echo "Starting: $(date)"
} >> "$LOG"

for folder in "${FOLDERS[@]}"; do
    LOCAL="$HOME/$folder"
    REMOTE="gdrive:Fedora/$folder"

    if [ -d "$LOCAL" ]; then
        echo "Syncing: $folder" >> "$LOG"

        rclone bisync \
            "$LOCAL" \
            "$REMOTE" \
            "${EXCLUDES[@]}" \
            --resilient \
            --recover \
            --max-lock=2m \
            --log-file="$LOG" \
            --log-level INFO
    fi
done

echo "Finished: $(date)" >> "$LOG"

# ----------------------------
# Usage Instructions (for systemd setup)
# ----------------------------

: <<'END_USAGE'

# 1. Initial --resync setup

rclone bisync "$HOME/dir" "gdrive:Fedora/dir" --resync --resync-mode path1 "${EXCLUDES[@]}"

# 2. Sync Automation
chmod +x ./gdrive-rclone-bisync.sh

# 3. Create a user service

mkdir -p ~/.config/systemd/user
nano ~/.config/systemd/user/gdrive-rclone-bisync.service

# Paste the following
[Unit]
Description=Rclone Bisync

[Service]
Type=oneshot
ExecStart=%h/Scripts/Bash-scripts/rclone/gdrive-rclone-bisync.sh


# 4. Create timer

nano ~/.config/systemd/user/gdrive-rclone-bisync.timer

# Paste the following
[Unit]
Description=Run rclone bisync hourly

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target

# 5. Enable timer
systemctl --user daemon-reload
systemctl --user enable --now gdrive-rclone-bisync.timer

# 6. Make it Persistent across boots
sudo loginctl enable-linger ryan
loginctl show-user ryan | grep Linger

# 7. Tests & troubleshoots
systemctl --user start gdrive-rclone-bisync.service
journalctl --user -u gdrive-rclone-bisync.service -f
grep "FAILED:" logs/gdrive-rclone-bisync.log
ls ~/.cache/rclone/bisync/
pgrep -af 'rclone.*bisync'
tail -100 logs/gdrive-rclone-bisync.log
systemctl --user list-timers
systemctl --user status gdrive-rclone-bisync.service
systemctl --user status gdrive-rclone-bisync.timer

Watch logs for error messages


END_USAGE
