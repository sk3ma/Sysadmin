#!/usr/bin/env bash

#####################################################################
# This script will automate a Zabbix installation on Ubuntu 20.04.  #
# The script installs the LAMP stack and downloads Zabbix server 6. #
#####################################################################

# Declaring variables.
DISTRO=$(lsb_release -ds)
USERID=$(id -u)
DATE=$(date +%F)
ZLOG=/var/log/zabbix/zabbix_server.log
ZPID=/run/zabbix/zabbix_server.pid
SOCK=/run/zabbix
PATH1=/usr/lib/zabbix/alertscripts
PATH2=/usr/lib/zabbix/externalscripts
PORT=10051
HOST=localhost
NAME=zabbix_db
USER=zabbix_user
PASS=2K9qT8Zb

# Sanity checking.
if [[ ${USERID} -ne "0" ]]; then
    echo -e "\e[31;1;3mYou must be root, exiting.\e[m"
    exit 1
fi

# Apache installation.
apache() {
    echo -e "\e[96;1;3mDistribution: ${DISTRO}\e[m"
    echo -e "\e[32;1;3mInstalling Apache\e[m"
    apt update
    apt install apache2 apache2-utils vim -qy
    systemctl start apache2
    systemctl enable apache2
    cd /var/www/html
    echo "<h1>Apache is operational</h1>" > index.html
}

# PHP installation.
php() {
    echo -e "\e[32;1;3mInstalling PHP\e[m"
    apt install libapache2-mod-php7.4 php7.4 php7.4-{cli,curl,common,dev,fpm,gd,mbstring,mysqlnd} -qy
    echo "<?php phpinfo(); ?>" > info.php
}

# MariaDB installation.
mariadb() {
    echo -e "\e[32;1;3mInstalling MariaDB\e[m"
    apt install software-properties-common curl -qy
    cd /opt
    curl -LsS -O https://downloads.mariadb.com/MariaDB/mariadb_repo_setup
    bash mariadb_repo_setup --mariadb-server-version=10.6
    apt update
    apt install mariadb-server-10.6 mariadb-client-10.6 mariadb-common -qy
    systemctl start mariadb
    systemctl enable mariadb
    rm -f mariadb_repo_setup
}

# Zabbix database.
database() {
    echo -e "\e[32;1;3mConfiguring MariaDB\e[m"
    local dbase=$(cat << STOP
CREATE DATABASE zabbix_db character set utf8 collate utf8_bin;
CREATE USER 'zabbix_user'@'%' IDENTIFIED by 'y5VgWsOK';
GRANT ALL PRIVILEGES ON zabbix_db.* TO 'zabbix_user'@'%';
STOP
)
    echo "${dbase}" > /var/www/html/zabbix_db.sql
}

# Zabbix installation.
zabbix() {
    echo -e "\e[32;1;3mDownloading Zabbix\e[m"
    cd /opt
    wget --progress=bar:force https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-3+ubuntu20.04_all.deb
    dpkg -i zabbix-release_6.0-3+ubuntu20.04_all.deb
    echo -e "\e[32;1;3mConfiguring repository\e[m"
    cd /etc/apt
    cp sources.{list,orig}
    rm -f sources.list
    local source=$(cat << STOP
deb http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal-backports main restricted universe multiverse
deb http://archive.canonical.com/ubuntu focal partner
deb-src http://archive.canonical.com/ubuntu focal partner
STOP
)
    echo "${source}" > sources.list
    echo -e "\e[32;1;3mInstalling Zabbix\e[m"
    cp /etc/apt/sources.list.d/zabbix.{list,orig}
    rm -f /etc/apt/sources.list.d/zabbix.list
    local list=$(cat << STOP
deb [arch=amd64] http://repo.zabbix.com/zabbix/6.0/ubuntu focal main
deb-src [arch=amd64] http://repo.zabbix.com/zabbix/6.0/ubuntu focal main
STOP
)
    echo "${list}" > /etc/apt/sources.list.d/zabbix.list
    apt update
    apt install zabbix-agent zabbix-server-mysql php-mysql zabbix-frontend-php zabbix-sql-scripts zabbix-apache-conf -qy
    systemctl start zabbix-server zabbix-agent
    systemctl enable zabbix-server zabbix-agent
    rm -f zabbix-release_6.0-3+ubuntu20.04_all.deb
}

# Configuring server.
config() {
    echo -e "\e[32;1;3mConfiguring Zabbix\e[m"
    cd /etc/zabbix
    cp zabbix_server.conf zabbix_zabbix_server.orig-${DATE}
    rm -f zabbix_server.conf
    tee zabbix_server.conf << STOP
ListenPort=${PORT}
LogFile=${ZLOG}
LogFileSize=0
PidFile=${ZPID}
SocketDir=${SOCK}
DBHost=${HOST}
DBName=${NAME}
DBUser=${USER}
DBPassword=${PASS}
StartPollers=100
StartPollersUnreachable=50
AlertScriptsPath=${PATH1}
ExternalScripts=${PATH2}
Timeout=30
FpingLocation=/usr/bin/fping
Fping6Location=/usr/bin/fping6
LogSlowQueries=3000
StatsAllowedIP=127.0.0.1
HousekeepingFrequency=1
MaxHousekeeperDelete=100
StartPingers=1
StartTrappers=1
StartDiscoverers=15
StartPreprocessors=15
StartHTTPPollers=5
StartAlerters=5
StartTimers=2
StartEscalators=2
CacheSize=256M
HistoryCacheSize=64M
HistoryIndexCacheSize=32M
TrendCacheSize=32M
ValueCacheSize=256M
STOP
}

# Firewall creation.
firewall() {
    echo -e "\e[32;1;3mAdjusting firewall\e[m"
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 10050:10051/tcp
    echo "y" | ufw enable
    ufw reload
    systemctl restart apache2
    echo -e "\e[33;1;3;5mFinished, configure Zabbix server.\e[m"
    exit
}

# Calling functions.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[35;1;3;5mUbuntu detected, proceeding...\e[m"
    apache
    php
    mariadb
    database
    zabbix
    config
    firewall
fi
