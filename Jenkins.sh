#!/usr/bin/env bash

##############################################################################
# The purpose of the script is to automate a Jenkins installation on Ubuntu. #          
# The script installs Jenkins, Maven and creates a firewall exception.       # 
##############################################################################

# Declaring variable.
USERID=$(id -u)

# Sanity checking.
if [[ ${USERID} -ne "0" ]]; then
    echo -e "\e[1;3mYou must be root, exiting.\e[m"
    exit 1
fi

# Java installation.
java() {
    echo -e "\e[1;3mInstalling Java\e[m"
    apt update
    apt install openjdk-11-jdk -qy
}

# Jenkins installation.
jenkins() {
    echo -e "\e[1;3mAdding repository\e[m"
    cd /opt
    wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
    bash -c 'echo "deb https://pkg.jenkins.io/debian-stable binary/" >> /etc/apt/sources.list'
    echo -e "\e[1;3mInstalling Jenkins\e[m"
    apt update
    apt install jenkins -qy
}

# Maven installation.
maven() {
    echo -e "\e[1;3mInstalling Maven\e[m"
    mkdir -v maven
    cd maven
    wget --progress=bar:force https://dlcdn.apache.org/maven/maven-3/3.8.4/binaries/apache-maven-3.8.4-bin.tar.gz
    tar -xvzf apache-maven-3.8.4-bin.tar.gz
    mv -v apache-maven-3.8.4 maven
    rm -rf apache-maven-3.8.4-bin.tar.gz
}

# Maven configuration.
environment() {
    echo -e "\e[1;3mPreparing environment\e[m"
    cp -v ~/.profile ~/.profile.orig
    echo 'export JAVA_HOME=/usr/lib/jvm/java-1.11.0-openjdk-amd64' >> ~/.profile
    echo 'export M2_HOME=/opt/maven' >> ~/.profile
    echo 'export M2=/opt/maven/bin' >> ~/.profile
    echo 'export PATH=${M2_HOME}/bin:${PATH}' >> ~/.profile
    echo 'export PATH=${PATH}:${HOME}/bin:${JAVA_HOME}' >> ~/.profile
}

# Creating exception.
firewall() {
    echo -e "\e[1;3mAdjusting firewall\e[m"
    sed -ie 's/HTTP_PORT=8080/HTTP_PORT=8090/g' /etc/default/jenkins
    ufw allow 8090/tcp
    echo "y" | ufw enable
    ufw reload
}

# Enabling service.
service() {
    echo -e "\e[1;3mStarting Jenkins\e[m"
    systemctl restart jenkins
    systemctl enable jenkins
    cat /var/lib/jenkins/secrets/initialAdminPassword
#    echo -e "\e[1;3;5mExecuting Ansible script...\e[m"
#    source /vagrant/Ansible.sh
    exit
}

# Calling functions.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[1;3mUbuntu detected...\e[m"
    java
    jenkins
    maven
    environment
    firewall
    service
fi
