#!/usr/bin/env bash
set -euo pipefail

export SQ_ENGINE_DIR=/opt/shell-quest/engine
export SQ_THEME_DIR=/opt/shell-quest/theme
export SQ_STATE_FILE=/home/traveler/.shell-quest/state
export HOME=/home/traveler

# Run init as traveler (copies filesystem, creates state)
su traveler -c "$SQ_ENGINE_DIR/bin/sq-init"

# Set up quest 6 permissions as root: gate_lock.txt must be
# unreadable until the user chmod's it
if [[ -f /home/traveler/mountain_pass/sealed_gate/gate_lock.txt ]]; then
    chown root:root /home/traveler/mountain_pass/sealed_gate/gate_lock.txt
    chmod 000 /home/traveler/mountain_pass/sealed_gate/gate_lock.txt
fi

# Show greeting as traveler
su traveler -c "$SQ_ENGINE_DIR/bin/sq-greeting"

# Drop to traveler and exec the CMD
exec su traveler -c "exec $*"
