#!/usr/bin/env bash
set -euo pipefail
SQ_STATE_FILE="${SQ_STATE_FILE:-$HOME/.shell-quest/state}"
ensure_state(){ mkdir -p "$(dirname "$SQ_STATE_FILE")"; [[ -f "$SQ_STATE_FILE" ]] || echo 'CURRENT_QUEST=01' > "$SQ_STATE_FILE"; source "$SQ_STATE_FILE"; }
get_current_quest(){ ensure_state >/dev/null 2>&1 || true; source "$SQ_STATE_FILE"; echo "$CURRENT_QUEST"; }
set_current_quest(){ printf 'CURRENT_QUEST=%s\n' "$1" > "$SQ_STATE_FILE"; }
next_quest(){ case "$1" in 01)echo 02;;02)echo 03;;03)echo 04;;04)echo 05;;05)echo 06;;06)echo 07;;07)echo 08;;08)echo done;;*)echo done;;esac; }
mark_quest_complete(){ set_current_quest "$(next_quest "$1")"; }
progress_bar(){ local n=${1:-0}; printf '[%0.s█' $(seq 1 "$n"); printf '%0.s░' $(seq 1 $((8-n))); printf '] %s/8' "$n"; }
