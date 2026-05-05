# Shell Quest - Interactive Themed Linux Tutorial

## Context

Build an interactive Linux tutorial that teaches new users by dropping them into a themed adventure inside a Docker container. The experience should feel open and sandbox-like -- no explicit "check" or "next" commands. The system passively detects progress by watching for filesystem side effects (files created, directories made, permissions changed) via `PROMPT_COMMAND`. Hints aren't requested -- they're discovered by exploring the world. If a user starts fresh on a new machine, they can skip ahead just by doing what they remember.

First theme: medieval fantasy. Designed so new themes can be created by swapping out content files.

---

## Architecture Overview

Three layers:

1. **Engine** (`engine/`) - Shell scripts for progress detection, greeting, and the minimal `quest` CLI. Lives in `/opt/shell-quest/` (root-owned, protected from user). The core innovation: a lightweight `PROMPT_COMMAND` hook that scans filesystem state after each command and reacts when quest conditions are met.
2. **Themes** (`themes/`) - Content: narrative text, filesystem trees, quest definitions, ASCII art. Each theme is a self-contained directory copied into the user's home at first login.
3. **Docker** (`docker/` + `Dockerfile`) - Packages engine + theme into a runnable container.

---

## Project Structure

```
shell-quest/
├── Dockerfile
├── docker-compose.yml
├── Makefile                            # build/run/test shortcuts
│
├── engine/
│   ├── bin/
│   │   ├── quest                       # minimal CLI: quest (status), quest map, quest reset
│   │   ├── sq-init                     # first-login setup: copies theme filesystem, seeds state
│   │   ├── sq-greeting                 # login banner with progress and current objective
│   │   └── sq-prompt-hook              # PROMPT_COMMAND script: checks quest conditions each prompt
│   ├── lib/
│   │   ├── common.sh                   # colors, text formatting, box drawing
│   │   ├── theme.sh                    # load theme.conf, render .tmpl files via envsubst
│   │   ├── progress.sh                 # read/write quest state
│   │   └── conditions.sh              # quest condition checking framework
│   └── conditions/
│       ├── quest-01.sh                 # per-quest condition checks (returns 0 if complete)
│       ├── quest-02.sh
│       └── ...
│
├── themes/
│   ├── medieval/
│   │   ├── theme.conf                  # shell-sourceable variables
│   │   ├── filesystem/                 # literal directory tree copied into ~/
│   │   │   ├── welcome_scroll.txt
│   │   │   ├── castle/...
│   │   │   ├── enchanted_forest/...
│   │   │   ├── village/...
│   │   │   ├── mountain_pass/...
│   │   │   └── archives/...
│   │   ├── quests/
│   │   │   ├── quest-01.conf           # quest metadata + completion conditions
│   │   │   └── ...
│   │   ├── narrative/
│   │   │   ├── greeting.txt.tmpl
│   │   │   ├── quest-01-intro.txt.tmpl
│   │   │   ├── quest-01-complete.txt.tmpl
│   │   │   └── ...
│   │   └── ascii-art/
│   │       └── banner.txt
│   └── _skeleton/                      # copy this to start a new theme
│
├── docker/
│   ├── entrypoint.sh
│   ├── skel/
│   │   ├── .bashrc
│   │   └── .profile
│   └── sudoers.d/
│       └── quest-user
│
└── tests/
    └── test-conditions.sh
```

---

## Core Mechanic: Passive Progress Detection

### How it works

`.bashrc` sets a `PROMPT_COMMAND` that calls `sq-prompt-hook` before every prompt. This script:

1. Sources the current progress state (which quests are already complete)
2. Scans for the *next uncompleted quest's* conditions (not all quests -- just the frontier)
3. If conditions are met: marks the quest complete, prints a themed congratulations message, and shows the next quest's intro narrative
4. Exits silently if nothing changed (no output on most prompts -- zero noise)

The hook must be fast (<50ms) since it runs on every prompt. All condition checks are simple filesystem tests (`[ -f file ]`, `stat`, `grep -q`), not expensive operations.

```bash
# engine/bin/sq-prompt-hook (simplified)
source "${SQ_ENGINE_DIR}/lib/progress.sh"
source "${SQ_ENGINE_DIR}/lib/conditions.sh"

current=$(get_current_quest)
[[ "$current" == "done" ]] && return

if check_quest_conditions "$current"; then
    mark_quest_complete "$current"
    show_completion_narrative "$current"
    next=$(get_current_quest)
    if [[ "$next" != "done" ]]; then
        show_quest_intro "$next"
    else
        show_finale
    fi
fi
```

