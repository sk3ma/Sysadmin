#!/usr/bin/env bash

############################################################################
# This script will automate a Zabbix agent 2 installation on Ubuntu 20.04. #
# The script will configure the Zabbix agent 2 with custom configuration.  #
############################################################################

# Declaring variables.
USERID=$(id -u)
DISTRO=$(lsb_release -ds)
DATE=$(date +%F)
ZABSRV=zabbix.mycompany,172.31.28.99
ZABIPA=13.248.45.67
AGENAME=Ubuntu_node1
AGEPORT=10050
AGEPID=/var/run/zabbix/zabbix_agent2.pid
AGELOG=/var/run/zabbix/zabbix_agent2.log

# Sanity checking.
if [[ ${USERID} -ne "0" ]]; then
    echo -e "\e[31;1;3mYou must be root, exiting.\e[m"
    exit 1
fi

# Downloading agent.
agent() {
    echo -e "\e[96;1;3mDistribution: ${DISTRO}\e[m"
    echo -e "\e[32;1;3mDownloading agent\e[m"
    local version=6.0-1+ubuntu20.04
    cd /opt
    wget --progress=bar:force https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_${version}_all.deb
    dpkg -i zabbix-release_${version}_all.deb
    echo -e "\e[32;1;3mUpdating repository\e[m"
    cd /etc/apt/sources.list.d
    rm -f zabbix.list
    local source=$(cat << STOP
deb [arch=amd64] http://repo.zabbix.com/zabbix/6.0/ubuntu focal main
deb-src [arch=amd64] http://repo.zabbix.com/zabbix/6.0/ubuntu focal main
STOP
)
    echo "${source}" > zabbix.list
    echo -e "\e[32;1;3mInstalling agent\e[m"
    apt update
    apt install zabbix-agent2 -y
    rm -f zabbix-release_${version}_all.deb
}
 
# Configuring agent.
config() {
    echo -e "\e[32;1;3mConfiguring agent\e[m"
    cd /etc/zabbix/
    cp -v zabbix_agent2.conf zabbix_agent2.orig-${DATE}
    tee zabbix_agent2.conf << STOP
ListenPort=${AGEPORT}
Server=${ZABSRV}
ServerActive=${ZABSRV}
Hostname=${AGENAME}
HostMetadata=Linux
PidFile=${AGEPID}
LogFile=${AGELOG}
LogFileSize=0
AllowKey=system.run[*]
RefreshActiveChecks=120
Timeout=30
DebugLevel=3
# AllowRoot=1
ControlSocket=/tmp/agent.sock
Include=/etc/zabbix/zabbix_agent2.d/*.conf
Include=./zabbix_agent2.d/plugins.d/*.conf
STOP
}

# Creating exception.
firewall() {
    echo -e "\e[32;1;3mAltering firewall\e[m"
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 10050/tcp
    ufw allow from ${ZABIPA} to any port ${AGEPORT}
    echo "y" | ufw enable 
    ufw reload
    ufw show added
}

# Enabling service.
service() {
    echo -e "\e[32;1;3mStarting agent\e[m"
    systemctl start zabbix-agent2
    systemctl enable zabbix-agent2
    echo -e "\e[33;1;3;5mFinished, agent installed.\e[m"
    exit
}

# Calling functions.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[35;1;3;5mUbuntu detected, proceeding...\e[m"
    agent
    config
    firewall
    service
fi
