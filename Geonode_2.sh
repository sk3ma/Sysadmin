#!/usr/bin/env bash

###############################################################
# This script will automate a Geonode installation on Ubuntu. #
# It will install Docker, Geonode, and create the containers. #
###############################################################

# Geonode installation.
geonode() {
    echo -e "\e[32;1;3mDownloading Geonode\e[m"
    git clone https://github.com/GeoNode/geonode.git -b 3.2.x /opt/geonode
    cd /opt/geonode
    echo -e "\e[32;1;3mCreating containers\e[m"
    docker-compose -f docker-compose.yml pull
    docker-compose -f docker-compose.yml up -d
    echo -e "\e[32;1;3mShowing containers\e[m"
    docker-compose ps
    echo -e "\e[33;1;3;5mFinished, configure webUI.\e[m"
    exit
}

# Calling function.
if [[ -f /etc/lsb-release ]]; then
    geonode
fi