### Skip-ahead behavior

Because progress is derived from filesystem state, a returning user on a fresh container can just do the things they remember (create the right files, navigate to the right places) and the system detects it. No "save file" to restore -- your knowledge is the save file. The prompt hook checks the *next incomplete* quest, so quests complete in order, but a user who already knows the commands breezes through.

### Condition definitions

Each quest's `.conf` file defines its completion conditions as simple shell expressions:

```bash
# themes/medieval/quests/quest-01.conf
QUEST_ID="01"
QUEST_TITLE="The First Scroll"
QUEST_TEACHES="cat, less, echo"
QUEST_SUMMARY="Read the welcome scroll and sign the traveler's log"

# Completion condition: the travelers_log.txt file exists and is non-empty
QUEST_CONDITION='[ -s "$HOME/travelers_log.txt" ]'
```

The condition engine evals these in a restricted context. Conditions are always filesystem-based tests -- no history snooping or process monitoring.

---

## Quest Progression (8 quests)

Every quest ends with the user creating or modifying a file -- the detectable side effect.

| # | Title | Teaches | Completion Condition | Flow |
|---|-------|---------|---------------------|------|
| 1 | The First Scroll | `cat`, `less`, `echo` | `~/travelers_log.txt` exists and is non-empty | Read `welcome_scroll.txt` (teaches `cat`). It says to also read the longer `lore_of_the_realm.txt` (teaches `less`). The lore file ends by telling the user to sign the traveler's log: `echo "your name" > travelers_log.txt`. |
| 2 | The Royal Summons | `ls`, `cd`, `pwd`, paths | `~/castle/tower/my_report.txt` exists | Navigate `castle/` following clues. `great_hall/royal_decree.txt` sends them to the tower. `tower/astronomer_notes.txt` asks them to write their findings: create `my_report.txt` in the tower directory. Files along the way teach `ls`, relative vs absolute paths, `cd ..`, `pwd`. |
| 3 | The Lost Runes | `find`, `grep` | `~/enchanted_forest/combined_runes.txt` exists and contains all 3 rune words | Three rune fragments scattered deep in `enchanted_forest/`. An owl's message in `ancient_oak/` hints at using `find` and `grep`. User must locate all three and combine them into one file. |
| 4 | The Scribe's Task | `echo`, `>`, `>>` | `~/village/notice_board/quest_notice.txt` exists AND `~/village/tavern/guest_book.txt` has been appended to (more lines than original) | Post a notice on the board (`>`), sign the tavern guest book (`>>`). Instructions scattered in village files. |
| 5 | The Blacksmith's Order | `cp`, `mv`, `rm`, `mkdir` | `~/village/blacksmith/completed/` dir exists with the right files moved into it, `raw_materials.txt` removed | Organize the workshop. `orders.txt` describes what to do: create a `completed/` directory, move finished work there, clean up scraps. |
| 6 | The Sealed Gate | `chmod`, `ls -l` | `~/mountain_pass/sealed_gate/gate_lock.txt` is readable by user (permission check via `test -r`) | Files in `mountain_pass/` are initially not readable (mode 000, owned by root). `guard_tower/duty_roster.txt` (readable) teaches about permissions and hints at `chmod`. Scoped sudo allows `chmod` only in this directory. |
| 7 | The Kingdom Census | pipes, `sort`, `uniq`, `wc` | `~/archives/census_answer.txt` exists and contains the correct number | Large data files in `archives/`. `archives/census_quest.txt` poses a specific question ("How many unique family names?"). User must pipe commands together and write the answer to a file. |
| 8 | The Sage's Final Test | `man`, `--help` | `~/sages_answers.txt` exists and contains correct answers to 3 questions | Questions that can only be answered by reading man pages. "What single-letter flag shows hidden files in ls?" User writes answers to a file. On completion, a finale narrative plays. |

---

## Discoverable Hints (No Hint Command)

Instead of a `quest hint` system, the world itself contains helpful information. The user learns to explore and find help as part of the adventure.

### Hint placement strategy

