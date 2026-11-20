# Linux Dotfiles

Personal Linux configuration files managed with a bare Git repository.

## Tracked configurations

- Bash shell
- Fish shell
- Ghostty terminal
- Git configuration
- Neovim / AstroNvim configuration

Fish's generated `~/.config/fish/fish_variables` file is intentionally not
tracked; hand-written Fish configuration belongs in `config.fish` or `conf.d/`.

## Repository setup

The repository is stored as a bare Git repository:

```bash
git init --bare "$HOME/.dotfiles"

git config --global alias.dotfiles \
  '!git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME"'

git dotfiles config --local status.showUntrackedFiles no
```

After the first commit, connect the GitHub remote and set the upstream branch
so that plain `git dotfiles push` and `git dotfiles pull` work:

```bash
git dotfiles remote add origin git@github.com:YOUR_USERNAME/dotfiles.git
git dotfiles push -u origin main
```

Also add the [ignore list](#security) so sensitive files cannot be added by
accident.

The tracked `~/.gitconfig` loads optional machine-local Git settings from
`~/.gitconfig.local`. Keep private or machine-specific values such as your email
address there instead of committing them to this repository:

```bash
git config --file "$HOME/.gitconfig.local" user.email "you@example.com"
```

`user.useConfigOnly = true` is enabled, so Git will refuse to create commits
until an email address is configured explicitly.

## Tracked files

```text
~/.bashrc
~/.config/fish/config.fish
~/.config/ghostty/
~/.config/nvim/
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

Add the [ignore list](#security), then configure your machine-local Git email
separately:

```bash
git config --file "$HOME/.gitconfig.local" user.email "you@example.com"
```

Verify the installation. The first line of `status -sb` should read
`## main...origin/main`:

```bash
git dotfiles status -sb
git config user.name
git config user.email
```

## Optional tools

The Fish configuration detects optional commands before using them. Install the
ones you want:

- `eza` for enhanced `ls` aliases
- `zoxide` for smarter directory navigation
- CachyOS Fish defaults from `/usr/share/cachyos-fish-config/cachyos-config.fish`
  when running CachyOS

The Neovim Markdown/image workflow additionally uses:

- ImageMagick for inline image conversion in Snacks
- `wl-clipboard` on Wayland or `xclip` on X11 for clipboard image pasting
- Ghostscript for PDF rendering (optional)
- Tectonic or another LaTeX engine for rendered math (optional)

The Neovim geospatial file-browser integration can additionally use:

- `exiftool` for image metadata
- GDAL (`gdalinfo` and `ogrinfo`) for raster/vector metadata
- QGIS for opening selected geospatial files

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

On each machine, list them in the repository's local exclude file. Git then
refuses to add them, even through a directory such as
`git dotfiles add ~/.config/fish`, unless forced with `-f`:

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
EOF
```
