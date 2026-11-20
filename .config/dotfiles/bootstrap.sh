#!/usr/bin/env bash
# Set up these dotfiles on a new machine. Safe to re-run.
#
#   curl -fsSL https://raw.githubusercontent.com/dairejpwalsh/dotfiles/main/.config/dotfiles/bootstrap.sh | bash
#
# Pass --packages (`| bash -s -- --packages`) to also install the packages in
# ~/.config/dotfiles/packages.txt with pacman. Existing files that the
# repository tracks are moved to ~/.dotfiles-backup/<timestamp>/ first.
#
# Environment overrides: DOTFILES_REPO (clone URL), DOTFILES_BRANCH.

set -euo pipefail

# Everything runs inside main so that, when piped from curl, bash has read the
# whole script before any command can consume stdin.
main() {
  local repo_url=${DOTFILES_REPO:-https://github.com/dairejpwalsh/dotfiles.git}
  local branch=${DOTFILES_BRANCH:-main}
  local git_dir="$HOME/.dotfiles"
  local install_packages=false

  local arg
  for arg in "$@"; do
    case "$arg" in
      --packages) install_packages=true ;;
      -h | --help)
        usage
        return 0
        ;;
      *)
        echo "Unknown option: $arg" >&2
        usage >&2
        return 2
        ;;
    esac
  done

  command -v git >/dev/null || die "git is required"

  dot() { git --git-dir="$git_dir" --work-tree="$HOME" "$@"; }

  if [[ -d $git_dir ]]; then
    log "Using the existing repository in $git_dir"
  else
    log "Cloning $repo_url into $git_dir"
    git clone --quiet --bare --branch "$branch" "$repo_url" "$git_dir"
  fi

  # `git clone --bare` creates no remote-tracking branches, so plain
  # `git dotfiles pull`/`push` would not know about origin's branches.
  dot config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  dot config status.showUntrackedFiles no
  dot fetch --quiet origin

  local fresh_checkout=false
  if [[ -f $git_dir/index ]]; then
    log "Dotfiles are already checked out; update them with: git dotfiles pull"
  else
    fresh_checkout=true
    local backup
    backup="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
    local moved=0 path
    while IFS= read -r -d '' path; do
      if [[ -e $HOME/$path || -L $HOME/$path ]]; then
        mkdir -p "$(dirname "$backup/$path")"
        mv "$HOME/$path" "$backup/$path"
        moved=$((moved + 1))
      fi
    done < <(dot ls-tree -r -z --name-only "$branch")
    if [[ $moved -gt 0 ]]; then log "Moved $moved existing file(s) to $backup"; fi

    log "Checking out $branch into $HOME"
    dot checkout --quiet "$branch"
  fi
  dot branch --quiet --set-upstream-to="origin/$branch" "$branch"

  # Keep sensitive files from being added by accident, even via a directory.
  local exclude="$git_dir/info/exclude" pattern
  mkdir -p "$(dirname "$exclude")"
  touch "$exclude"
  while IFS= read -r pattern; do
    grep -qxF -- "$pattern" "$exclude" || printf '%s\n' "$pattern" >>"$exclude"
  done < <(grep -Ev '^[[:space:]]*(#|$)' "$HOME/.config/dotfiles/never-track")

  if $install_packages; then install_packages; fi

  # Install Neovim's plugins at the versions in lazy-lock.json. On first start
  # lazy.nvim installs the newest versions the plugin specs allow and rewrites
  # the lockfile, so put the committed lockfile back and check out its commits.
  # Only on a fresh checkout, so a re-run never discards local lockfile changes.
  local plugins_installed=false
  if $fresh_checkout && command -v nvim >/dev/null; then
    log "Installing Neovim plugins at the locked versions"
    nvim --headless +qa </dev/null
    dot checkout -- .config/nvim/lazy-lock.json
    nvim --headless "+Lazy! restore" +qa </dev/null
    plugins_installed=true
  fi

  log "Done."
  if ! git config --file "$HOME/.gitconfig.local" user.email >/dev/null 2>&1; then
    echo
    echo "Set the Git email for this machine (kept out of the repository):"
    echo "  git config --file \"\$HOME/.gitconfig.local\" user.email \"you@example.com\""
  fi
  echo
  if $fresh_checkout && ! $plugins_installed; then
    echo "Next: open a new shell. Start nvim once to install its plugins, then run"
    echo ":Lazy restore in it to switch them to the versions in lazy-lock.json."
  else
    echo "Next: open a new shell."
  fi
}

install_packages() {
  command -v pacman >/dev/null || die "--packages needs pacman (Arch Linux or CachyOS)"

  local lists=("$HOME/.config/dotfiles/packages.txt")
  if grep -qx 'ID=cachyos' /etc/os-release 2>/dev/null; then
    lists+=("$HOME/.config/dotfiles/packages-cachyos.txt")
  fi

  local packages=()
  mapfile -t packages < <(sed -e 's/#.*//' -e 's/[[:space:]]//g' -e '/^$/d' "${lists[@]}")
  log "Installing ${#packages[@]} packages with pacman"
  # Read pacman's confirmation from the terminal, not from the piped script.
  # (The redirect only needs to read the terminal, so it doesn't need root.)
  if [[ -r /dev/tty ]]; then
    # shellcheck disable=SC2024
    sudo pacman -S --needed "${packages[@]}" </dev/tty
  else
    sudo pacman -S --needed --noconfirm "${packages[@]}"
  fi

  # Not in the Arch repositories; uv installs it into ~/.local/bin.
  if ! command -v jupytext >/dev/null && command -v uv >/dev/null; then
    log "Installing jupytext with uv"
    uv tool install --quiet jupytext
  fi
}

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [--packages]

Clone the dotfiles as a bare repository in ~/.dotfiles, check them out into
$HOME (backing up files they would replace), and configure the remote and the
ignore list. --packages also installs the package list with pacman.
EOF
}

log() { printf '==> %s\n' "$*"; }
die() {
  echo "error: $*" >&2
  exit 1
}

main "$@"
