#!/usr/bin/env bash
QE_STATE_FILE="${QE_STATE_FILE:-$HOME/.quest-engine/state}"

ensure_state() {
    mkdir -p "$(dirname "$QE_STATE_FILE")"
    if [[ ! -f "$QE_STATE_FILE" ]]; then
        printf 'CURRENT_QUEST=01\n' > "$QE_STATE_FILE"
    fi
}

get_current_quest() {
    ensure_state
    source "$QE_STATE_FILE"
    echo "$CURRENT_QUEST"
}

set_current_quest() {
    ensure_state
    printf 'CURRENT_QUEST=%s\n' "$1" > "$QE_STATE_FILE"
}

next_quest() {
    local total=${TOTAL_QUESTS:-8}
    local num=$((10#$1))
    if [[ $num -ge $total ]]; then
        echo done
    else
        printf '%02d' $((num + 1))
    fi
}

mark_quest_complete() {
    set_current_quest "$(next_quest "$1")"
}

quest_number() {
    echo $((10#$1))
}

completed_count() {
    local total=${TOTAL_QUESTS:-8}
    local current
    current=$(get_current_quest)
    if [[ "$current" == "done" ]]; then
        echo "$total"
    else
        echo $(( 10#$current - 1 ))
    fi
}

progress_bar() {
    local total=${TOTAL_QUESTS:-8}
    local done
    done=$(completed_count)
    local bar=""
    for ((i=1; i<=done; i++)); do bar+="██"; done
    for ((i=done+1; i<=total; i++)); do bar+="░░"; done
    printf '  Quest Progress: [%s] %s/%s\n' "$bar" "$done" "$total"
}
