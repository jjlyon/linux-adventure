# Quest Engine Refactor + Code Quest Implementation

## Overview

Refactor the Shell Quest repo into a multi-adventure platform with a shared quest engine. The engine uses a generic `QE_` prefix and delegates adventure-specific logic to theme hooks. Each adventure has its own Dockerfile, docker-compose, theme directory, and tests.

This spec adds a second adventure — **Code Quest** — teaching Vue 3 web development to Shell Quest graduates. Same philosophy: Docker-based, quest-driven, passive progress detection. Users edit Vue components via a mounted volume in their host editor, view the site at localhost:5173, and interact with the quest engine in the container terminal.

**Target audience for Code Quest**: Shell Quest graduates. They know `cat`, `ls`, `cd`, `grep`, `find`, `echo >`, pipes, etc. They do NOT know HTML, CSS, JavaScript, or web frameworks. Every web concept must be taught from scratch.

---

## New Project Structure

```
├── engine/                              # SHARED quest engine
│   ├── bin/
│   │   ├── quest                        # CLI: status, map, reset
│   │   ├── quest-init                   # first-run initialization
│   │   ├── quest-greeting               # login banner
│   │   └── quest-prompt-hook            # PROMPT_COMMAND hook
│   └── lib/
│       ├── common.sh                    # colors, banners, theme loading
│       ├── conditions.sh                # quest condition checking
│       └── progress.sh                  # state management, progress bar
│
├── adventures/
│   ├── shell-quest/
│   │   ├── Dockerfile
│   │   ├── docker-compose.yml
│   │   ├── Makefile
│   │   ├── docker/
│   │   │   ├── entrypoint.sh
│   │   │   ├── skel/
│   │   │   │   ├── .bashrc
│   │   │   │   └── .profile
│   │   │   └── sudoers.d/
│   │   │       └── quest-user
│   │   ├── theme/
│   │   │   ├── theme.conf
│   │   │   ├── hooks/
│   │   │   │   ├── init.sh
│   │   │   │   ├── reset.sh
│   │   │   │   └── on-complete.sh
│   │   │   ├── quests/                  ← MOVE from themes/medieval/quests/
│   │   │   ├── narrative/               ← MOVE from themes/medieval/narrative/
│   │   │   └── filesystem/              ← MOVE from themes/medieval/filesystem/
│   │   └── tests/
│   │       └── test-conditions.sh
│   │
│   └── code-quest/
│       ├── Dockerfile
│       ├── docker-compose.yml
│       ├── Makefile
│       ├── .gitignore
│       ├── docker/
│       │   ├── entrypoint.sh
│       │   └── skel/
│       │       ├── .bashrc
│       │       └── .profile
│       ├── theme/
│       │   ├── theme.conf
│       │   ├── hooks/
│       │   │   ├── init.sh
│       │   │   └── reset.sh
│       │   ├── quests/                  (8 quest configs)
│       │   ├── narrative/               (greeting, 8 intros, 8 completes, finale)
│       │   ├── project/                 (Vue 3 project template)
│       │   │   ├── package.json
│       │   │   ├── package-lock.json    ← GENERATE with npm install
│       │   │   ├── vite.config.js
│       │   │   ├── index.html
│       │   │   └── src/
│       │   │       ├── main.js
│       │   │       ├── App.vue
│       │   │       ├── style.css
│       │   │       ├── assets/          (empty dir)
│       │   │       └── components/
│       │   │           └── .gitkeep
│       │   └── reference/
│       │       └── vue-reference.txt
│       └── tests/
│           └── test-conditions.sh
│
├── Makefile                             # top-level, delegates to adventures
└── .gitignore
```

---

## Part 1: Shared Engine

All engine scripts use the `QE_` prefix. Environment variables (`QE_ENGINE_DIR`, `QE_THEME_DIR`, `QE_STATE_FILE`) are set by each adventure's `.bashrc` and entrypoint.

Delete `engine/lib/theme.sh` (unused — theme loading is now in common.sh).

### engine/lib/common.sh

```bash
#!/usr/bin/env bash
QE_BOLD='\033[1m'
QE_GREEN='\033[0;32m'
QE_CYAN='\033[0;36m'
QE_YELLOW='\033[0;33m'
QE_RESET='\033[0m'

if [[ -n "${QE_THEME_DIR:-}" && -f "${QE_THEME_DIR}/theme.conf" ]]; then
    source "${QE_THEME_DIR}/theme.conf"
fi

qe_banner() {
    printf '\n'
    printf '  %b✦ ═══════════════════════════════════════ ✦%b\n' "$QE_YELLOW" "$QE_RESET"
    printf '\n'
}

qe_banner_end() {
    printf '\n'
    printf '  %b✦ ═══════════════════════════════════════ ✦%b\n' "$QE_YELLOW" "$QE_RESET"
    printf '\n'
}
```

### engine/lib/progress.sh

```bash
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
```

### engine/lib/conditions.sh

```bash
#!/usr/bin/env bash

check_quest_conditions() {
    local q="$1"
    local conf="${QE_THEME_DIR}/quests/quest-${q}.conf"
    [[ -f "$conf" ]] || return 1
    source "$conf"
    eval "$QUEST_CONDITION" 2>/dev/null && return 0 || return 1
}
```

### engine/bin/quest

