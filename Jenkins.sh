#!/usr/bin/env bash

##################################################################
# This script automates a Jenkins build server for Ubuntu 20.04. #
# The script installs Java, Jenkins, Maven and Keycloak server.  #
##################################################################

# Declaring variables.
DISTRO=$(lsb_release -ds)
USERID=$(id -u)

# Sanity checking.
if [[ ${USERID} -ne "0" ]]; then
    echo -e "\e[32;1;3;5mYou must be root, exiting.\e[m"
    exit 1
fi

# System packages.
system() {
    echo -e "\e[96;1;3mDistribution: ${DISTRO}\e[m"
    echo -e "\e[32;1;3mInstalling packages\e[m"
    apt update
    apt install ca-certificates haproxy certbot git vim -qy
}

# Java installation.
java() {
    echo -e "\e[32;1;3mInstalling Java\e[m"
    apt install default-jdk -qy
}

# Jenkins installation.
jenkins() {
    echo -e "\e[32;1;3mAdding repository\e[m"
    cd /opt
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    bash -c 'echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" >> /etc/apt/sources.list'
    echo -e "\e[32;1;3mInstalling Jenkins\e[m"
    apt update
    apt install jenkins -qy
    sed -ie 's|HTTP_PORT=8080|HTTP_PORT=8090|g' /etc/default/jenkins
    sed -ie 's|JENKINS_ARGS="--webroot=/var/cache/$NAME/war --httpPort=$HTTP_PORT"|JENKINS_ARGS="--webroot=/var/cache/$NAME/war --httpPort=$HTTP_PORT --httpListenAddress=192.168.56.72"|g' /etc/default/jenkins
}

# Maven installation.
install() {
    echo -e "\e[32;1;3mInstalling Maven\e[m"
    wget --progress=bar:force https://dlcdn.apache.org/maven/maven-3/3.8.6/binaries/apache-maven-3.8.6-bin.tar.gz
    echo -e "\e[32;1;3mUnpacking files\e[m"
    tar -xvzf apache-maven-3.8.6-bin.tar.gz
    mv -v apache-maven-3.8.6 maven
    rm -f apache-maven-3.8.6-bin.tar.gz
}

# Maven configuration.
config() {
    echo -e "\e[32;1;3mPreparing environment\e[m"
    cp -v ~/.profile{,.orig}
    local maven=$(cat << STOP
export JAVA_HOME=/usr/lib/jvm/java-1.11.0-openjdk-amd64
export M2_HOME=/opt/maven
export M2=/opt/maven/bin
export PATH=${M2_HOME}/bin:${PATH}
export PATH=${PATH}:${HOME}/bin:${JAVA_HOME}
STOP
)
    echo "${maven}" >> ~/.profile
}

# Keycloak installation.
key() {
    echo -e "\e[32;1;3mInstalling Keycloak\e[m"
    mkdir -vp /etc/keycloak
    wget --progress=bar:force https://github.com/keycloak/keycloak/releases/download/15.0.2/keycloak-15.0.2.tar.gz
    echo -e "\e[32;1;3mUnpacking files\e[m"
    tar -xvzf keycloak-15.0.2.tar.gz
    mv -v keycloak-15.0.2 keycloak
    echo -e "\e[32;1;3mCreating user\e[m"
    groupadd keycloak
    useradd -rg keycloak -d /opt/keycloak -s /sbin/nologin keycloak
    chown -R keycloak: keycloak
    chmod o+x /opt/keycloak/bin
    echo -e "\e[32;1;3mCopying files\e[m"
    cp -v /opt/keycloak/docs/contrib/scripts/systemd/wildfly.conf /etc/keycloak/keycloak.conf
    cp -v /opt/keycloak/docs/contrib/scripts/systemd/launch.sh /opt/keycloak/bin
    chown keycloak: /opt/keycloak/bin/launch.sh
    sed -ie 's|WILDFLY_HOME="/opt/wildfly"|WILDFLY_HOME="/opt/keycloak"|g' /opt/keycloak/bin/launch.sh
    rm -f keycloak-15.0.2.tar.gz
}

# Keycloak configuration.
cloak() {
    echo -e "\e[32;1;3mCreating service\e[m"
    cp -v /opt/keycloak/docs/contrib/scripts/systemd/wildfly.service /etc/systemd/system/keycloak.service
    tee /etc/systemd/system/keycloak.service << STOP > /dev/null
[Unit]
Description=The Keycloak Server
After=syslog.target network.target
Before=httpd.service

[Service]
Environment=LAUNCH_JBOSS_IN_BACKGROUND=1
EnvironmentFile=/etc/keycloak/keycloak.conf
User=keycloak
Group=keycloak
LimitNOFILE=102642
PIDFile=/var/run/keycloak/keycloak.pid
ExecStart=/opt/keycloak/bin/launch.sh ${WILDFLY_MODE} ${WILDFLY_CONFIG} ${WILDFLY_BIND}
StandardOutput=null

[Install]
WantedBy=multi-user.target
STOP
    echo -e "\e[32;1;3mStarting Keycloak\e[m"
    systemctl daemon-reload
    systemctl start keycloak
    systemctl enable keycloak
}

# Creating exception.
firewall() {
    echo -e "\e[32;1;3mAdjusting firewall\e[m"
    ufw allow 80,443/tcp
    ufw allow 8080,8090/tcp
    ufw allow 5044,10050/tcp
    echo "y" | ufw enable
    ufw reload
}

# Enabling service.
service() {
    echo -e "\e[32;1;3mStarting Jenkins\e[m"
    systemctl restart jenkins
    systemctl enable jenkins
    echo -e "\e[32;1;3mRevealing password\e[m"
    cat /var/lib/jenkins/secrets/initialAdminPassword
    echo -e "\e[33;32;1;3;5mFinished, configure webUI.\e[m"
    exit
}

# Calling functions.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[35;1;3;5mUbuntu detected, proceeding...\e[m"
    system
    java
    jenkins
    install
    config
    key
    cloak
    firewall
    service
fi
