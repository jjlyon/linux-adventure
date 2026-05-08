#!/usr/bin/env bash
set -euo pipefail

export QE_ENGINE_DIR=/opt/quest-engine/engine
export QE_THEME_DIR=/opt/quest-engine/theme
export QE_STATE_FILE=/home/traveler/.quest-engine/state
export QE_PROJECT_DIR=/home/traveler/project
export HOME=/home/traveler

mkdir -p "$QE_PROJECT_DIR"
chown -R traveler:traveler "$QE_PROJECT_DIR" 2>/dev/null || true

sudo -E -u traveler "$QE_ENGINE_DIR/bin/quest-init"

sudo -E -u traveler bash -c 'cd "$QE_PROJECT_DIR" && npm run dev -- --host 0.0.0.0 > /tmp/vite.log 2>&1 &'

sleep 2

sudo -E -u traveler "$QE_ENGINE_DIR/bin/quest-greeting"

exec sudo -E -u traveler -- "$@"