```bash
#!/usr/bin/env bash
set -euo pipefail

source "${QE_ENGINE_DIR}/lib/progress.sh"
source "${QE_ENGINE_DIR}/lib/common.sh"

current=$(get_current_quest)

case "${1:-status}" in
    status)
        if [[ "$current" == "done" ]]; then
            printf '\n  All quests complete! You are a true champion.\n'
            progress_bar
            printf '\n'
        else
            source "${QE_THEME_DIR}/quests/quest-${current}.conf"
            printf '\n'
            progress_bar
            printf '\n  %bCurrent Quest:%b %s - %s\n\n' "$QE_BOLD" "$QE_RESET" "$(quest_number "$current")" "$QUEST_TITLE"
            cat "${QE_THEME_DIR}/narrative/quest-${current}-intro.txt"
        fi
        ;;
    map)
        printf '\n  %b═══ QUEST MAP ═══%b\n\n' "$QE_BOLD" "$QE_RESET"
        current_num=0
        [[ "$current" != "done" ]] && current_num=$((10#$current))
        for ((n=1; n<=${TOTAL_QUESTS:-8}; n++)); do
            i=$(printf '%02d' "$n")
            source "${QE_THEME_DIR}/quests/quest-${i}.conf"
            if [[ "$current" == "done" ]] || [[ "$n" -lt "$current_num" ]]; then
                printf '  %b[✓]%b Quest %s: %s\n' "$QE_GREEN" "$QE_RESET" "$n" "$QUEST_TITLE"
            elif [[ "$i" == "$current" ]]; then
                printf '  %b[>]%b Quest %s: %s  %b(current)%b\n' "$QE_YELLOW" "$QE_RESET" "$n" "$QUEST_TITLE" "$QE_YELLOW" "$QE_RESET"
            else
                printf '  [ ] Quest %s: %s\n' "$n" "$QUEST_TITLE"
            fi
        done
        printf '\n'
        progress_bar
        printf '\n'
        ;;
    reset)
        printf '  This will reset all progress and restore the original files.\n'
        printf '  Are you sure? Type YES to confirm: '
        read -r confirm
        if [[ "$confirm" == "YES" ]]; then
            if [[ -f "$QE_THEME_DIR/hooks/reset.sh" ]]; then
                source "$QE_THEME_DIR/hooks/reset.sh"
            fi
            set_current_quest 01
            printf '  Reset complete. Type quest to see your first objective.\n'
        else
            printf '  Reset cancelled.\n'
        fi
        ;;
    *)
        printf 'Usage: quest [map|reset]\n'
        printf '  quest        Show current objective\n'
        printf '  quest map    Show all quests and progress\n'
        printf '  quest reset  Start over from the beginning\n'
        ;;
esac
```

### engine/bin/quest-init

```bash
#!/usr/bin/env bash
set -euo pipefail

: "${QE_THEME_DIR:=/opt/quest-engine/theme}"
: "${QE_STATE_FILE:=$HOME/.quest-engine/state}"

if [[ -f "$QE_STATE_FILE" ]]; then
    exit 0
fi

if [[ -f "$QE_THEME_DIR/hooks/init.sh" ]]; then
    source "$QE_THEME_DIR/hooks/init.sh"
fi

mkdir -p "$(dirname "$QE_STATE_FILE")"
printf 'CURRENT_QUEST=01\n' > "$QE_STATE_FILE"
```

### engine/bin/quest-greeting

```bash
#!/usr/bin/env bash
source "${QE_ENGINE_DIR}/lib/common.sh"
source "${QE_ENGINE_DIR}/lib/progress.sh"

current=$(get_current_quest)

cat "${QE_THEME_DIR}/narrative/greeting.txt"

if [[ "$current" != "01" && "$current" != "done" ]]; then
    printf '\n'
    progress_bar
    printf '\n  You were last working on quest %s.\n' "$(quest_number "$current")"
    printf '  Type %bquest%b to see your current objective.\n\n' "$QE_BOLD" "$QE_RESET"
elif [[ "$current" == "done" ]]; then
    printf '\n'
    progress_bar
    printf '\n  You have completed all quests!\n\n'
fi
```

### engine/bin/quest-prompt-hook

```bash
#!/usr/bin/env bash
# NO set -e -- this runs on every prompt

source "${QE_ENGINE_DIR}/lib/progress.sh"
source "${QE_ENGINE_DIR}/lib/conditions.sh"
source "${QE_ENGINE_DIR}/lib/common.sh"

current=$(get_current_quest 2>/dev/null) || exit 0
[[ "$current" == "done" ]] && exit 0

if check_quest_conditions "$current"; then
    mark_quest_complete "$current"

    local_complete="${QE_THEME_DIR}/narrative/quest-${current}-complete.txt"
    [[ -f "$local_complete" ]] && cat "$local_complete"

    if [[ -x "$QE_THEME_DIR/hooks/on-complete.sh" ]]; then
        "$QE_THEME_DIR/hooks/on-complete.sh" "$current" 2>/dev/null || true
    fi

    next=$(get_current_quest)

    if [[ "$next" != "done" ]]; then
        local_intro="${QE_THEME_DIR}/narrative/quest-${next}-intro.txt"
        [[ -f "$local_intro" ]] && cat "$local_intro"
    else
        local_finale="${QE_THEME_DIR}/narrative/finale.txt"
        [[ -f "$local_finale" ]] && cat "$local_finale"
    fi
fi
```

---

## Part 2: Shell Quest Adventure

### Migration of existing files

Move these directories as-is (no content changes needed):
- `themes/medieval/quests/` → `adventures/shell-quest/theme/quests/`
- `themes/medieval/narrative/` → `adventures/shell-quest/theme/narrative/`
- `themes/medieval/filesystem/` → `adventures/shell-quest/theme/filesystem/`
- `themes/medieval/theme.conf` → `adventures/shell-quest/theme/theme.conf`

### adventures/shell-quest/Dockerfile

