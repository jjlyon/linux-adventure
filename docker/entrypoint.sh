#!/usr/bin/env bash
set -euo pipefail

export SQ_ENGINE_DIR=/opt/shell-quest/engine
export SQ_THEME_DIR=/opt/shell-quest/theme
export SQ_STATE_FILE=/home/traveler/.shell-quest/state
export HOME=/home/traveler

# Run init as traveler (copies filesystem, creates state)
sudo -E -u traveler "$SQ_ENGINE_DIR/bin/sq-init"

# Set up quest 6 permissions as root: protected files must be
# unreadable until the user chmod's them
protected_files=(
    /home/traveler/mountain_pass/sealed_gate/gate_lock.txt
    /home/traveler/mountain_pass/treasure_vault/treasure_manifest.txt
)
for protected_file in "${protected_files[@]}"; do
    if [[ -f "$protected_file" ]]; then
        chown root:root "$protected_file"
        chmod 000 "$protected_file"
    fi
done

# Show greeting as traveler
sudo -E -u traveler "$SQ_ENGINE_DIR/bin/sq-greeting"

# Drop to traveler without wrapping the interactive shell in `su -c`.
# Keeping the requested command as the foreground process preserves TTY
# job control for `docker compose run` sessions.
exec sudo -E -u traveler -- "$@"
