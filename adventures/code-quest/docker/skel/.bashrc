export QE_ENGINE_DIR=/opt/quest-engine/engine
export QE_THEME_DIR=/opt/quest-engine/theme
export QE_STATE_FILE="$HOME/.quest-engine/state"
export QE_PROJECT_DIR="$HOME/project"

PS1='\[\033[0;35m\]⚒ \[\033[0;36m\]\w\[\033[0m\] \$ '

PROMPT_COMMAND="${QE_ENGINE_DIR}/bin/quest-prompt-hook"
