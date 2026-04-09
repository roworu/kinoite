autoload -Uz colors && colors

### prompt
PROMPT='%F{green}%n%f@%m %~ > '

### history
DISABLE_UNTRACKED_FILES_DIRTY="true"
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

### useful options
setopt append_history hist_ignore_dups inc_append_history share_history
setopt COMBINING_CHARS
setopt autocd

### aliases

# ls
# https://github.com/eza-community/eza
alias ls="eza -F --icons=auto --color=always --group-directories-first"
alias ll="eza -alF --git --icons --color=always --group-directories-first"
alias la="eza -aF --git --icons --color=always --group-directories-first"
alias l="ls"

# cat
# https://github.com/sharkdp/bat
alias cat="bat -P --decorations=never --color=always"

# grep
# https://github.com/burntsushi/ripgrep
alias grep="rg"

# find
# https://github.com/sharkdp/fd
alias find="fd"

# as some terminal not provide it
alias ssh="TERM=xterm-256color ssh"

fastfetch