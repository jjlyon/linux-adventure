# Shell Quest: Learn Linux in the Kingdom of Linuxia

Welcome, traveler! **Shell Quest** is a friendly, story-driven way to learn your first Linux terminal commands. You will run a small medieval world inside Docker, then explore it by typing commands such as `cat`, `ls`, `cd`, `grep`, `find`, `chmod`, and command pipelines.

You do **not** need to know Linux, Docker, GitHub, or programming before you start. This guide assumes you may be opening a terminal for the first time.

## What You Are About to Do

Shell Quest is an interactive tutorial. When you start it, you enter a container as a traveler in the Kingdom of Linuxia. The game gives you a prompt, a small filesystem to explore, and quests that advance when you create, read, move, search, or modify files.

You will learn how to:

- Open and read files with `cat` and `less`
- Look around with `ls`
- Move through folders with `cd` and `pwd`
- Search by filename and by text with `find` and `grep`
- Create and append to files with `echo`, `>`, and `>>`
- Organize files with `mkdir`, `cp`, `mv`, and `rm`
- Understand permissions with `ls -l`, `chmod`, and `sudo`
- Combine commands with pipes, `sort`, `uniq`, `wc`, and `cut`
- Find help with `man`, `--help`, and `history`

The tutorial runs inside Docker so it does not change your normal computer files.

## What You Need

You need three things installed:

1. A terminal application
2. Docker
3. Git

If you have never used these before, follow the step-by-step sections below.

## Step 1: Open a Terminal

A **terminal** is an application where you type commands and press Enter.

### On macOS

1. Press `Command + Space` to open Spotlight Search.
2. Type `Terminal`.
3. Press Enter.

You can also find Terminal in `Applications` → `Utilities` → `Terminal`.

### On Windows

Use **PowerShell** or **Windows Terminal**:

1. Click the Start menu.
2. Type `PowerShell` or `Terminal`.
3. Open **Windows PowerShell** or **Windows Terminal**.

If you install Docker Desktop on Windows, it may ask you to enable WSL 2. Accept that setup when prompted.

### On Linux

Most Linux desktops open a terminal with:

- `Ctrl + Alt + T`

You can also search your app menu for `Terminal`, `Konsole`, `Console`, or `GNOME Terminal`.

## Step 2: Install Docker

Docker lets Shell Quest run in a safe, repeatable environment. Feel free to learn more about docker [here](https://docs.docker.com/get-started/docker-overview/), but don't worry about understanding it for the purposes of Shell Quest; just know we are using it to isolate your linux learning experience from your normal computer usage.

### macOS or Windows

1. Go to <https://www.docker.com/products/docker-desktop/>.
2. Download **Docker Desktop** for your operating system.
3. Install it like a normal application.
4. Open Docker Desktop after installing it.
5. Wait until Docker says it is running.

To check that Docker works, open your terminal and type:

```bash
docker --version
```

You should see a version number.

### Linux

Install Docker Engine using Docker's official instructions for your distribution:

<https://docs.docker.com/engine/install/>

After installing Docker, also make sure Docker Compose is available:

```bash
docker compose version
```

If your system requires `sudo` for Docker commands, you can either run the project commands with `sudo` or follow Docker's post-install instructions to allow your user to run Docker.

## Step 3: Install Git

Git downloads the project files from GitHub. Feel free to learn more about git [here](https://git-scm.com/book/en/v2/Getting-Started-What-is-Git%3F). Similar to docker, it's not important for your experience of Shell Quest, we are just using it to get the files for Shell Quest (that you can see here in GitHub) onto your computer.

### macOS

In Terminal, type:

```bash
git --version
```

If Git is not installed, macOS usually prompts you to install command line tools. Follow the prompt, then run `git --version` again.

You can also install Git from <https://git-scm.com/downloads>.

### Windows

1. Go to <https://git-scm.com/download/win>.
2. Download and install Git for Windows.
3. Reopen PowerShell or Windows Terminal.
4. Check it with:

```bash
git --version
```

### Linux

Use your distribution's package manager. For Ubuntu or Debian:

```bash
sudo apt update
sudo apt install git
```

Then check it:

```bash
git --version
```

## Step 4: Download Shell Quest from GitHub

A GitHub page is a project page on the web. To download this project, you clone it.

In your terminal, go to a place where you keep projects. If you are not sure, your home folder is fine. Type:

```bash
cd ~
```

Then clone the project by either typing the command below:

```bash
git clone https://github.com/jjlyon/linux-adventure.git
```

Or you can construct the command yourself from the GitHub project page (the page you're on now):

1. Click the green **Code** button.
2. Make sure the **HTTPS** tab is selected.
3. Copy the URL shown there.

Then typing `git clone`, a space, and pasting the URL (depending on your terminal, simply right clicking will paste the URL from your clipboard). It should look like the command above.

After cloning, enter the project folder (you'll learn more about `cd` in Shell Quest):

```bash
cd linux-adventure
```

## Step 5: Start the Adventure

Start Shell Quest with Docker Compose:

```bash
docker compose run --rm shell-quest
```

This command reads the project's Docker Compose settings, starts the `shell-quest` container, and removes that temporary container when you exit so your computer stays tidy.

You should see a welcome message from the Kingdom of Linuxia. It will ask you to type:

```bash
cat welcome_scroll.txt
```

Type that command and press Enter. From there, the game will guide you.

## How to Leave Shell Quest

When you are inside the Shell Quest container and want to stop, type:

```bash
exit
```

Then press Enter. This returns you to your normal terminal.

## Guidance Inside Shell Quest

If you have lost sight of your current objective type:

```bash
quest
```

If you want to see your overall progress of Shell Quest, type:

```bash
quest map
```

You can reset ALL your progress with:

```bash
quest reset
```

It will ask you to type `YES` before it resets anything.

## Troubleshooting

### `docker: command not found`

Docker is not installed, or your terminal cannot find it. Install Docker Desktop or Docker Engine, then close and reopen your terminal.

### `Cannot connect to the Docker daemon`

Docker is installed but not running. Open Docker Desktop, wait for it to finish starting, and try again.

On Linux, you may need to run Docker commands with `sudo` or add your user to the Docker group.

### `git: command not found`

Git is not installed. Install Git using the instructions above, then close and reopen your terminal.

### The terminal looks unfamiliar

That is expected. Shell Quest is designed for first-time terminal users. Read each scroll carefully, type commands exactly as shown at first, and remember that pressing the Tab key can help complete filenames.

## Project Layout

If you're curious about the Shell Quest project itself and want to poke around here:

- `engine/` contains the scripts that track quests and show progress.
- `themes/medieval/` contains the Kingdom of Linuxia story, quests, and filesystem.
- `docker/` contains container startup and shell configuration.
- `tests/` contains automated checks for quest conditions.
- `themes/_skeleton/` is a starter template for creating a new theme.

## Welcome, Traveler

If this is your first time using a terminal, you are exactly who Shell Quest is for. Take your time, read the story files, and experiment. The container is a safe practice realm, and every command you learn here is a real Linux skill you can use later. Other than potentially installing some new tools (git and docker), nothing you do following this guide will impact your computer in any way.
