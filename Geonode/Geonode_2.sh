#!/usr/bin/env bash

#######################################################################
# This script will automate a Geonode installation on Ubuntu 20.04.   #
# Part two will prepare Geonode, the containers, and the environment. #
#######################################################################

# Geonode installation.
geonode() {
    echo -e "\e[32;1;3m[INFO] Downloading Geonode\e[m"
    git clone https://github.com/GeoNode/geonode.git -b 3.2.x /opt/geonode
    cd /opt/geonode
    echo -e "\e[32;1;3m[INFO] Creating containers\e[m"
    docker-compose -f docker-compose.yml pull
    docker-compose -f docker-compose.yml up -d
}

# Configuring environment.
environment() {
    echo -e "\e[32;1;3m[INFO] Updating configuration\e[m"
    sudo sed -i 's|HTTP_HOST=localhost|HTTP_HOST=192.168.56.80|g' .env
    sudo sed -i 's|GEONODE_LB_HOST_IP=localhost|GEONODE_LB_HOST_IP=192.168.56.80|g' .env
    sudo sed -i 's|SITEURL=http://localhost/|SITEURL=http://192.168.56.80/|g' .env
    sudo sed -i 's|GEOSERVER_WEB_UI_LOCATION=http://localhost/geoserver/|GEOSERVER_WEB_UI_LOCATION=http://192.168.56.80/geoserver/|g' .env
    sudo sed -i 's|GEOSERVER_PUBLIC_LOCATION=http://localhost/geoserver/|GEOSERVER_PUBLIC_LOCATION=http://192.168.56.80/geoserver/|g' .env
    sudo sed -i 's|GEOSERVER_PUBLIC_LOCATION=http://localhost/geoserver/|GEOSERVER_PUBLIC_LOCATION=http://192.168.56.80/geoserver/|g' .env
    echo -e "\e[32;1;3m[INFO] Restarting containers\e[m"
    docker-compose up -d
    echo -e "\e[32;1;3m[INFO] Showing containers\e[m"
    docker-compose ps
    echo -e "\e[33;1;3;5m[✓] Finished, configure webUI.\e[m"
    exit
}

# Defining function.
main() {
    geonode
    environment
}

# Calling function.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[35;1;3;5m[OK] Ubuntu detected, proceeding...\e[m"
    main
fi
