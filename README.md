# Linux Dotfiles

Personal Linux configuration files managed with a bare Git repository.

## Tracked configurations

- Bash shell
- Fish shell, including the `newproj` project generator
- Ghostty terminal
- Git configuration, with delta diffs and optional SSH commit signing
- Neovim / AstroNvim configuration (see `~/.config/nvim/README.md`)
- Package list and bootstrap script for new machines
- GitHub Actions checks for all of the above, and weekly plugin updates

**This repository is public.** Anything committed can be read by anyone; see
[Security](#security).

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

If Neovim is installed, the script also installs its plugins at the versions
recorded in `lazy-lock.json`. Otherwise, start `nvim` once to install them and
then run `:Lazy restore` in it: on first start lazy.nvim installs the newest
versions the plugin specs allow rather than the locked ones.

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

### Diffs with delta

When delta (`git-delta`) is installed, Fish and Bash set `GIT_PAGER=delta`, so
`git diff`, `git log -p` and `git show` are syntax-highlighted, side by side and
with line numbers; `n`/`N` jump between files. Without delta Git uses its normal
pager. In a narrow split, use `git -c delta.side-by-side=false diff`.

### Signed commits

Commit signing uses SSH keys and is off until you turn it on per machine:

```bash
~/.config/dotfiles/setup-signing.sh
```

It signs with `~/.ssh/id_ed25519` (or the key you pass), writes the settings to
`~/.gitconfig.local`, and prints the public key to add on GitHub as a *signing
key* (Settings > SSH and GPG keys > New SSH key > Key type: Signing Key), so
commits show as Verified.

## Terminal and shells

- **Ghostty over SSH:** `ssh-env` and `ssh-terminfo` shell-integration features
  make servers that don't know Ghostty's terminal type work: Ghostty installs its
  terminfo on the server (needs `tic` there) or falls back to `xterm-256color`.
- **Editor:** Fish and Bash set `EDITOR` and `VISUAL` to Neovim and show man
  pages in Neovim (`MANPAGER='nvim +Man!'`) when it is installed.
- **Bash** gets the same direnv and zoxide hooks as Fish, for sessions that use it.

## Tracked files

```text
~/.bashrc
~/.config/dotfiles/        bootstrap.sh, setup-signing.sh, package lists, never-track
~/.config/fish/            config.fish and functions/newproj.fish
~/.config/ghostty/
~/.config/nvim/
~/.github/                 CI and plugin-update workflows, their scripts, Dependabot
~/.gitconfig
~/README.md
```

## Starting a Python project

`newproj NAME` (Fish) creates a ready-to-use project in `./NAME` and cds into
it:

- a uv-managed package (`src/` layout) with pytest, Ruff, BasedPyright and
  ipykernel, plus GeoPandas, Rasterio, Shapely and pyproj (skip them with
  `--no-geo`)
- the BasedPyright, Ruff and pytest settings from
  `~/.config/nvim/examples/pyproject.toml`, and a starter test
- `data/` and `outputs/` folders (ignored by Git, along with `.env`)
- the direnv `.envrc`, already allowed, so the environment activates on `cd`
- a Jupyter kernel named after the project, for `:MoltenInit NAME` in Neovim

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

- **Lint:** StyLua and selene for the Neovim Lua, `fish --no-execute` for the
  Fish files, and ShellCheck for `.bashrc` and every shell script
- **Secret scan:** Gitleaks checks the full history for credentials, and the
  job fails if any tracked file matches `.config/dotfiles/never-track`
- **Arch package names:** every name in `packages.txt` exists in the Arch repos
- **Ghostty config:** `ghostty +validate-config` with the latest Ghostty
- **Shell scripts:** `setup-signing.sh` produces commits that verify, and
  `newproj --no-geo` creates a project whose tests, lint and kernel work
- **Neovim smoke test:** installs the plugins at the versions in
  `lazy-lock.json` and runs `.github/scripts/nvim-smoke.lua`, which fails on
  plugin spec or loading errors and checks the Python, Molten, Catppuccin,
  image, notebook, Neo-tree, DuckDB-preview and raster-thumbnail behaviour.
  The job also fails if `lazy-lock.json` doesn't match what was installed, and
  checks that BasedPyright and Ruff start on a Python file and report errors.

`.github/workflows/update-plugins.yml` runs every Monday: it updates the
plugins, runs the smoke test against the new versions and, only if it passes,
opens (or refreshes) a pull request with the new `lazy-lock.json`. Dependabot
keeps the workflows' GitHub Actions up to date.

### Repository settings

Two settings on GitHub complete this; they can't be committed:

1. **Settings > Actions > General > Workflow permissions:** tick *Allow GitHub
   Actions to create and approve pull requests*, so the weekly plugin update
   can open its pull request.
2. **Settings > Rules > Rulesets > New branch ruleset** (or *Branches > Add
   branch protection rule*) for `main`: *Require status checks to pass* with
   the CI jobs (Lint, Secret scan, Arch package names, Ghostty config, Shell
   scripts, Neovim smoke test). New machines install from `main`, so this
   keeps a broken change from reaching them.

## Security

This repository is public: anything committed, now or in its history, can be
read by anyone. Keep credentials, private keys, tokens, shell history and
machine-specific details (hostnames in `~/.ssh/config`, internal paths, your
email) out of it. Machine-specific Git settings live in the untracked
`~/.gitconfig.local`.

`~/.config/dotfiles/never-track` lists paths that must never be committed. The
bootstrap script copies them into the repository's local exclude file, so Git
refuses to add them, even through a directory such as
`git dotfiles add ~/.config/fish`, unless forced with `-f`; CI fails if a
tracked file matches one, and Gitleaks catches keys and tokens anywhere. To
apply the list by hand:

```bash
grep -Ev '^[[:space:]]*(#|$)' ~/.config/dotfiles/never-track >> ~/.dotfiles/info/exclude
```
