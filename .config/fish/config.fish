# Load CachyOS defaults when they are available, but keep this config portable.
if test -r /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# Use Neovim for commit messages, $EDITOR and man pages.
if command -q nvim
    set -gx EDITOR nvim
    set -gx VISUAL nvim
    set -gx MANPAGER 'nvim +Man!'
end

# Page Git output through delta when it is installed (options in ~/.gitconfig).
if command -q delta
    set -gx GIT_PAGER delta
end

# Aliases and directory jumping are for interactive shells only, so scripts and
# `fish -c` keep calling the real commands.
if status is-interactive
    # Prefer eza when installed; otherwise leave the system ls command untouched.
    if command -q eza
        alias ls 'eza'
        alias ll 'eza -lah --icons --git --group-directories-first'
        alias lt 'eza --tree --level=2 --icons'
        alias la 'eza -a'
        alias l 'eza -lh'
        alias lsize 'eza -lah --sort=size --reverse'
        alias ltime 'eza -lah --sort=modified --reverse'
    end

    # Enable smarter directory jumping when zoxide is installed.
    if command -q zoxide
        zoxide init fish | source
    end

    # Load and unload per-project environments (.envrc) on cd.
    if command -q direnv
        direnv hook fish | source
    end

    # `dots status`, `dots add ...`: expands to the bare-repository command.
    abbr --add dots 'git dotfiles'
end
