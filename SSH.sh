#!/usr/bin/env bash

###############################################################################
# This script will add an SSH user onto the system and configure permissions. #
###############################################################################

# Define variables.
USERNAME="sysadmin"
PASSWORD="$6$aLfDh4JuCYYoaba/$gGSWI6VSsW1JaN2sH4eVwFaNiKpOK03mMI8A6vqfrhkNWVCnRJWfjTW8GscDtIybxSA.JcvC3y0jx3d.GTj.c1"
SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCNf4ea7DoAgZ9Knei9RoLUkEiGTts73tYLR6R87csbngp/cA98T9pzrFfzU3nduFd7DShb6EkALgXubUq5IARTt4IAQWGkNkvLc8mNkYJEz6eT281rHdKLzjcNsbE4SSi+IQTDyIzgnCdEk76ySQ+J5ogzaxu/uBBLul5GHvqdclex2FmpxYUnchH1hOXJisT3GYeDpjGuRuaCyvXH1KCbCUhRjZhgGYfsCu48xahUui8sYzbmwbNhUq+w4zmyoVkolGu2McIOMnxtRbuISpEzkAGQglmfwu6mJegRV3EtRAAOLp3+DjASQGOhB7YX/2DhYFnDvbyyXGZS//5rLpst"

# Sanity checking.
if [[ ${USERID} -ne "0" ]]; then
  echo -e "\e[31;1;3m[✗] You must be root, exiting.\e[m"
  exit 1
fi

# Adding user.
echo -e "\e[32;1;3m[INFO] Creating user\e[m"
yes "y" | adduser ${USERNAME} --force-badname --disabled-password --gecos "System Administrator,Room Number,Work Phone,Home Phone,Other"

# Adding group.
echo -e "\e[32;1;3m[INFO] Configuring sudo\e[m"
usermod -aG sudo ${USERNAME}

# Keys directory.
echo -e "\e[32;1;3m[INFO] Creating file\e[m"
mkdir /home/${USERNAME}/.ssh
touch /home/${USERNAME}/.ssh/authorized_keys

# Set permissions.
echo -e "\e[32;1;3m[INFO] Setting permissions\e[m"
chmod 700 /home/${USERNAME}/.ssh
chmod 600 /home/${USERNAME}/.ssh/authorized_keys

# Adding file.
echo -e "\e[32;1;3m[INFO] Adding key\e[m"
echo "${SSH_KEY}" > /home/${USERNAME}/.ssh/authorized_keys

# Setting ownership.
echo -e "\e[32;1;3m[INFO] Changing ownership\e[m"
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh

# Setting password.
echo -e "\e[32;1;3m[INFO] Hashed password\e[m"
usermod -p "${PASSWORD}" ${USERNAME}

# Restart service.
echo -e "\e[32;1;3m[INFO] Reloading SSH\e[m"
systemctl restart ssh

# End result.
echo -e "\e[33;1;3;5m[✓] User added\e[m"
exit
