# Shell Quest - Complete Implementation Plan

## What This Is

An interactive Linux tutorial for absolute beginners, themed as a medieval adventure. Ships as a Docker container. Users learn commands (`cat`, `ls`, `cd`, `grep`, `find`, pipes, permissions, man pages) by exploring a themed filesystem and completing quests. Progress is detected passively via `PROMPT_COMMAND` checking filesystem side effects -- no explicit "check" or "next" commands. Knowledge is the save file: start a fresh container, do what you remember, skip ahead.

## Current State

A structural skeleton exists at `~/repos/linux-adventure/`. The file tree is correct but:
- **Engine scripts have critical bugs** (PROMPT_COMMAND quoting, `set -e` in prompt hook, missing permission setup for quest 6)
- **ALL narrative and content files are placeholders** ("Quest NN complete!", "Flavor lore.", 89 identical lines for lore)
- **Missing filesystem directories** (dungeon, armory, feast_menu.txt, star_chart.txt, etc.)
- **Duplicate/wrong files** exist in `deep_woods/stream/` (copies of files from other dirs)

## What Needs to Happen

Rewrite every file in the repo. Treat this as a from-scratch implementation using the existing directory structure as a starting point. Every engine script, every Docker file, every content file needs to be replaced with production-quality content.

---

## Pedagogical Design Principles

These are **mandatory constraints** on all quest content.

### The Scaffolding Gradient

- **Quests 1-2 (Maximum)**: Give the EXACT command to type, character for character. Explain what every part does. "Type this exactly: `cat welcome_scroll.txt`"
- **Quests 3-4 (Guided)**: Give the command pattern with a placeholder. "To search for files by name: `find . -name \"<pattern>\"`"
- **Quests 5-6 (Light)**: Name the command and what it does, reference the library for syntax. "You'll need `mkdir` to create a directory. Check the command reference in the castle library."
- **Quests 7-8 (Minimal)**: State the goal. The user should find help themselves. "Count the unique family names. You'll need to combine several commands."

### Every Quest Content File Must Include

1. **Clear objective** in plain language
2. **Exact command or pattern** -- at least one working example
3. **Plain English explanation** of what the command does
4. **General reusable syntax** -- after the specific example, show the general form
5. **Breadcrumb** pointing to the next place or thing to try

### Teach the Pattern, Not Just the Instance

Every command introduction follows: (1) exact thing to type now, (2) what it does, (3) general form for reuse.

### Concept Dependency Chain

Never require something the user hasn't seen. The chain:
- Quest 1 introduces: `cat`, `less` (spacebar/q), `echo "text" > file`
- Quest 2 introduces: `ls`, `cd <dir>`, `cd ..`, `pwd`, relative paths
- Quest 3 introduces: `find . -name "pattern"`, `grep "word" file`, `grep -r "word" dir/`
- Quest 4 deepens: `>` (overwrite) vs `>>` (append)
- Quest 5 introduces: `mkdir`, `cp`, `mv`, `rm`
- Quest 6 introduces: `ls -l`, permission strings (rwx), `chmod`, `sudo`
- Quest 7 introduces: `|` (pipe), `sort`, `uniq`, `wc -l`
- Quest 8 introduces: `man <cmd>`, `<cmd> --help`, `history`

### Error Recovery

Early files must include: "No such file or directory" means check spelling; `pwd` shows where you are; `cd` alone goes home; Tab completes filenames; commands are case-sensitive.

### Self-Sufficiency Foreshadowing

`--help` and `man` are mentioned casually in quest 5-6 area files before being required in quest 8.

---

## Part 1: Engine Code

Every engine file below should be written EXACTLY as shown. These are the corrected, production-ready versions.

### engine/lib/common.sh

```bash
#!/usr/bin/env bash
SQ_BOLD='\033[1m'
SQ_GREEN='\033[0;32m'
SQ_CYAN='\033[0;36m'
SQ_YELLOW='\033[0;33m'
SQ_RESET='\033[0m'

sq_banner() {
    printf '\n'
    printf '  %b✦ ═══════════════════════════════════════ ✦%b\n' "$SQ_YELLOW" "$SQ_RESET"
    printf '\n'
}

sq_banner_end() {
    printf '\n'
    printf '  %b✦ ═══════════════════════════════════════ ✦%b\n' "$SQ_YELLOW" "$SQ_RESET"
    printf '\n'
}
```

### engine/lib/progress.sh

```bash
#!/usr/bin/env bash
SQ_STATE_FILE="${SQ_STATE_FILE:-$HOME/.shell-quest/state}"

ensure_state() {
    mkdir -p "$(dirname "$SQ_STATE_FILE")"
    if [[ ! -f "$SQ_STATE_FILE" ]]; then
        printf 'CURRENT_QUEST=01\n' > "$SQ_STATE_FILE"
    fi
}

get_current_quest() {
    ensure_state
    source "$SQ_STATE_FILE"
    echo "$CURRENT_QUEST"
}

set_current_quest() {
    ensure_state
    printf 'CURRENT_QUEST=%s\n' "$1" > "$SQ_STATE_FILE"
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
    printf '  Quest Progress: [%s] %s/8\n' "$bar" "$done"
}
```

### engine/lib/theme.sh

```bash
#!/usr/bin/env bash
load_theme() {
    source "${SQ_THEME_DIR}/theme.conf"
}

render_template() {
    envsubst < "$1"
}
```

### engine/lib/conditions.sh

```bash
#!/usr/bin/env bash

check_quest_conditions() {
    local q="$1"
    local conf="${SQ_THEME_DIR}/quests/quest-${q}.conf"
    [[ -f "$conf" ]] || return 1
    source "$conf"
    # eval the condition -- return 1 (false) if it fails, never let set -e kill us
    eval "$QUEST_CONDITION" 2>/dev/null && return 0 || return 1
}
```

### engine/bin/sq-init

This is critical. It must: copy the theme filesystem into the user's home, set up permissions for quest 6 (gate_lock.txt must be owned by root with mode 000), and create the initial state file. The permissions setup requires running parts as root, so `sq-init` needs to be called from the entrypoint BEFORE `USER` is switched (or the entrypoint runs as root and drops privileges).

```bash
#!/usr/bin/env bash
set -euo pipefail

: "${SQ_THEME_DIR:=/opt/shell-quest/theme}"
: "${SQ_STATE_FILE:=$HOME/.shell-quest/state}"

# Only run once
if [[ -f "$SQ_STATE_FILE" ]]; then
    exit 0
fi

# Copy theme filesystem into user's home
cp -a "$SQ_THEME_DIR/filesystem/." "$HOME/"

# Create state directory and initial state
mkdir -p "$(dirname "$SQ_STATE_FILE")"
printf 'CURRENT_QUEST=01\n' > "$SQ_STATE_FILE"
```

### engine/bin/sq-greeting

```bash
#!/usr/bin/env bash
source "${SQ_ENGINE_DIR}/lib/common.sh"
source "${SQ_ENGINE_DIR}/lib/progress.sh"

current=$(get_current_quest)

cat "${SQ_THEME_DIR}/narrative/greeting.txt"

if [[ "$current" != "01" && "$current" != "done" ]]; then
    printf '\n'
    progress_bar
    printf '\n  You were last working on quest %s.\n' "$(quest_number "$current")"
    printf '  Type %bquest%b to see your current objective.\n\n' "$SQ_BOLD" "$SQ_RESET"
elif [[ "$current" == "done" ]]; then
    printf '\n'
    progress_bar
    printf '\n  You have completed all quests! Well done, adventurer!\n\n'
fi
```

