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
# HISTSIZE=1000
HISTSIZE=-1
#HISTFILESIZE=2000
HISTFILESIZE=-1

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Source profile if not already sourced
if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.profile" ]; then
    . "$HOME/.profile"
fi

HISTFILE="$XDG_STATE_HOME/bash/history"

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

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

alias cal='ncal -M -b'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

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

alias zathura='zathura --fork'

export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}/usr/local/lib"

export NNN_NOWAIT=1

if [[ $(hostname) = new-centos.novalocal ]]; then
    export TERM=xterm
    alias vim="$HOME/software/vim/build/bin/vim"
    alias kira="$HOME/software/kira/build/bin/kira"
    # Fermat executable for Kira
    export FERMATPATH="/usr/local/bin/fer64"
    alias tmux="tmux -2"
    #export PATH="$HOME/software/git/build/bin:$PATH"
fi

if [[ $(hostname) = amps ]]; then
    export FERMATPATH="$HOME/scratch/software/fermat/ferl6/fer64"
    source "/media/scratch/software/OpenXM/rc/dot.bashrc"

    # http://blog.joncairns.com/2013/12/understanding-ssh-agent-and-ssh-add/
    source "$HOME/scratch/software/ssh-find-agent/ssh-find-agent.sh"
    # set_ssh_agent_socket
    # set_ssh_agent
    ssh-add -l >&/dev/null || ssh-find-agent -a || eval $(ssh-agent) > /dev/null

    [ -f ~/.fzf.bash ] && source ~/.fzf.bash
fi

if [[ $(hostname) = mac ]]; then
    # export FERMATPATH="$HOME/soft/ferl6/fer64"
    # source "$HOME/soft/OpenXM/rc/dot.bashrc"

    # http://blog.joncairns.com/2013/12/understanding-ssh-agent-and-ssh-add/
    # source ~/soft/ssh-find-agent/ssh-find-agent.sh
    source "$HOME/.local/src/ssh-find-agent/ssh-find-agent.sh"
    # set_ssh_agent_socket
    ssh-add -l >&/dev/null || ssh-find-agent -a || eval $(ssh-agent) > /dev/null

    [ -f ~/.fzf.bash ] && source ~/.fzf.bash
    . "$CARGO_HOME/env"

    if type rg &> /dev/null; then
      export FZF_DEFAULT_COMMAND='rg --files'
      export FZF_DEFAULT_OPTS='-m --height 50% --border'
    fi
fi

if [[ $(hostname) = thinkpad ]]; then
    # http://blog.joncairns.com/2013/12/understanding-ssh-agent-and-ssh-add/
    source "$HOME/.local/src/ssh-find-agent/ssh-find-agent.sh"
    ssh-find-agent -a \
        || ssh-add -l \
        || eval $(ssh-agent)

    [ -f "$XDG_CONFIG_HOME/fzf.bash" ] && . "$XDG_CONFIG_HOME/fzf.bash"
    [ -f "$CARGO_HOME/env" ] && . "$CARGO_HOME/env"

    if type rg &> /dev/null; then
        export FZF_DEFAULT_COMMAND='rg --files'
        export FZF_DEFAULT_OPTS='-m --height 50% --border'
    fi
    
    # Scientific software environment
    source $XDG_CONFIG_HOME/scientific-env.sh

    # TeX Live environment
    source $XDG_CONFIG_HOME/texlive-env.sh
fi

if [[ $(hostname) = fire-chief-ash.maths.ox.ac.uk ]]; then
    # http://blog.joncairns.com/2013/12/understanding-ssh-agent-and-ssh-add/
    source "$HOME/.local/src/ssh-find-agent/ssh-find-agent.sh"
    ssh-find-agent -a \
        || ssh-add -l \
        || eval $(ssh-agent)

    [ -f "$XDG_CONFIG_HOME/fzf.bash" ] && . "$XDG_CONFIG_HOME/fzf.bash"
    [ -f "$CARGO_HOME/env" ] && . "$CARGO_HOME/env"

    if type rg &> /dev/null; then
        export FZF_DEFAULT_COMMAND='rg --files'
        export FZF_DEFAULT_OPTS='-m --height 50% --border'
    fi
    
    # Scientific software environment
    source $XDG_CONFIG_HOME/scientific-env.sh
fi

# export NVM_DIR="$HOME/.config/nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

alias gnomecc='XDG_CURRENT_DESKTOP=GNOME gnome-control-center'

# Custom aliases for development environment
alias v='vim'
alias nv='nvim'
alias vf='vifm'
alias za='zathura'
alias rg='rg --smart-case'
alias fd='fd --hidden'

# fzf integration
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

# fzf functions
fv() {
    local file
    file=$(fzf --preview 'head -100 {}') && [ -n "$file" ] && vim "$file"
}

fnv() {
    local file
    file=$(fzf --preview 'head -100 {}') && [ -n "$file" ] && nvim "$file"
}

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'

# Theme switching aliases
alias theme-dark='theme-switch dark'
alias theme-light='theme-switch light'
alias theme-toggle='if grep -q "#282828" ~/.Xresources 2>/dev/null; then theme-switch light; else theme-switch dark; fi'

# Check current theme
theme-status() {
    if grep -q "#282828" ~/.Xresources 2>/dev/null; then
        echo "Current theme: dark"
    elif grep -q "#fbf1c7" ~/.Xresources 2>/dev/null; then
        echo "Current theme: light"
    else
        echo "Theme not detected or custom theme in use"
    fi
}

clean_bash_history() {
    local src="$HOME/dotfiles/dotfiles-private/bash_history"
    local tmp

    # create temp file
    tmp=$(mktemp) || { echo "Failed to create temp file"; return 1; }

    # generate cleaned history
    if sort -u "$src" > "$tmp"; then
        if [ -s "$tmp" ]; then
            # create backup
            cp "$src" "$src.bak" || { echo "Backup failed, aborting."; rm -f "$tmp"; return 1; }
            # replace original
            mv "$tmp" "$src"
            echo "History cleaned. Backup saved as $src.bak"
        else
            echo "Generated file is empty. Not replacing original."
            rm -f "$tmp"
            return 1
        fi
    else
        echo "sort command failed."
        rm -f "$tmp"
        return 1
    fi
}

export PASSWORD_STORE_DIR="$XDG_DATA_HOME/password-store"

# Suppress GTK accessibility bridge warning
export NO_AT_BRIDGE=1

# GnuPG: ensure terminal pinentry works correctly
if [ -t 1 ]; then
    export GPG_TTY="$(tty)"
fi
# . "/home/chestnov/.local/share/cargo/env"

# SSH agent helper functions
ssh_agent_start() {
    eval $(ssh-agent -s)
    ssh-add ~/.ssh/id_rsa 2>/dev/null || ssh-add ~/.ssh/id_ed25519 2>/dev/null || echo "No SSH keys found to add"
}

ssh_agent_list() {
    ssh-find-agent -c
}

ssh_agent_kill() {
    ssh-agent -k
}
