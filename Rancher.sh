#!/usr/bin/env bash

####################################################################
# This script will automate a Docker installation on Ubuntu 20.04. #
# The script installs Docker and creates a Rancher container.      #
####################################################################

# Declaring variables.
DISTRO=$(lsb_release -ds)
VERSION=$(lsb_release -cs)
USERID=$(id -u)

# Sanity checking.
if [[ ${USERID} -ne "0" ]]; then
    echo -e "\e[32;1;3;5m[✗] You must be root, exiting\e[m"
    exit 1
fi

# Docker installation.
install() {
    echo -e "\e[96;1;3m[OK] Distribution: ${DISTRO}\e[m"
    echo
    cat << STOP
#--------------------#
# Welcome to Ubuntu. #
#--------------------#
                    ##        .            
              ## ## ##       ==            
           ## ## ## ##      ===            
       /""""""""""""""""\___/ ===        
  ~~~ {~~ ~~~~ ~~~ ~~~~ ~~ ~ /  ===- ~~~
       \______ o          __/            
         \    \        __/             
          \____\______/                    
STOP
    echo
    echo -e "\e[32;1;3m[INFO] Updating system\e[m"
    apt update
    echo -e "\e[32;1;3m[INFO] Adding repository\e[m"
    apt install apt-transport-https ca-certificates software-properties-common curl -qy
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu ${VERSION} stable" -y
    echo -e "\e[32;1;3m[INFO] Installing Docker\e[m"
    apt install docker-ce docker-ce-cli docker-compose containerd.io -qy
    usermod -aG docker ${USER}
    chmod a=rw /var/run/docker.sock
    echo -e "\e[32;1;3m[INFO] Creating volume\e[m"
    mkdir -p /container
    docker volume create bindmount
}

# Enabling service.
service() {
    echo -e "\e[32;1;3m[INFO] Starting service\e[m"
    systemctl start docker
    systemctl enable docker
}

container() {
    echo -e "\e[32;1;3m[INFO] Creating container\e[m"
    docker run -d             \
    --privileged              \
    --restart=unless-stopped  \
    -p 80:80                  \
    -p 443:443                \
    -v /container             \
    --name master-node        \
    rancher/rancher:latest
    docker logs master-node 2>&1 | grep "Bootstrap Password:"
    echo -e "\e[33;1;3;5m[✓] Finished, Docker installed.\e[m"
}

# Defining function.
main() {
    install
    service
    container
}

# Calling function.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[35;1;3;5m[OK] Ubuntu detected, proceeding...\e[m"
    main
    exit
fi
