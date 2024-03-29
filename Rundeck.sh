#!/usr/bin/env bash

#################################################################
# This script automates a Rundeck installation Ubuntu 20.04.    #
# The script installs Java, MariaDB, Rundeck and configures it. #
#################################################################

# Declaring variables.
DISTRO=$(lsb_release -ds)
USERID=$(id -u)
DEST=/srv/scripts

# Sanity checking.
if [[ ${USERID} -ne "0" ]]; then
    echo -e "\e[32;1;3;5m[❌] You must be root, exiting\e[m"
    exit 1
fi

# Directory creation.
if [[ ! -d "${DEST}" ]]; then
  echo -e "\e[32;1;3m[INFO] Creating directory\e[m"
  mkdir -p "${DEST}"
fi

# System packages.
system() {
    echo -e "\e[96;1;3m[OK] Distribution: ${DISTRO}\e[m"
    echo
    echo -e "\e[32;1;3m[INFO] Updating system\e[m"
    apt update
}

# Java installation.
java() {
    echo -e "\e[32;1;3m[INFO] Installing Java\e[m"
    apt install openjdk-11-jre -qy
}

# MariaDB installation.
maria() {
    echo -e "\e[32;1;3m[INFO] Installing MariaDB\e[m"
    apt install curl software-properties-common -qy
    cd /opt
    curl -LsS -O https://downloads.mariadb.com/MariaDB/mariadb_repo_setup
    bash mariadb_repo_setup --mariadb-server-version=10.6
    apt update
    apt install mariadb-server-10.6 mariadb-client-10.6 mariadb-common pv -qy
    echo -e "\e[32;1;3m[INFO] Starting MariaDB\e[m"
    systemctl start mariadb
    systemctl enable mariadb
    rm -f mariadb_repo_setup
}

# Rundeck database.
data() {
    echo -e "\e[32;1;3m[INFO] Creating database\e[m"
    local dbase=$(cat << STOP
CREATE DATABASE rundeck_db;
CREATE USER 'rundeck_user'@'localhost' IDENTIFIED BY '1q2w3e4r5t';
GRANT ALL PRIVILEGES ON *.* TO 'rundeck_user'@'localhost' WITH GRANT OPTION;
STOP
)
    echo "${dbase}" > /srv/scripts/rundeck_db.sql
    echo -e "\e[32;1;3m[INFO] Configuring MariaDB\e[m"
    cat << STOP > /tmp/answer.txt
echo | "enter"
y
y
4XiZCnOk
4XiZCnOk
y
y
y
y
STOP
   mysql_secure_installation < /tmp/answer.txt
   echo -e "\e[32;1;3m[INFO] Importing database\e[m"
   mysql -u root -p4XiZCnOk < /srv/scripts/rundeck_db.sql | pv
}

# Rundeck installation.
install() {
    echo -e "\e[32;1;3m[INFO] Installing Rundeck\e[m"
    echo "deb https://packages.rundeck.com/pagerduty/rundeck/any/ any main" >> /etc/apt/sources.list.d/rundeck.list
    echo "deb-src https://packages.rundeck.com/pagerduty/rundeck/any/ any main" >> /etc/apt/sources.list.d/rundeck.list
    curl -L https://packages.rundeck.com/pagerduty/rundeck/gpgkey | apt-key add -
    apt update
    apt install rundeck -qy
    
}

# Rundeck configuration.
config() {
    echo -e "\e[32;1;3m[INFO] Configuring Rundeck\e[m"
    sed -ie 's|grails.serverURL=http://localhost:4440|grails.serverURL=http://192.168.56.72:4440|g' /etc/rundeck/rundeck-config.properties
    echo -e "dataSource.driverClassName = org.mariadb.jdbc.Driver" >> /etc/rundeck/rundeck-config.properties
    echo -e "dataSource.url = jdbc:mysql://localhost/rundeck_db?autoReconnect=true&useSSL=false" >> /etc/rundeck/rundeck-config.properties
    echo -e "dataSource.username = rundeck_user" >> /etc/rundeck/rundeck-config.properties
    echo -e "dataSource.password = 1q2w3e4r5t" >> /etc/rundeck/rundeck-config.properties
    echo -e "\e[32;1;3m[INFO] Starting Rundeck\e[m"
    systemctl start rundeckd
    systemctl enable rundeckd
}

# Firewall exception.
fire() {
    echo -e "\e[32;1;3m[INFO] Adjusting firewall\e[m"
    ufw allow 80,443/tcp
    ufw allow 4440/tcp
    echo "y" | ufw enable
    ufw reload
    echo -e "\e[32;1;3m[INFO] Restarting Rundeck\e[m"
    systemctl restart rundeckd
    echo -e "\e[33;1;3;5m[✅] Finished, installation complete\e[m"
}

# Defining function.
main() {
    system
    java
    maria
    data
    install
    config
    fire
}

# Calling function.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[35;1;3;5m[OK] Ubuntu detected, proceeding...\e[m"
    main
    exit
fi
