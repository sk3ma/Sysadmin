# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Configuring hardware resources.
  config.vm.provider "virtualbox" do |v|
    v.customize ["modifyvm", :id, "--cableconnected1", "on"]
    v.memory = 6144
    v.cpus = 2
    v.gui = false
  end
  # Customizing Ubuntu server.
  config.vm.box = "bento/ubuntu-18.04"
  config.vm.box_check_update = false
  config.ssh.forward_agent = true
  config.vm.define "jenkins" do |j|
    j.vm.hostname = "jenkins"
    # Defining the network.
    j.vm.network "private_network", ip: "192.168.33.100"
    j.vm.network "forwarded_port", guest: 80, host: 8090
    j.vm.network "forwarded_port", guest: 80, host: 9090
    # Preparing Jenkins installation.
    j.vm.provision "shell", inline: <<-SHELL
      tee /etc/hosts << STOP
127.0.0.1    	localhost
127.0.1.1    	jenkins
STOP
    SHELL
    # Using script to bootstrap.
    j.vm.provision "shell", path: "Docker.sh", privileged: true
  end
end
