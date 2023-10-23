#!/usr/bin/env bash

#############################################################################
# The purpose of the script is to automate a Docker installation on Ubuntu. #
# The script installs Docker, downloads Portainer and creates an exception. #
#############################################################################

# Declaring variables.
DISTRO=$(lsb_release -ds)
USERID=$(id -u)
IPADDR=192.168.56.74

# Sanity checking.
if [[ ${USERID} -ne "0" ]]; then
    echo -e "\e[31;1;3m[❌] You must be root, exiting.\e[m"
    exit 1
fi

# Docker installation.
install() {
    echo -e "\e[96;1;3m[OK] Distribution: ${DISTRO}\e[m"
    echo
    echo -e "\e[32;1;3m[INFO] Updating system\e[m"
    apt update
    echo -e "\e[32;1;3m[INFO] Adding repository\e[m"
    apt install apt-transport-https ca-certificates software-properties-common curl -qy
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable" -y
    echo -e "\e[32;1;3m[INFO] Installing Docker\e[m"
    apt install docker-ce docker-ce-cli containerd.io -qy
    usermod -aG docker ${USER}
    chmod a=rw /var/run/docker.sock
}

# Docker configuration.
config() {
    echo -e "\e[32;1;3m[INFO] Testing Docker\e[m"
    docker pull docker/whalesay:latest
    docker run docker/whalesay:latest cowsay "Docker is functional."
    echo -e "\e[32;1;3m[INFO] Creating volume\e[m"
    mkdir -pv /container
    docker volume create bindmount
}

# Enabling service.
service() {
    echo -e "\e[32;1;3m[INFO] Starting service\e[m"
    systemctl start docker
    systemctl enable docker
}

# Firewall creation.
firewall() {
    echo -e "\e[32;1;3m[INFO] Adjusting firewall\e[m"
    ufw allow 9000/tcp
    echo "y" | ufw enable
    ufw reload
}

# Downloading Portainer.
portainer() {
    echo -e "\e[32;1;3m[INFO] Downloading Portainer\e[m"
    docker pull portainer/portainer-ce:latest
    docker run -d                                \
    -p ${IPADDR}:9000:9000                       \
    --name portainer                             \
    --restart=always                             \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /container:/data portainer/portainer-ce:latest
    echo -e "\e[33;1;3;5m[✅] Finished, configure webUI.\e[m"
}
    
# Defining function.
main() {
    install
    config
    service
    firewall
    portainer
}

# Calling function.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[35;1;3;5m[OK] Ubuntu detected, proceeding...\e[m"
    main
    exit
fi
