#!/usr/bin/env bash

#############################################################################
# The purpose of the script is to automate an AWX installation on Ubuntu.   #
# The script installs Docker and Ansible then executes an Ansible playbook. #
#############################################################################

# Declaring variable.
DISTRO=$(lsb_release -ds)

# Package installation.
system() {
    echo -e "\e[96;1;3m[OK] Distribution: ${DISTRO}\e[m"
    sudo apt update
    echo -e "\e[32;1;3m[INFO] Installing packages\e[m"
    sudo apt install nodejs npm python3-pip git git-secrets -y
    sudo npm install npm --global
}

# Docker installation.
install() {
    echo -e "\e[32;1;3m[INFO] Installing packages\e[m"
    sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
    sudo bash -c 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -'
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable" -y
    echo -e "\e[32;1;3m[INFO] Installing Docker\e[m"
    sudo apt install docker-ce docker-compose -y
    pip3 install docker-compose==1.25.0
}

# Ansible installation.
awx() {
    echo -e "\e[32;1;3m[INFO] Installing Ansible\e[m"
    cd /tmp
    sudo apt install pwgen unzip ansible -y
    local secret=$(pwgen -N 1 -s 40)
    wget https://github.com/ansible/awx/archive/17.1.0.zip
    unzip 17.1.0.zip
    cd awx-17.1.0/installer
    echo -e "\e[32;1;3m[INFO] Configuring inventory\e[m"
    sudo sed -i 's|admin_user=|# admin_user=admin|g' inventory
    echo -e "admin_user=admin" >> inventory
    echo -e "admin_password=1q2w3e4r5t" >> inventory
    echo -e "secret_key=${secret}" >> inventory
    echo -e "\e[32;1;3m[INFO] Executing playbook\e[m"
    sudo ansible-playbook -i inventory install.yml
    echo -e "\e[33;1;3;5m[OK] Finished, installation complete.\e[m"
}

# Defining function.
main() {
    system
    install
    awx
}

# Calling function.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[35;1;3;5m[OK] Ubuntu detected, proceeding...\e[m"
    main
    exit
fi
