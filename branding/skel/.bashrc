# LiteOffice OS — User Bash Configuration
if [ -z "$PS1" ]; then
    return
fi

shopt -s checkwinsize
shopt -s histappend

HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000

# Color prompt with LiteOffice OS styling
PS1='\[\033[01;34m\]\u@liteoffice\[\033[00m\]:\[\033[01;32m\]\w\[\033[00m\]\$ '

alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias df='df -h'
alias free='free -m'
alias status='liteoffice-healthd --check'
alias monitor='liteoffice-monitor --cli'
