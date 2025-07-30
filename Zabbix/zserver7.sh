#!/usr/bin/env bash

# Defining variables.
DATE=$(date +%F)
DISTRO=$(hostnamectl | awk '/Operating/ { print $3 }')
LINUX=$(hostnamectl | awk '/Operating/ { print $4 }')
ZLOG="/var/log/zabbix/zabbix_server.log"
ZPID="/run/zabbix/zabbix_server.pid"
SOCK="/run/zabbix"
PATH1="/usr/lib/zabbix/alertscripts"
PATH2="/usr/lib/zabbix/externalscripts"
PORT="10051"
DHOST="localhost"
DNAME="zabbix_db"
DUSER="zabbix_user"
DPASS="y5VqW1K="

# Sanity checking.
if [[ "${EUID}" -ne "0" ]]; then
    echo
    echo "███████╗██████╗ ██████╗  ██████╗ ██████╗ "
    echo "██╔════╝██╔══██╗██╔══██╗██╔═══██╗██╔══██╗"
    echo "█████╗  ██████╔╝██████╔╝██║   ██║██████╔╝"
    echo "██╔══╝  ██╔══██╗██╔══██╗██║   ██║██╔══██╗"
    echo "███████╗██║  ██║██║  ██║╚██████╔╝██║  ██║"
    echo "╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝"
    echo
    echo -e "\e[31;1;3;5m[🔴] You must be root, exiting.\e[m"
    exit 1
fi

# EPEL repository.
epel() {
    echo -e "\e[35;1;3m[🟡] Distribution: ${DISTRO} ${LINUX}\e[0m"
    echo
    echo -e "\e[32;1;3m[🟡] Installing EPEL\e[m"
    dnf install epel-release -y
    echo -e "\e[32;1;3m[🟡] Exclude Zabbix\e[m"
    sed -i '/\[epel\]/a excludepkgs=zabbix*' /etc/yum.repos.d/epel.repo
}

# Apache installation.
web() {
    echo -e "\e[32;1;3m[🟡] Installing Apache\e[m"
    dnf install httpd -y
    echo -e "\e[32;1;3m[🟡] Creating index.html\e[m"
    tee /var/www/html/index.html << STOP > /dev/null
          <html>
          <head>
            <style>
              body {
                background-color: black;
                color: white;
                font-family: Arial, sans-serif;
              }
            </style>
          </head>
          <body>
            <h1>Apache is operational</h1>
          </body>   
          </html>
STOP
    systemctl start httpd && systemctl enable httpd
    echo -e "\e[32;1;3m[🟡] Installing PHP\e[m"
    dnf install php php-cli php-common php-fpm php-gd php-mbstring php-pdo php-xml -y
    echo -e '<?php php🟡(); ?>' >> /var/www/html/🟡.php
    sed -i "s|;date.timezone =|date.timezone = Africa/Johannesburg|" /etc/php.ini
    systemctl start php-fpm && systemctl enable php-fpm
    echo -e "\e[32;1;3m[🟡] Restarting Apache\e[m"
    systemctl restart httpd
}

# PostgreSQL installation.
postgres() {
    echo -e "\e[32;1;3m[🟡] Installing PostgreSQL\e[m"
    dnf install postgresql-server postgresql-contrib php-pgsql -y
    postgresql-setup --initdb --unit postgresql
    systemctl start postgresql && systemctl enable postgresql
    echo -e "\e[32;1;3m[🟡] Updating configuration\e[m"
    cd /var/lib/pgsql/data || exit
    grep -q "^listen_addresses" postgresql.conf || echo "listen_addresses = '*'" >> postgresql.conf
    cp -v pg_hba.conf pg_hba.orig-${DATE}
    rm -f pg_hba.conf
    cat << STOP > pg_hba.conf
local all all trust
host all all 127.0.0.1/32 trust
host all all ::1/128 md5
local replication all peer
host replication all 127.0.0.1/32 ident
host replication all ::1/128 ident
STOP
    echo -e "\e[32;1;3m[🟡] Restarting PostgreSQL\e[m"
    systemctl restart postgresql
}

