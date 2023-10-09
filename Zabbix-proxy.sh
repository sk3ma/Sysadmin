#!/usr/bin/env bash

#################################################################################
# This scripts downloads, installs and configures Zabbix Proxy on Ubuntu 22.04. #
#################################################################################

# Declaring variables.
DISTRO=$(lsb_release -ds)
USERID=$(id -u)
DATE=$(date +%F)
PORT="10051"
DBASE="/var/lib/zabbix/zabbix_pxy.sqlite3"
MODE="0" # active mode.

# Sanity checking.
if [[ ${USERID} -ne "0" ]]; then
    echo -e "\e[31;1;3m[ERROR] You must be root, exiting\e[m"
    exit 1
fi

# SQLite directory.
if ! [[ -d "/var/lib/zabbix" ]]; then 
    mkdir -p /var/lib/zabbix
fi

# SQLite installation.
dbase() {
    echo -e "\e[96;1;3m[OK] Distribution: ${DISTRO}\e[m"
    echo -e "\e[32;1;3m[INFO] Installing SQLite\e[m"
    apt update
    apt install sqlite3 -qy
}

# Zabbix installation.
proxy() {
    echo -e "\e[32;1;3m[INFO] Downloading package\e[m"
    cd /tmp
    wget --progress=bar:force https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-3+ubuntu22.04_all.deb
    dpkg -i zabbix-release_6.0-3+ubuntu22.04_all.deb
    echo -e "\e[32;1;3m[INFO] Configuring repository\e[m"
    cd /etc/apt
    cp sources.{list,orig}
    rm -f sources.list
    local source=$(cat << STOP
deb http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse
deb http://archive.canonical.com/ubuntu jammy partner
deb-src http://archive.canonical.com/ubuntu jammy partner
STOP
)
    echo "${source}" > sources.list
    echo -e "\e[32;1;3m[INFO] Installing package\e[m"
    cp /etc/apt/sources.list.d/zabbix.{list,orig}
    rm -f /etc/apt/sources.list.d/zabbix.list
    local list=$(cat << STOP
deb [arch=amd64] http://repo.zabbix.com/zabbix/6.0/ubuntu jammy main
deb-src [arch=amd64] http://repo.zabbix.com/zabbix/6.0/ubuntu jammy main
STOP
)
    echo "${list}" > /etc/apt/sources.list.d/zabbix.list
    apt update
    apt install zabbix-proxy-sqlite3 zabbix-sql-scripts -qy
    systemctl start zabbix-proxy
    systemctl enable zabbix-proxy
    rm -f zabbix-release_6.0-3+ubuntu22.04_all.deb
}

# Importing scripts.
scripts() {
    echo -e "\e[32;1;3m[INFO] Importing schema\e[m"
    chown zabbix:zabbix /var/lib/zabbix
    cat /usr/share/zabbix-sql-scripts/sqlite3/proxy.sql | sqlite3
}

# Configuring server.
config() {
    echo -e "\e[32;1;3m[INFO] Configuring proxy\e[m"
    read -p "Enter the Zabbix server IP address: " ZBXSRV
    cd /etc/zabbix
    cp -v zabbix_proxy.conf zabbix_proxy.orig-${DATE}
    rm -f zabbix_proxy.conf
    tee zabbix_proxy.conf << STOP > /dev/null
ProxyMode=${MODE}
Server=${ZBXSRV}
Hostname=Zabbix proxy
ListenPort=${PORT}
LogFile=/var/log/zabbix/zabbix_proxy.log
LogFileSize=0
PidFile=/run/zabbix/zabbix_proxy.pid
SocketDir=/run/zabbix
DBHost=localhost
DBName=${DBASE}
HeartbeatFrequency=60
SNMPTrapperFile=/var/log/snmptrap/snmptrap.log
Timeout=30
FpingLocation=/usr/bin/fping
Fping6Location=/usr/bin/fping6
LogSlowQueries=3000
StatsAllowedIP=127.0.0.1
STOP
}

# Restarting services.
reload() {
    echo -e "\e[32;1;3m[INFO] Restarting service\e[m"
    systemctl restart zabbix-proxy
    echo -e "\e[33;1;3;5m[OK] Register the proxy and configure the agent\e[m"
    exit
}

# Defining function.
main() {
    dbase
    proxy
    scripts
    config
    reload
}

# Calling function.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[35;1;3;5m[OK] Ubuntu detected, proceeding...\e[m"
    main
fi
