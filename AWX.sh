#!/usr/bin/env bash

#############################################################################
# The purpose of the script is to automate an AWX installation on Ubuntu.   #
# The script installs Docker and Ansible then executes an Ansible playbook. #
#############################################################################

# Declaring variable.
DISTRO=$(lsb_release -ds)

# Welcome message.
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

# Package installation.
system() {
    echo -e "\e[96;1;3m[OK] Distribution: ${DISTRO}\e[m"
    sudo apt update
    echo -e "\e[32;1;3m[INFO] Installing packages\e[m"
    sudo apt install nodejs npm python3-pip git -y
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
    sudo rm -f inventory
    sudo tee inventory << STOP > /dev/null
localhost ansible_connection=local ansible_python_interpreter="/usr/bin/env python3"
[all:vars]
dockerhub_base=ansible
awx_task_hostname=awx
awx_web_hostname=awxweb
postgres_data_dir="~/.awx/pgdocker"
host_port=80
host_port_ssl=443
docker_compose_dir="~/.awx/awxcompose"
pg_username=awx
pg_password=awxpass
pg_database=awx
pg_port=5432
admin_user=admin
admin_password=1q2w3e4r5t
secret_key=${secret}
create_preload_data=True
STOP
    echo -e "\e[32;1;3m[INFO] Executing playbook\e[m"
    ansible-playbook -i inventory install.yml
    echo -e "\e[33;1;3;5m[✓] Finished, installation complete.\e[m"
    exit
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
fi
