#!/usr/bin/env bash
set -euo pipefail
export SQ_ENGINE_DIR=/opt/shell-quest/engine
export SQ_THEME_DIR=/opt/shell-quest/theme
export SQ_STATE_FILE=$HOME/.shell-quest/state
$SQ_ENGINE_DIR/bin/sq-init
$SQ_ENGINE_DIR/bin/sq-greeting
exec bash -i
