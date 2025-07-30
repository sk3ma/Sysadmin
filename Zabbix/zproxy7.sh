#!/usr/bin/env bash

# Defining variables.
DATE=$(date +%F)
DISTRO=$(hostnamectl | awk '/Operating/ { print $3 }')
LINUX=$(hostnamectl | awk '/Operating/ { print $4 }')
MODE="0"
HNAME="Zabbix proxy"
PXYPORT="10051"
AGEPORT="10050"
GTYPORT="10052"
DHOST="localhost"
TIMEOUT="30"

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
    read -p "Enter the Zabbix server IP address: " ZBXSRV
    echo -e "\e[32;1;3m[🟡] Installing EPEL\e[m"
    dnf install epel-release python3-pip ca-certificates -y
    echo -e "\e[32;1;3m[🟡] Exclude Zabbix\e[m"
    sed -i '/\[epel\]/a excludepkgs=zabbix-*' /etc/yum.repos.d/epel.repo
}

# Zabbix repository.
repo() {
    echo -e "\e[32;1;3m[🟡] Adding repository\e[m"
    rpm --import https://repo.zabbix.com/zabbix-official-repo.key
    tee /etc/yum.repos.d/zabbix.repo << STOP > /dev/null
[zabbix]
name=Zabbix Official Repository
baseurl=http://repo.zabbix.com/zabbix/7.0/rocky/9/x86_64/
gpgcheck=1
gpgkey=https://repo.zabbix.com/zabbix-official-repo.key
enabled=1
STOP
}

# Zabbix proxy.
zbxpxy() {
    echo -e "\e[32;1;3m[🟡] Adding repository\e[m"
    dnf clean all
    dnf install https://repo.zabbix.com/zabbix/7.0/rocky/9/x86_64/zabbix-release-7.0-5.el9.noarch.rpm -y
    echo -e "\e[32;1;3m[🟡] Installing SQLite\e[m"
    dnf install sqlite -y
    echo -e "\e[32;1;3m[🟡] Installing Zabbix\e[m"
    dnf --disablerepo=epel install zabbix-proxy-sqlite3 zabbix-sql-scripts zabbix-agent zabbix-selinux-policy zabbix-java-gateway -y
    echo -e "\e[32;1;3m[🟡] Installing API\e[m"
    pip3 install py-zabbix zabbix_api
    echo -e "\e[32;1;3m[🟡] Creating directory\e[m"
    mkdir -p /var/lib/zabbix
    chown zabbix:zabbix /var/lib/zabbix
    chmod 770 /var/lib/zabbix
    echo -e "\e[32;1;3m[🟡] Importing schema\e[m"
    cat /usr/share/zabbix-sql-scripts/sqlite3/proxy.sql | sqlite3 /var/lib/zabbix/zabbix_pxy.sqlite3
    chown zabbix:zabbix /var/lib/zabbix/zabbix_pxy.sqlite3
    echo -e "\e[32;1;3m[🟡] Configuring Zabbix\e[m"
    cd /etc/zabbix || exit
    cp -v zabbix_proxy.conf zabbix_proxy.orig-${DATE}
    rm -f zabbix_proxy.conf
    tee zabbix_proxy.conf << STOP > /dev/null
# Custom proxy configuration.
ProxyMode=${MODE}
Server=${ZBXSRV}
Hostname=${HNAME}
ListenPort=${PXYPORT}
LogFileSize=0
LogFile=/var/log/zabbix/zabbix_proxy.log
PidFile=/run/zabbix/zabbix_proxy.pid
SocketDir=/run/zabbix
DebugLevel=3
DBHost=${DHOST}
DBName=/var/lib/zabbix/zabbix_pxy.sqlite3
SNMPTrapperFile=/var/log/snmptrap/snmptrap.log
CacheSize=64M
ProxyOfflineBuffer=24
ProxyConfigFrequency=120
Timeout=${TIMEOUT}
FpingLocation=/usr/bin/fping
Fping6Location=/usr/bin/fping6
LogSlowQueries=3000
JavaGateway=127.0.0.1
JavaGatewayPort=${GTYPORT}
StartJavaPollers=5
StatsAllowedIP=127.0.0.1,${ZBXSRV}
STOP
}

# Java Gateway.
javgty() {
    echo -e "\e[32;1;3m[🟡] Configuring java-gateway\e[m"
    tee zabbix_java_gateway.conf << STOP > /dev/null
# Custom java-gateway configuration.
LISTEN_PORT=${GTYPORT}
TIMEOUT=${TIMEOUT}
PID_FILE=/var/run/zabbix/zabbix_java_gateway.pid
STOP
}

# Zabbix agent.
zbxage() {
    echo -e "\e[32;1;3m[🟡] Installing agent\e[m"
    dnf --disablerepo=epel install zabbix-agent -y
    echo -e "\e[32;1;3m[🟡] Configuring agent\e[m"
    cp -v zabbix_agentd.{conf,orig-${DATE}}
    tee zabbix_agentd.conf << STOP > /dev/null
# Custom agent configuration.
DebugLevel=3
ListenPort=${AGEPORT}
Server=${ZBXSRV}
ServerActive=${ZBXSRV}
Hostname=${HNAME}
HostMetadata=Linux
PidFile=/var/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=0
AllowKey=system.run[*]
RefreshActiveChecks=120
Timeout=${TIMEOUT}
DebugLevel=3
Include=/etc/zabbix/zabbix_agentd.d/*.conf
STOP
}

# Firewall configuration.
fwall() {
    echo -e "\e[32;1;3m[🟡] Configuring firewall\e[m"
    systemctl start firewalld && systemctl enable firewalld
    firewall-cmd --add-port={10050/tcp,10051/tcp,10052/tcp} --permanent
    firewall-cmd --reload
}

# Restart services.
reload() {
    echo -e "\e[32;1;3m[🟡] Disabling SELinux\e[m"
    setenforce 0
    sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
    echo -e "\e[32;1;3m[🟡] Restarting services\e[m"
    cat << "STOP"
 ______      _     _     _       ______                    
|___  /     | |   | |   (_)      | ___ \                   
   / /  __ _| |__ | |__  ___  __ | |_/ / __ _____  ___   _ 
  / /  / _` | '_ \| '_ \| \ \/ / |  __/ '__/ _ \ \/ / | | |
./ /__| (_| | |_) | |_) | |>  <  | |  | | | (_) >  <| |_| |
\_____/\__,_|_.__/|_.__/|_/_/\_\ \_|  |_|  \___/_/\_\\__, |
                                                      __/ |
                                                     |___/ 

STOP
    systemctl restart zabbix-proxy zabbix-agent zabbix-java-gateway
    echo -e "\e[33;1;3m[🟢] Finished, register proxy\e[m"
    exit
}

# Defining function.
main() {
    epel
    repo
    zbxpxy
    javgty
    zbxage
    fwall
    reload
}

# Start installation.
if [[ -f /etc/rocky-release ]]; then
    echo -e "\e[38;5;208;1;3;5m[OK] Rocky detected, proceeding...\e[m"
    echo
    main
fi
