#!/usr/bin/env bash

###########################################################################
# The purpose of the script is to automate a LAMP installation on Ubuntu. #          
# The script installs LAMP, Mediawiki, creates a database and wiki page.  #
###########################################################################

# Declaring variable.
USERID=$(id -u)

# Sanity checking.
if [[ "${USERID}" -ne "0" ]]; then
    echo -e "\e[1;3mYou must be root, exiting\e[m"
    exit 1
fi

# Apache installation.
apache() {
    echo -e "\e[1;3mInstalling Apache\e[m"
    apt update
    apt install apache2 apache2-{utils,doc} openssl libssl-{dev,doc} -qy
    cd /var/www/html
    echo "<h1>Apache is operational</h1>" > index.html
}

# PHP installation.
php() {
    echo -e "\e[1;3mInstalling PHP\e[m"
    apt install libapache2-mod-php7.4 php7.4 php7.4-{cli,dev,common,gd,mbstring,zip} -qy
    echo "<?php phpinfo(); ?>" > info.php
}

# MySQL installation.
mysql() {
    echo -e "\e[1;3mInstalling MySQL\e[m"
    debconf-set-selections <<< 'mysql-server mysql-server/root_password password ivyLab'
    debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password ivyLab'
    apt install mysql-{common,server} php7.4-mysql -qy
    echo -e "\e[1;3mStarting MySQL\e[m"
    systemctl start mysql
}

# Database creation.
database() {
    echo -e "\e[1;3mCreating database\e[m"
    tee wiki.sql << STOP
CREATE DATABASE mediawiki;
CREATE USER 'osadmin'@'localhost' IDENTIFIED BY 'P@ssword321';
GRANT ALL PRIVILEGES ON mediawiki.* TO 'osadmin'@'localhost';
FLUSH PRIVILEGES;
STOP
}

# Firewall creation.
firewall() {
    echo -e "\e[1;3mAdjusting firewall\e[m"
    ufw allow 80/tcp
    ufw allow 3306/tcp
    echo "y" | ufw enable
    ufw reload
}

# Enabling service.
service() {
    echo -e "\e[1;3mRestarting Apache\e[m"
    systemctl restart apache2
}

# Mediawiki installation.
wiki() {
    echo -e "\e[1;3mInstalling Mediawiki\e[m"
    cd /opt
    wget --progress=bar:force https://releases.wikimedia.org/mediawiki/1.35/mediawiki-1.35.0.tar.gz
    mv -v mediawiki-1.35.0.tar.gz /var/www/html
    cd /var/www/html
    tar -xzf mediawiki-1.35.0.tar.gz
    rm -f mediawiki-1.35.0.tar.gz
    mv -v mediawiki-1.35.0 /var/www/html/mediawiki
    echo -e "\e[1;3mLoading database\e[m"
    mysql --verbose -u root -pivyLab < /var/www/html/wiki.sql
    echo -e "\e[1;3;5mFinished, configure Mediawiki webUI...\e[m"
    exit
}

# Calling functions.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[1;3;5mUbuntu detected, proceeding...\e[m"
    apache
    php
    mysql
    database
    firewall
    service
    wiki
fi
