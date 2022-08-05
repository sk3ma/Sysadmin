#!/usr/bin/env bash

###############################################################
# This script will automate a Geonode installation on Ubuntu. #
# It will install Docker, Geonode, and create the containers. #
###############################################################

# Declaring variable.
DISTRO=$(lsb_release -ds)

# System preparation.
system() {
    echo -e "\e[96;1;3mDistribution: ${DISTRO}\e[m"
    echo -e "\e[32;1;3mUpdating repositories\e[m"
    sudo add-apt-repository ppa:ubuntugis/ppa -y
    sudo apt update
    echo -e "\e[32;1;3mInstalling packages\e[m"
    sudo apt install software-properties-common -qy
    sudo add-apt-repository universe -y
    sudo apt install git-core git-buildpackage debhelper devscripts -qy
    sudo apt install apt-transport-https ca-certificates gnupg-agent curl -qy
}

# Docker installation.
install() {
    echo -e "\e[32;1;3mAdding repository\e[m"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    echo -e "\e[32;1;3mInstalling Docker\e[m"
    sudo apt install docker-ce docker-ce-cli docker-compose containerd.io -qy
    sudo apt autoremove --purge
    echo -e "\e[32;1;3mStarting service\e[m"
    sudo systemctl start docker && sudo systemctl enable docker
    sudo usermod -aG docker ${USER}
    sudo chmod a=rw /var/run/docker.sock
}

# Directory creation.
directory() {
    echo -e "\e[32;1;3mCreating directory\e[m"
    cd /opt
    sudo mkdir -vp /opt/geonode/
    echo -e "\e[32;1;3mAltering permissions\e[m"
    sudo usermod -aG www-data ${USER}
    sudo chown -Rfv ${USER}:www-data /opt/geonode/
    sudo chmod -Rfv 775 /opt/geonode/
}

# Script execution.
script() {
    echo -e "\e[33;1;3;5mExecuting second script...\e[m"
    source /srv/scripts/Geonode_2.sh
}

# Calling functions.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[35;1;3;5mUbuntu detected, proceeding...\e[m"
    system
    install
    directory
    script
fi
