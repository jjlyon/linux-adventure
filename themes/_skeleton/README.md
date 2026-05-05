# Creating a New Theme

1. Copy this directory to themes/<your-theme-name>/
2. Edit theme.conf with your theme's names and vocabulary
3. Create filesystem/ directory tree with all content files
4. Create quests/quest-01.conf through quest-08.conf with completion conditions
5. Create narrative/ files: greeting.txt, quest-NN-intro.txt, quest-NN-complete.txt, finale.txt, sages_challenge.txt
6. Build: docker build --build-arg THEME=<your-theme-name> -t shell-quest-<name> .

See themes/medieval/ for a complete example.
