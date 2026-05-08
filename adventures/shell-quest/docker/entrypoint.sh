#!/usr/bin/env bash
set -euo pipefail

export QE_ENGINE_DIR=/opt/quest-engine/engine
export QE_THEME_DIR=/opt/quest-engine/theme
export QE_STATE_FILE=/home/traveler/.quest-engine/state
export HOME=/home/traveler

sudo -E -u traveler "$QE_ENGINE_DIR/bin/quest-init"

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

sudo -E -u traveler "$QE_ENGINE_DIR/bin/quest-greeting"

exec sudo -E -u traveler -- "$@"
