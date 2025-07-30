#!/usr/bin/env bash

############################################################################
# A script to apply minor updates to the Zabbix server and proxy packages. #
# It detects which Zabbix package is present and performs a minor update.  #
############################################################################

# Define colour variables.
RED='\033[0;31m'
GREEN='\033[0;32m'
NORMAL='\033[0m'

# Zabbix server function.
update_zabbix_server() {
    echo -e "${GREEN}Updating Zabbix server and frontend...${NORMAL}"
    if sudo dnf --disablerepo=epel update zabbix-server-pgsql zabbix-web -y; then
        sudo systemctl restart zabbix-server
        sudo systemctl restart httpd
        echo -e "${GREEN}Zabbix server and frontend updated and restarted.${NORMAL}"
        echo -e "${GREEN}Zabbix server version:${NORMAL}"
        sudo zabbix_server -V | grep "Zabbix" || echo -e "${RED}Unable to retrieve Zabbix server version.${NORMAL}"
    else
        echo -e "${RED}Error occurred during Zabbix server and web update.${NORMAL}"
    fi
}

# Zabbix proxy function.
update_zabbix_proxy() {
    echo -e "${GREEN}Updating Zabbix proxy...${NORMAL}"
    if sudo dnf --disablerepo=epel update zabbix-proxy-sqlite3 zabbix-sql-scripts zabbix-agent zabbix-selinux-policy -y; then
        sudo systemctl restart zabbix-proxy
        echo -e "${GREEN}Zabbix proxy updated and restarted.${NORMAL}"
        echo -e "${GREEN}Zabbix proxy version:${NORMAL}"
        sudo zabbix_proxy -V | grep "Zabbix" || echo -e "${RED}Unable to retrieve Zabbix proxy version.${NORMAL}"
    else
        echo -e "${RED}Error occurred during Zabbix Proxy update.${NORMAL}"
    fi
}

# Confirm server package.
if dnf list installed zabbix-server-pgsql >/dev/null 2>&1; then
    # If it's a Zabbix server, perform the server update.
    update_zabbix_server
else
    echo -e "${RED}Zabbix Server package not found. Skipping server update.${NORMAL}"
fi

# Confirm proxy package.
if dnf list installed zabbix-proxy-sqlite3 >/dev/null 2>&1; then
    # If it's a Zabbix proxy, perform the proxy update.
    update_zabbix_proxy
else
    echo -e "${RED}Zabbix Proxy package not found. Skipping proxy update.${NORMAL}"
fi

exit
