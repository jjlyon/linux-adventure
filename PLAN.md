# Shell Quest - Interactive Themed Linux Tutorial

## Context

Build an interactive Linux tutorial that teaches new users by dropping them into a themed adventure inside a Docker container. The experience should feel open and sandbox-like -- no explicit "check" or "next" commands. The system passively detects progress by watching for filesystem side effects (files created, directories made, permissions changed) via `PROMPT_COMMAND`. Hints aren't requested -- they're discovered by exploring the world. If a user starts fresh on a new machine, they can skip ahead just by doing what they remember.

First theme: medieval fantasy. Designed so new themes can be created by swapping out content files.

**Target audience**: People who have never used a terminal before. They do not know what `cat` means, what a "path" is, or that commands have flags. Every piece of content must be written with this in mind.

---

## Pedagogical Design Principles

These principles are **mandatory constraints** on all quest content. The implementing agent must follow them when writing any narrative text, quest files, or in-world content.

### 1. The Scaffolding Gradient

Hand-holding decreases gradually across the 8 quests:

- **Quests 1-2 (Maximum scaffolding)**: Give the user the exact command to type, character for character. Explain what every part of the command does. Introduce one concept at a time. Example: "Type this exactly: `cat welcome_scroll.txt`"
- **Quests 3-4 (Guided scaffolding)**: Give the command pattern with a placeholder the user must fill in. Explain the pattern. Example: "To search for a file by name, type: `find . -name \"<the filename you want>\"`"
- **Quests 5-6 (Light scaffolding)**: Describe what needs to happen and name the command, but let the user construct it. Reference the library for syntax help. Example: "You'll need to use the `mkdir` command to create a new directory. Check the command reference in the castle library if you need the exact syntax."
- **Quests 7-8 (Minimal scaffolding)**: Describe the goal. The user should know how to find help themselves by now (library, `--help`, `man`). Example: "Count the unique family names in the census. You'll need to combine several commands together."

### 2. Every Quest Must Include

When writing quest content (the intro narrative, the in-world files, completion messages), every quest must provide:

