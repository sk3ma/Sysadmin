#!/usr/bin/env bash

#####################################################################
# This script will automate a Geonode installation on Ubuntu 20.04. #
# Part one will install Docker and create the Geonode directory.    #
#####################################################################

# Declaring variables.
DISTRO=$(lsb_release -ds)
VERSION=$(lsb_release -cs)

cat << STOP
# --------------------------#
#   Welcome to the script.  #
# --------------------------#
        \   ^__^
         \  (OO)\_______
            (__)\       )\/\
             U  ||----w |
                ||     ||

STOP

# System preparation.
system() {
    echo -e "\e[96;1;3m[OK] Distribution: ${DISTRO}\e[m"
    echo -e "\e[32;1;3m[INFO] Updating repositories\e[m"
    sudo add-apt-repository ppa:ubuntugis/ppa -y
    sudo add-apt-repository universe -y
    echo -e "\e[32;1;3m[INFO] Installing packages\e[m"
    sudo apt install -qy apt-transport-https \
        ca-certificates                      \
        software-properties-common           \
        git-core                             \
        git-buildpackage                     \
        debhelper                            \
        devscripts                           \
        gnupg-agent                          \
        curl
}

# Docker installation.
install() {
    echo -e "\e[32;1;3m[INFO] Adding repository\e[m"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu ${VERSION} stable" -y
    echo -e "\e[32;1;3m[INFO] Installing Docker\e[m"
    sudo apt install docker-ce docker-ce-cli docker-compose containerd.io -qy
    sudo apt autoremove --purge
    echo -e "\e[32;1;3m[INFO] Starting service\e[m"
    sudo systemctl start docker && sudo systemctl enable docker
    sudo usermod -aG docker ${USER}
    sudo chmod a=rw /var/run/docker.sock
}

# Directory creation.
directory() {
    echo -e "\e[32;1;3m[INFO] Creating directory\e[m"
    sudo mkdir -vp /opt/geonode/
    echo -e "\e[32;1;3m[INFO] Altering permissions\e[m"
    sudo usermod -aG www-data ${USER}
    sudo chown -Rfv ${USER}:www-data /opt/geonode/
    sudo chmod -Rfv 775 /opt/geonode/
}

# Script execution.
script() {
    echo -e "\e[33;1;3;5m[INFO] Executing second script...\e[m"
    source /srv/scripts/Geonode_2.sh
}

# Defining function.
main() {
    system
    install
    directory
    script
}

# Calling function.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[35;1;3;5m[OK] Ubuntu detected, proceeding...\e[m"
    main
fi