- **The castle library** contains "reference scrolls" -- files like `library/command_reference.txt` that list useful commands with short examples. This is always available and serves as a built-in cheat sheet the user discovers naturally.
- **Flavor files throughout the world** contain embedded tips. The `tavern/rumor_mill.txt` might have a patron saying "I heard if you say `ls -la` you can see things that are hidden..." -- teaching hidden files in-character.
- **Each quest area has a "mentor" file** that gives contextual guidance. In the enchanted forest, `ancient_oak/owl_message.txt` says "The owl hoots: 'To find something lost in the forest, try the ancient spell: find . -name \"something\"'" -- teaching `find` in a natural context.
- **Previous quest completion messages** contain breadcrumbs pointing to the next area and hinting at what commands will be useful.
- **Error/wrong-turn files** -- if a user goes to the dungeon early, `prisoner_log.txt` might say "I've been down here so long... if only I knew how to `find` my way out" -- planting seeds for later quests.

### The library as always-available help

```
castle/library/
├── command_reference.txt        # cat, ls, cd, pwd, echo, cp, mv, mkdir, rm, chmod
├── navigation_guide.txt         # paths, . and .., absolute vs relative, tab completion
├── ancient_tome.txt             # flavor text about the kingdom's history
└── catalog.txt                  # "These scrolls contain knowledge of the realm's magic (commands)"
```

The `command_reference.txt` is written in-theme but genuinely useful -- it's a real reference card disguised as a game prop.

---

## The `quest` Command (Minimal)

The `quest` command still exists but is much simpler -- it's a status tool, not a progression mechanic.

| Subcommand | Action |
|---|---|
| `quest` (no args) | Show current objective, what you're working toward |
| `quest map` | Show all 8 quests with completion status (checkmarks/blanks) |
| `quest reset` | Reset everything -- re-copies theme filesystem, clears progress (with confirmation) |

No `quest check`, no `quest hint`, no `quest next`. Progress is organic.

---

## Key Design Decisions

### Template system: hybrid (theme.conf variables + literal filesystem trees)
- `theme.conf` is a shell-sourceable file defining variables (character names, place names, vocabulary).
- Narrative `.txt.tmpl` files use `${VAR_NAME}` syntax, rendered by `envsubst` at init time.
- The `filesystem/` directory is a literal tree owned by each theme. Medieval gets a castle, sci-fi gets a spaceship. No shared topology is forced.

### All validation is filesystem-state-based
Every quest ends with the user creating or modifying a file. The `PROMPT_COMMAND` hook checks for these side effects. No history snooping, no surveillance. The user's actions have natural consequences that the system observes.

### Progress is reconstructable from filesystem state
On first login, `sq-init` copies the theme filesystem and creates a minimal state file. But the state file is essentially a cache of what the condition checks would find. A user who starts fresh and quickly recreates the right files skips ahead naturally. Knowledge is the save file.

### The state file still exists for performance
Rather than re-checking all 8 conditions on every prompt (slow), the state file records which quests are already complete so the hook only checks the *next* one. It's a cache, not the source of truth.

### Engine protected from users
Engine lives in `/opt/shell-quest/` (root-owned). Only the `quest` command is in PATH. User's home is their sandbox -- `quest reset` restores it.

### Quest config: `.conf` files, not YAML
Zero external dependencies. Shell-sourceable. Conditions are shell expressions evaluated by the engine.

---

## Medieval Theme Filesystem

