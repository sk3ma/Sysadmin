#!/usr/bin/env python3

import subprocess
import os

# Declaring variables.
DISTRO = subprocess.check_output(['lsb_release', '-ds']).decode().strip()
VERSION = subprocess.check_output(['lsb_release', '-cs']).decode().strip()
USERID = subprocess.check_output(['id', '-u']).decode().strip()

# Sanity checking.
if USERID != "0":
    print("\x1b[32;1;3;5m[❌] You must be root, exiting\x1b[m")
    exit(1)

# Docker installation.
def install():
    print("\x1b[96;1;3m[OK] Distribution: {}\x1b[m".format(DISTRO))
    print("\x1b[32;1;3m[INFO] Updating system\x1b[m")
    subprocess.run(['apt', 'update'])
    print("\x1b[32;1;3m[INFO] Adding repository\x1b[m")
    subprocess.run(['apt', 'install', 'apt-transport-https', 'ca-certificates', 'software-properties-common', 'curl', '-qy'])
    subprocess.run(['curl', '-fsSL', 'https://download.docker.com/linux/ubuntu/gpg', '|', 'apt-key', 'add', '-'])
    subprocess.run(['add-apt-repository', 'deb [arch=amd64] https://download.docker.com/linux/ubuntu {} stable'.format(VERSION), '-y'])
    print("\x1b[32;1;3m[INFO] Installing Docker\x1b[m")
    subprocess.run(['apt', 'install', 'docker-ce', 'docker-ce-cli', 'docker-compose', 'containerd.io', '-qy'])
    subprocess.run(['usermod', '-aG', 'docker', 'USER'])
    subprocess.run(['chmod', 'a=rw', '/var/run/docker.sock'])
    print("\x1b[32;1;3m[INFO] Creating volume\x1b[m")
    os.makedirs('/container', exist_ok=True)
    subprocess.run(['docker', 'volume', 'create', 'bindmount'])

# Enabling service.
def service():
    print("\x1b[32;1;3m[INFO] Starting service\x1b[m")
    subprocess.run(['systemctl', 'start', 'docker'])
    subprocess.run(['systemctl', 'enable', 'docker'])

# Creating container.
def container():
    print("\x1b[32;1;3m[INFO] Creating container\x1b[m")
    subprocess.run(['docker', 'run', '-d', '--privileged', '--restart=unless-stopped', '-p', '80:80', '-p', '443:443', '-v', '/container', '--name', 'master-node', 'rancher/rancher:latest'])
    subprocess.run(['docker', 'logs', 'master-node', '2>&1', '|', 'grep', '"Bootstrap Password:"'])
    print("\x1b[33;1;3;5m[✅] Finished, Docker installed.\x1b[m")

# Defining function.
def main():
    install()
    service()
    container()

# Calling function.
if os.path.isfile('/etc/lsb-release'):
    print("\x1b[35;1;3;5m[OK] Ubuntu detected, proceeding...\x1b[m")
    main()
