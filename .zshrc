## ENV
## -----------------------

source "$HOME/.cargo/env"
eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(zoxide init zsh)"
export EDITOR='nvim'

# History
ISTFILE=$HOME/.zhistory
setopt APPEND_HISTORY
HISTSIZE=1200
SAVEHIST=1000

export CARGO_PROFILE_DEV_SPLIT_DEBUGINFO=unpacked
export CARGO_PROFILE_TEST_SPLIT_DEBUGINFO=unpacked
export CARGO_INCREMENTAL=1

## PLUGINS
## -----------------------

source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.fzf.zsh

## PROMPT
## -----------------------

# Make the colors work
autoload -U colors && colors

# Allow for output of commands
setopt prompt_subst

# Save a smiley to a local variable if the last command exited with success.
# local symbol="$"
local symbol="❯"
local start="%(?,%{$fg[green]%}$symbol%{$reset_color%},%{$fg[red]%}$symbol%{$reset_color%})"

PROMPT=$'
$(smart-pwd) %{$reset_color%}$(git-prompt)%{$reset_color%}
${start} '
RPROMPT=$''

## ALIASES
## -----------------------

alias ..='z ..'
alias c='clear'
alias ca='cargo'
alias cat='bat'
alias dt='cd ~/Desktop'
alias ea='nvim ~/.zshrc'
alias rl='source ~/.zshrc'
alias l='exa --long --header --git --all --sort name'
alias la='exa -a --long --header --sort name'
alias mkdir='mkdir -p'
alias xtask='cargo xtask'
alias o='open .'

# nvim
alias vi='nvim'
alias vim='nvim'
alias vimconflicts='nvim $(rg -l -. "[<>]{5}")'
alias vv='nvim $(rg --files | fzf)'

# git
alias gaa='git add --all'
alias gap='git add -p'
alias gb='git branch'
alias gc='git commit --verbose'
alias gco='git checkout'
alias gcob='git checkout -b'
alias gcof='git-branch-picker'
alias git-cargo-lock-conflict='git checkout main -- Cargo.lock'
alias gl='git log --decorate --graph --oneline -20'
alias gll='git log --decorate --graph --oneline'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias d='git diff'
alias gdc='git diff --cached'
alias gr='git reset'
alias grh='git reset --hard'

## FU
## -----------------------

function g {
  if [[ $# > 0 ]]; then
    git $@
  else
    git status -sb
  fi
}

function v {
  if [[ $# > 0 ]]; then
    nvim $@
  else
    nvim
  fi
}

function take() {
  mkdir -p "$1"
  cd "$1"
}
