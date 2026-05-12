#!/usr/bin/env bash
quest_id="$1"
if [[ "$quest_id" == "07" ]]; then
    cp "${QE_THEME_DIR}/narrative/sages_challenge.txt" "$HOME/sages_challenge.txt" 2>/dev/null || true
fi
