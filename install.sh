#!/usr/bin/env bash

SOURCE=${BASH_SOURCE[0]}
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_HOME=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
RUNT=$(date +%F_%H-%M-%S)

if [ $USER == "root" ]; then
  SHELLUSER=$SUDO_USER
else
  SHELLUSER=$USER
fi

HOMEDIR=$(eval echo ~$SHELLUSER)


function shutup_on_apt() {
    echo "Disable APT warning."
    if [ ! -d ~/.cloudshell ]; then mkdir ~/.cloudshell; fi
    touch ~/.cloudshell/no-apt-get-warning
}

function update_apt() {
    export DEBIAN_FRONTEND=noninteractive
    export DEBIAN_PRIORITY=critical
    echo "Updating pkg manager db"
    sudo -E apt-get -qy update 
}

function install_utils_apt() {
    export DEBIAN_FRONTEND=noninteractive
    export DEBIAN_PRIORITY=critical
    shutup_on_apt 
    update_apt > /dev/null 2>&1
    echo "Installing or updating utils via pkg manager"
    sudo apt install -qy \
        zsh \
        curl \
        fzf \
        bat \
        htop \
        ncdu \
        nmap \
        > /dev/null 2>&1
}

function install_krew() {
  echo "Installing krew"
  (
    set -x; cd "$(mktemp -d)" &&
    OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
    KREW="krew-${OS}_${ARCH}" &&
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
    tar zxvf "${KREW}.tar.gz" &&
    ./"${KREW}" install krew
  ) > /dev/null 2>&1
}

function install_krew_utils() {
  echo "Installing or updating krew plugins"
  export PATH="${KREW_ROOT:-$HOMEDIR/.krew}/bin:$PATH"
  kubectl krew install -v=0 \
    sniff \
    ctx \
    ns \
    tail \
    node-shell \
    neat \
    > /dev/null 2>&1
}

function install_omz() {

  if [ -d $HOMEDIR/.oh-my-zsh ]; then
    echo "Backup old ohmyzsh and p10k scripts"
    mv $HOMEDIR/.oh-my-zsh $HOMEDIR/.oh-my-zsh-$RUNT
  fi
  echo "Installing ohmyzsh and p10k scripts"
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended > /dev/null 2>&1
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOMEDIR/.oh-my-zsh/custom}/themes/powerlevel10k > /dev/null 2>&1
}

function configure_zsh() {
  echo "Installing ohmyzsh profile"
  if [ -f $HOMEDIR/.zshrc ]; then
    mv $HOMEDIR/.zshrc $HOMEDIR/.zshrc-$RUNT
  fi
  ln -sf $SCRIPT_HOME/zshrc.sh $HOMEDIR/.zshrc
  
  echo "Installing p10k profile"
  if [ -f $HOMEDIR/.p10k.zsh ]; then
    mv $HOMEDIR/.p10k.zsh $HOMEDIR/.p10k.zsh-$(date +%F)
  fi
  ln -sf $SCRIPT_HOME/p10k.zsh $HOMEDIR/.p10k.zsh
}

function switch_shell() {
  echo "Changing default shell to zsh"
  sudo chsh $SHELLUSER -s $(which zsh)
  
}

function install_myself() {
  # I need a couple sha512
  ME=$SOURCE
  ME_FULL_SHA=$(sha512sum $ME)
  ME_SHA=${ME_FULL_SHA:0:129}

  INIT_SCRIPT="$HOMEDIR/.customize_environment"
  if [ -f $INIT_SCRIPT ]; then
    INIT_SCRIPT_FULL_SHA=$(sha512sum $INIT_SCRIPT)
    INIT_SCRIPT_SHA=${INIT_SCRIPT_FULL_SHA:0:129}
  else
    INIT_SCRIPT_SHA=0
  fi

  if [ $ME_SHA != $INIT_SCRIPT_SHA ]; then
    echo "Installed myself too."
    ln -sf $ME $INIT_SCRIPT
  fi

  if [ "$(crontab -l -u $SHELLUSER 2>/dev/null|grep -c $SCRIPT_HOME)" -lt 1 ]; then
    echo "Installing crontab"
    CRONTMP=$(mktemp)
    crontab -l -u $SHELLUSER 2>/dev/null|grep -v $SCRIPT_HOME > $CRONTMP
    echo  -e "# Update shell init git\n0,15,30,45 * * * * git -C $SCRIPT_HOME pull -q" >> $CRONTMP
    crontab -u $SHELLUSER $CRONTMP
    rm $CRONTMP
  fi
}

function correct_permissions() {
  # Deference is a bitch.
  find $HOMEDIR -type l -not -user $SHELLUSER -exec sudo chown -h $SHELLUSER:$SHELLUSER {} \;
  find $HOMEDIR -not -type l -not -user $SHELLUSER -exec sudo chown $SHELLUSER:$SHELLUSER {} \;
}

function main() {
    if [ ! $GOOGLE_CLOUD_SHELL ]; then
      echo -e "I've been written for Google Cloud Shell.\nIf you want to proceed\nexport GOOGLE_CLOUD_SHELL=true"
      exit 0
    fi
    INSTALL=0
    which zsh > /dev/null || INSTALL=1  2>&1
    if [ $INSTALL -gt 0 ] || [ ${FORCE:-0} -gt 0 ]; then
        if [ ${FORCE:-0} -gt 0 ]; then echo "Forcing Install"; fi
        install_utils_apt
        install_omz
        configure_zsh
        install_krew
        install_krew_utils
        switch_shell
    else
        echo "ZSH is present. Assuming I'm already installed."
    fi
    install_myself
    correct_permissions
}

main
exit 0