### engine/bin/sq-prompt-hook

**CRITICAL**: This script must NEVER use `set -e` or `set -o pipefail`. It runs on every prompt. If it errors, it breaks the user's shell. It must be completely silent when nothing happens.

```bash
#!/usr/bin/env bash
# NO set -e, NO set -o pipefail -- this runs on every prompt

source "${SQ_ENGINE_DIR}/lib/progress.sh"
source "${SQ_ENGINE_DIR}/lib/conditions.sh"
source "${SQ_ENGINE_DIR}/lib/common.sh"

current=$(get_current_quest 2>/dev/null) || exit 0
[[ "$current" == "done" ]] && exit 0

if check_quest_conditions "$current"; then
    mark_quest_complete "$current"

    # Show completion narrative
    local_complete="${SQ_THEME_DIR}/narrative/quest-${current}-complete.txt"
    [[ -f "$local_complete" ]] && cat "$local_complete"

    next=$(get_current_quest)

    # Special: quest 7 complete -> place sages_challenge.txt in home
    if [[ "$current" == "07" ]]; then
        cp "${SQ_THEME_DIR}/narrative/sages_challenge.txt" "$HOME/sages_challenge.txt" 2>/dev/null || true
    fi

    if [[ "$next" != "done" ]]; then
        local_intro="${SQ_THEME_DIR}/narrative/quest-${next}-intro.txt"
        [[ -f "$local_intro" ]] && cat "$local_intro"
    else
        local_finale="${SQ_THEME_DIR}/narrative/finale.txt"
        [[ -f "$local_finale" ]] && cat "$local_finale"
    fi
fi
```

### engine/bin/quest

```bash
#!/usr/bin/env bash
set -euo pipefail

source "${SQ_ENGINE_DIR}/lib/progress.sh"
source "${SQ_ENGINE_DIR}/lib/common.sh"

current=$(get_current_quest)

case "${1:-status}" in
    status)
        if [[ "$current" == "done" ]]; then
            printf '\n  All quests complete! You are a true Shell Knight.\n'
            progress_bar
            printf '\n'
        else
            source "${SQ_THEME_DIR}/quests/quest-${current}.conf"
            printf '\n'
            progress_bar
            printf '\n  %bCurrent Quest:%b %s - %s\n\n' "$SQ_BOLD" "$SQ_RESET" "$(quest_number "$current")" "$QUEST_TITLE"
            cat "${SQ_THEME_DIR}/narrative/quest-${current}-intro.txt"
        fi
        ;;
    map)
        printf '\n  %b═══ QUEST MAP ═══%b\n\n' "$SQ_BOLD" "$SQ_RESET"
        for i in 01 02 03 04 05 06 07 08; do
            source "${SQ_THEME_DIR}/quests/quest-${i}.conf"
            if [[ "$current" == "done" ]] || [[ "10#$i" -lt "10#$current" ]]; then
                printf '  %b[✓]%b Quest %s: %s\n' "$SQ_GREEN" "$SQ_RESET" "$((10#$i))" "$QUEST_TITLE"
            elif [[ "$i" == "$current" ]]; then
                printf '  %b[>]%b Quest %s: %s  %b(current)%b\n' "$SQ_YELLOW" "$SQ_RESET" "$((10#$i))" "$QUEST_TITLE" "$SQ_YELLOW" "$SQ_RESET"
            else
                printf '  [ ] Quest %s: %s\n' "$((10#$i))" "$QUEST_TITLE"
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
            # Remove user-created and theme files, then re-copy
            rm -rf "$HOME"/{castle,enchanted_forest,village,mountain_pass,archives}
            rm -f "$HOME"/{welcome_scroll.txt,lore_of_the_realm.txt,travelers_log.txt,sages_challenge.txt,sages_answers.txt}
            cp -a "$SQ_THEME_DIR/filesystem/." "$HOME/"
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

---

## Part 2: Docker & Build Files

### Dockerfile

```dockerfile
FROM ubuntu:24.04

ARG THEME=medieval

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

# Create quest user
RUN useradd -m -s /bin/bash traveler

# Install engine and theme
COPY engine/ /opt/shell-quest/engine/
COPY themes/${THEME}/ /opt/shell-quest/theme/

