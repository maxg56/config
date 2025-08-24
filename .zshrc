# ================================
# PATH & Oh My Zsh
# ================================
export ZSH="$HOME/.oh-my-zsh"

# Ajout PNPM et local bin
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$HOME/.local/bin:$PATH"

# ================================
# Oh My Zsh configuration
# ================================
ZSH_THEME="robbyrussell"

# Plugins utiles
plugins=(
  git
)

source $ZSH/oh-my-zsh.sh

# ================================
# NVM (Node Version Manager)
# ================================
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# ================================
# Git Prompt Info (custom branch display)
# ================================
function git_prompt_info() {
    local branch
    branch=$(git symbolic-ref --quiet HEAD 2>/dev/null | \
             sed -E 's|refs/heads/||; s|feature/|f:|; s|bugfix/|b:|; s|hotfix/|h:|')
    [[ -z "$branch" ]] && return

    # Raccourcir si la branche dépasse 12 caractères
    (( ${#branch} > 12 )) && branch="${branch:0:12}…"

    echo "%{$fg[blue]%}git:(%{$fg[red]%}$branch%{$fg[blue]%})%{$reset_color%}"
}


# ================================
# Aliases pratiques
# ================================
alias gs="git status"
alias gp="git push"
alias gl="git pull"
alias gc="git commit -m"
alias gb="git branch"
alias gco="git checkout"
alias gsw="git switch"
alias gsc="git switch -c"

alias cl="clear"
alias ll="ls -la"


# ================================
# Options diverses
# ================================
# Corrige automatiquement les fautes de frappe dans les commandes
ENABLE_CORRECTION="true"

# Historique avec timestamp
HIST_STAMPS="yyyy-mm-dd"
