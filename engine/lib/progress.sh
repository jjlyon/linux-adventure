#!/usr/bin/env bash
SQ_STATE_FILE="${SQ_STATE_FILE:-$HOME/.shell-quest/state}"

ensure_state() {
    mkdir -p "$(dirname "$SQ_STATE_FILE")"
    if [[ ! -f "$SQ_STATE_FILE" ]]; then
        printf 'CURRENT_QUEST=01
' > "$SQ_STATE_FILE"
    fi
}

get_current_quest() {
    ensure_state
    source "$SQ_STATE_FILE"
    echo "$CURRENT_QUEST"
}

set_current_quest() {
    ensure_state
    printf 'CURRENT_QUEST=%s
' "$1" > "$SQ_STATE_FILE"
}

next_quest() {
    case "$1" in
        01) echo 02 ;; 02) echo 03 ;; 03) echo 04 ;; 04) echo 05 ;;
        05) echo 06 ;; 06) echo 07 ;; 07) echo 08 ;; 08) echo done ;;
        *) echo done ;;
    esac
}

mark_quest_complete() {
    set_current_quest "$(next_quest "$1")"
}

quest_number() {
    # Convert quest ID like "03" to plain number 3 for display
    echo $((10#$1))
}

completed_count() {
    local current
    current=$(get_current_quest)
    if [[ "$current" == "done" ]]; then
        echo 8
    else
        echo $(( 10#$current - 1 ))
    fi
}

progress_bar() {
    local done
    done=$(completed_count)
    local bar=""
    for ((i=1; i<=done; i++)); do bar+="██"; done
    for ((i=done+1; i<=8; i++)); do bar+="░░"; done
    printf '  Quest Progress: [%s] %s/8
' "$bar" "$done"
}
