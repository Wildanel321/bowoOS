# LiteOffice OS — User Bash Configuration
# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

shopt -s checkwinsize
shopt -s histappend

HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000

# Color prompt with LiteOffice OS styling
PS1='\[\033[01;36m\]┌──(\[\033[01;32m\]\u@liteoffice\[\033[01;36m\])-[\[\033[01;34m\]\w\[\033[01;36m\]]\n\[\033[01;36m\]└─\[\033[01;33m\]\$\[\033[00m\] '

alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias df='df -h'
alias free='free -m'
alias status='liteoffice-health --check'
alias monitor='liteoffice-monitor --cli'
alias install='sudo lite-installer'

# Friendly interactive welcome banner
if [ -t 0 ] && [ -z "${LITEOFFICE_BANNER_SHOWN:-}" ]; then
    export LITEOFFICE_BANNER_SHOWN=1
    echo -e "\033[1;36m=================================================================="
    echo -e "  LiteOffice OS 1.0 LTS — Terminal Console"
    echo -e "  Type \033[1;32msudo lite-installer\033[1;36m to install OS to disk"
    echo -e "==================================================================\033[0m"
fi
