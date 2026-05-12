#!/usr/bin/env bash
rm -f "$HOME"/{travelers_log.txt,sages_challenge.txt,sages_answers.txt}
rm -f "$HOME/castle/tower/my_report.txt"
rm -f "$HOME/enchanted_forest/combined_runes.txt"
rm -f "$HOME/village/notice_board/quest_notice.txt"
rm -f "$HOME/village/blacksmith/completed/orders.txt"
rm -f "$HOME/archives/census_answer.txt"
rm -f "$HOME/mountain_pass/sealed_gate/gate_lock.txt"
rm -f "$HOME/mountain_pass/sealed_gate/sigil_report.txt"
rm -f "$HOME/mountain_pass/treasure_vault/treasure_manifest.txt"

current_pwd="${PWD:-}"
completed_dir="$HOME/village/blacksmith/completed"
case "$current_pwd" in
    "$completed_dir"|"$completed_dir"/*)
        ;;
    *)
        rm -rf "$completed_dir"
        ;;
esac

cp -a "$QE_THEME_DIR/filesystem/." "$HOME/"
chmod 000 "$HOME/mountain_pass/sealed_gate/gate_lock.txt" 2>/dev/null || true
chmod 000 "$HOME/mountain_pass/treasure_vault/treasure_manifest.txt" 2>/dev/null || true
