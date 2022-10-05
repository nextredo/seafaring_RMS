# Gen
- This folder contains files and information used for the following purposes
  - Repository conventions
    - Git commit conventions
  - Repository styling
    - Spellcheck

# vscode
- Just open the repo folder as a standalone workspace in vscode
- Ensure you have the spell check extension

# Python
- Formatting with Python Black
- Use Conda environments because they're good

# Git
## Gitmessage
- Add `.gitmessage` from this repo to your home (`~`) directory
  - Windows might take the "." off the front when copying the file
- Run the following to have the `.gitmessage` as part of your git
  - `git config --global commit.template ~/.gitmessage`
- Just stage changes are run `git commit` when ready. Default editor will show the commit template from `.gitmessage`
- Based off "Conventional Commits"

## Branching
- Branch naming schemes are in the `.gitmessage` file
- Make a new branch for each major enough change
- Pull request to master once purpose of branch fulfilled
- Merge into master as squash commit?
  - Might be better to keep history idk
- Rebase other branches as necessary
- Try not to push to master lmao

## Commits
- Follow conventions in the `.gitmessage` template for commits

# Spelling
- Spellcheck exceptions are kept in `seafaring_RMS/.vscode/settings.json`
- Spellcheck performed in the vscode editor with the "[Code Spell Checker](https://marketplace.visualstudio.com/items?itemName=streetsidesoftware.code-spell-checker)" extension by streetsidesoftware
