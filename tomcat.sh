#!/usr/bin/env bash

# Declaring variables.
DISTRO=$(hostnamectl | awk '/Operating/ { print $3 }')
LINUX=$(hostnamectl | awk '/Operating/ { print $4 }')
TC_VERSION="10.1.33"
TC_TAR="apache-tomcat-${TC_VERSION}.tar.gz"
TC_URL="https://downloads.apache.org/tomcat/tomcat-10/v${TC_VERSION}/bin/${TC_TAR}"
TC_DIR="/opt/tomcat"
TC_USER="tcuser"
TC_GROUP="tcgroup"
JMX_IP="192.168.56.73"
JMX_PORT="12345"

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

# Java installation.
jdk() {
    echo -e "\e[35;1;3m[🟡] Distribution: ${DISTRO} ${LINUX}\e[0m"
    echo
    echo -e "\e[32;1;3m[🟡] Installing Java\e[m"
    dnf install java-11-openjdk-devel wget -y
    echo -e "\e[32;1;3m[🟡] Creating user\e[m"
    groupadd ${TC_GROUP}
    useradd -g ${TC_GROUP} -s /sbin/nologin ${TC_USER}
}

# Tomcat installation.
tcat() {
    echo -e "\e[32;1;3m[🟡] Installing Tomcat\e[m"
    wget -O /tmp/${TC_TAR} ${TC_URL}
    mkdir -p ${TC_DIR}
    tar -xzf /tmp/$TC_TAR -C ${TC_DIR} --strip-components=1
    chown -R ${TC_USER}:${TC_GROUP} ${TC_DIR}
}

# Firewall configuration.
fwall() {
    echo -e "\e[32;1;3m[🟡] Configuring firewall\e[m"
    systemctl start firewalld && systemctl enable firewalld
    firewall-cmd --add-port=8080/tcp --permanent
    firewall-cmd --add-port=12345/tcp --permanent
    firewall-cmd --reload
}

# Enabling service.
reload() {
    echo -e "\e[32;1;3m[🟡] Creating service\e[m"
    cat << STOP > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

User=${TC_USER}
Group=${TC_GROUP}

Environment="JAVA_HOME=/usr/lib/jvm/java-11-openjdk"
Environment="CATALINA_PID=${TC_DIR}/temp/tomcat.pid"
Environment="CATALINA_HOME=${TC_DIR}"
Environment="CATALINA_BASE=${TC_DIR}"
Environment="CATALINA_OPTS=-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=${JMX_PORT} -Dcom.sun.management.jmxremote.rmi.port=${JMX_PORT} -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=${JMX_IP}"

ExecStart=${TC_DIR}/bin/startup.sh
ExecStop=${TC_DIR}/bin/shutdown.sh

Restart=on-failure

[Install]
WantedBy=multi-user.target
STOP
    echo -e "\e[32;1;3m[🟡] Starting service\e[m"
    systemctl daemon-reload
    cat << "STOP"
  _______                        _   
 |__   __|                      | |  
    | | ___  _ __ ___   ___ __ _| |_ 
    | |/ _ \| '_ ` _ \ / __/ _` | __|
    | | (_) | | | | | | (_| (_| | |_ 
    |_|\___/|_| |_| |_|\___\__,_|\__|
                                                    
STOP
   systemctl start tomcat && systemctl enable tomcat
   echo -e "\e[33;1;3;5m[🟢] Finished, installation complete\e[m"
   exit
}

# Defining function.
main() {
    jdk
    tcat
    fwall
    reload
}

if [[ -f /etc/rocky-release ]]; then
    echo -e "\e[38;5;208;1;3;5m[OK] Rocky detected, proceeding...\e[m"
    echo
    main
fi
