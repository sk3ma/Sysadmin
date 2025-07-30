#!/usr/bin/env bash

# Declaring variables.
DATE=$(date +%F)
AGENAME=$(hostname -f)
DISTRO=$(hostnamectl | awk '/Operating/ { print $3 }')
LINUX=$(hostnamectl | awk '/Operating/ { print $4 }')
MDATA="Linux"
AGEPORT="10050"
AGEPID="/run/zabbix/zabbix_agent2.pid"
AGELOG="/var/log/zabbix/zabbix_agent2.log"

# Sanity checking.
if [[ "${EUID}" -ne "0" ]]; then
    echo
    echo "███████╗██████╗ ██████╗  ██████╗ ██████╗ "
    echo "██╔════╝██╔══██╗██╔══██╗██╔═══██╗██╔══██╗"
    echo "█████╗  ██████╔╝██████╔╝██║   ██║██████╔╝"
    echo "██╔══╝  ██╔══██╗██╔══██╗██║   ██║██╔══██╗"
    echo "███████╗██║  ██║██║  ██║╚██████╔╝██║  ██║"
    echo "╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝"
    echo
    echo -e "\e[31;1;3;5m[🔴] You must be root, exiting.\e[m"
    exit 1
fi

# IP addresses.
read -rp "Enter Zabbix Server IP: " ZBX_SERVER
read -rp "Enter Zabbix Proxy IP: " ZBX_PROXY

# EPEL repository.
epel() {
    echo -e "\e[35;1;3m[🟡] Distribution: ${DISTRO} ${LINUX}\e[0m"
    echo
    echo -e "\e[32;1;3m[🟡] Installing EPEL\e[m"
    dnf install epel-release ca-certificates -y
    echo -e "\e[32;1;3m[🟡] Exclude Zabbix\e[m"
    sed -i '/\[epel\]/a excludepkgs=zabbix-*' /etc/yum.repos.d/epel.repo
}

# Zabbix repository.
repo() {
    echo -e "\e[32;1;3m[🟡] Download repository\e[m"
    rpm --import https://repo.zabbix.com/zabbix-official-repo.key
    tee /etc/yum.repos.d/zabbix.repo << STOP > /dev/null
[zabbix]
name=Zabbix Official Repository
baseurl=http://repo.zabbix.com/zabbix/7.0/rocky/9/x86_64/
gpgcheck=1
gpgkey=https://repo.zabbix.com/zabbix-official-repo.key
enabled=1
STOP
}

# Agent installation.
zagent() {
    echo -e "\e[32;1;3m[🟡] Adding repository\e[m"
    dnf clean all
    dnf install https://repo.zabbix.com/zabbix/7.0/rocky/9/x86_64/zabbix-release-7.0-5.el9.noarch.rpm -y
}

# Agent configuration.
config() {
    echo -e "\e[32;1;3m[🟡] Installing agent\e[m"
    dnf install zabbix-agent2 zabbix-get zabbix-selinux-policy python3-pip -y
    echo -e "\e[32;1;3m[🟡] Installing API\e[m"
    pip3 install py-zabbix zabbix_api
    echo -e "\e[32;1;3m[🟡] Configuring agent\e[m"
    cd /etc/zabbix || exit
    cp -v /etc/zabbix/zabbix_agent2.{conf,orig-${DATE}}
    rm -f zabbix_agent2.conf
    tee /etc/zabbix/zabbix_agent2.conf << STOP > /dev/null
# Custom agent configuration.
DebugLevel=3
ListenPort=${AGEPORT}
Server=${ZBX_SERVER},${ZBX_PROXY}
ServerActive=${ZBX_PROXY}:10051
Hostname=${AGENAME}
HostMetadata=${MDATA}
PidFile=${AGEPID}
LogFile=${AGELOG}
LogFileSize=0
AllowKey=system.run[*]
RefreshActiveChecks=120
Timeout=30
ControlSocket=/tmp/agent.sock
Include=/etc/zabbix/zabbix_agent2.d/*.conf
Include=/etc/zabbix/zabbix_agent2.d/plugins.d/*.conf
STOP
    echo -e "\e[32;1;3m[🟡] Disabling SELinux\e[m"
    setenforce 0
    sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
}

# Firewall configuration.
fwall() {
    echo -e "\e[32;1;3m[🟡] Configuring firewall\e[m"
    systemctl start firewalld && systemctl enable firewalld
    firewall-cmd --add-port=10050/tcp --permanent
    firewall-cmd --reload
}

# Enabling service.
reload() {
    echo -e "\e[32;1;3m[🟡] Starting service\e[m"
    cat << "STOP"
 ______      _     _     _         ___                   _   
|___  /     | |   | |   (_)       / _ \                 | |  
   / /  __ _| |__ | |__  ___  __ / /_\ \ __ _  ___ _ __ | |_ 
  / /  / _` | '_ \| '_ \| \ \/ / |  _  |/ _` |/ _ \ '_ \| __|
./ /__| (_| | |_) | |_) | |>  <  | | | | (_| |  __/ | | | |_ 
\_____/\__,_|_.__/|_.__/|_/_/\_\ \_| |_/\__, |\___|_| |_|\__|
                                         __/ |               
                                        |___/                
STOP
    systemctl start zabbix-agent2 && systemctl enable zabbix-agent2
    echo -e "\e[33;1;3m[🟢] Finished, installation complete\e[m"
}

# Defining function.
main() {
    epel
    repo
    zagent
    config
    fwall
    reload
}

if [[ -f /etc/rocky-release ]]; then
    echo -e "\e[38;5;208;1;3;5m[OK] Rocky detected, proceeding...\e[m"
    echo
    main
fi
