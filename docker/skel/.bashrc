export SQ_ENGINE_DIR=/opt/shell-quest/engine
export SQ_THEME_DIR=/opt/shell-quest/theme
export SQ_STATE_FILE=$HOME/.shell-quest/state
export PATH="$SQ_ENGINE_DIR/bin:$PATH"
PROMPT_COMMAND='"$SQ_ENGINE_DIR/bin/sq-prompt-hook"'
