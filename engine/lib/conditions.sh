#!/usr/bin/env bash

check_quest_conditions() {
    local q="$1"
    local conf="${QE_THEME_DIR}/quests/quest-${q}.conf"
    [[ -f "$conf" ]] || return 1
    source "$conf"
    eval "$QUEST_CONDITION" 2>/dev/null && return 0 || return 1
}