```
~/
├── welcome_scroll.txt               # Quest 1: short, teaches cat
├── lore_of_the_realm.txt            # Quest 1: long, teaches less, ends with "sign the log"
│
├── castle/
│   ├── great_hall/
│   │   ├── royal_decree.txt         # Quest 2: "go to the tower"
│   │   └── feast_menu.txt           # flavor, hidden tip about ls flags
│   ├── tower/
│   │   ├── astronomer_notes.txt     # Quest 2: "write your report here"
│   │   └── star_chart.txt           # flavor
│   ├── dungeon/
│   │   └── prisoner_log.txt         # flavor, early seeds for find/grep
│   ├── armory/
│   │   ├── weapon_inventory.txt     # flavor
│   │   └── shield_catalog.txt       # flavor
│   └── library/                     # ALWAYS-AVAILABLE HELP
│       ├── command_reference.txt    # in-theme command cheat sheet
│       ├── navigation_guide.txt     # paths, directories, tab completion
│       ├── ancient_tome.txt         # flavor + hidden tips
│       └── catalog.txt              # index of what's in the library
│
├── enchanted_forest/                # Quest 3: find/grep
│   ├── clearing/
│   │   ├── mushroom_circle.txt      # flavor
│   │   └── fairy_note.txt           # hints about searching
│   ├── deep_woods/
│   │   ├── hollow_tree/
│   │   │   └── rune_fragment_1.txt  # "RUNE: IRON"
│   │   ├── cave/
│   │   │   ├── bear_warning.txt     # flavor
│   │   │   └── rune_fragment_2.txt  # "RUNE: HEART"
│   │   └── stream/
│   │       └── water_spirit.txt     # flavor
│   ├── edge/
│   │   └── traveler_camp/
│   │       ├── journal.txt          # tips about combining commands
│   │       └── rune_fragment_3.txt  # "RUNE: OAK"
│   └── ancient_oak/
│       └── owl_message.txt          # teaches find and grep in-character
│
├── village/                         # Quests 4 & 5
│   ├── notice_board/
│   │   └── instructions.txt         # Quest 4: "post a notice using echo >"
│   ├── blacksmith/
│   │   ├── orders.txt               # Quest 5: detailed instructions
│   │   └── raw_materials.txt        # to be removed as part of quest
│   ├── market/
│   │   ├── price_list.txt           # flavor
│   │   └── merchant_note.txt        # hidden tip about cp/mv
│   └── tavern/
│       ├── guest_book.txt           # Quest 4: append with >>
│       └── rumor_mill.txt           # tips disguised as tavern gossip
│
├── mountain_pass/                   # Quest 6: permissions
│   ├── guard_tower/
│   │   └── duty_roster.txt          # readable, teaches ls -l and chmod
│   ├── sealed_gate/
│   │   └── gate_lock.txt            # mode 000, must chmod to read
│   └── treasure_vault/
│       └── treasure_manifest.txt    # reward file after gate_lock
│
└── archives/                        # Quest 7: pipes
    ├── census_quest.txt             # the specific question to answer
    ├── census_records.txt           # large data file
    ├── battle_logs.txt              # practice data
    └── tax_records.txt              # practice data
```

Note: Quest 8's content appears in the quest 7 completion narrative (directing them to seek the Sage). The Sage's questions are printed when they type `quest` after completing quest 7, or are placed in a file that appears in their home directory upon quest 7 completion (the prompt hook creates it).

---

## Docker Setup

- **Base image**: `ubuntu:24.04`
- **Packages**: `bash coreutils findutils grep less man-db manpages sudo gettext-base`
- **Build arg**: `THEME=medieval` (swap for other themes)
- **User**: non-root `traveler` with scoped sudo for `mountain_pass/` only
- **Entrypoint**: runs `sq-init` on first login if state file doesn't exist
- **Hostname**: themed (e.g., `linuxia` for medieval)
- **Run**: `docker run -it --rm --hostname linuxia shell-quest`

---

## Implementation Order

1. **Engine core**: `common.sh`, `progress.sh`, `theme.sh`, `conditions.sh`
2. **Engine scripts**: `sq-init`, `sq-greeting`, `sq-prompt-hook`, `quest`
3. **Medieval theme**: `theme.conf`, full filesystem tree with all content files (the bulk of the creative work)
4. **Conditions**: `conditions/quest-01.sh` through `quest-08.sh`
5. **Docker**: `Dockerfile`, `entrypoint.sh`, `.bashrc`, sudoers, `docker-compose.yml`
6. **Polish**: `Makefile`, `_skeleton/` theme template, tests

---

## Verification

1. `docker compose build` succeeds
2. `docker compose run --rm shell-quest` drops into bash with greeting banner and quest 1 intro
3. `cat welcome_scroll.txt` shows the scroll. `less lore_of_the_realm.txt` works. `echo "name" > travelers_log.txt` triggers quest 1 completion message + quest 2 intro automatically on next prompt
4. Navigating to `castle/tower/` and creating `my_report.txt` triggers quest 2 completion
5. `quest` shows current objective. `quest map` shows progress
6. `quest reset` restores filesystem and progress to initial state
7. Starting a fresh container and immediately running `echo x > travelers_log.txt` skips quest 1 instantly
8. Completing all 8 quests shows a finale narrative

---

## Creating a New Theme

1. Copy `themes/_skeleton/` to `themes/<name>/`
2. Fill in `theme.conf` (character names, vocabulary, place names)
3. Build the `filesystem/` directory tree with all content files
4. Write `quests/quest-NN.conf` with conditions and `narrative/*.txt.tmpl` for each quest
5. Build: `docker build --build-arg THEME=<name> -t shell-quest-<name> .`
