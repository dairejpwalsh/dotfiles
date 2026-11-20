#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# Match ~/.config/fish/config.fish for tools and sessions that use Bash.
if command -v nvim >/dev/null; then
  export EDITOR=nvim VISUAL=nvim MANPAGER='nvim +Man!'
fi
if command -v delta >/dev/null; then export GIT_PAGER=delta; fi
if command -v zoxide >/dev/null; then eval "$(zoxide init bash)"; fi
if command -v direnv >/dev/null; then eval "$(direnv hook bash)"; fi
