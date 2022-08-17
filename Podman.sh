#!/usr/bin/env bash

################################################################################
# The purpose of this script is to automate a Podman installation on CentOS 8. #
# The script will install Podman, create a pod, and add containers to the pod. #
################################################################################

# Declaring variable.
USERID=$(id -u)
DISTRO=$(cat /etc/redhat-release)

# Sanity checking.
if [[ ${USERID} -ne "0" ]]; then
    echo -e "\e[31;1;3mYou must be root, exiting.\e[m"
    exit 1
fi

# System preparation.
system() {
    echo -e "\e[96;1;3mDistribution: ${DISTRO}\e[m"
    echo -e "\e[32;1;3mPreparing system\e[m"
    sed -i 's|mirrorlist|#mirrorlist|g' /etc/yum.repos.d/CentOS-*
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
    echo -e "\e[32;1;3mUpdatinging system\e[m"
    yum update -y
    echo -e "\e[32;1;3Installing Podman\e[m"
    yum install podman-docker vim -y
    echo -e "\e[32;1;3mCreating directory\e[m"
    mkdir -vp /opt/mysql
}

# Pod creation.
pod() {
    echo -e "\e[32;1;3mCreating pod\e[m"
    podman pod create \
    --name zabbix \
    -p 80:8080 \
    -p 10051:10051 \
    -p 3000:3000
}

# MySQL container.
sqlcon() {
    echo -e "\e[32;1;3mCreating MySQL\e[m"
podman run --name mysql-server \
    -t -e MYSQL_DATABASE="zabbix_db" \
    -e MYSQL_USER="zabbix_user" \
    -e MYSQL_PASSWORD="zabbix" \
    -e MYSQL_ROOT_PASSWORD="L0gM31n" \
    -v /opt/mysql/:/var/lib/mysql/:Z \
    --restart=always \
    --pod=zabbix \
    -d mysql:8.0:latest --character-set-server=utf8 --collation-server=utf8_bin --default-authentication-plugin=mysql_native_password
}

# Zabbix container.
zabcon() {
    echo -e "\e[32;1;3mCreating Zabbix\e[m"
    podman run \
    --name zabbix-server-mysql \
    -t -e DB_SERVER_HOST="127.0.0.1" \
    -e MYSQL_DATABASE="zabbix_db" \
    -e MYSQL_USER="zabbix_user" \
    -e MYSQL_PASSWORD="zabbix" \
    -e MYSQL_ROOT_PASSWORD="L0gM31n" \
    -e ZBX_JAVAGATEWAY="127.0.0.1" \
    --restart=always \
    --pod=zabbix \
    -d docker.io/zabbix/zabbix-server-mysql:latest
}

# Agent container.
agecon() {
    echo -e "\e[32;1;3mCreating Agent\e[m"
    podman run \
    --name zabbix-agent \
    -eZBX_SERVER_HOST="192.168.56.80,127.0.0.1" \
    --restart=always \
    --pod=zabbix \
    -d docker.io/zabbix/zabbix-agent2:latest
}

# Java container.
javcon() {
    echo -e "\e[32;1;3mCreating Java\e[m"
    podman run \
    --name zabbix-java-gateway \
    -t --restart=always \
    --pod=zabbix \
    -d docker.io/zabbix/zabbix-java-gateway:latest
}

# Web container.
webcon() {
    echo -e "\e[32;1;3mCreating Web\e[m"
    podman run \
    --name zabbix-web-mysql \
    -t -e ZBX_SERVER_HOST="192.168.56.80" \
    -e DB_SERVER_HOST="192.168.56.80" \
    -e MYSQL_DATABASE="zabbix_db" \
    -e MYSQL_USER="zabbix_user" \
    -e MYSQL_PASSWORD="zabbix" \
    -e MYSQL_ROOT_PASSWORD="L0gM31n" \
    --restart=always --pod=zabbix \
    -d docker.io/zabbix/zabbix-web-nginx-mysql:latest
}

# Grafana container.
grafcon() {
    echo -e "\e[32;1;3mCreating Grafana\e[m"
    podman run \
    --name grafana \
    --restart=always \
    --pod=zabbix \
    -d docker.io/grafana/grafana:latest
    echo -e "\e[33;1;3;5mFinished, podman installed.\e[m"
    exit
}

# Calling functions.
if [[ -f /etc/redhat-release ]]; then
    echo -e "\e[35;1;3;5mCentOS detected, proceeding...\e[m"
    system
    pod
    sqlcon
    zabcon
    agecon
    javcon
    webcon
    grafcon
fi
