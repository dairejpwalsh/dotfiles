# Linux Dotfiles

Personal Linux configuration files managed with a bare Git repository.

## Tracked configurations

- Bash shell
- Fish shell
- Ghostty terminal
- Git configuration
- Neovim / AstroNvim configuration (see `~/.config/nvim/README.md`)
- Package list and bootstrap script for new machines
- GitHub Actions checks for all of the above

Fish's generated `~/.config/fish/fish_variables` file is intentionally not
tracked; hand-written Fish configuration belongs in `config.fish` or `conf.d/`.

## Install on a new machine

On Arch Linux or CachyOS, one command clones the repository, backs up any files
it would replace, checks everything out and configures the remote and the
ignore list:

```bash
curl -fsSL https://raw.githubusercontent.com/dairejpwalsh/dotfiles/main/.config/dotfiles/bootstrap.sh | bash -s -- --packages
```

Leave off `-s -- --packages` to skip installing packages. The script is safe to
re-run. Replaced files are moved to `~/.dotfiles-backup/<timestamp>/`. Then set
this machine's Git email, which is kept out of the repository:

```bash
git config --file "$HOME/.gitconfig.local" user.email "you@example.com"
```

Open a new shell and start `nvim` once to install its plugins.

### Manual install

These are the steps the bootstrap script runs. Clone the bare repository:

```bash
git clone --bare https://github.com/dairejpwalsh/dotfiles.git "$HOME/.dotfiles"
```

Back up or remove any existing files that the repository tracks before the
checkout. In particular, do **not** create a global Git alias first: doing so
would create `~/.gitconfig`, which is itself tracked and would block checkout.

Check out the tracked files using the full bare-repository command:

```bash
git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME" checkout
git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME" \
  config --local status.showUntrackedFiles no
```

The checked-out `.gitconfig` provides the `git dotfiles` alias.

`git clone --bare` does not create remote-tracking branches or an upstream, so
`git dotfiles push` and `git dotfiles pull` fail until they are configured:

```bash
git dotfiles config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git dotfiles fetch origin
git dotfiles branch --set-upstream-to=origin/main main
```

Add the [ignore list](#security) and set your Git email as above. Verify the
installation; the first line of `status -sb` should read `## main...origin/main`:

```bash
git dotfiles status -sb
git config user.name
git config user.email
```

## Repository setup

How the repository was first created, for reference:

```bash
git init --bare "$HOME/.dotfiles"

git config --global alias.dotfiles \
  '!git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME"'

git dotfiles config --local status.showUntrackedFiles no
```

After the first commit, connect the GitHub remote. With
`push.autoSetupRemote` (set in the tracked `.gitconfig`), the first push also
sets the upstream branch:

```bash
git dotfiles remote add origin git@github.com:YOUR_USERNAME/dotfiles.git
git dotfiles push
```

## Git configuration

The tracked `~/.gitconfig` loads optional machine-local Git settings from
`~/.gitconfig.local`. Keep private or machine-specific values such as your email
address there instead of committing them to this repository.
`user.useConfigOnly = true` is enabled, so Git will refuse to create commits
until an email address is configured explicitly.

It also sets some defaults:

| Setting | Effect |
| --- | --- |
| `init.defaultBranch = main` | New repositories start on `main` |
| `push.autoSetupRemote = true` | The first `git push` of a new branch creates and tracks the remote branch |
| `pull.rebase = true` | `git pull` rebases local commits instead of creating merge commits |
| `rebase.autoStash = true` | Rebasing (including `git pull`) stashes and restores uncommitted changes |
| `fetch.prune = true` | Fetching removes remote-tracking branches deleted on the remote |
| `merge.conflictStyle = zdiff3` | Conflicts also show the common ancestor version |
| `diff.algorithm = histogram` | Diffs that line up moved and repeated code more readably |

## Tracked files

```text
~/.bashrc
~/.config/dotfiles/        bootstrap.sh and package lists
~/.config/fish/config.fish
~/.config/ghostty/
~/.config/nvim/
~/.github/                 CI workflow and Neovim smoke test
~/.gitconfig
~/README.md
```

## Common commands

In Fish, the abbreviation `dots` expands to `git dotfiles`.

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

## Packages

`~/.config/dotfiles/packages.txt` lists everything these dotfiles use, by Arch
package name, and `packages-cachyos.txt` adds CachyOS-only packages. Install
them on an existing machine by re-running the bootstrap script, which skips
everything already set up:

```bash
~/.config/dotfiles/bootstrap.sh --packages
```

The Fish configuration detects optional commands before using them: `eza` for
`ls` aliases, `zoxide` for directory jumping, `direnv` for per-project
environments, and the CachyOS Fish defaults (which include the pure prompt)
when running CachyOS. The Neovim README explains what its tools are for.

## Continuous integration

`.github/workflows/ci.yml` runs on every push and pull request:

- **Lint:** StyLua and selene for the Neovim Lua, `fish --no-execute`, and
  ShellCheck for `.bashrc` and the bootstrap script
- **Secrets:** Gitleaks scans the full history for committed credentials
- **Packages:** every name in `packages.txt` must exist in the Arch repositories
- **Neovim:** installs the plugins at the versions in `lazy-lock.json`, then
  runs `.github/scripts/nvim-smoke.lua`. That script fails on plugin spec or
  loading errors, checks the Python, Molten, Catppuccin and image settings,
  and runs the DuckDB previews against sample files. The job also fails if
  `lazy-lock.json` is missing any plugin, and prints the entries to add.

## Security

Do not commit credentials, private keys, tokens, browser profiles, shell history,
or other sensitive files. Keep machine-specific Git identity data in
`~/.gitconfig.local`, which is intentionally not tracked.

Examples of files that should not be tracked:

```text
~/.ssh/id_*
~/.aws/credentials
~/.gnupg/
~/.netrc
~/.local/share/fish/fish_history
~/.gitconfig.local
~/.config/fish/fish_variables
```

The bootstrap script lists these in the repository's local exclude file, so Git
refuses to add them, even through a directory such as
`git dotfiles add ~/.config/fish`, unless forced with `-f`. To add the list by
hand:

```bash
mkdir -p "$HOME/.dotfiles/info"
cat >> "$HOME/.dotfiles/info/exclude" <<'EOF'
/.ssh/
/.aws/credentials
/.gnupg/
/.netrc
/.local/share/fish/fish_history
/.gitconfig.local
/.config/fish/fish_variables
/.dotfiles-backup/
EOF
```