```dockerfile
FROM ubuntu:24.04

RUN yes | unminimize

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    coreutils \
    findutils \
    grep \
    less \
    man-db \
    manpages \
    sudo \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash traveler

COPY engine/ /opt/quest-engine/engine/
COPY adventures/shell-quest/theme/ /opt/quest-engine/theme/

RUN chmod +x /opt/quest-engine/engine/bin/* \
    && ln -s /opt/quest-engine/engine/bin/quest /usr/local/bin/quest \
    && if [ -d /opt/quest-engine/theme/hooks ]; then chmod +x /opt/quest-engine/theme/hooks/*.sh 2>/dev/null || true; fi

COPY adventures/shell-quest/docker/sudoers.d/quest-user /etc/sudoers.d/quest-user
RUN chmod 440 /etc/sudoers.d/quest-user

COPY adventures/shell-quest/docker/skel/.bashrc /home/traveler/.bashrc
COPY adventures/shell-quest/docker/skel/.profile /home/traveler/.profile
RUN chown traveler:traveler /home/traveler/.bashrc /home/traveler/.profile

COPY adventures/shell-quest/docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /home/traveler
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash", "--login", "-i"]
```

### adventures/shell-quest/docker-compose.yml

```yaml
services:
  shell-quest:
    build:
      context: ../..
      dockerfile: adventures/shell-quest/Dockerfile
    image: shell-quest
    hostname: linuxia
    tty: true
    stdin_open: true
```

### adventures/shell-quest/Makefile

```makefile
.PHONY: build run test clean

build:
	docker compose build

run:
	docker compose run --rm shell-quest

test:
	bash tests/test-conditions.sh

clean:
	docker rmi shell-quest 2>/dev/null || true
```

### adventures/shell-quest/docker/entrypoint.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

export QE_ENGINE_DIR=/opt/quest-engine/engine
export QE_THEME_DIR=/opt/quest-engine/theme
export QE_STATE_FILE=/home/traveler/.quest-engine/state
export HOME=/home/traveler

sudo -E -u traveler "$QE_ENGINE_DIR/bin/quest-init"

protected_files=(
    /home/traveler/mountain_pass/sealed_gate/gate_lock.txt
    /home/traveler/mountain_pass/treasure_vault/treasure_manifest.txt
)
for protected_file in "${protected_files[@]}"; do
    if [[ -f "$protected_file" ]]; then
        chown root:root "$protected_file"
        chmod 000 "$protected_file"
    fi
done

sudo -E -u traveler "$QE_ENGINE_DIR/bin/quest-greeting"

exec sudo -E -u traveler -- "$@"
```

### adventures/shell-quest/docker/skel/.bashrc

```bash
export QE_ENGINE_DIR=/opt/quest-engine/engine
export QE_THEME_DIR=/opt/quest-engine/theme
export QE_STATE_FILE="$HOME/.quest-engine/state"

PS1='\[\033[0;32m\]⚔ \[\033[0;36m\]\w\[\033[0m\] \$ '

