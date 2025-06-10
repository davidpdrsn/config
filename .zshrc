## ENV
## -----------------------

source "$HOME/.cargo/env"
eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(zoxide init zsh)"

export EDITOR='nvim'

export DOTNET_CLI_TELEMETRY_OPTOUT=1

export RIPGREP_CONFIG_PATH=$HOME/.ripgreprc

export ANTHROPIC_API_KEY=***REMOVED***
export BITS_N_WIRES_PLANE_API_KEY=***REMOVED***

# History
ISTFILE=$HOME/.zhistory
setopt APPEND_HISTORY
HISTSIZE=1200
SAVEHIST=1000

export CARGO_PROFILE_DEV_SPLIT_DEBUGINFO=unpacked
export CARGO_PROFILE_TEST_SPLIT_DEBUGINFO=unpacked
export CARGO_INCREMENTAL=1
export CARGO_UNSTABLE_SPARSE_REGISTRY=true
export CARGO_TERM_COLOR=always
export BLENDER_PATH="/Applications/Blender.app/Contents/MacOS/Blender"
export GODOT_PATH="/Applications/Godot_mono.app/Contents/MacOS/Godot"

export LUN_DEV_DB_PASS="***REMOVED***"
export LUN_PROD_DB_PASS="***REMOVED***"

export PATH=$PATH:/usr/local
export PATH=$PATH:/Users/davidpdrsn/.ark/bin
export PATH=$PATH:/Users/davidpdrsn/.bin
export PATH=$PATH:/Applications/Postgres.app/Contents/Versions/latest/bin
export PATH=$PATH:/Applications/wim-dev.app/Contents/MacOS
export PATH=$PATH:/Users/davidpdrsn/.dotnet/tools
export PATH=$PATH:"/opt/homebrew/opt/postgresql@17/bin"
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:/Users/davidpdrsn/go/bin
export PATH=$PATH:/Users/davidpdrsn/Code/google-cloud-sdk/bin
export PATH=/opt/homebrew/opt/make/libexec/gnubin:$PATH

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# make ctrl-p, ctrl-n, etc work in tmux
bindkey -e

# enable completion
autoload -Uz compinit
compinit

# make completion with tab look not terrible
setopt auto_menu
setopt always_to_end
setopt complete_in_word
unsetopt flow_control
unsetopt menu_complete
zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion::complete:*' use-cache 1
zstyle ':completion::complete:*' cache-path $ZSH_CACHE_DIR
zstyle ':completion:*' list-colors ''
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'

## PLUGINS
## -----------------------

source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

source ~/.fzf.zsh

# graphite completion
_gt_yargs_completions()
{
  local reply
  local si=$IFS
  IFS=$'
' reply=($(COMP_CWORD="$((CURRENT-1))" COMP_LINE="$BUFFER" COMP_POINT="$CURSOR" /opt/homebrew/bin/gt --get-yargs-completions "${words[@]}"))
  IFS=$si
  _describe 'values' reply
}
compdef _gt_yargs_completions gt

## PROMPT
## -----------------------

# Make the colors work
autoload -U colors && colors

# edit current line in vim
if [[ -z "$NVIM" ]]; then
  autoload -U edit-command-line
  zle -N edit-command-line
  bindkey '\033' edit-command-line
  export KEYTIMEOUT=1
fi

# Allow for output of commands
setopt prompt_subst

# Save a smiley to a local variable if the last command exited with success.
# local symbol="$"
local symbol="❯"
local start="%(?,%{$fg[green]%}$symbol%{$reset_color%},%{$fg[red]%}$symbol%{$reset_color%})"

# rust things to install
# https://github.com/davidpdrsn/is-vim-running
# https://github.com/davidpdrsn/smart-pwd
# https://github.com/davidpdrsn/smart-pwd-2
# https://github.com/davidpdrsn/git-prompt
# https://github.com/davidpdrsn/git-branch-picker
# https://github.com/davidpdrsn/git-remove-merged-branches
# https://github.com/davidpdrsn/build-proxy
# https://github.com/davidpdrsn/test-command
# https://github.com/davidpdrsn/git-diff-ai-summarize
# ripgrep
# zoxide
# exa
# cargo-hack
# /Users/davidpdrsn/code/cli
# brew install difftastic
# https://github.com/cargo-limit/cargo-limit

PROMPT=$'
$(smart-pwd-2) %{$reset_color%}$(git-prompt)$(is-vim-running)%{$reset_color%}
${start} '
RPROMPT=$''

## ALIASES
## -----------------------

alias ..='z ..'
alias c='clear'
alias ca='cargo'
alias cd='z'
alias cat='bat'
alias dt='cd ~/Desktop'
alias diff='diff --color'
alias ea='nvim ~/.zshrc'
alias rl='source ~/.zshrc'
alias l='exa --long --header --git --all --sort name'
alias la='exa -a --long --header --sort name'
alias mkdir='mkdir -p'
alias xtask='cargo xtask'
alias o='open .'
alias b='/Users/davidpdrsn/.cargo/bin/t build'
alias r='/Users/davidpdrsn/.cargo/bin/t run'
alias tl='ingestlogs pipe --'
alias ci='/Users/davidpdrsn/.cargo/bin/t "open ci"'
alias wim='/Applications/wim-dev.app/Contents/MacOS/ark-client'
alias wim-app='/Applications/wim-dev.app/Contents/MacOS/ark-client'
alias commit-config='cd ~ && git add --all && git commit -m "misc changes" && git push && cd -'
alias at='tmux attach'
alias local-ark-client='/Users/davidpdrsn/code/embark/wim-app/wim-app/target/release/ark-client'
alias mbark='/Users/davidpdrsn/code/embark/wim-mod/mbark'
alias godot='/Applications/Godot_mono.app/Contents/MacOS/Godot'
alias x='/Users/davidpdrsn/Games/traffic-signal-sim/x'
alias blender='/Applications/Blender.app/Contents/MacOS/Blender'

# nvim
alias vi='nvim'
alias vim='nvim'
alias vimconflicts='nvim $(rg -l -. "[<>=]{7}")'
alias vv='nvim $(rg --files | fzf)'

# git
alias gaa='git add --all'
alias gac='git add --all && git commit --verbose'
alias gap='git add -p'
alias gb='git branch'
alias gc='git commit --verbose'
alias gcai='git commit --verbose -e -m "$(git-diff-ai-summarize)"'
alias gco='git checkout'
alias gcob='git checkout -b'
alias gcof='git-branch-picker checkout'
alias gmf='git-branch-picker merge'
alias git-cargo-lock-conflict='git checkout main -- Cargo.lock'
alias gl='git log --decorate --graph --oneline -20'
alias gll='git log --decorate --graph --oneline'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gd='git diff'
alias d='git diff'
alias gdc='git diff --cached'
alias gr='git reset'
alias grh='git reset --hard'
alias gca='git commit --amend --verbose'
alias gpr='cargo fmt -- --check && gh pr create'
alias gpll='git pull'
alias ga='git add'
alias grb='git rebase'
alias gm='git merge'
alias grbc='git rebase --continue'
alias grba='git rebase --abort'
alias grbi='git rebase -i'
alias gs='git show'
alias gg='lazygit'

## FUNCTIONS
## -----------------------

function g {
  if [[ $# > 0 ]]; then
    git $@
  else
    git status -sb
  fi
}
compdef g=git

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
