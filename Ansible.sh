#!/usr/bin/env bash

###############################################################################
# The purpose of the script is to automate an Ansible installation on Ubuntu. #          
# The script installs Ansible and configures the Ansible hosts inventory.     #
# The script then downloads an Apache role from Ansible Galaxy.               # 
###############################################################################

# Declaring variable.
USERID=$(id -u)

# Sanity checking.
if [[ ${USERID} -ne "0" ]]; then
    echo -e "\e[1;3mYou must be root, exiting.\e[m"
    exit 1
fi

# Ansible installation.
install() {
    echo -e "\e[1;3mInstalling Ansible\e[m"
    apt update
    apt install software-properties-common -qy
    add-apt-repository ppa:ansible/ansible -y
    apt install ansible sshpass python3 git vim -qy
}

# Ansible configuration.      
config() {
    echo -e "\e[1;3mConfiguring hosts\e[m"
    tee /etc/hosts << STOP
127.0.0.1        localhost
127.0.1.1        ansible
192.168.33.21    node01
192.168.33.22    node02
STOP
    echo -e "\e[1;3mConfiguring inventory\e[m"
    cp /etc/ansible/hosts /etc/ansible/hosts.orig
    tee /etc/ansible/hosts << STOP
[managed_nodes]
node01
node02
STOP
}

# Galaxy role.      
role() {
    echo -e "\e[1;3mAdding role\e[m"
    ansible-galaxy init /etc/ansible/apache --offline
    echo -e "\e[1;3;5mInstallation is complete.\e[m"
    exit
}

# Calling functions.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[1;3mUbuntu detected, proceeding...\e[m"
    install
    config
    role
fi
