# Path to your oh-my-zsh installation.
export ZSH=$HOME"/.oh-my-zsh"

ZSH_THEME="blinks"
HYPHEN_INSENSITIVE="true"

plugins=(
  git
  history-substring-search
  mercurial
  z
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# initialize vars used for mercurial plugin
ZSH_THEME_HG_PROMPT_PREFIX=" [%{%B%F{blue}%}"
ZSH_THEME_HG_PROMPT_SUFFIX="%{%f%k%b%K{${bkg}}%B%F{green}%}]"
ZSH_THEME_HG_PROMPT_DIRTY=" %{%F{red}%}*%{%f%k%b%}"
ZSH_THEME_HG_PROMPT_CLEAN=""

source $ZSH/oh-my-zsh.sh

export PROMPT='%{%f%k%b%}
%{%K{${bkg}}%B%F{green}%}%n%{%B%F{blue}%}@%{%B%F{cyan}%}%m%{%B%F{green}%} %{%b%F{yellow}%K{${bkg}}%}%~%{%B%F{green}%}$(git_prompt_info)$(hg_prompt_info)%E%{%f%k%b%}
%{%K{${bkg}}%}$(_prompt_char)%{%K{${bkg}}%} %#%{%f%k%b%} '

# bind keys for history-substring-search
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='vim'
fi

# Enable Vi key bindings
set -o vi

# save a long history
HISTSIZE=130000
SAVEHIST=130000

# share history between terminals
fc -IR

export PATH="/usr/local/sbin:$PATH"

source ~/.aliases
