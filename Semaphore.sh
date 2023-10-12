#!/usr/bin/env bash

######################################################################
# This script automates a Semaphore installation Ubuntu 22.04.       #
# The script installs Ansible, MariaDB, Semaphore and configures it. #
######################################################################

# Declaring variables.
DISTRO=$(lsb_release -ds)
USERID=$(id -u)

# Sanity checking.
if [[ ${USERID} -ne "0" ]]; then
    echo -e "\e[31;1;3;5m[❌] You must be root, exiting\e[m"
    exit 1
fi

# Semaphore installation.
install() {
    echo -e "\e[96;1;3m[OK] Distribution: ${DISTRO}\e[m"
    echo
    echo -e "\e[32;1;3m[INFO] Installing Ansible\e[m"
    apt update
    apt install git curl wget software-properties-common -y
    apt-add-repository ppa:ansible/ansible -y
    apt install ansible -y
    echo -e "\e[32;1;3m[INFO] Installing Semaphore\e[m"
    cd /opt
    wget https://github.com/ansible-semaphore/semaphore/releases/download/v2.9.37/semaphore_2.9.37_linux_amd64.deb
    dpkg -i semaphore_2.9.37_linux_amd64.deb
}

# MariaDB installation.
dbase() {
    echo -e "\e[32;1;3m[INFO] Installing MariaDB\e[m"
    apt install software-properties-common curl -qy
    curl -LsS -O https://downloads.mariadb.com/MariaDB/mariadb_repo_setup
    bash mariadb_repo_setup --mariadb-server-version=10.6
    apt install mariadb-server-10.6 mariadb-client-10.6 mariadb-common -qy
    systemctl start mariadb
    systemctl enable mariadb
    rm -f mariadb_repo_setup
    echo -e "\e[32;1;3m[INFO] Configuring MariaDB\e[m"
    cat << STOP > /tmp/mariadb.txt
echo | "enter"
y
y
XDRIOXY=
XDRIOXY=
y
y
y
y
STOP
   mysql_secure_installation < /tmp/mariadb.txt
}

# Semaphore configuration.
config() {
    echo -e "\e[32;1;3m[INFO] Configuring Semaphore\e[m"
    cat << STOP > /tmp/semaphore.txt
1
127.0.0.1:3306
root
XDRIOXY=
semaphore
/opt/semaphore
http://192.168.56.74:3000
no
no
no
no
/tmp
sysadmin
sysadmin@mycompany.com
System Administrator
VYLKZVQ=
STOP
    semaphore setup < /tmp/semaphore.txt
}

# Semaphore service.
create() {
    echo -e "\e[32;1;3m[INFO] Creating service\e[m"
    cd /etc/systemd/system/
    tee semaphore.service << STOP > /dev/null
[Unit]
Description=Semaphore Ansible UI
Documentation=https://github.com/ansible-semaphore/semaphore
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/bin/semaphore server --config /etc/semaphore/config.json
SyslogIdentifier=semaphore
Restart=always

[Install]
WantedBy=multi-user.target
STOP
}

# Restarting service.
reload() {
    echo -e "\e[32;1;3m[INFO] Restarting service\e[m"
    systemctl daemon-reload
    semaphore server --config /tmp/config.json &
    mkdir -v /etc/semaphore
    cp -v /tmp/config.json /etc/semaphore/config.json
    systemctl restart semaphore
    systemctl enable --now semaphore
    echo -e "\e[33;1;3;5m[✅] Finished, installation complete\e[m"
}

# Defining function.
main() {
    install
    dbase
    config
    create
    reload
    exit
}

# Calling function.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[35;1;3;5m[OK] Ubuntu detected, proceeding...\e[m"
    main
fi
