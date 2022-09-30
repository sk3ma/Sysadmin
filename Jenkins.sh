#!/usr/bin/env bash

#####################################################################
# This script automates a Jenkins build server for Ubuntu 20.04.    #
# The script installs Java 11, Jenkins and configures the firewall. #
#####################################################################

# Declaring variables.
DISTRO=$(lsb_release -ds)
USERID=$(id -u)

# Sanity checking.
if [[ ${USERID} -ne "0" ]]; then
    echo -e "\e[1;3;5mYou must be root, exiting.\e[m"
    exit 1
fi

# Java installation.
java() {
    echo -e "\e[96;1;3mDistribution: ${DISTRO}\e[m"
    echo -e "\e[1;3mInstalling Java\e[m"
    apt update
    apt install openjdk-11-jdk -qy
}

# Jenkins installation.
jenkins() {
    echo -e "\e[1;3mAdding repository\e[m"
    cd /opt
    wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | apt-key add -
    bash -c 'echo "deb https://pkg.jenkins.io/debian-stable binary/" >> /etc/apt/sources.list'
    echo -e "\e[1;3mInstalling Jenkins\e[m"
    apt update
    apt install jenkins git -qy
}

# Maven installation.
install() {
    echo -e "\e[1;3mInstalling Maven\e[m"
    wget --progress=bar:force https://dlcdn.apache.org/maven/maven-3/3.8.4/binaries/apache-maven-3.8.4-bin.tar.gz
    echo -e "\e[1;3mUnpacking files\e[m"
    tar -xvzf apache-maven-3.8.4-bin.tar.gz
    mv -v apache-maven-3.8.4 maven
    rm -rf apache-maven-3.8.4-bin.tar.gz
}

# Maven configuration.
config() {
    echo -e "\e[1;3mPreparing environment\e[m"
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

# Creating exception.
firewall() {
    echo -e "\e[1;3mAdjusting firewall\e[m"
    sed -ie 's|HTTP_PORT=8080|HTTP_PORT=8090|g' /etc/default/jenkins
    ufw allow 8090/tcp
    echo "y" | ufw enable
    ufw reload
}

# Enabling service.
service() {
    echo -e "\e[1;3mStarting service\e[m"
    systemctl restart jenkins
    systemctl enable jenkins
    echo -e "\e[1;3mRevealing password\e[m"
    cat /var/lib/jenkins/secrets/initialAdminPassword
    echo -e "\e[33;1;3;5mFinished, configure webUI.\e[m"
    exit
}

# Calling functions.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[1;3;5mUbuntu detected, proceeding...\e[m"
    java
    jenkins
    install
    config
    firewall
    service
fi
