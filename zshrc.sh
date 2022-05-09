# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
COMPLETION_WAITING_DOTS="true"

plugins=(
  git
  fzf
  golang
  gcloud
  sudo
  vscode
  docker-compose
  brew
  themes
  kubectl
  kubectx
  terraform
)

source $ZSH/oh-my-zsh.sh
source <(KUBECONFIG=/dev/null kubectl completion zsh)

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
export PATH="${PATH}:${HOME}/.krew/bin"

# aliases
alias cat=batcat
alias k=kubectl
alias vi=vim
