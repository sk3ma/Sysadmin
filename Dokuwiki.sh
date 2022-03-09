#!/usr/bin/env bash

###################################################################
# This script will automate a Dokuwiki installation on Ubuntu.    #
# It will install Apache, PHP, Dokuwiki and create a virtualhost. #
###################################################################

# Declaring variables.
USERID=$(id -u)
DISTRO=$(lsb_release -ds)
IPADDR=192.168.33.60

# Sanity checking.
if [[ ${USERID} -ne "0" ]]; then
    echo -e "\e[1;3;5mYou must be root, exiting.\e[m"
    exit 1
fi

# Apache installation.
apache() {
    echo -e "\e[1;3;5mDistribution: ${DISTRO}\e[m"
    echo -e "\e[1;3mInstalling Apache\e[m"
    sudo apt update
    sudo apt install apache2 apache2-{doc,utils} software-properties-common vim -qy
    sudo systemctl start apache2
    sudo systemctl enable --now apache2
}

# PHP installation.
php() {
    echo -e "\e[1mInstalling PHP\e[m"
    sudo apt install libapache2-mod-php7.4 php7.4 php7.4-{cli,dev,common,gd,mbstring,zip} -qy
    echo "<?php phpinfo(); ?>" > /var/www/html/info.php
}

# Creating exception.
firewall() {
    echo -e "\e[1;3mAdjusting firewall\e[m"
    ufw allow 80/tcp
    echo "y" | ufw enable
    ufw reload
}

# Downloading Dokuwiki.
wiki() {
    echo -e "\e[1;3mDownloading Dokuwiki\e[m"
    mkdir -p /var/www/html/dokuwiki
    wget --progress=bar:force https://download.dokuwiki.org/src/dokuwiki/dokuwiki-stable.tgz
    tar xzf dokuwiki-stable.tgz -C /var/www/html/dokuwiki/ --strip-components=1
    cp /var/www/html/dokuwiki/.htaccess{.dist,}
    chown -R www-data:www-data /var/www/html/dokuwiki
    rm -f dokuwiki-stable.tgz
}

# Dokuwiki configuration.
website() {
    echo -e "\e[1;3mCreating virtualhost\e[m"
    tee /etc/apache2/sites-available/dokuwiki.conf << STOP
<VirtualHost *:80>
        ServerName wiki.locstat.co.za
        DocumentRoot /var/www/html/dokuwiki

        <Directory ~ "/var/www/html/dokuwiki/(bin/|conf/|data/|inc/)">
            <IfModule mod_authz_core.c>
                AllowOverride All
                Require all denied
            </IfModule>
            <IfModule !mod_authz_core.c>
                Order allow,deny
                Deny from all
            </IfModule>
        </Directory>

        ErrorLog /var/log/apache2/dokuwiki_error.log
        CustomLog /var/log/apache2/dokuwiki_access.log combined
</VirtualHost>
STOP
    a2dissite 000-default.conf
    a2ensite dokuwiki.conf
}

# Certbot installation.
cert() {
    echo -e "\e[1;3mInstalling Certbot\e[m"
    systemctl reload apache2
    apt install certbot python3-certbot-apache -qy
    echo -e "\e[1;3;5mFinished, configure webUI.\e[m"
    exit
}

# Docker installation.
# docker() {
#    echo -e "\e[1;3mInstalling Docker\e[m"
#    apt install apt-transport-https ca-certificates software-properties-common curl -qy
#    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
#    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable" -y
#    apt install docker-ce docker-ce-cli containerd.io -qy
#    usermod -aG docker ${USER}
#    systemctl start docker
#    systemctl enable docker
#}

# Portainer agent.
# agent() {
#    echo -e "\e[1;3mDownloading agent\e[m"
#    docker pull portainer/portainer/agent:latest
#    docker run -d  \
#    -p ${IPADDR}:9001:9001 \
#    --name portainer_agent \
#    --restart=always \
#    -v /var/run/docker.sock:/var/run/docker.sock \
#    -v /var/lib/docker/volumes:/var/lib/docker/volumes portainer/agent:latest
#}

# Calling functions.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[1;3;5mUbuntu detected, proceeding...\e[m"
    apache
    php
    firewall
    wiki
    website
    cert
#    docker
#    agent
fi