# Zabbix database.
dbase() {
    echo -e "\e[32;1;3m[🟡] Creating database\e[m"
    sudo -u postgres psql -c "CREATE USER zabbix_user WITH PASSWORD 'y5VqW1K=';"
    sudo -u postgres psql -c "CREATE DATABASE zabbix_db WITH OWNER zabbix_user;"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE zabbix_db TO zabbix_user;"
    sudo -u postgres psql -d zabbix_db -c "ALTER SCHEMA public OWNER TO zabbix_user;"
    sudo -u postgres psql -d zabbix_db -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO zabbix_user;"
    sudo -u postgres psql -d zabbix_db -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO zabbix_user;"
    sudo -u postgres psql -d zabbix_db -c "GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO zabbix_user;"
    sudo -u postgres psql -c "ALTER USER zabbix_user WITH SUPERUSER;"
    sudo -u postgres psql -U postgres -c "ALTER USER postgres PASSWORD '1q2w3e4r5t';"
}

# Zabbix server.
zbxsrv() {
    echo -e "\e[32;1;3m[🟡] Installing Zabbix\e[m"
    dnf clean all
    dnf install https://repo.zabbix.com/zabbix/7.0/rocky/9/x86_64/zabbix-release-7.0-5.el9.noarch.rpm -y
    dnf --disablerepo=epel install zabbix-server-pgsql zabbix-apache-conf zabbix-sql-scripts zabbix-web-pgsql zabbix-agent zabbix-get zabbix-selinux-policy -y
    systemctl start zabbix-server && systemctl enable zabbix-server
    systemctl start zabbix-agent && systemctl enable zabbix-agent
    echo -e "\e[32;1;3m[🟡] Importing schema\e[m"
    su - postgres -c "zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | psql -d zabbix_db"
    echo -e "\e[32;1;3m[🟡] Configuring Zabbix\e[m"
    cd /etc/zabbix || exit
    cp -v zabbix_server.conf zabbix_server.orig-${DATE}
    rm -f zabbix_server.conf
    tee zabbix_server.conf << STOP > /dev/null
# Custom server configuration.
ListenPort=${PORT}
LogFile=${ZLOG}
PidFile=${ZPID}
SocketDir=${SOCK}
DBHost=${DHOST}
DBName=${DNAME}
DBUser=${DUSER}
DBPassword=${DPASS}
AlertScriptsPath=${PATH1}
ExternalScripts=${PATH2}
LogFileSize=0
DebugLevel=3
StartPollers=10
StartHTTPPollers=10
StartTrappers=10
StartDiscoverers=10
HousekeepingFrequency=1
HistoryCacheSize=256M
TrendCacheSize=512M
CacheSize=1G
ValueCacheSize=1G
Timeout=30
FpingLocation=/usr/bin/fping
Fping6Location=/usr/bin/fping6
LogSlowQueries=3000
StatsAllowedIP=127.0.0.1
EnableGlobalScripts=0
SNMPTrapperFile=/var/log/snmptrap/snmptrap.log
STOP
}

fwall() {
    echo -e "\e[32;1;3m[🟡] Configuring firewall\e[m"
    systemctl start firewalld && systemctl enable firewalld
    firewall-cmd --add-service={http,https} --permanent
    firewall-cmd --add-port={10051/tcp,10050/tcp} --permanent
    firewall-cmd --reload
}

reload() {
    echo -e "\e[32;1;3m[🟡] Disabling SELinux\e[m"
    setenforce 0
    sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
    echo -e "\e[32;1;3m[🟡] Restarting services\e[m"
    cat << "STOP"
 ______      _     _     _        _____                          
|___  /     | |   | |   (_)      /  ___|                         
   / /  __ _| |__ | |__  ___  __ \ `--.  ___ _ ____   _____ _ __ 
  / /  / _` | '_ \| '_ \| \ \/ /  `--. \/ _ \ '__\ \ / / _ \ '__|
./ /__| (_| | |_) | |_) | |>  <  /\__/ /  __/ |   \ V /  __/ |   
\_____/\__,_|_.__/|_.__/|_/_/\_\ \____/ \___|_|    \_/ \___|_|   

STOP
    systemctl restart httpd php-fpm postgresql zabbix-agent zabbix-server
    echo -e "\e[33;1;3m[🟢] Access frontend at: http://$(hostname -I | awk '{print $1}')/zabbix\e[m"
    exit
}

# Defining function.
main() {
    epel
    web
    postgres
    dbase
    zbxsrv
    fwall
    reload
}

# Start installation.
if [[ -f /etc/rocky-release ]]; then
    echo -e "\e[38;5;208;1;3;5m[OK] Rocky detected, proceeding...\e[m"
    echo
    main
fi
