# Path settings (modify as needed)
export PATH="$HOME/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

# Use modern completion system
autoload -Uz compinit && compinit

# Enable command auto-correction
setopt correct

# Enable case-insensitive tab completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# Syntax highlighting (install with `brew install zsh-syntax-highlighting`)
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Autosuggestions (install with `brew install zsh-autosuggestions`)
source /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# History settings
HISTSIZE=5000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt appendhistory
setopt sharehistory
setopt histignorealldups
setopt histreduceblanks

# Prompt customization (simple but useful)
autoload -Uz promptinit && promptinit
PROMPT='%F{cyan}%n@%m%f %F{yellow}%~%f %# '

# Aliases (customize based on your workflow)
alias ls='ls --color=auto'    # Linux
alias ll='ls -lh'
alias la='ls -lAh'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

# Conditional loading (macOS vs Linux)
if [[ "$(uname)" == "Darwin" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
    alias ls='ls -G'  # macOS equivalent for colored output
fi

if [[ "$(uname)" == "Darwin" ]]; then
    # FZF setup (install with `brew install fzf`)
    [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
else
    [ -f ~/soft/fzf.zsh ] && source ~/soft/fzf.zsh
fi
