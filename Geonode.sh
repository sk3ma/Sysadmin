#!/usr/bin/env bash

###############################################################
# This script will automate a Geonode installation on Ubuntu. #
# It will install Docker, Geonode, and create the containers. #
###############################################################

# System preparation.
system() {
    echo -e "\e[32;1;3mUpdating repositories\e[m"
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
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker ${USER}
    chmod a=rw /var/run/docker.sock
}

# Geonode installation.
geonode() {
    echo -e "\e[32;1;3mCreating directory\e[m"
    sudo mkdir -vp /opt/geonode/
    echo -e "\e[32;1;3mAltering permissions\e[m"
    sudo usermod -aG www-data ${USER}
    sudo chown -Rfv ${USER}:www-data /opt/geonode/
    sudo chmod -Rfv 775 /opt/geonode/
    cd /opt
    echo -e "\e[32;1;3mDownloading Geonode\e[m"
    git clone https://github.com/GeoNode/geonode.git -b 3.2.x /opt/geonode
    cd /opt/geonode
    echo -e "\e[32;1;3mCreating containers\e[m"
    docker-compose -f docker-compose.yml pull
    docker-compose -f docker-compose.yml up -d
    echo -e "\e[32;1;3mShowing containers\e[m"
    docker-compose ps
    exit
}

# Calling functions.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[35;1;3;5mUbuntu detected, proceeding...\e[m"
    system
    install
    geonode
fi
