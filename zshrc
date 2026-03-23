# Source Facebook definitions
if [ -f /usr/facebook/ops/rc/master.zshrc ]; then
  source /usr/facebook/ops/rc/master.zshrc
fi

# Path to your oh-my-zsh installation.
export ZSH=$HOME"/.oh-my-zsh"

ZSH_THEME="blinks"
HYPHEN_INSENSITIVE="true"

plugins=(
  git
  history-substring-search
  mercurial
  z
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

# Force blinking block cursor in all vi modes
function zle-keymap-select zle-line-init {
  echo -ne '\e[1 q'
}
zle -N zle-keymap-select
zle -N zle-line-init

# save a long history
HISTSIZE=130000
SAVEHIST=130000

# share history between terminals
fc -IR

export PATH="/usr/local/sbin:$PATH"
export PATH=/usr/local/bin:$PATH

source ~/.aliases

# added by setup_fb4a.sh
export ANDROID_SDK=/opt/android_sdk
export ANDROID_NDK_REPOSITORY=/opt/android_ndk
export ANDROID_HOME=${ANDROID_SDK}
export PATH=${PATH}:${ANDROID_SDK}/emulator:${ANDROID_SDK}/tools:${ANDROID_SDK}/tools/bin:${ANDROID_SDK}/platform-tools