1. **What the user should do next** -- a clear, unambiguous objective stated in plain language
2. **The exact command or command pattern** -- at minimum one working example they can type (for early quests, this is literal; for later quests, it's a pattern with a placeholder)
3. **What the command does in plain English** -- not just "use cat" but "the `cat` command displays the contents of a file on your screen"
4. **General syntax they can reuse** -- after showing the specific example, show the general form. Example: after `cat welcome_scroll.txt`, explain: "Any time you want to read a file, type: `cat <filename>`"
5. **Where to go next** -- a breadcrumb pointing toward the next quest area or the next thing to try

### 3. Teach the Pattern, Not Just the Instance

Every command introduction must follow this structure:
1. Here is the exact thing to type right now (specific)
2. Here is what that command does (explanation)
3. Here is the general form so you can use it on other things (pattern)

Example from welcome_scroll.txt:
```
To read any file, use the cat command followed by the file's name.

  Try it now -- type exactly this:

    cat lore_of_the_realm.txt

  The general pattern is:

    cat <any-filename>

  This works for any file you find in your travels!
```

### 4. Introduce Concepts Before Requiring Them

Never require the user to use a concept they haven't seen yet. If quest 3 requires `>` to write output to a file, quest 2's completion message or an in-world file encountered during quest 2 must have introduced `echo "text" > filename` first. Map this dependency chain explicitly:

- Quest 1 introduces: `cat`, `less` (scrolling with spacebar/q), `echo "text" > file`
- Quest 2 introduces: `ls`, `cd <directory>`, `cd ..`, `pwd`, relative paths, that directories contain things
- Quest 3 introduces: `find . -name "pattern"`, `grep "word" filename`, `grep -r "word" directory/`
- Quest 4 deepens: `echo "text" > file` (overwrite) vs `echo "text" >> file` (append), output redirection
- Quest 5 introduces: `mkdir`, `cp`, `mv`, `rm`, and reinforces paths from quest 2
- Quest 6 introduces: `ls -l` (long listing), permission strings (rwx), `chmod`, `sudo`
- Quest 7 introduces: `|` (pipe), `sort`, `uniq`, `wc`, `wc -l`, command chaining
- Quest 8 introduces: `man <command>`, `<command> --help`, `<command> -h`, `history`

### 5. The Self-Sufficiency Ramp

The final act of the tutorial is teaching users they don't need the tutorial. Quest 8 explicitly teaches `--help`, `-h`, and `man` pages. But these should be foreshadowed earlier:

- **Quest 5 or 6**: An in-world file casually mentions "Most commands will tell you how they work if you ask. Try typing `ls --help` to see all the things `ls` can do." This is a flavor hint, not a quest requirement.
- **Quest 7**: The archives should include a file that says something like "The ancient sages wrote detailed manuals for every command. Type `man sort` to read the manual for the sort command. Press `q` to close it when you're done." Again, helpful context, not required.
- **Quest 8**: Now the user MUST use `man` or `--help` to answer questions. By this point they've seen it mentioned twice and used `less`-style scrolling (from quest 1), so man pages won't feel alien.

### 6. Error Recovery Guidance

Early quests should anticipate common mistakes and address them in-world:

- `welcome_scroll.txt` should include: "If you see 'No such file or directory', make sure you typed the filename exactly as shown, including the .txt part."
- Navigation files should mention: "If you get lost, type `pwd` to see where you are. Type `cd` by itself to go back to your home."
- The library's `navigation_guide.txt` should cover: what happens when you mistype a command, how to use Tab to complete filenames, that commands and filenames are case-sensitive.

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

## Example Content: The Login Experience and Quest 1

This section shows the exact tone, level of detail, and pedagogical approach that ALL quest content must follow. The implementing agent should use this as the reference standard.

### What the user sees on first login (sq-greeting output)

```
    ╔═══════════════════════════════════════════════════╗
    ║                                                   ║
    ║   Hail and well met, traveler!                    ║
    ║   Welcome to the Kingdom of Linuxia.              ║
    ║                                                   ║
    ╚═══════════════════════════════════════════════════╝

  You have arrived at your cottage after a long journey.
  Before you on the table lies a scroll.

  In this world, you interact by typing commands.
  To read the scroll, type the following and press Enter:

    cat welcome_scroll.txt

  Try it now!
```

Key points about this greeting:
- It tells the user they interact by "typing commands" -- assumes zero prior knowledge
- It gives the EXACT command to type, not "use cat to read the file"
- It says "press Enter" because a true beginner might not know that
- It's short -- not a wall of text

### welcome_scroll.txt (what they see after typing `cat welcome_scroll.txt`)

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

Key points:
- Explains what `cat` does in plain English immediately after they use it
- Shows the general pattern (`cat <filename>`) so they can reuse it
- Introduces `less` with the exact command to type
- Explains the `less` controls (spacebar, b, q) because they won't know
- Includes error recovery ("No such file or directory")
- Directs them to the next thing with a clear instruction

### lore_of_the_realm.txt (the long file, ~80 lines of in-theme worldbuilding)

This file should be long enough that `cat` shows it flying past (motivating why `less` exists), but engaging enough to actually read. The lore itself is flavor -- medieval kingdom history, mentions of the castle, the enchanted forest, the village, planting seeds for later quests.

The LAST section of the file (what the user sees when they scroll to the end):

```
  ...and so the Kingdom endures, waiting for a
  hero who will learn its ways and restore order.

  ───────────────────────────────────────────────

  MERLIN'S TASK FOR YOU:

  You have read the ancient lore -- well done!
  Now sign the traveler's log to mark your arrival.

  The echo command lets you write text. To create
  a new file with your name in it, type:

    echo "your name here" > travelers_log.txt

  Replace "your name here" with whatever you like,
  but keep the quotes! The > symbol means "write
  this to a file." You will learn more about this
  later.

  Try it now!
```

Key points:
- The task is at the END, requiring them to actually scroll through with `less`
- Gives the exact command with a clear placeholder ("your name here")
- Briefly explains what `>` does but defers the full lesson ("You will learn more about this later")
- This is the completion trigger -- creating `travelers_log.txt` completes quest 1

### Quest 1 completion message (shown by sq-prompt-hook after detecting the file)

```

  ✦ ═══════════════════════════════════════ ✦

    Well done, traveler! You have signed the
    log and proven you can read the ancient
    texts.

    Skills learned:
      cat <file>    - display a file
      less <file>   - read a long file page by page
      echo "..." > <file>  - write text to a file

    Quest Progress: [██░░░░░░░░░░░░░░] 1/8

  ✦ ═══════════════════════════════════════ ✦

  Merlin speaks:

    "A royal summons has arrived from the castle!
     The King requires your aid. To reach the
     castle, you must learn to move between places.

     First, see what is around you. Type:

       ls

     This shows you the files and folders here.
     Folders (also called directories) are like
     rooms -- you can go inside them. To enter
     a folder, type:

       cd <foldername>

     You should see a folder called 'castle'.
     Enter it with:

       cd castle

     Then use ls again to look around inside!"

```

Key points:
- Summarizes what was learned with the reusable syntax patterns
- Shows progress visually
- Immediately introduces the next quest's first commands (`ls`, `cd`) with exact examples
- Gives the specific next action: `ls` then `cd castle`
- This is the intro to quest 2 -- the completion message for quest N is also the intro for quest N+1

---

## Quest Progression (8 quests)

Every quest ends with the user creating or modifying a file -- the detectable side effect.

| # | Title | Teaches | Completion Condition | Flow |
|---|-------|---------|---------------------|------|
| 1 | The First Scroll | `cat`, `less`, `echo "..." > file` | `~/travelers_log.txt` exists and is non-empty | Read `welcome_scroll.txt` (teaches `cat`). Read `lore_of_the_realm.txt` with `less`. Sign the traveler's log with `echo "name" > travelers_log.txt`. |
| 2 | The Royal Summons | `ls`, `cd`, `cd ..`, `pwd`, relative paths | `~/castle/tower/my_report.txt` exists | Navigate `castle/` following clues file-to-file. `great_hall/royal_decree.txt` sends them to the tower. `tower/astronomer_notes.txt` asks them to create `my_report.txt` here. Files along the way teach `ls` to look around, `cd` to move, `cd ..` to go back, `pwd` to check location. |
| 3 | The Lost Runes | `find`, `grep` | `~/enchanted_forest/combined_runes.txt` exists and contains all 3 rune words | Three rune fragments scattered deep in `enchanted_forest/`. `owl_message.txt` teaches `find . -name "pattern"` with an exact example. A fairy note teaches `grep "word" filename`. User locates all three runes and combines them into one file (reinforcing `echo` and `>>`/`>`). |
| 4 | The Scribe's Task | `>` (overwrite) vs `>>` (append), deeper `echo` | `~/village/notice_board/quest_notice.txt` exists AND `~/village/tavern/guest_book.txt` has more lines than original | Instructions explain the difference between `>` (replaces everything) and `>>` (adds to the end). Post a notice (`>`), sign the guest book (`>>`). |
| 5 | The Blacksmith's Order | `mkdir`, `cp`, `mv`, `rm` | `~/village/blacksmith/completed/` dir exists with expected files, `raw_materials.txt` gone | `orders.txt` gives step-by-step instructions with the pattern for each command. Creates a directory, copies a file, moves files, removes waste. |
| 6 | The Sealed Gate | `ls -l`, permissions (rwx), `chmod`, `sudo` | `~/mountain_pass/sealed_gate/gate_lock.txt` is readable by user | `guard_tower/duty_roster.txt` is readable and explains `ls -l` output, what `rwx` means, how `chmod` works. Gives the exact command pattern. Gate file starts as mode 000 owned by root. Scoped sudoers allows chmod only here. |
| 7 | The Kingdom Census | `\|` (pipe), `sort`, `uniq`, `wc -l`, command chaining | `~/archives/census_answer.txt` exists with the correct number | `census_quest.txt` explains pipes with a concrete analogy ("pass the output of one command into another, like handing a letter from one person to the next"). Gives a worked example, then poses the actual question. Also foreshadows: "For more detail on any command, try `man <command>` to read its manual." |
| 8 | The Sage's Final Test | `man`, `--help`, `-h`, `history` | `~/sages_answers.txt` exists with correct answers to 3 questions | The sage's questions can only be answered by reading man pages or `--help` output. Teaches that these resources exist and how to use them. Explicitly shows `man ls`, `ls --help`, how to navigate man pages (they already know `less`-style controls from quest 1). This is the "you are now self-sufficient" graduation quest. |

---

## Discoverable Hints (No Hint Command)

Instead of a `quest hint` system, the world itself contains helpful information. The user learns to explore and find help as part of the adventure.

### Hint placement strategy

- **The castle library** contains "reference scrolls" -- files like `library/command_reference.txt` that list useful commands with short examples and the general syntax pattern for each. This is always available and serves as a built-in cheat sheet the user discovers naturally.
- **Flavor files throughout the world** contain embedded tips. The `tavern/rumor_mill.txt` might have a patron saying "I heard if you say `ls -la` you can see things that are hidden..." -- teaching hidden files in-character.
- **Each quest area has a "mentor" file** that gives contextual guidance with exact command examples. In the enchanted forest, `ancient_oak/owl_message.txt` says "The owl hoots: 'To find something lost in the forest, try: `find . -name \"rune\"`'" -- teaching `find` with a directly relevant example.
- **Completion messages double as intros** -- each quest's completion message contains the breadcrumbs, first commands, and exact examples needed to start the next quest.
- **Error/wrong-turn files** plant seeds for later quests. The dungeon `prisoner_log.txt` might say "I've been down here for ages... if only I could search through all these cells at once. There must be a way to `find` things..." -- foreshadowing quest 3.

### The library as always-available help

```
castle/library/
├── command_reference.txt        # every command taught so far with syntax pattern
├── navigation_guide.txt         # paths, . and .., absolute vs relative, tab completion, pwd
├── ancient_tome.txt             # flavor text + hidden tips
└── catalog.txt                  # "These scrolls contain knowledge of the realm's magic (commands)"
```

The `command_reference.txt` is written in-theme but genuinely useful. It follows the same teach-the-pattern approach:

```
  ═══ THE COMMAND REFERENCE SCROLL ═══

  READING FILES
    cat <filename>         Show a file's contents
    less <filename>        Read a long file (SPACE=next page, q=quit)

  LOOKING AROUND
    ls                     List what's in the current directory
    ls -l                  List with details (size, permissions, date)
    ls <directory>         List what's inside a specific directory

  MOVING AROUND
    cd <directory>         Go into a directory
    cd ..                  Go back to the parent directory
    cd                     Go back to your home (cottage)
    pwd                    Show where you are right now

  WRITING
    echo "text" > file     Write text to a file (overwrites!)
    echo "text" >> file    Add text to the end of a file

  (more entries added as the user progresses -- but all are
   available from the start for curious explorers)
```

### Self-sufficiency foreshadowing schedule

These in-world mentions prepare the user for quest 8 without requiring action:

- **Quest 5 area** (`village/market/merchant_note.txt`): "The old merchant mutters: 'Every tool in this land comes with instructions. Just ask! Try `ls --help` sometime -- you might be surprised what you learn.'"
- **Quest 7 area** (`archives/` intro file): "The archivist notes: 'For the ancient manuals on any command, type `man <command>`. These manuals are thorough but dense. You already know how to scroll through long texts with less -- man pages work the same way. Press q to leave.'"
- **Quest 8**: Now requires using these. The user has seen them twice and has the reading skills from quest 1.

---

## The `quest` Command (Minimal)

The `quest` command is a status tool, not a progression mechanic.

| Subcommand | Action |
|---|---|
| `quest` (no args) | Show current objective and a reminder of what to do next (including exact commands for early quests) |
| `quest map` | Show all 8 quests with completion status (checkmarks/blanks) |
| `quest reset` | Reset everything -- re-copies theme filesystem, clears progress (with confirmation) |

No `quest check`, no `quest hint`, no `quest next`. Progress is organic.

The `quest` (no args) output should be genuinely helpful for stuck users. For early quests, it repeats the exact command to try. For later quests, it gives the objective and points to the library.

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
├── welcome_scroll.txt               # Quest 1: first file, teaches cat
├── lore_of_the_realm.txt            # Quest 1: long file, teaches less, task at the end
│
├── castle/
│   ├── great_hall/
│   │   ├── royal_decree.txt         # Quest 2: teaches ls, sends them to tower
│   │   └── feast_menu.txt           # flavor, hidden tip about ls flags
│   ├── tower/
│   │   ├── astronomer_notes.txt     # Quest 2: teaches pwd, asks for my_report.txt
│   │   └── star_chart.txt           # flavor
│   ├── dungeon/
│   │   └── prisoner_log.txt         # flavor, foreshadows find
│   ├── armory/
│   │   ├── weapon_inventory.txt     # flavor
│   │   └── shield_catalog.txt       # flavor
│   └── library/                     # ALWAYS-AVAILABLE HELP
│       ├── command_reference.txt    # full syntax patterns for all commands
│       ├── navigation_guide.txt     # paths, .., tab completion, error recovery
│       ├── ancient_tome.txt         # flavor + hidden tips
│       └── catalog.txt              # describes what each library file contains
│
├── enchanted_forest/                # Quest 3: find/grep
│   ├── clearing/
│   │   ├── mushroom_circle.txt      # flavor
│   │   └── fairy_note.txt           # teaches grep with example
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
│   │       ├── journal.txt          # tips about combining outputs into a file
│   │       └── rune_fragment_3.txt  # "RUNE: OAK"
│   └── ancient_oak/
│       └── owl_message.txt          # teaches find with exact working example
│
├── village/                         # Quests 4 & 5
│   ├── notice_board/
│   │   └── instructions.txt         # Quest 4: teaches > vs >> with examples
│   ├── blacksmith/
│   │   ├── orders.txt               # Quest 5: step-by-step with command patterns
│   │   └── raw_materials.txt        # to be removed as part of quest
│   ├── market/
│   │   ├── price_list.txt           # flavor
│   │   └── merchant_note.txt        # foreshadows --help
│   └── tavern/
│       ├── guest_book.txt           # Quest 4: append with >>
│       └── rumor_mill.txt           # tips disguised as tavern gossip
│
├── mountain_pass/                   # Quest 6: permissions
│   ├── guard_tower/
│   │   └── duty_roster.txt          # readable, teaches ls -l and chmod with examples
│   ├── sealed_gate/
│   │   └── gate_lock.txt            # mode 000, must chmod to read
│   └── treasure_vault/
│       └── treasure_manifest.txt    # reward flavor after gate_lock
│
└── archives/                        # Quest 7: pipes
    ├── census_quest.txt             # explains pipes with analogy, gives worked example, poses question
    ├── census_records.txt           # large data file (~200 lines)
    ├── battle_logs.txt              # practice data
    └── tax_records.txt              # practice data
```

Quest 8 content: The prompt hook creates `~/sages_challenge.txt` in the user's home directory when quest 7 is completed. This file contains the sage's three questions and teaches `man` and `--help` with exact examples. The user writes answers to `~/sages_answers.txt`.

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
3. **Medieval theme**: `theme.conf`, full filesystem tree with all content files -- this is the bulk of the work. Every content file must follow the pedagogical principles above: exact commands for early quests, patterns with placeholders for mid quests, goal-only for late quests. Every file that teaches a command must show the specific example AND the general pattern.
4. **Conditions**: `conditions/quest-01.sh` through `quest-08.sh`
5. **Docker**: `Dockerfile`, `entrypoint.sh`, `.bashrc`, sudoers, `docker-compose.yml`
6. **Polish**: `Makefile`, `_skeleton/` theme template, tests

---

## Verification

1. `docker compose build` succeeds
2. `docker compose run --rm shell-quest` drops into bash with greeting banner telling user to type `cat welcome_scroll.txt`
3. `cat welcome_scroll.txt` explains cat, teaches less, directs to `lore_of_the_realm.txt`
4. `less lore_of_the_realm.txt` -- scrolling to end reveals the task: `echo "name" > travelers_log.txt`
5. Creating `travelers_log.txt` triggers quest 1 completion + quest 2 intro (teaches ls, cd) on next prompt
6. Following the breadcrumb trail through `castle/` and creating `my_report.txt` in the tower triggers quest 2 completion
7. `quest` shows current objective with helpful guidance
8. `quest map` shows progress
9. `quest reset` restores filesystem and progress to initial state
10. Starting a fresh container and immediately running `echo x > travelers_log.txt` skips quest 1 instantly
11. Completing all 8 quests shows a finale narrative
12. A user with zero Linux experience can complete quest 1 by following the on-screen instructions alone, without any external help

---

## Creating a New Theme

1. Copy `themes/_skeleton/` to `themes/<name>/`
2. Fill in `theme.conf` (character names, vocabulary, place names)
3. Build the `filesystem/` directory tree with all content files -- must follow the pedagogical principles (scaffolding gradient, teach-the-pattern, exact examples, error recovery)
4. Write `quests/quest-NN.conf` with conditions and `narrative/*.txt.tmpl` for each quest
5. Build: `docker build --build-arg THEME=<name> -t shell-quest-<name> .`
