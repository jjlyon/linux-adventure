#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
assert() {
    local name="$1"
    local check="$2"
    if eval "$check"; then
        PASS=$((PASS + 1))
        echo "PASS: $name"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: $name"
    fi
}

export HOME
HOME=$(mktemp -d)
trap 'rm -rf "$HOME"' EXIT
export QE_ENGINE_DIR
QE_ENGINE_DIR="$(cd "$(dirname "$0")/../../../engine" && pwd)"
export QE_THEME_DIR
QE_THEME_DIR="$(cd "$(dirname "$0")/../theme" && pwd)"
export QE_STATE_FILE="$HOME/.quest-engine/state"

source "$QE_ENGINE_DIR/lib/progress.sh"
source "$QE_ENGINE_DIR/lib/conditions.sh"
source "$QE_ENGINE_DIR/lib/common.sh"

cp -a "$QE_THEME_DIR/filesystem/." "$HOME/"
mkdir -p "$(dirname "$QE_STATE_FILE")"
printf 'CURRENT_QUEST=01\n' > "$QE_STATE_FILE"

assert "Initial current quest is 01" '[[ "$(get_current_quest)" == "01" ]]'
assert "next_quest 01 is 02" '[[ "$(next_quest 01)" == "02" ]]'
mark_quest_complete 01
assert "mark_quest_complete advances to 02" '[[ "$(get_current_quest)" == "02" ]]'
set_current_quest 01
assert "completed_count starts at 0" '[[ "$(completed_count)" == "0" ]]'
set_current_quest done
assert "completed_count done is 8" '[[ "$(completed_count)" == "8" ]]'
set_current_quest 01

assert "Quest 01 not complete initially" "! check_quest_conditions 01"
echo "test" > "$HOME/travelers_log.txt"
assert "Quest 01 complete after creating travelers_log.txt" "check_quest_conditions 01"

assert "Quest 02 not complete initially" "! check_quest_conditions 02"
echo "report" > "$HOME/castle/tower/my_report.txt"
assert "Quest 02 complete after creating my_report.txt" "check_quest_conditions 02"

assert "Quest 03 not complete initially" "! check_quest_conditions 03"
printf 'IRON\nHEART\nOAK\n' > "$HOME/enchanted_forest/combined_runes.txt"
assert "Quest 03 complete after combined runes contain all words" "check_quest_conditions 03"

assert "Quest 04 not complete initially" "! check_quest_conditions 04"
original_guest_lines=$(wc -l < "$HOME/village/tavern/guest_book.txt")
assert "Guest book starts with exactly 3 lines" '[[ "$original_guest_lines" -eq 3 ]]'
echo "Notice" > "$HOME/village/notice_board/quest_notice.txt"
echo "Test Traveler" >> "$HOME/village/tavern/guest_book.txt"
assert "Quest 04 complete after notice and appended guest book" "check_quest_conditions 04"

assert "Quest 05 not complete initially" "! check_quest_conditions 05"
mkdir -p "$HOME/village/blacksmith/completed"
mv "$HOME/village/blacksmith/orders.txt" "$HOME/village/blacksmith/completed/orders.txt"
rm "$HOME/village/blacksmith/raw_materials.txt"
assert "Quest 05 complete after organizing blacksmith" "check_quest_conditions 05"

assert "Quest 06 not complete initially" "! check_quest_conditions 06"
chmod -R a+rx "$HOME"
chmod 000 "$HOME/mountain_pass/sealed_gate/gate_lock.txt" "$HOME/mountain_pass/treasure_vault/treasure_manifest.txt"
if runuser -u nobody -- env HOME="$HOME" QE_ENGINE_DIR="$QE_ENGINE_DIR" QE_THEME_DIR="$QE_THEME_DIR" QE_STATE_FILE="$QE_STATE_FILE" bash -c 'source "$QE_ENGINE_DIR/lib/conditions.sh"; source "$QE_ENGINE_DIR/lib/common.sh"; check_quest_conditions 06'; then
    FAIL=$((FAIL + 1))
    echo "FAIL: Quest 06 not complete when protected files are unreadable"
else
    PASS=$((PASS + 1))
    echo "PASS: Quest 06 not complete when protected files are unreadable"
fi
chmod a+r "$HOME/mountain_pass/sealed_gate/gate_lock.txt"
assert "Quest 06 not complete after only reading gate lock" "! check_quest_conditions 06"
echo "AURUM" > "$HOME/mountain_pass/sealed_gate/sigil_report.txt"
if runuser -u nobody -- env HOME="$HOME" QE_ENGINE_DIR="$QE_ENGINE_DIR" QE_THEME_DIR="$QE_THEME_DIR" QE_STATE_FILE="$QE_STATE_FILE" bash -c 'source "$QE_ENGINE_DIR/lib/conditions.sh"; source "$QE_ENGINE_DIR/lib/common.sh"; check_quest_conditions 06'; then
    FAIL=$((FAIL + 1))
    echo "FAIL: Quest 06 not complete before treasure manifest is readable"
else
    PASS=$((PASS + 1))
    echo "PASS: Quest 06 not complete before treasure manifest is readable"
fi
chmod a+r "$HOME/mountain_pass/treasure_vault/treasure_manifest.txt"
assert "Quest 06 complete after recording AURUM and opening manifest" "check_quest_conditions 06"

assert "Quest 07 not complete initially" "! check_quest_conditions 07"
echo "10" > "$HOME/archives/census_answer.txt"
assert "Quest 07 complete after census answer" "check_quest_conditions 07"

assert "Quest 08 not complete initially" "! check_quest_conditions 08"
echo "1: -a 2: -r 3: history" > "$HOME/sages_answers.txt"
assert "Quest 08 complete after sages_answers.txt" "check_quest_conditions 08"

unique_count=$(tail -n +2 "$HOME/archives/census_records.txt" | cut -d, -f2 | sort | uniq | wc -l)
assert "Census records have 10 unique families" '[[ "$unique_count" -eq 10 ]]'

if grep -rn "Flavor lore\.\|placeholder\|TODO" "$QE_THEME_DIR" 2>/dev/null | grep -v ".conf:" >/tmp/qe-placeholder-check.txt 2>/dev/null; then
    cat /tmp/qe-placeholder-check.txt
    FAIL=$((FAIL + 1))
    echo "FAIL: No placeholder content remains"
else
    PASS=$((PASS + 1))
    echo "PASS: No placeholder content remains"
fi

assert "Quest reset preserves current directory" '(set_current_quest 05 && echo "report" > "$HOME/castle/tower/my_report.txt" && cd "$HOME/castle/tower" && printf "YES\n" | "$QE_ENGINE_DIR/bin/quest" reset >/tmp/qe-reset-output && pwd -P >/dev/null && [[ "$(get_current_quest)" == "01" ]] && [[ ! -e "$HOME/castle/tower/my_report.txt" ]])'
assert "Quest reset restores guest book to exactly 3 lines" '[[ "$(wc -l < "$HOME/village/tavern/guest_book.txt")" -eq 3 ]]'
assert "Quest reset restores unreadable gate lock" '! runuser -u nobody -- test -r "$HOME/mountain_pass/sealed_gate/gate_lock.txt"'
assert "Quest reset restores unreadable treasure manifest" '! runuser -u nobody -- test -r "$HOME/mountain_pass/treasure_vault/treasure_manifest.txt"'
chmod a+r "$HOME/mountain_pass/sealed_gate/gate_lock.txt" "$HOME/mountain_pass/treasure_vault/treasure_manifest.txt" 2>/dev/null || true

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
