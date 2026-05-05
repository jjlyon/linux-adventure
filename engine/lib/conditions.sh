#!/usr/bin/env bash
set -euo pipefail
check_quest_conditions(){ local q=$1; source "${SQ_THEME_DIR}/quests/quest-${q}.conf"; eval "$QUEST_CONDITION"; }
