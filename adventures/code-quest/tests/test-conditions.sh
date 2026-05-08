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
export QE_PROJECT_DIR="$HOME/project"

source "$QE_ENGINE_DIR/lib/progress.sh"
source "$QE_ENGINE_DIR/lib/conditions.sh"
source "$QE_ENGINE_DIR/lib/common.sh"

cp -a "$QE_THEME_DIR/project/." "$QE_PROJECT_DIR/"
mkdir -p "$(dirname "$QE_STATE_FILE")"
printf 'CURRENT_QUEST=01\n' > "$QE_STATE_FILE"

assert "Quest 01 incomplete initially" "! check_quest_conditions 01"
sed -i '/CODE_QUEST_PLACEHOLDER/d' "$QE_PROJECT_DIR/src/App.vue"
assert "Quest 01 complete after edit" "check_quest_conditions 01"

assert "Quest 02 incomplete" "! check_quest_conditions 02"
echo '<li>Test</li>' >> "$QE_PROJECT_DIR/src/App.vue"
assert "Quest 02 complete after adding list" "check_quest_conditions 02"

assert "Quest 03 incomplete" "! check_quest_conditions 03"
echo 'background-color: red;' >> "$QE_PROJECT_DIR/src/App.vue"
assert "Quest 03 complete after adding CSS" "check_quest_conditions 03"

assert "Quest 04 incomplete" "! check_quest_conditions 04"
echo '<template><p>Hi</p></template>' > "$QE_PROJECT_DIR/src/components/Test.vue"
assert "Quest 04 complete after creating component" "check_quest_conditions 04"

assert "Quest 05 incomplete" "! check_quest_conditions 05"
echo "import { ref } from 'vue'; const x = ref(0)" > "$QE_PROJECT_DIR/src/components/Counter.vue"
assert "Quest 05 complete after adding ref" "check_quest_conditions 05"

assert "Quest 06 incomplete" "! check_quest_conditions 06"
echo '<input v-model="x" />' >> "$QE_PROJECT_DIR/src/components/Counter.vue"
assert "Quest 06 complete after adding v-model" "check_quest_conditions 06"

assert "Quest 07 incomplete" "! check_quest_conditions 07"
echo '<li v-for="i in items" :key="i">{{ i }}</li>' >> "$QE_PROJECT_DIR/src/components/Counter.vue"
assert "Quest 07 complete after adding v-for" "check_quest_conditions 07"

assert "Quest 08 incomplete" "! check_quest_conditions 08"
mkdir -p "$QE_PROJECT_DIR/src/router"
echo "export default {}" > "$QE_PROJECT_DIR/src/router/index.js"
assert "Quest 08 complete after creating router" "check_quest_conditions 08"

if grep -rn "Flavor lore\.\|TODO" "$QE_THEME_DIR/narrative/" 2>/dev/null >/tmp/cq-placeholder-check.txt; then
    cat /tmp/cq-placeholder-check.txt
    FAIL=$((FAIL + 1))
    echo "FAIL: No placeholder content remains in narratives"
else
    PASS=$((PASS + 1))
    echo "PASS: No placeholder content remains in narratives"
fi

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
