# Shell Quest environment
export SQ_ENGINE_DIR=/opt/shell-quest/engine
export SQ_THEME_DIR=/opt/shell-quest/theme
export SQ_STATE_FILE="$HOME/.shell-quest/state"

# Quest command is in PATH via symlink in /usr/local/bin

# Themed prompt
PS1='\[[0;32m\]⚔ \[[0;36m\]\w\[[0m\] \$ '

# Passive quest progress detection -- runs before every prompt
PROMPT_COMMAND="${SQ_ENGINE_DIR}/bin/sq-prompt-hook"
