source /usr/share/cachyos-fish-config/cachyos-config.fish


# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end
alias ls 'eza'
alias ll 'eza -lah --icons --git --group-directories-first'
alias lt 'eza --tree --level=2 --icons'
alias la 'eza -a'
alias l 'eza -lh'
alias lsize 'eza -lah --sort=size --reverse'
alias ltime 'eza -lah --sort=modified --reverse'
