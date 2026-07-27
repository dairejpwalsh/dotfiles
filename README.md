
# Linux Dotfiles

Personal Linux configuration files managed using a bare Git repository.

## Tracked configurations

* Fish shell
* Ghostty terminal
* Git configuration
* Additional application configuration files

## Repository setup

The repository is stored as a bare Git repository:

```bash
git init --bare "$HOME/.dotfiles"

git config --global alias.dotfiles \
  '!git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME"'

git dotfiles config --local status.showUntrackedFiles no
```

## Tracked files

```text
~/.config/fish/
~/.config/ghostty/
~/.gitconfig
~/README.md
```

## Common commands

Check the repository status:

```bash
git dotfiles status
```

Add a configuration file or directory:

```bash
git dotfiles add ~/.config/example
```

Commit changes:

```bash
git dotfiles commit -m "Update configuration"
```

Push changes:

```bash
git dotfiles push
```

## Install on another machine

Clone the bare repository:

```bash
git clone --bare git@github.com:YOUR_USERNAME/dotfiles.git "$HOME/.dotfiles"
```

Create the Git alias:

```bash
git config --global alias.dotfiles \
  '!git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME"'
```

Check out the tracked files:

```bash
git dotfiles checkout
git dotfiles config --local status.showUntrackedFiles no
```

Existing configuration files may need to be backed up or removed before checkout.

## Security

Do not commit credentials, private keys, tokens, browser profiles, shell history, or other sensitive files.

Examples of files that should not be tracked:

```text
~/.ssh/id_*
~/.aws/credentials
~/.gnupg/
~/.netrc
~/.local/share/fish/fish_history
```
