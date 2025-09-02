# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
    *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        # We have color support; assume it's compliant with Ecma-48
        # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
        # a case would tend to support setf rather than setaf.)
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi

unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
    xterm*|rxvt*)
        PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
        ;;
    *)
        ;;
esac

# Fuzzy finding navigation
function select_project {
    selected=$(find ~/projects -mindepth 1 -maxdepth 1 -type d | sort -d | fzf)
    if  [[ $selected ]]; then
        cd $selected
        return 0 # Success
    else
        return 1 # Fail (No selection)
    fi
}

function wsp {
    if select_project; then
        clear
    fi
}

function directory_search {
    selected=$(find * -type d -not \( -name node_modules -prune \) | fzf)
    if  [[ $selected ]]; then
        cd $selected
        return 0 # Success
    else
        return 1 # Fail (No selection)
    fi
}

function wds {
    if directory_search; then
        clear
    fi
}

function spring_profile_active {
    export SPRING_PROFILES_ACTIVE="$1"
    echo "SPRING_PROFILES_ACTIVE set to $SPRING_PROFILES_ACTIVE"
}

function ap {
    local chosen command
    chosen=$(alias | fzf)
    if [[ -n "$chosen" ]]; then
        command=$(echo "$chosen" | sed -E "s/^alias [^=]+='(.*)'$/\1/")
        eval "$command"
    fi
}

# Startup dev tmux session
function dev {
    if clear; then
        tmux new-session -s Dev -n nvim
    fi
}

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Alias
alias ls='eza -l'
alias ll='eza -alF'
alias cl="clear"
alias shutdown='wsl.exe --shutdown'
alias proj="cd ~/projects"
alias dots="cd ~/.dotfiles/"
alias lg="lazygit"
alias grpo="git remote prune origin"

# Neovim
alias vim='nvim'
alias neovim='cd ~/.config/nvim/'

# Java stuff
alias mjr='mvn exec:java'
alias mjt='mvn test'
alias msr='mvn spring-boot:run'
alias mdr='mvn dependency:resolve'
alias mdt='mvn dependency:tree'
alias mdp='mvn dependency:purge-local-repository'
alias mcc='mvn clean compile'
alias mci='mvn clean install'
alias mvdu='mvn versions:display-dependency-updates'
alias spa='spring_profile_active'

# Ansible-vault
alias ave='ansible-vault encrypt'
alias avd='ansible-vault decrypt'

# Docker
alias dip='docker image pull'
alias dcu='docker compose up'
alias dcd='docker compose down'
alias dps='docker ps'
alias drm='docker rm'
alias drun='docker run'
alias dstop='docker stop'

# Envs
alias envs='$(ListEnvs | fzf)'
alias untrack='git update-index --assume-unchanged ~/.dotfiles/.bashrc.d/envrc ~/.dotfiles/connections/connections.json'
alias track='git update-index --no-assume-unchanged ~/.dotfiles/.bashrc.d/envrc ~/.dotfiles/connections/connections.json'

# Binds
bind '"\C-f":"wsp\n"'
bind '"\C-g":"wds\n"'
bind '"\C-e":"ap\n"'

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

export PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
echo -ne '\033]0;Ubuntu\a'

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export M2_HOME=/usr/share/maven
export PATH=${M2_HOME}/bin:${PATH}
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
export PATH=$PATH:/usr/share/python3

export EDITOR="nvim"

# Source config files from the bashrc config drop directory
if [ -d "$HOME/.bashrc.d" ]; then
    for rc in ~/.bashrc.d/*rc; do
        source "$rc"
    done
fi

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

eval "$(starship init bash)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
