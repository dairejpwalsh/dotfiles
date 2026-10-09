# Load CachyOS defaults when they are available, but keep this config portable.
if test -r /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

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