PROMPT_COMMAND="${QE_ENGINE_DIR}/bin/quest-prompt-hook"
```

### adventures/shell-quest/docker/skel/.profile

```bash
if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
```

### adventures/shell-quest/docker/sudoers.d/quest-user

```
traveler ALL=(root) NOPASSWD: /bin/chmod * /home/traveler/mountain_pass/sealed_gate/*, /usr/bin/chmod * /home/traveler/mountain_pass/sealed_gate/*, /bin/chmod * /home/traveler/mountain_pass/treasure_vault/*, /usr/bin/chmod * /home/traveler/mountain_pass/treasure_vault/*
```

### adventures/shell-quest/theme/hooks/init.sh

```bash
#!/usr/bin/env bash
cp -a "$QE_THEME_DIR/filesystem/." "$HOME/"
```

### adventures/shell-quest/theme/hooks/reset.sh

```bash
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
```

### adventures/shell-quest/theme/hooks/on-complete.sh

```bash
#!/usr/bin/env bash
quest_id="$1"
if [[ "$quest_id" == "07" ]]; then
    cp "${QE_THEME_DIR}/narrative/sages_challenge.txt" "$HOME/sages_challenge.txt" 2>/dev/null || true
fi
```

### adventures/shell-quest/tests/test-conditions.sh

```bash
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
```

---

## Part 3: Code Quest Adventure

Code Quest teaches Vue 3 web development. Users edit Vue components in their host editor (VS Code etc.), view results at localhost:5173, and interact with the quest engine in the container terminal. The Vite dev server runs inside the container and auto-reloads on file changes.

### adventures/code-quest/Dockerfile

```dockerfile
FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    less \
    sudo \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash traveler

COPY engine/ /opt/quest-engine/engine/
COPY adventures/code-quest/theme/ /opt/quest-engine/theme/

RUN chmod +x /opt/quest-engine/engine/bin/* \
    && ln -s /opt/quest-engine/engine/bin/quest /usr/local/bin/quest \
    && if [ -d /opt/quest-engine/theme/hooks ]; then chmod +x /opt/quest-engine/theme/hooks/*.sh 2>/dev/null || true; fi

COPY adventures/code-quest/docker/skel/.bashrc /home/traveler/.bashrc
COPY adventures/code-quest/docker/skel/.profile /home/traveler/.profile
RUN chown traveler:traveler /home/traveler/.bashrc /home/traveler/.profile

COPY adventures/code-quest/docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN mkdir -p /home/traveler/project && chown traveler:traveler /home/traveler/project

EXPOSE 5173

WORKDIR /home/traveler
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash", "--login", "-i"]
```

### adventures/code-quest/docker-compose.yml

```yaml
services:
  code-quest:
    build:
      context: ../..
      dockerfile: adventures/code-quest/Dockerfile
    image: code-quest
    hostname: code-forge
    tty: true
    stdin_open: true
    ports:
      - "5173:5173"
    volumes:
      - ./project:/home/traveler/project
```

### adventures/code-quest/Makefile

```makefile
.PHONY: build run test clean

build:
	docker compose build

run:
	docker compose run --rm code-quest

test:
	bash tests/test-conditions.sh

clean:
	docker rmi code-quest 2>/dev/null || true
```

### adventures/code-quest/.gitignore

```
project/
```

### adventures/code-quest/docker/entrypoint.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

export QE_ENGINE_DIR=/opt/quest-engine/engine
export QE_THEME_DIR=/opt/quest-engine/theme
export QE_STATE_FILE=/home/traveler/.quest-engine/state
export QE_PROJECT_DIR=/home/traveler/project
export HOME=/home/traveler

sudo -E -u traveler "$QE_ENGINE_DIR/bin/quest-init"

sudo -E -u traveler bash -c "cd $QE_PROJECT_DIR && npm run dev -- --host 0.0.0.0 > /tmp/vite.log 2>&1 &"

sleep 2

sudo -E -u traveler "$QE_ENGINE_DIR/bin/quest-greeting"

exec sudo -E -u traveler -- "$@"
```

### adventures/code-quest/docker/skel/.bashrc

```bash
export QE_ENGINE_DIR=/opt/quest-engine/engine
export QE_THEME_DIR=/opt/quest-engine/theme
export QE_STATE_FILE="$HOME/.quest-engine/state"
export QE_PROJECT_DIR="$HOME/project"

PS1='\[\033[0;35m\]⚒ \[\033[0;36m\]\w\[\033[0m\] \$ '

PROMPT_COMMAND="${QE_ENGINE_DIR}/bin/quest-prompt-hook"
```

### adventures/code-quest/docker/skel/.profile

```bash
if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
```

### adventures/code-quest/theme/theme.conf

```bash
THEME_NAME="Chronicle of Linuxia"
THEME_DISPLAY_NAME="The Chronicle of Linuxia"
MENTOR_NAME="Aldric the Chronicler"
HOSTNAME="code-forge"
TOTAL_QUESTS=8
```

### adventures/code-quest/theme/hooks/init.sh

```bash
#!/usr/bin/env bash
: "${QE_PROJECT_DIR:=$HOME/project}"

if [[ ! -f "$QE_PROJECT_DIR/package.json" ]]; then
    cp -a "$QE_THEME_DIR/project/." "$QE_PROJECT_DIR/"
fi

if [[ ! -d "$QE_PROJECT_DIR/node_modules" ]]; then
    cd "$QE_PROJECT_DIR"
    npm ci --silent 2>/dev/null || npm install --silent
fi

cp "$QE_THEME_DIR/reference/vue-reference.txt" "$QE_PROJECT_DIR/vue-reference.txt" 2>/dev/null || true
```

### adventures/code-quest/theme/hooks/reset.sh

```bash
#!/usr/bin/env bash
: "${QE_PROJECT_DIR:=$HOME/project}"

find "$QE_PROJECT_DIR/src/components" -name "*.vue" -delete 2>/dev/null || true
rm -rf "$QE_PROJECT_DIR/src/router" 2>/dev/null || true
rm -rf "$QE_PROJECT_DIR/src/views" 2>/dev/null || true

cp "$QE_THEME_DIR/project/src/App.vue" "$QE_PROJECT_DIR/src/App.vue"
cp "$QE_THEME_DIR/project/src/main.js" "$QE_PROJECT_DIR/src/main.js"
cp "$QE_THEME_DIR/project/src/style.css" "$QE_PROJECT_DIR/src/style.css"

touch "$QE_PROJECT_DIR/src/components/.gitkeep"

cp "$QE_THEME_DIR/reference/vue-reference.txt" "$QE_PROJECT_DIR/vue-reference.txt" 2>/dev/null || true
```

### Quest Configuration Files

All in `adventures/code-quest/theme/quests/`.

**quest-01.conf**
```bash
QUEST_ID="01"
QUEST_TITLE="The Workshop"
QUEST_TEACHES="project structure, npm, dev server"
QUEST_CONDITION='! grep -q "CODE_QUEST_PLACEHOLDER" "$QE_PROJECT_DIR/src/App.vue" 2>/dev/null'
```

**quest-02.conf**
```bash
QUEST_ID="02"
QUEST_TITLE="The Scribe's Quill"
QUEST_TEACHES="HTML basics"
QUEST_CONDITION='grep -q "<li>" "$QE_PROJECT_DIR/src/App.vue" 2>/dev/null'
```

**quest-03.conf**
```bash
QUEST_ID="03"
QUEST_TITLE="Colors & Flourishes"
QUEST_TEACHES="CSS basics"
QUEST_CONDITION='grep -qE "(background-color|border|color:)" "$QE_PROJECT_DIR/src/App.vue" 2>/dev/null'
```

**quest-04.conf**
```bash
QUEST_ID="04"
QUEST_TITLE="Building Blocks"
QUEST_TEACHES="Vue components"
QUEST_CONDITION='find "$QE_PROJECT_DIR/src/components" -name "*.vue" -not -name ".gitkeep" 2>/dev/null | grep -q .'
```

**quest-05.conf**
```bash
QUEST_ID="05"
QUEST_TITLE="Living Magic"
QUEST_TEACHES="reactivity, ref(), interpolation"
QUEST_CONDITION='grep -rq "ref(" "$QE_PROJECT_DIR/src/" 2>/dev/null'
```

**quest-06.conf**
```bash
QUEST_ID="06"
QUEST_TITLE="The People's Voice"
QUEST_TEACHES="events, v-model"
QUEST_CONDITION='grep -rq "v-model" "$QE_PROJECT_DIR/src/" 2>/dev/null'
```

**quest-07.conf**
```bash
QUEST_ID="07"
QUEST_TITLE="The Many & the Few"
QUEST_TEACHES="v-for, v-if, lists"
QUEST_CONDITION='grep -rq "v-for" "$QE_PROJECT_DIR/src/" 2>/dev/null'
```

**quest-08.conf**
```bash
QUEST_ID="08"
QUEST_TITLE="The Grand Map"
QUEST_TEACHES="Vue Router, multi-page apps"
QUEST_CONDITION='[ -f "$QE_PROJECT_DIR/src/router/index.js" ] || [ -f "$QE_PROJECT_DIR/src/router/index.ts" ]'
```

### Vue Project Template

All in `adventures/code-quest/theme/project/`. This is a standard Vite + Vue 3 project.

**IMPORTANT**: After creating `package.json`, run `npm install` in the `theme/project/` directory to generate a real `package-lock.json`. Include the generated lock file so `npm ci` works in the container. Do NOT write a fake lock file.

**package.json**
```json
{
  "name": "chronicle-of-linuxia",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "vue": "^3.5.0"
  },
  "devDependencies": {
    "@vitejs/plugin-vue": "^5.2.0",
    "vite": "^6.0.0"
  }
}
```

**vite.config.js**
```js
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    host: '0.0.0.0',
    port: 5173,
  },
})
```

The `host: '0.0.0.0'` is critical — it makes the dev server accessible from the host through Docker's port mapping.

**index.html**
```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>The Chronicle of Linuxia</title>
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="/src/main.js"></script>
  </body>
</html>
```

**src/main.js**
```js
import { createApp } from 'vue'
import App from './App.vue'
import './style.css'

createApp(App).mount('#app')
```

**src/style.css**
```css
body {
  margin: 0;
  font-family: Georgia, 'Times New Roman', serif;
  background-color: #fdf6e3;
  color: #3c3836;
}
```

**src/App.vue**
```vue
<script setup>
// CODE_QUEST_PLACEHOLDER
//
// Welcome to Code Quest!
//
// This is the <script> section of a Vue component.
// JavaScript code goes here. You'll learn to add code
// in later quests. For now, you can leave this empty.
</script>

<template>
  <div class="page">
    <h1>The Chronicle of Linuxia</h1>
    <p>A new page awaits your words, traveler.</p>
    <p>Open this file in your editor and begin writing!</p>
  </div>
</template>

<style scoped>
.page {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
}
</style>
```

**src/components/.gitkeep** — empty file.

**src/assets/** — empty directory (create with a `.gitkeep` inside).

### Vue Reference Card

**adventures/code-quest/theme/reference/vue-reference.txt**

Write ~90 lines covering all concepts taught across all 8 quests. Use this exact structure:

```
═══════════════════════════════════════════════════
         THE VUE REFERENCE SCROLL
═══════════════════════════════════════════════════

  This scroll records the knowledge needed to
  build with Vue. Refer to it at any time.

  ─── VUE FILE STRUCTURE ─────────────────────

  A .vue file has three sections:

    <script setup>
      JavaScript code goes here
    </script>

    <template>
      HTML goes here (what the user sees)
    </template>

    <style scoped>
      CSS goes here (how it looks)
    </style>

  ─── HTML BASICS ────────────────────────────

    <h1>Big heading</h1>           Main heading
    <h2>Smaller heading</h2>       Sub-heading
    <p>A paragraph of text</p>     Paragraph
    <div>...</div>                 Container (groups things)
    <ul>                           Bullet list
      <li>Item</li>
    </ul>
    <ol>                           Numbered list
      <li>Item</li>
    </ol>
    <a href="https://...">text</a> Link
    <img src="..." alt="..." />    Image
    <strong>bold</strong>          Bold text
    <em>italic</em>                Italic text

  ─── CSS BASICS ─────────────────────────────

    color: #ff0000;                Text color
    background-color: #f0f0f0;    Background
    font-family: Arial, sans-serif; Font
    font-size: 1.2rem;            Text size
    margin: 1rem;                 Space outside element
    padding: 1rem;                Space inside element
    border: 1px solid #ccc;       Border
    border-radius: 8px;           Rounded corners
    text-align: center;           Center text
    max-width: 800px;             Maximum width
    margin: 0 auto;               Center a block element

  ─── VUE REACTIVITY ────────────────────────

    import { ref } from 'vue'

    const count = ref(0)           Create reactive data
    count.value++                  Change it in script
    {{ count }}                    Display it in template

  ─── VUE EVENTS ─────────────────────────────

    <button @click="doSomething">  Handle a click
    @click="count++"               Inline expression
    v-model="name"                 Two-way binding (forms)

  ─── VUE DIRECTIVES ─────────────────────────

    v-if="condition"               Show only if true
    v-else                         Show if v-if was false
    v-for="item in list"           Repeat for each item
    :key="item.id"                 Unique key for v-for

  ─── COMPONENTS ─────────────────────────────

    Create: src/components/MyComponent.vue

    Import and use:
      <script setup>
      import MyComponent from './components/MyComponent.vue'
      </script>
      <template>
        <MyComponent />
      </template>

  ─── VUE ROUTER ─────────────────────────────

    Install: npm install vue-router
    Create: src/router/index.js

    <RouterLink to="/about">About</RouterLink>
    <RouterView />    (shows the current page)

  ─── USEFUL TERMINAL COMMANDS ───────────────

    npm run dev          Start the dev server
    npm install <pkg>    Install a package
    npm run build        Build for production
    cat <file>           View a file
    quest                Show current objective
    quest map            Show all quests

═══════════════════════════════════════════════════
```

### Code Quest Tests

**adventures/code-quest/tests/test-conditions.sh**

```bash
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

if grep -rn "Flavor lore\.\|placeholder\|TODO" "$QE_THEME_DIR/narrative/" 2>/dev/null >/tmp/cq-placeholder-check.txt; then
    cat /tmp/cq-placeholder-check.txt
    FAIL=$((FAIL + 1))
    echo "FAIL: No placeholder content remains in narratives"
else
    PASS=$((PASS + 1))
    echo "PASS: No placeholder content remains in narratives"
fi

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

---

## Part 4: Top-Level Files

### Makefile

```makefile
.PHONY: shell-quest code-quest build-all

shell-quest:
	cd adventures/shell-quest && $(MAKE) run

code-quest:
	cd adventures/code-quest && $(MAKE) run

build-all:
	cd adventures/shell-quest && $(MAKE) build
	cd adventures/code-quest && $(MAKE) build
```

### .gitignore

```
adventures/code-quest/project/
node_modules/
```

---

## Part 5: Files to Delete After Migration

Remove these files/directories that have been moved or are no longer needed:

- `Dockerfile` (replaced by adventure-specific Dockerfiles)
- `docker-compose.yml` (replaced by adventure-specific files)
- `Makefile` (replaced by adventure-specific + top-level Makefiles)
- `PLAN.md` (implementation plan, no longer needed)
- `docker/` (moved to `adventures/shell-quest/docker/`)
- `themes/` (moved to `adventures/shell-quest/theme/`)
- `tests/` (moved to `adventures/shell-quest/tests/`)
- `engine/lib/theme.sh` (unused, theme loading moved to common.sh)
- `engine/bin/sq-init` (replaced by generic `quest-init`)
- `engine/bin/sq-greeting` (replaced by generic `quest-greeting`)
- `engine/bin/sq-prompt-hook` (replaced by generic `quest-prompt-hook`)
- `.gitkeep` (no longer needed)

---

## Part 6: Code Quest Narrative Content Specifications

All narrative files go in `adventures/code-quest/theme/narrative/`. Write in a medieval-ish tone, warm and encouraging, from the perspective of "Aldric the Chronicler" (the mentor character). Teaching content must be clearly separated from narrative (indented, on its own lines with code examples).

### Pedagogical Rules

- **Quests 1-3 (Maximum scaffolding)**: Show the exact code to type/paste, character for character. Explain every tag, attribute, and symbol.
- **Quests 4-5 (Guided scaffolding)**: Show the pattern with a placeholder. "Create a new file with this structure."
- **Quests 6-7 (Light scaffolding)**: Name the concept, show a small example, let them build their own version.
- **Quest 8 (Minimal scaffolding)**: State the goal. Give the steps. Point to docs.
- **HTML/CSS/JS assumed knowledge: NONE**. The user does not know what `<h1>` means.

### greeting.txt (~35-40 lines)

The first thing the user sees. Must include:

1. Decorative banner (box-drawing characters like Shell Quest's greeting)
2. Welcome tying to Shell Quest: "You have mastered the ways of the command line. Now the Kingdom needs something new — a Chronicle, a living record that anyone in the realm can read through their scrying glass (a web browser)."
3. Explain what they'll build: "A website — a collection of pages with text, images, colors, and interactive features."
4. Brief framework note: "We will use Vue — a tool for building websites. There are others (React, Angular) but Vue's style is closest to the language of the web itself. The skills you learn here work everywhere."
5. Explain the setup: "Your project is in the `project/` folder. Open this folder in your code editor (like VS Code) on your machine."
6. Site is already running: "The Chronicle is already live! Open your web browser and visit: http://localhost:5173"
7. First instructions: "Explore the project. In your terminal, type: `ls project/src/`"
8. "Then read the main file: `cat project/src/App.vue`"
9. "When you're ready, open `project/src/App.vue` in your editor and make it your own!"

### quest-01-intro.txt (~12 lines)

Reminder of the current objective. Include:
- Your first task is to explore the project and make your first edit
- Use `ls project/src/` to see the project files
- Use `cat project/src/App.vue` to read the main file — notice the three sections: `<template>`, `<script setup>`, and `<style scoped>`
- Open `project/src/App.vue` in your editor and change the content — remove the placeholder and write something of your own
- Save the file and check your browser at http://localhost:5173

### quest-01-complete.txt (~40 lines)

Skills learned: `.vue` file structure (template/script/style), `npm run dev`, live reloading.

**Must teach (intro to quest 2)**: HTML tags. This is the user's first encounter with HTML. Include:
- "HTML uses **tags** — pairs of markers that wrap content"
- Exact code examples (these MUST appear in the file):
  ```
    <h1>The Chronicle of Linuxia</h1>     Main heading
    <h2>Places of Interest</h2>           Sub-heading
    <p>The kingdom stretches far...</p>   Paragraph
    <ul>                                   Bullet list
      <li>The Castle</li>
      <li>The Enchanted Forest</li>
    </ul>
    <a href="https://vuejs.org">Vue Docs</a>   Link
    <strong>bold text</strong>             Bold
    <em>italic text</em>                  Italic
  ```
- "Build a Chronicle page about the Kingdom. Include a heading, some paragraphs, and a list of locations."
- "All HTML goes inside the `<template>` section of App.vue, inside a `<div>`."

Include hardcoded progress bar: `Quest Progress: [██░░░░░░░░░░░░░░] 1/8`

### quest-02-intro.txt (~12 lines)

Reminder: build a structured page with HTML. Reference the tags taught in quest-01-complete. Mention the `<template>` section. Say to add a list (`<ul>` and `<li>` tags) to complete this quest.

### quest-02-complete.txt (~40 lines)

Skills learned: HTML tags (h1-h3, p, ul, ol, li, a, img, div, strong, em).

**Must teach (intro to quest 3)**: CSS. First encounter with styling. Include:
- "CSS controls how things look — colors, spacing, borders, fonts"
- "CSS goes in the `<style scoped>` section of your .vue file"
- "`scoped` means styles only affect THIS component"
- Exact code examples:
  ```css
    h1 {
      color: #8b4513;
      text-align: center;
    }

    .page {
      background-color: #fdf6e3;
      padding: 2rem;
      max-width: 800px;
      margin: 0 auto;
    }

    ul {
      border: 1px solid #d4a574;
      border-radius: 8px;
      padding: 1rem 2rem;
    }
  ```
- Explain what each property does in plain English
- "Add some styles to the `<style scoped>` section of App.vue"

Include hardcoded progress bar: `Quest Progress: [████░░░░░░░░░░░░] 2/8`

### quest-03-intro.txt (~12 lines)

Reminder: style the page with CSS. Reference the properties taught. Say to add `background-color`, `border`, or `color:` to complete this quest.

### quest-03-complete.txt (~45 lines)

Skills learned: CSS properties, `<style scoped>`, selectors.

**Must teach (intro to quest 4)**: Vue components. Include:
- "A component is a self-contained piece of your page with its own HTML, CSS, and JavaScript"
- "Components keep files small and let you reuse pieces"
- How to create one — step by step:
  1. Create a new `.vue` file in `src/components/` (e.g., `PageHeader.vue`)
  2. Give it `<template>`, `<script setup>`, and `<style scoped>` sections
  3. Import it in App.vue: `import PageHeader from './components/PageHeader.vue'`
  4. Use it in the template: `<PageHeader />`
- Complete example component:
  ```vue
    <script setup>
    </script>

    <template>
      <header class="page-header">
        <h1>The Chronicle of Linuxia</h1>
        <p>A record of the realm's history and wonders</p>
      </header>
    </template>

    <style scoped>
    .page-header {
      text-align: center;
      padding: 2rem;
      background-color: #5b3a29;
      color: #fdf6e3;
    }
    </style>
  ```
- Show how App.vue imports and uses it:
  ```vue
    <script setup>
    import PageHeader from './components/PageHeader.vue'
    </script>

    <template>
      <div class="page">
        <PageHeader />
        <!-- rest of your content -->
      </div>
    </template>
  ```

Include hardcoded progress bar: `Quest Progress: [██████░░░░░░░░░░] 3/8`

### quest-04-intro.txt (~12 lines)

Reminder: create a component in `src/components/`. Reference the example from quest-03-complete. Say to create any `.vue` file in `src/components/` to complete this quest.

### quest-04-complete.txt (~45 lines)

Skills learned: components, import, `<ComponentName />`.

**Must teach (intro to quest 5)**: Reactivity. Include:
- "So far your page is static — the same every time. Let's make it come alive!"
- "Reactive data is data the page watches — when it changes, the page updates automatically"
- `ref()` creates reactive data
- `{{ }}` displays reactive data in templates
- `<script setup>` and `import { ref } from 'vue'`
- Complete example:
  ```vue
    <script setup>
    import { ref } from 'vue'

    const visitorCount = ref(0)
    const kingdomName = ref('Linuxia')
    </script>

    <template>
      <p>Welcome to {{ kingdomName }}!</p>
      <p>Visitors so far: {{ visitorCount }}</p>
      <button @click="visitorCount++">I have visited!</button>
    </template>
  ```
- Explain: "In `<script setup>`, `ref(0)` creates a reactive value starting at 0. In the template, `{{ visitorCount }}` shows its current value. When it changes, the page updates instantly."
- Note: `@click` is previewed here, quest 6 goes deeper.

Include hardcoded progress bar: `Quest Progress: [████████░░░░░░░░] 4/8`

### quest-05-intro.txt (~12 lines)

Reminder: add reactive data with `ref()` and display it with `{{ }}`. Say to add `ref(` to any `.vue` file to complete this quest.

### quest-05-complete.txt (~45 lines)

Skills learned: `ref()`, `{{ }}`, reactivity, `<script setup>`.

**Must teach (intro to quest 6)**: Events and v-model. Include:
- `@click="expression"` runs JavaScript when clicked
- `v-model="ref"` creates two-way binding between input and reactive data
- Complete example (guest book form):
  ```vue
    <script setup>
    import { ref } from 'vue'

    const guestName = ref('')
    const message = ref('')
    const entries = ref([])

    function addEntry() {
      entries.value.push({ name: guestName.value, text: message.value })
      guestName.value = ''
      message.value = ''
    }
    </script>

    <template>
      <h2>Guest Book</h2>
      <input v-model="guestName" placeholder="Your name" />
      <input v-model="message" placeholder="Your message" />
      <button @click="addEntry">Sign the Book</button>
    </template>
  ```
- Explain `v-model` vs `@click`
- Explain the `<input>` HTML element and `placeholder` attribute
- "Add `v-model` to any `.vue` file to complete this quest."

Include hardcoded progress bar: `Quest Progress: [██████████░░░░░░] 5/8`

### quest-06-intro.txt (~12 lines)

Reminder: add user interaction with `v-model` and `@click`. Reference the example. Say to add `v-model` to any `.vue` file to complete.

### quest-06-complete.txt (~45 lines)

Skills learned: `@click`, `v-model`, event handling, two-way binding.

**Must teach (intro to quest 7)**: v-for and v-if. Include:
- `v-for="item in list"` repeats an element for each item in an array
- `:key="item.id"` gives each repeated element a unique ID (Vue requires this)
- `v-if="condition"` shows an element only when true
- `v-else` shows when the preceding `v-if` was false
- Explain arrays: "A list of things: `[item1, item2, item3]`"
- Explain objects: "A bundle of named values: `{ name: 'Castle', visited: true }`"
- Complete example:
  ```vue
    <script setup>
    import { ref } from 'vue'

    const locations = ref([
      { id: 1, name: 'The Castle', visited: true },
      { id: 2, name: 'Enchanted Forest', visited: false },
      { id: 3, name: 'The Village', visited: true },
    ])
    </script>

    <template>
      <h2>Kingdom Directory</h2>
      <ul>
        <li v-for="place in locations" :key="place.id">
          {{ place.name }}
          <span v-if="place.visited">✓ Visited</span>
          <span v-else>Not yet visited</span>
        </li>
      </ul>
    </template>
  ```
- "Add `v-for` to any `.vue` file to complete this quest."

Include hardcoded progress bar: `Quest Progress: [████████████░░░░] 6/8`

### quest-07-intro.txt (~12 lines)

Reminder: render lists with `v-for` and conditional content with `v-if`. Reference the example. Say to add `v-for` to any `.vue` file to complete.

### quest-07-complete.txt (~50 lines)

Skills learned: `v-for`, `v-if`/`v-else`, `:key`, arrays.

**Must teach (intro to quest 8)**: Vue Router. This is the most complex quest. Include step-by-step:
1. "Your Chronicle has grown! Time to split it into separate pages with navigation."
2. What routing is: connecting URLs (like `/about`) to different page components
3. Install Vue Router: `npm install vue-router` (run in terminal inside `~/project/`)
4. Create `src/router/index.js`:
   ```js
     import { createRouter, createWebHistory } from 'vue-router'
     import Home from '../views/Home.vue'
     import About from '../views/About.vue'

     const routes = [
       { path: '/', component: Home },
       { path: '/about', component: About },
     ]

     const router = createRouter({
       history: createWebHistory(),
       routes,
     })

     export default router
   ```
5. Create `src/views/` directory with `Home.vue` and `About.vue`
6. Update `src/main.js`:
   ```js
     import { createApp } from 'vue'
     import App from './App.vue'
     import router from './router'
     import './style.css'

     createApp(App).use(router).mount('#app')
   ```
7. Update `App.vue`:
   ```vue
     <template>
       <nav>
         <RouterLink to="/">Home</RouterLink>
         <RouterLink to="/about">About</RouterLink>
       </nav>
       <RouterView />
     </template>
   ```
- "Create `src/router/index.js` to complete this quest."

Include hardcoded progress bar: `Quest Progress: [██████████████░░] 7/8`

### quest-08-intro.txt (~15 lines)

Reminder: set up Vue Router for multi-page navigation. List the steps: install vue-router, create router config, create view components, update main.js and App.vue. Say to create `src/router/index.js` to complete.

### quest-08-complete.txt (~20 lines)

Skills learned: Vue Router, routes, `<RouterLink>`, `<RouterView>`, multi-page apps.

Brief celebration — "You've built a complete multi-page web application!" Defer the grand finale to `finale.txt`.

Include hardcoded progress bar: `Quest Progress: [████████████████] 8/8`

### finale.txt (~30 lines)

Grand conclusion. Must include:
1. Decorative banner (box-drawing characters)
2. "The Chronicle of Linuxia is complete!"
3. Recap: HTML structure, CSS styling, components, reactive data, user interaction, conditional/list rendering, multi-page routing
4. "You have built a real web application using the same tools professional developers use every day."
5. "Vue, React, and Angular all share these core concepts — components, reactivity, routing, props. Learning one makes the others easier."
6. Next steps: official Vue docs (vuejs.org), add more pages, learn about APIs
7. "The skills you've learned — HTML, CSS, JavaScript, component architecture — are the foundation of all modern web development."
8. Farewell from Aldric the Chronicler

---

## Part 7: Verification

### Shell Quest
1. `cd adventures/shell-quest && make build` succeeds
2. `make run` starts container, shows greeting, quest engine works
3. `quest` shows current objective; `quest map` shows 8 quests
4. `quest reset` restores files and resets progress
5. `bash tests/test-conditions.sh` passes all checks (run inside Docker or with root for permission tests)
6. All narrative files contain real content (no placeholders)

### Code Quest
1. `cd adventures/code-quest && make build` succeeds
2. `mkdir -p project && make run` starts container, copies project template, runs npm install, starts Vite dev server, shows greeting
3. `http://localhost:5173` in browser shows the default Chronicle page
4. `ls project/src/` and `cat project/src/App.vue` work in terminal
5. Editing `project/src/App.vue` on the host (removing placeholder) and pressing Enter in terminal triggers quest 1 completion
6. Adding `<li>` tags triggers quest 2; adding `background-color:` triggers quest 3
7. `quest` shows current objective; `quest map` shows 8 quests with titles
8. `quest reset` restores project files without deleting node_modules
9. `cat project/vue-reference.txt` shows the complete reference card
10. `bash tests/test-conditions.sh` passes all checks
11. All narrative files contain real content (no placeholders)
12. A user with Shell Quest experience but zero web knowledge can complete quest 1 by following the greeting instructions alone

### Both
- The shared engine at `engine/` is never duplicated — both Dockerfiles COPY from the same `engine/` directory
- `make build-all` from repo root builds both adventures
- `make shell-quest` and `make code-quest` from repo root run the respective adventures

---

## Implementation Order

1. **Engine refactor** — rewrite `engine/lib/` and `engine/bin/` with `QE_` prefix and hook support. Delete `engine/lib/theme.sh`, `engine/bin/sq-init`, `engine/bin/sq-greeting`, `engine/bin/sq-prompt-hook`.
2. **Shell Quest migration** — create `adventures/shell-quest/` directory structure. Move theme files from `themes/medieval/`. Create new Dockerfile, docker-compose, entrypoint, .bashrc, .profile, hooks, tests.
3. **Code Quest creation** — create `adventures/code-quest/` with all files. Generate `package-lock.json` by running `npm install` from the package.json.
4. **Top-level files** — create Makefile and .gitignore at repo root.
5. **Cleanup** — delete old top-level files (Dockerfile, docker-compose.yml, Makefile, PLAN.md, docker/, themes/, tests/, .gitkeep).
6. **Narrative content** — write all Code Quest narrative files following the content specifications above. This is the BULK of the creative work.
7. **Verification** — run tests for both adventures.