# Make engine scripts executable, symlink quest into PATH
RUN chmod +x /opt/shell-quest/engine/bin/* \
    && ln -s /opt/shell-quest/engine/bin/quest /usr/local/bin/quest

# Set up sudoers for permission quest (quest 6)
COPY docker/sudoers.d/quest-user /etc/sudoers.d/quest-user
RUN chmod 440 /etc/sudoers.d/quest-user

# Copy shell config
COPY docker/skel/.bashrc /home/traveler/.bashrc
COPY docker/skel/.profile /home/traveler/.profile
RUN chown traveler:traveler /home/traveler/.bashrc /home/traveler/.profile

# Entrypoint handles first-run init and permission setup
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /home/traveler
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash", "--login", "-i"]
```

### docker/entrypoint.sh

Runs as root, sets up quest 6 permissions, then drops to traveler user.

```bash
#!/usr/bin/env bash
set -euo pipefail

export SQ_ENGINE_DIR=/opt/shell-quest/engine
export SQ_THEME_DIR=/opt/shell-quest/theme
export SQ_STATE_FILE=/home/traveler/.shell-quest/state
export HOME=/home/traveler

# Run init as traveler (copies filesystem, creates state)
su traveler -c "$SQ_ENGINE_DIR/bin/sq-init"

# Set up quest 6 permissions as root: gate_lock.txt must be
# unreadable until the user chmod's it
if [[ -f /home/traveler/mountain_pass/sealed_gate/gate_lock.txt ]]; then
    chown root:root /home/traveler/mountain_pass/sealed_gate/gate_lock.txt
    chmod 000 /home/traveler/mountain_pass/sealed_gate/gate_lock.txt
fi

# Show greeting as traveler
su traveler -c "$SQ_ENGINE_DIR/bin/sq-greeting"

# Drop to traveler and exec the CMD
exec su traveler -c "exec $*"
```

NOTE: The `exec su traveler -c "exec $*"` pattern ensures the CMD (default: `bash --login -i`) runs as traveler with proper signal handling. If this causes issues with argument passing, an alternative is `exec gosu traveler "$@"` (would require installing gosu) or `exec sudo -u traveler -i` for an interactive login shell.

### docker/skel/.bashrc

```bash
# Shell Quest environment
export SQ_ENGINE_DIR=/opt/shell-quest/engine
export SQ_THEME_DIR=/opt/shell-quest/theme
export SQ_STATE_FILE="$HOME/.shell-quest/state"

# Quest command is in PATH via symlink in /usr/local/bin

# Themed prompt
PS1='\[\033[0;32m\]⚔ \[\033[0;36m\]\w\[\033[0m\] \$ '

# Passive quest progress detection -- runs before every prompt
PROMPT_COMMAND="${SQ_ENGINE_DIR}/bin/sq-prompt-hook"
```

### docker/skel/.profile

```bash
# Shell Quest profile -- intentionally minimal
# .bashrc handles everything for interactive shells
```

### docker/sudoers.d/quest-user

The chmod path on Ubuntu 24.04 may be `/usr/bin/chmod`. Use both to be safe.

```
traveler ALL=(root) NOPASSWD: /bin/chmod * /home/traveler/mountain_pass/sealed_gate/*, /usr/bin/chmod * /home/traveler/mountain_pass/sealed_gate/*
```

### docker-compose.yml

```yaml
services:
  shell-quest:
    build:
      context: .
      args:
        THEME: medieval
    image: shell-quest
    hostname: linuxia
    tty: true
    stdin_open: true
```

### Makefile

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

---

## Part 3: Quest Configuration Files

All files in `themes/medieval/quests/`. Each is shell-sourceable.

### quest-01.conf
```bash
QUEST_ID="01"
QUEST_TITLE="The First Scroll"
QUEST_TEACHES="cat, less, echo"
QUEST_SUMMARY="Read the welcome scroll and sign the traveler's log"
QUEST_CONDITION='[ -s "$HOME/travelers_log.txt" ]'
```

### quest-02.conf
```bash
QUEST_ID="02"
QUEST_TITLE="The Royal Summons"
QUEST_TEACHES="ls, cd, cd .., pwd"
QUEST_SUMMARY="Navigate to the castle tower and write a report"
QUEST_CONDITION='[ -s "$HOME/castle/tower/my_report.txt" ]'
```

### quest-03.conf
```bash
QUEST_ID="03"
QUEST_TITLE="The Lost Runes"
QUEST_TEACHES="find, grep"
QUEST_SUMMARY="Find all three rune fragments in the enchanted forest"
QUEST_CONDITION='[ -f "$HOME/enchanted_forest/combined_runes.txt" ] && grep -qi "IRON" "$HOME/enchanted_forest/combined_runes.txt" && grep -qi "HEART" "$HOME/enchanted_forest/combined_runes.txt" && grep -qi "OAK" "$HOME/enchanted_forest/combined_runes.txt"'
```

### quest-04.conf
```bash
QUEST_ID="04"
QUEST_TITLE="The Scribe's Task"
QUEST_TEACHES="echo, >, >>"
QUEST_SUMMARY="Post a notice and sign the guest book"
QUEST_CONDITION='[ -s "$HOME/village/notice_board/quest_notice.txt" ] && [ "$(wc -l < "$HOME/village/tavern/guest_book.txt" 2>/dev/null)" -gt 3 ]'
```

Note: The original `guest_book.txt` should have exactly 3 lines (see content spec below). The condition checks for more than 3, meaning the user appended at least one line.

### quest-05.conf
```bash
QUEST_ID="05"
QUEST_TITLE="The Blacksmith's Order"
QUEST_TEACHES="mkdir, cp, mv, rm"
QUEST_SUMMARY="Organize the blacksmith's workshop"
QUEST_CONDITION='[ -d "$HOME/village/blacksmith/completed" ] && [ -f "$HOME/village/blacksmith/completed/orders.txt" ] && [ ! -e "$HOME/village/blacksmith/raw_materials.txt" ]'
```

Note: The user must create `completed/`, move `orders.txt` into it, and remove `raw_materials.txt`. This tests mkdir, mv, and rm.

### quest-06.conf
```bash
QUEST_ID="06"
QUEST_TITLE="The Sealed Gate"
QUEST_TEACHES="ls -l, chmod, sudo, permissions"
QUEST_SUMMARY="Unlock the sealed gate in the mountain pass"
QUEST_CONDITION='[ -r "$HOME/mountain_pass/sealed_gate/gate_lock.txt" ]'
```

### quest-07.conf
```bash
QUEST_ID="07"
QUEST_TITLE="The Kingdom Census"
QUEST_TEACHES="pipes, sort, uniq, wc"
QUEST_SUMMARY="Analyze the census records using command pipes"
QUEST_CONDITION='[ -s "$HOME/archives/census_answer.txt" ]'
```

### quest-08.conf
```bash
QUEST_ID="08"
QUEST_TITLE="The Sage's Final Test"
QUEST_TEACHES="man, --help, history"
QUEST_SUMMARY="Answer the sage's questions using manual pages"
QUEST_CONDITION='[ -s "$HOME/sages_answers.txt" ]'
```

---

## Part 4: Narrative Content Files

All files in `themes/medieval/narrative/`. These are shown by the engine at key moments. Each specification below describes what the file MUST contain -- the implementing agent should write the actual prose following these specs and matching the medieval adventure tone ("hail and well met," Merlin as guide, the Kingdom of Linuxia).

**Narrative voice rules:**
- Merlin is the mentor figure who speaks in the completion/intro messages
- Tone is warm, encouraging, mildly archaic but not hard to read ("well done, traveler" not "thou hast achieved greatness")
- Teaching content is always clearly set apart from narrative (indented, with exact commands on their own lines)
- Never say "simple" or "easy" -- what's obvious to us is new to the user

### greeting.txt

The FIRST thing the user sees. ~15 lines. Must include:

```
╔═══════════════════════════════════════════════════╗
║                                                   ║
║   Hail and well met, traveler!                    ║
║   Welcome to the Kingdom of Linuxia.              ║
║                                                   ║
╚═══════════════════════════════════════════════════╝

  You have arrived at your cottage after a long journey.
  Before you on the table lies a scroll.

  In this world, you interact by typing commands
  and pressing Enter.

  To read the scroll, type the following and press Enter:

    cat welcome_scroll.txt

  Try it now!
```

Use this content verbatim or very close to it.

### quest-01-intro.txt

Shown when user types `quest` during quest 1. ~10 lines. Must include:
- Reminder that they need to read `welcome_scroll.txt` using `cat`
- The exact command: `cat welcome_scroll.txt`
- Mention that the scroll will guide them from there
- "If you haven't yet, start by typing: cat welcome_scroll.txt"

### quest-01-complete.txt

Shown when `travelers_log.txt` is created. This is the celebration for quest 1 AND the introduction to quest 2. ~35-45 lines. This is the MOST IMPORTANT narrative file because it's the template for all other complete files. Must include, in this order:

1. **Celebration banner** with `✦` borders
2. **"Well done, traveler!"** congratulations
3. **Skills learned summary** -- list the three commands with their general patterns:
   ```
   cat <file>           - display a file's contents
   less <file>          - read a long file page by page
   echo "..." > <file>  - write text to a file
   ```
4. **Progress bar**: `[██░░░░░░░░░░░░░░] 1/8`
5. **Quest 2 introduction** by Merlin:
   - "A royal summons has arrived from the castle!"
   - Teach `ls`: "First, see what is around you. Type: `ls`"
   - Explain what ls shows: "This lists all the files and folders in your current location."
   - Explain folders: "Folders (also called directories) are like rooms -- you can go inside them."
   - Teach `cd`: "To enter a folder, type: `cd <foldername>`"
   - Give specific next step: "You should see a folder called 'castle'. Enter it with: `cd castle`"
   - "Then use `ls` again to look around inside!"

### quest-02-intro.txt

Shown when user types `quest` during quest 2. ~12 lines. Remind them:
- They need to navigate to the castle tower and create a report
- `ls` to see what's around, `cd <folder>` to enter, `cd ..` to go back
- `pwd` to check where they are
- "Start at the castle's great hall. Look for a royal decree."
- If they're lost: `cd` alone goes back to their cottage (home)

### quest-02-complete.txt

Shown when `castle/tower/my_report.txt` is created. ~35-45 lines. Must include:

1. Celebration banner
2. Skills learned:
   ```
   ls                   - list files and folders here
   ls <directory>       - list contents of a specific folder
   cd <folder>          - enter a folder
   cd ..                - go back one level
   cd                   - return to your cottage (home)
   pwd                  - show where you are
   ```
3. Progress bar: `[████░░░░░░░░░░░░] 2/8`
4. Quest 3 introduction:
   - "Ancient runes have been scattered across the Enchanted Forest!"
   - "The forest is vast with many nested paths. Searching folder by folder would take ages."
   - "Enter the forest: `cd ~/enchanted_forest`" (introduces `~/` shorthand for home)
   - "An old owl in the ancient oak is said to know powerful search magic..."
   - "Start by exploring: `ls enchanted_forest` or `cd enchanted_forest`"
   - NOTE: Do NOT teach find/grep here. The owl_message.txt in the forest teaches those. This just sets the scene and gets them into the forest.

### quest-03-intro.txt

Shown when user types `quest` during quest 3. ~12 lines. Remind them:
- Find 3 rune fragments hidden in the enchanted forest
- Combine them into `enchanted_forest/combined_runes.txt`
- "The owl in the ancient oak knows search commands that can help"
- "Try: `cd ~/enchanted_forest` to enter the forest"

### quest-03-complete.txt

~35-45 lines. Must include:

1. Celebration banner
2. Skills learned:
   ```
   find . -name "<pattern>"      - find files by name
   grep "<word>" <file>          - search for text inside a file
   grep -r "<word>" <directory>  - search for text in all files in a directory
   ```
3. Progress bar: `[██████░░░░░░░░░░] 3/8`
4. Quest 4 introduction:
   - "The village needs your help! The notice board needs a posting and the tavern's guest book awaits your signature."
   - Teach the difference between `>` and `>>`:
     - "`>` writes to a file, REPLACING everything in it"
     - "`>>` ADDS to the end of a file without erasing what's there"
   - "Head to the village: `cd ~/village`"
   - "Check the notice board instructions to get started"

### quest-04-intro.txt

~10 lines. Remind them:
- Post a notice: create `village/notice_board/quest_notice.txt`
- Sign the guest book: append a line to `village/tavern/guest_book.txt`
- `>` creates/overwrites, `>>` appends
- "Head to `cd ~/village/notice_board` and read the instructions there"

### quest-04-complete.txt

~35-45 lines. Must include:

1. Celebration banner
2. Skills learned:
   ```
   echo "text" > <file>    - write text to a file (replaces contents!)
   echo "text" >> <file>   - add text to end of a file (keeps existing contents)
   ```
3. Progress bar: `[████████░░░░░░░░] 4/8`
4. Quest 5 introduction:
   - "The village blacksmith needs help organizing the workshop!"
   - Briefly mention the new commands they'll need: `mkdir` (make a new folder), `cp` (copy), `mv` (move/rename), `rm` (remove)
   - "Go to the blacksmith: `cd ~/village/blacksmith`"
   - "Read the orders to see what needs doing"
   - Reference the library: "The command reference scroll in the castle library has the patterns for these commands."

### quest-05-intro.txt

~12 lines. Remind them:
- Organize the blacksmith's shop: create a `completed` folder, move orders into it, remove raw_materials.txt
- Commands they need: `mkdir`, `mv`, `rm`
- "The orders.txt file has the details"
- "The command reference in `~/castle/library/command_reference.txt` has the syntax"

### quest-05-complete.txt

~35-45 lines. Must include:

1. Celebration banner
2. Skills learned:
   ```
   mkdir <name>           - create a new directory
   cp <source> <dest>     - copy a file
   mv <source> <dest>     - move or rename a file
   rm <file>              - remove a file (careful -- no undo!)
   ```
3. Progress bar: `[██████████░░░░░░] 5/8`
4. Quest 6 introduction:
   - "The mountain pass is blocked by a sealed gate!"
   - "Some files are protected -- not everyone is allowed to read them."
   - "Go to the mountain pass: `cd ~/mountain_pass`"
   - "The guard tower has a duty roster that explains how protections work"
   - "Start with: `cd ~/mountain_pass/guard_tower` and read what you find"

### quest-06-intro.txt

~12 lines. Remind them:
- The gate_lock.txt in mountain_pass/sealed_gate/ is protected
- Go to the guard tower first to learn about permissions
- `ls -l` shows the protection details
- The duty roster explains how to change protections with `chmod`

### quest-06-complete.txt

~35-45 lines. Must include:

1. Celebration banner
2. Skills learned:
   ```
   ls -l                     - show detailed file info including permissions
   chmod <mode> <file>       - change file permissions
   sudo <command>            - run a command with special privileges
   ```
3. Brief explanation: "Permissions control who can read (r), write (w), or execute (x) files."
4. Progress bar: `[████████████░░░░] 6/8`
5. Quest 7 introduction:
   - "The Royal Archives hold the kingdom's census records. The king needs answers!"
   - "You'll learn to chain commands together, passing the output of one into the next."
   - "Go to the archives: `cd ~/archives`"
   - "Read the census quest scroll there for your mission"

### quest-07-intro.txt

~12 lines. Remind them:
- Answer the census question in `archives/census_quest.txt`
- Write their answer to `archives/census_answer.txt`
- "The `|` symbol (pipe) passes one command's output into another"
- Hint: "You'll need `sort`, `uniq`, and `wc` combined together"

### quest-07-complete.txt

~35-45 lines. Must include:

1. Celebration banner
2. Skills learned:
   ```
   command1 | command2   - pipe: feed output of one command into another
   sort <file>           - sort lines alphabetically
   uniq                  - remove adjacent duplicate lines
   wc -l                 - count the number of lines
   ```
3. Progress bar: `[██████████████░░] 7/8`
4. Quest 8 introduction:
   - "A new scroll has appeared in your cottage -- the Sage's Final Challenge!"
   - "The sage believes a true Shell Knight should be able to find answers on their own."
   - "Go home (`cd`) and read `sages_challenge.txt`"
   - "This time, you must discover the answers yourself using the ancient manuals."
   - NOTE: This is where the sage's challenge file gets copied into $HOME by the prompt hook.

### quest-08-intro.txt

~12 lines. Remind them:
- Read `~/sages_challenge.txt` for the three questions
- Write answers to `~/sages_answers.txt`
- "Use `man <command>` to read the manual for any command"
- "Use `<command> --help` for a quick summary"
- "Press q to exit a manual page (just like `less`)"

### quest-08-complete.txt

~20 lines. Celebration for the final quest:

1. Celebration banner (bigger/fancier than usual)
2. "You have answered the Sage's questions!"
3. Skills learned:
   ```
   man <command>         - read the full manual for a command
   <command> --help      - quick help summary
   history               - show commands you've used before
   ```
4. Progress bar: `[████████████████] 8/8`
5. Brief note: "These three tools mean you can learn ANY command on your own now."
6. Then defer to finale.txt (which the prompt hook will show next).

### finale.txt

~25-35 lines. The grand conclusion. Must include:

1. Large ASCII art or decorative banner
2. Merlin's final speech: congratulations on completing all quests
3. Recap of everything learned: reading files, navigating, searching, writing, organizing, permissions, pipes, self-help
4. "You are now a Shell Knight of the Kingdom of Linuxia!"
5. Encouragement: "The real world beyond this kingdom works the same way. Every server, every cloud machine, every Linux system responds to the commands you've learned."
6. Mention they can `quest map` to see their completed journey
7. Suggest next steps: "Try exploring more commands with `man`. There are thousands of commands to discover."
8. Farewell from Merlin

### sages_challenge.txt

This file is COPIED into the user's home directory when quest 7 completes. ~30-40 lines. Must include:

1. Introduction from the Sage character (distinct from Merlin -- perhaps "Sage Elara" or similar)
2. Explain how to use `man` and `--help`:
   - "`man <command>` opens the full manual for any command"
   - "Navigate man pages just like `less`: SPACEBAR for next page, b for back, q to quit"
   - "`<command> --help` shows a shorter summary"
   - "Try `man ls` right now to see the manual for ls"
3. Three questions the user must answer:
   - Question 1: "What single-character flag for `ls` shows hidden files (files starting with `.`)?" (answer: `-a` -- findable via `man ls` or `ls --help`)
   - Question 2: "What flag for `sort` sorts in reverse order?" (answer: `-r` -- findable via `man sort`)
   - Question 3: "What command shows the list of commands you have previously typed?" (answer: `history` -- mentioned in the question itself as a hint, findable via general knowledge by now)
4. Instructions: "Write your three answers into a file called `sages_answers.txt` in your home directory."
5. Example: `echo "1: -a\n2: -r\n3: history" > ~/sages_answers.txt` or let them format however they want
6. NOTE: Quest 8 condition just checks that `sages_answers.txt` exists and is non-empty. It does NOT validate the answers. The point is that the user practiced using `man` and `--help`, not that they got a specific right answer.

---

## Part 5: Filesystem Content Files

All files in `themes/medieval/filesystem/`. These are the actual files the user explores. Each specification includes what the file must contain and approximately how long it should be.

### Root directory files

#### welcome_scroll.txt (~40-50 lines)

Use the example from the Pedagogical Principles section verbatim or very close to it:

```
═══════════════════════════════════════════════════
              THE WELCOME SCROLL
═══════════════════════════════════════════════════

  Hail, traveler! I am Merlin the Wise, keeper of
  this realm's knowledge.

  You have just used your first command: cat
  The cat command displays the contents of a file
  on your screen. You can use it on any file:

    cat <filename>

  Replace <filename> with the name of whatever file
  you wish to read.

  Now, there is a longer scroll here as well --
  the Lore of the Realm. It is too long to read
  with cat (it will scroll past too quickly).
  For longer texts, use the less command instead:

    less lore_of_the_realm.txt

  When reading with less:
    - Press SPACEBAR to go to the next page
    - Press b to go back a page
    - Press q to quit and return to the prompt

  Read the Lore of the Realm now. There is an
  important task for you at the very end!

  HELPFUL TIP: If you ever see "No such file or
  directory" it means you mistyped the filename.
  Filenames must be typed exactly, including the
  .txt part. Upper and lower case matter too!

═══════════════════════════════════════════════════
```

#### lore_of_the_realm.txt (~80-100 lines)

This file MUST be long enough that `cat` makes it scroll past too fast, motivating `less`. Write actual engaging medieval lore -- the history of the Kingdom of Linuxia. It should:

- Be ~80-100 lines of actual narrative (NOT repeated lines)
- Tell the history of the kingdom: its founding, the different regions (castle, forest, village, mountain pass, archives), notable characters
- Mention each region by name to plant seeds for later quests
- Be enjoyable to read -- reward the user for using `less` properly
- Include a few paragraph breaks and section dividers for readability

The LAST 15 lines must be:

```
  ───────────────────────────────────────────────

  MERLIN'S TASK FOR YOU:

  You have read the ancient lore -- well done!
  Now sign the traveler's log to mark your arrival
  in our kingdom.

  The echo command lets you write text. To create
  a new file with your name in it, type:

    echo "your name here" > travelers_log.txt

  Replace "your name here" with whatever you like,
  but keep the quotes! The > symbol means "write
  this text into a file." You will learn more about
  this later.

  Try it now!
```

### castle/great_hall/

#### royal_decree.txt (~25-30 lines, Quest 2 critical)

Framed as an official royal decree. Must teach `ls` and `cd` and direct users to the tower. Must include:

1. Royal decree framing (from King Torvalds or similar)
2. Teach `ls`: "Look around this hall! Type `ls` to see what is here."
3. Explain what `ls` shows: "The `ls` command lists all files and folders in your current location."
4. Teach `cd`: "To travel to another room, use the `cd` command: `cd <roomname>`"
5. Teach `cd ..`: "To go back the way you came: `cd ..`" (explain `..` means "one level up")
6. Teach `pwd`: "Lost? Type `pwd` to see where you are right now."
7. Direct to tower: "The Royal Astronomer in the tower has discovered something urgent. Go to him! From here, type: `cd ../tower`"
8. General patterns summary:
   ```
   ls              See what's here
   cd <folder>     Enter a folder
   cd ..           Go back one level
   pwd             Where am I?
   ```

#### feast_menu.txt (~15 lines, flavor)

A fun menu for a royal feast. Pure worldbuilding flavor. Can casually mention: "The head chef keeps a detailed list. If this menu were longer, you could use `less feast_menu.txt` to read it page by page. But for short files like this, `cat` works just fine!"

### castle/tower/

#### astronomer_notes.txt (~20-25 lines, Quest 2 critical)

The astronomer has seen something alarming from the tower. Must include:

1. In-character notes from the astronomer (strange lights in the enchanted forest, etc.)
2. Ask the user to record this finding: "Write a report about what you've seen. Type exactly: `echo \"stars are falling\" > my_report.txt`"
3. Remind them of the general pattern: `echo "<text>" > <filename>`
4. This creates `my_report.txt` which completes quest 2
5. Mention they can verify by typing `ls` to see their new file, or `cat my_report.txt` to read it back

#### star_chart.txt (~10-15 lines, flavor)

A decorative star chart with constellation names. Pure flavor. Maybe mentions that "the stars change with the seasons -- if you had many charts, you could `find` the right one..." (subtle foreshadowing for quest 3).

### castle/dungeon/ (MISSING -- must be created)

#### prisoner_log.txt (~15 lines, flavor + foreshadowing)

A prisoner's journal entries. Should foreshadow `find` and `grep`:
- "Day 47: I've hidden notes all over the cells but I can never find them again..."
- "Day 52: If only there were a way to search through every cell at once..."
- "Day 61: I wrote the word FREEDOM in so many places. If only I could search for it across all my writings..."

This plants seeds for quest 3's `find` and `grep` commands.

### castle/armory/ (MISSING -- must be created)

#### weapon_inventory.txt (~15 lines, flavor)

A list of weapons in the armory. Include varied items to make it feel real. Could mention "This inventory is kept in alphabetical order. The armorer uses some kind of sorting magic..." (foreshadows `sort`).

#### shield_catalog.txt (~10 lines, flavor)

Brief catalog of shields. Pure worldbuilding.

### castle/library/ (ALWAYS-AVAILABLE HELP)

#### catalog.txt (~12-15 lines)

Describes what each scroll in the library contains. Must include:
- "This library holds the collected knowledge of the realm."
- List each file with a one-line description:
  - `command_reference.txt` -- "A reference of useful commands and their patterns"
  - `navigation_guide.txt` -- "A guide to moving about the kingdom and finding your way"
  - `ancient_tome.txt` -- "Lore and secrets of the kingdom"
- "To read any scroll, use: `cat <filename>`"
- "For long scrolls, use: `less <filename>`"

#### command_reference.txt (~50-60 lines)

The in-world cheat sheet. Must list ALL commands taught across all 8 quests, organized by category, with the general pattern AND a brief description. Use this format:

```
═══════════════════════════════════════════════════
         THE COMMAND REFERENCE SCROLL
═══════════════════════════════════════════════════

  This scroll records the most useful commands
  known to the scholars of Linuxia.

  ─── READING FILES ──────────────────────────

    cat <filename>           Show a file's contents
    less <filename>          Read a long file page by page
                             (SPACE=next page, b=back, q=quit)

  ─── LOOKING AROUND ────────────────────────

    ls                       List files and folders here
    ls -l                    Detailed list (permissions, size, date)
    ls -a                    Show hidden files too
    ls <directory>           List what's inside a specific folder

  ─── MOVING AROUND ─────────────────────────

    cd <directory>           Go into a folder
    cd ..                    Go back one level (parent folder)
    cd                       Go back to your home (cottage)
    cd ~/<path>              Go to a path starting from home
    pwd                      Show where you are right now

  ─── WRITING ───────────────────────────────

    echo "text" > <file>     Write text to file (OVERWRITES!)
    echo "text" >> <file>    Add text to end of file (keeps existing)

  ─── SEARCHING ─────────────────────────────

    find <where> -name "<pattern>"
                             Find files by name
    grep "<word>" <file>     Search for a word inside a file
    grep -r "<word>" <dir>   Search all files in a directory

  ─── FILE OPERATIONS ───────────────────────

    mkdir <name>             Create a new folder
    cp <source> <dest>       Copy a file
    mv <source> <dest>       Move or rename a file
    rm <file>                Remove a file (cannot be undone!)

  ─── PERMISSIONS ───────────────────────────

    ls -l                    See permissions (rwx) on files
    chmod <mode> <file>      Change permissions on a file
    sudo <command>           Run command with special authority

  ─── COMBINING COMMANDS ────────────────────

    command1 | command2      Pipe: pass output of one into another
    sort <file>              Sort lines alphabetically
    uniq                     Remove duplicate adjacent lines
    wc -l                    Count number of lines

  ─── GETTING HELP ──────────────────────────

    man <command>            Read the full manual for a command
    <command> --help         Quick help summary
    history                  Show commands you have typed before

═══════════════════════════════════════════════════
```

#### navigation_guide.txt (~30-35 lines)

Practical guide to filesystem navigation, error recovery, and tips. Must include:
- What a "directory" is (a folder that contains files and other folders)
- Absolute paths (`/home/traveler/castle/tower`) vs relative paths (`castle/tower`, `../tower`)
- What `.` means (here) and `..` means (one level up)
- `~` is shorthand for your home directory
- Tab completion: "Press the Tab key while typing a filename to have it completed automatically! If nothing happens, press Tab twice to see all options."
- Case sensitivity: "Commands and filenames are case-sensitive! `Castle` and `castle` are different."
- Common errors and what they mean:
  - "No such file or directory" -- check spelling, check you're in the right place with `pwd`
  - "Permission denied" -- you don't have access to this file (you'll learn about this later)
  - "command not found" -- check spelling of the command name
- Recovery: "`cd` by itself always takes you home. `pwd` always tells you where you are."

#### ancient_tome.txt (~20-25 lines, flavor + tips)

Kingdom history with embedded tips. Write it as a scholarly text about the kingdom's magical traditions. Embed practical hints naturally:
- "The ancient scribes could view invisible entries by invoking `ls -a` -- the sacred 'show all' incantation"
- "Files that begin with a `.` are hidden from normal view -- the scribes used this to keep secrets"
- This teaches hidden files in a natural way, useful for general Linux knowledge

### enchanted_forest/

#### ancient_oak/owl_message.txt (~25-30 lines, Quest 3 critical)

The owl is the mentor for quest 3. This is the KEY teaching file for `find` and `grep`. Must include:

1. In-character framing: the owl hoots wisdom from the ancient oak
2. Teach `find` with exact working example:
   ```
   To find files hidden in the forest, use the find command:

     find . -name "rune_fragment_*.txt"

   This searches the current folder and everything inside it
   for files matching the pattern. The * means "anything."

   General pattern:
     find <where> -name "<pattern>"

   The . means "start searching from here." You can also
   search from your home: find ~ -name "<pattern>"
   ```
3. Teach `grep` with exact working example:
   ```
   To search for text INSIDE files, use grep:

     grep "RUNE" rune_fragment_1.txt

   This shows any line containing the word "RUNE" in that file.
   To search all files in a directory at once:

     grep -r "RUNE" .

   The -r means "search recursively" (in all sub-folders too).

   General pattern:
     grep "<word>" <filename>
     grep -r "<word>" <directory>
   ```
4. Hint: "There are three rune fragments hidden in this forest. Once you find them all, combine their words into a single file: `enchanted_forest/combined_runes.txt`"

#### clearing/mushroom_circle.txt (~10-12 lines, flavor)

A description of a fairy ring of mushrooms. Mystical flavor text. Can mention: "The fairies left a note nearby -- perhaps it contains useful knowledge." (points to fairy_note.txt)

#### clearing/fairy_note.txt (~15-20 lines, Quest 3 helper)

The fairy's note teaches `grep` with a different angle than the owl. Must include:
- "We fairies hide words inside our writings."
- Teach `grep` for searching within a file: "To find a hidden word, try: `grep \"RUNE\" <filename>`"
- "The word you seek will be revealed!"
- This reinforces what the owl teaches, giving a second exposure to `grep`

#### deep_woods/hollow_tree/rune_fragment_1.txt (~5 lines)
```
The bark of the hollow tree bears an ancient carving:

  RUNE: IRON

This is one of three fragments. Find them all!
```

#### deep_woods/cave/rune_fragment_2.txt (~5 lines)
```
Deep in the cave, glowing symbols appear on the wall:

  RUNE: HEART

This is one of three fragments. Find them all!
```

#### deep_woods/cave/bear_warning.txt (~8-10 lines, flavor)

A sign warning about bears. Humorous/atmospheric. "BEWARE: This cave is home to a rather grumpy bear. Proceed quietly. (The bear is currently hibernating, so you are safe... for now.)"

#### deep_woods/stream/water_spirit.txt (~10-12 lines, flavor)

A water spirit's message. Flavor text about the stream. Can hint: "The stream flows from deep within the forest to the edge -- much like how the `|` pipe carries things from one command to the next..." (very subtle foreshadowing for quest 7).

**IMPORTANT**: Remove the duplicate `deep_woods/stream/bear_warning.txt` and `deep_woods/stream/mushroom_circle.txt` that exist in the current repo. Only `water_spirit.txt` should be in the stream directory.

#### edge/traveler_camp/rune_fragment_3.txt (~5 lines)
```
A weathered stone at the camp bears markings:

  RUNE: OAK

This is one of three fragments. Find them all!
```

#### edge/traveler_camp/journal.txt (~15-20 lines, Quest 3 helper)

A traveler's journal with tips about combining information. Must include:
- In-character journal entries from a previous traveler
- Teach how to combine runes into one file:
  ```
  "I found three rune fragments! To record them all in
   one scroll, I wrote the first one like this:

     echo "IRON" > combined_runes.txt

   Then I ADDED the others to the same file:

     echo "HEART" >> combined_runes.txt
     echo "OAK" >> combined_runes.txt

   Remember: > replaces, >> adds to the end!"
  ```
- This reinforces `>` vs `>>` from quest 1 and teaches how to complete quest 3

### village/

#### notice_board/instructions.txt (~20-25 lines, Quest 4 critical)

The village notice board instructions. Must include:

1. Context: "The village needs a quest notice posted! And the tavern keeper asks all travelers to sign the guest book."
2. Teach `>` (overwrite) vs `>>` (append) explicitly:
   ```
   The > symbol writes text to a file. If the file exists,
   it REPLACES everything in it:

     echo "Help wanted: dragon spotted near the bridge" > quest_notice.txt

   The >> symbol ADDS text to the end of a file without
   erasing what's already there:

     echo "Your Name" >> ../tavern/guest_book.txt

   BE CAREFUL: > replaces, >> adds. If you use > on a file
   that already has content, the old content is gone!
   ```
3. Two tasks:
   - Create `quest_notice.txt` here (using `>`)
   - Add your name to the tavern guest book (using `>>`)
4. Mention: "The tavern is nearby -- from here: `cd ../tavern`"

#### tavern/guest_book.txt (exactly 3 lines)

Must have exactly 3 lines (the quest 4 condition checks for more than 3):
```
Aldric the Bold was here - Year of the Dragon
Seraphina Stormweaver passed through - Year of the Hawk
Old Tom stopped by for ale - Year of the Serpent
```

#### tavern/rumor_mill.txt (~15-20 lines, flavor + tips)

Tavern gossip that embeds command tips. Write as overheard conversations:
- "I heard if you say `ls -la` you can see things that are hidden... hidden files, that is!"
- "That blacksmith is drowning in unfinished orders. Someone should help organize that workshop."
- "The mountain pass is sealed shut. Something about 'permissions' they say. Only those with the right authority can pass."
- "Some traveling sage is offering a final test to any who complete the quests... they say the answer lies in the ancient manuals."
- Each tip should foreshadow a future quest while sounding like natural tavern talk.

#### blacksmith/orders.txt (~25-30 lines, Quest 5 critical)

The blacksmith's task list. Must include step-by-step instructions with command patterns at the LIGHT scaffolding level (name the command, show the pattern, but don't give the exact command for every step):

1. "Create a new folder called `completed` for finished work. The command to make a new folder is `mkdir`."
   - Pattern: `mkdir <foldername>`
2. "Move the orders scroll into the completed folder so I know the work is done. The `mv` command moves files."
   - Pattern: `mv <source> <destination>`
3. "Throw away the raw materials list -- we've used everything up. The `rm` command removes files."
   - Pattern: `rm <filename>`
   - Warning: "Be careful with `rm` -- removed files cannot be recovered!"
4. Reference: "If you need the exact patterns, check the command reference scroll in the castle library: `cat ~/castle/library/command_reference.txt`"

#### blacksmith/raw_materials.txt (~5-8 lines)

```
╔════════════════════════════╗
║   RAW MATERIALS IN STOCK   ║
╠════════════════════════════╣
║  Iron ingots ......... 12  ║
║  Coal bricks ......... 30  ║
║  Leather strips ....... 8  ║
║  Oak planks ........... 5  ║
╚════════════════════════════╝
```

#### market/price_list.txt (~12-15 lines, flavor)

A market price list. Fun flavor items with medieval flair. Pure worldbuilding.

#### market/merchant_note.txt (~12-15 lines, self-sufficiency foreshadowing)

A note from a merchant. Must include the foreshadowing hint about `--help`:
- "The old merchant mutters to himself as he sorts his wares..."
- "Every tool in this land comes with instructions if you know how to ask!"
- "Try typing `ls --help` sometime and see what happens."
- "Most commands will tell you all their secrets if you just add `--help` after them."
- This is NOT required for any quest -- it's casual foreshadowing for quest 8.

### mountain_pass/

#### guard_tower/duty_roster.txt (~30-35 lines, Quest 6 critical)

This is the teaching file for permissions. The guard tower file is READABLE (normal permissions). It teaches about the sealed gate. Must include:

1. Context: "Guard Tower Duty Roster and Security Protocols"
2. Teach `ls -l`:
   ```
   To inspect the protections on a file, use:

     ls -l <filename>

   You'll see something like: -rwxrw-r-- which shows
   who can do what:
     r = read (view the file)
     w = write (change the file)
     x = execute (run the file as a program)

   The first rwx is for the owner, the next for the
   group, the last for everyone else.
   ```
3. Explain the problem: "The sealed gate's lock file has no permissions set. No one can read it."
4. Teach chmod:
   ```
   To change permissions, use chmod. Since the gate file
   is specially protected, you need sudo (special authority):

     sudo chmod a+r <filepath>

   This adds read permission for all users.

   Try this on the gate lock:

     sudo chmod a+r ~/mountain_pass/sealed_gate/gate_lock.txt
   ```
5. After chmod, they can `cat` the gate_lock.txt to complete the quest.
6. Mention: "From here, go to the sealed gate: `cd ../sealed_gate`"

#### sealed_gate/gate_lock.txt (~5-8 lines)

This file starts as mode 000 owned by root (set by entrypoint.sh). After the user chmod's it, they can read:
```
═══════════════════════════════════
  THE GATE IS UNLOCKED!

  The ancient sigil glows: AURUM

  Beyond the gate lies the treasure
  vault. You have proven your worth!
═══════════════════════════════════
```

#### treasure_vault/treasure_manifest.txt (~10-15 lines, flavor reward)

A treasure list. Reward flavor for unlocking the gate. Fun, celebratory tone. "Gold coins: 10,000. Enchanted gems: 47. Dragon eggs: 3 (do NOT touch)." etc.

### archives/

#### census_quest.txt (~35-40 lines, Quest 7 critical)

The census challenge. Must include:

1. Context: "By Royal Decree: The King requires a count of unique family names in the census."
2. Teach pipes with a concrete analogy:
   ```
   Sometimes you need to pass the result of one command
   into another, like handing a letter from person to person.
   The | symbol (called a "pipe") does exactly this:

     command1 | command2

   The output of command1 becomes the input of command2.
   ```
3. Teach the individual commands:
   ```
   Useful commands for this task:

     sort <file>    - sort lines in alphabetical order
     uniq           - remove duplicate lines that are next to each other
                      (this is why you sort first!)
     wc -l          - count the number of lines
   ```
4. Give a WORKED EXAMPLE on different data:
   ```
   Example: To count unique items in a shopping list:

     cat shopping.txt | sort | uniq | wc -l

   This takes the file, sorts it, removes duplicates,
   then counts how many unique lines remain.
   ```
5. State the actual task:
   ```
   The census is in census_records.txt. It has two columns
   separated by commas: id and family name. The first line
   is a header.

   Your task: How many UNIQUE family names are there?

   Hints:
     - You need to extract just the family name column
     - The 'cut' command can extract columns: cut -d, -f2
     - Don't forget to skip the header line!

   Write your answer (just the number) to:

     echo "<number>" > census_answer.txt
   ```
6. Foreshadow man pages: "For the ancient manuals on any command, type `man <command>`. These manuals are thorough. You already know how to navigate long text (like `less`). Press q to exit."

#### census_records.txt (~200 lines)

A CSV file with `id,family` header. Must have:
- First line: `id,family`
- 199 data lines with a mix of family names
- Use at least 8-10 different family names so the answer isn't trivially obvious: Baker, Miller, Carter, Hill, Smith, Fletcher, Cooper, Thatcher, Weaver, Mason
- The exact number of unique family names must be deterministic. If using the 10 names above, the answer is 10.
- Distribution should feel natural (some names more common than others)

#### battle_logs.txt (~40-50 lines)

Battle records for practice. Multiple lines with entries like:
```
Year 1042: Knights defended the Eastern Wall against dragon attack
Year 1043: Archers repelled goblin raid at the village bridge
Year 1044: Knights and archers combined forces against the Shadow Army
...
```
Include enough variety to make `grep "dragon" battle_logs.txt` return interesting results. This is practice data, not quest-critical.

#### tax_records.txt (~30-40 lines)

Tax records for practice. Entries like:
```
Baker: 12 gold
Miller: 8 gold
Smith: 15 gold
Baker: 10 gold
...
```
Good for practicing `sort | uniq` patterns. Not quest-critical, but useful for experimentation.

---

## Part 6: Files to Delete

Remove these files that exist in the current repo but shouldn't:
- `themes/medieval/filesystem/enchanted_forest/deep_woods/stream/bear_warning.txt` (duplicate)
- `themes/medieval/filesystem/enchanted_forest/deep_woods/stream/mushroom_circle.txt` (duplicate)

---

## Part 7: Directories to Create

These directories are in the plan but missing from the current repo:
- `themes/medieval/filesystem/castle/dungeon/` (with `prisoner_log.txt`)
- `themes/medieval/filesystem/castle/armory/` (with `weapon_inventory.txt`, `shield_catalog.txt`)

Also add to `castle/great_hall/`:
- `feast_menu.txt`

And to `castle/tower/`:
- `star_chart.txt`

---

## Part 8: theme.conf

```bash
THEME_NAME="Kingdom of Linuxia"
THEME_DISPLAY_NAME="The Kingdom of Linuxia"
MENTOR_NAME="Merlin the Wise"
RULER_NAME="King Torvalds"
HOSTNAME="linuxia"
TOTAL_QUESTS=8
```

---

## Part 9: Tests

### tests/test-conditions.sh

Write a test script that:
1. Sets up a temporary directory as a fake HOME
2. Copies the medieval theme filesystem into it
3. For each quest, simulates the completion condition and verifies it detects correctly
4. Tests that conditions return false before completion and true after
5. Tests the progress tracking functions (get_current_quest, mark_quest_complete, next_quest)

Example structure:
```bash
#!/usr/bin/env bash
set -euo pipefail

PASS=0; FAIL=0
assert() { if eval "$2"; then ((PASS++)); echo "PASS: $1"; else ((FAIL++)); echo "FAIL: $1"; fi; }

# Set up temp environment
export HOME=$(mktemp -d)
export SQ_ENGINE_DIR="$(cd "$(dirname "$0")/../engine" && pwd)"
export SQ_THEME_DIR="$(cd "$(dirname "$0")/../themes/medieval" && pwd)"
export SQ_STATE_FILE="$HOME/.shell-quest/state"

source "$SQ_ENGINE_DIR/lib/progress.sh"
source "$SQ_ENGINE_DIR/lib/conditions.sh"

# Copy filesystem
cp -a "$SQ_THEME_DIR/filesystem/." "$HOME/"
mkdir -p "$(dirname "$SQ_STATE_FILE")"
printf 'CURRENT_QUEST=01\n' > "$SQ_STATE_FILE"

# Test quest 1: should fail before, pass after
assert "Quest 01 not complete initially" "! check_quest_conditions 01"
echo "test" > "$HOME/travelers_log.txt"
assert "Quest 01 complete after creating travelers_log.txt" "check_quest_conditions 01"

# Test quest 2
assert "Quest 02 not complete initially" "! check_quest_conditions 02"
mkdir -p "$HOME/castle/tower"
echo "report" > "$HOME/castle/tower/my_report.txt"
assert "Quest 02 complete after creating my_report.txt" "check_quest_conditions 02"

# ... continue for all 8 quests ...

# Cleanup
rm -rf "$HOME"
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

---

## Part 10: Skeleton Theme

### themes/_skeleton/theme.conf
```bash
THEME_NAME="New Theme"
THEME_DISPLAY_NAME="Your Theme Name Here"
MENTOR_NAME="Guide"
RULER_NAME="Leader"
HOSTNAME="adventure"
TOTAL_QUESTS=8
```

### themes/_skeleton/README.md
```
# Creating a New Theme

1. Copy this directory to themes/<your-theme-name>/
2. Edit theme.conf with your theme's names and vocabulary
3. Create filesystem/ directory tree with all content files
4. Create quests/quest-01.conf through quest-08.conf with completion conditions
5. Create narrative/ files: greeting.txt, quest-NN-intro.txt, quest-NN-complete.txt, finale.txt, sages_challenge.txt
6. Build: docker build --build-arg THEME=<your-theme-name> -t shell-quest-<name> .

See themes/medieval/ for a complete example.

## Pedagogical Requirements

Every content file must follow the scaffolding gradient:
- Quests 1-2: exact commands to type
- Quests 3-4: command patterns with placeholders
- Quests 5-6: name commands, reference the library
- Quests 7-8: state goals, let user find help

Every command introduction must: show specific example, explain what it does, show general reusable pattern.
```

---

## Verification

After implementation, verify by building and running:

1. `docker compose build` succeeds with no errors
2. `docker compose run --rm shell-quest` drops into bash with the greeting banner
3. Greeting tells user to type `cat welcome_scroll.txt` and press Enter
4. `cat welcome_scroll.txt` shows the full welcome scroll with cat/less teaching
5. `less lore_of_the_realm.txt` shows ~80-100 lines of actual lore (NOT repeated lines), task at the bottom
6. `echo "test" > travelers_log.txt` then pressing Enter triggers quest 1 completion + quest 2 intro on next command
7. Quest 2 intro teaches `ls` and `cd` with exact commands
8. Navigating to `castle/tower/` and `echo "report" > my_report.txt` triggers quest 2 completion
9. `quest` shows current objective with helpful detail
10. `quest map` shows all 8 quests with titles and completion marks
11. `quest reset` prompts for confirmation, then resets
12. Starting a fresh container and immediately running `echo x > travelers_log.txt` skips quest 1
13. All flavor files contain actual content (NOT "Flavor lore." placeholder text)
14. `castle/library/command_reference.txt` is a complete reference card
15. `bash tests/test-conditions.sh` passes all condition checks
