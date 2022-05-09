#!/usr/bin/env bash

SOURCE=${BASH_SOURCE[0]}
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_HOME=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

function shutup_on_apt() {
    if [ ! -d ~/.cloudshell ]; then mkdir ~/.cloudshell; fi
    touch ~/.cloudshell/no-apt-get-warning
}

function update_apt() {
    export DEBIAN_FRONTEND=noninteractive
    export DEBIAN_PRIORITY=critical
    sudo -E apt-get -qy update 
}

function install_utils_apt() {
    export DEBIAN_FRONTEND=noninteractive
    export DEBIAN_PRIORITY=critical
    shutup_on_apt
    update_apt
    sudo apt install -qy \
        zsh \
        curl \
        fzf \
        bat \
        htop \
        ncdu \
        nmap
}

function install_krew() {
  (
    set -x; cd "$(mktemp -d)" &&
    OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
    KREW="krew-${OS}_${ARCH}" &&
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
    tar zxvf "${KREW}.tar.gz" &&
    ./"${KREW}" install krew
  )
}

function install_krew_utils() {
  export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
  kubectl krew install \
    sniff \
    ctx \
    ns \
    tail \
    node-shell \
    neat
}

function install_omz() {
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
}

function configure_zsh() {
  if [ ! -f $HOME/.zshrc ]; then
    ln -sf $SCRIPT_HOME/zshrc.sh $HOME/.zshrc
  fi

  if [ ! -f $HOME/.p10k.zsh ]; then
    ln -sf $SCRIPT_HOME/p10k.zsh $HOME/.p10k.zsh
  fi
}

function switch_shell() {
  sudo chsh $USER -s $(which zsh)
  echo "Default Shell changed to ZSH. Please run zsh to start"
}

function install_myself() {
  # I need a couple sha512
  ME=$SCRIPT_HOME/$(basename $0)
  ME_FULL_SHA=$(sha512sum $ME)
  ME_SHA=${ME_FULL_SHA:0:129}

  INIT_SCRIPT="$HOME/.customize_environment"
  INIT_SCRIPT_FULL_SHA=$(sha512sum $INIT_SCRIPT)
 

  if [ -f $INIT_SCRIPT ]; then
    INIT_SCRIPT_SHA=${INIT_SCRIPT_FULL_SHA:0:129}
  else
    INIT_SCRIPT_SHA=0
  fi

  if [ $ME_SHA != $INIT_SCRIPT_SHA ]; then
    ls -sf $ME $INIT_SCRIPT
  fi

}

function main() {
    INSTALL=0
    command -v zsh || INSTALL=1
    if [ $INSTALL -gt 0 ] || [ ${FORCE:-0} -gt 0 ]; then
        echo "Installing utils via pkg manager"
        install_utils_apt >/dev/null #2>&1
        echo "Installing ZSH via curl"
        configure_zsh  >/dev/null #2>&1
        install_omz  >/dev/null #2>&1
        echo "Installing KubeUtils via curl"
        install_krew  >/dev/null #2>&1
        install_krew_utils  >/dev/null #2>&1
        switch_shell  >/dev/null #2>&1
    fi
    install_myself
}


set -e
main
set +e
exit 0