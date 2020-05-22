
# -*- mode: ruby -*-
# vi: set ft=ruby ts=2 sw=2 et:
Vagrant.require_version ">= 2.1.0"
require 'fileutils'
require 'yaml'

### PRE PROVISONING ###

## Constants
vagrant_dir = File.expand_path(File.dirname(__FILE__))

## Load Configuration (antidote-custom.yml)
antidote_config_file = File.join(vagrant_dir, 'antidote-config.yml')
antidote_config = YAML.load_file(antidote_config_file)

## Configure VM Defaults
defaults = Hash.new
defaults['memory'] = 2048
defaults['cores'] = 1
# This should rarely be overridden, so it's not included in the default antidote-config.yml file by default.
defaults['private_network_ip'] = '192.168.34.100'
antidote_config['vm_config'] = defaults.merge(antidote_config['vm_config'])

if defined? antidote_config['vm_config']['provider'] then
  # Override or set the vagrant provider.
  ENV['VAGRANT_DEFAULT_PROVIDER'] = antidote_config['vm_config']['provider']
end

## Configure VAGRANT Variables
trimmed_version = antidote_config['version'].to_s.tr('.','')
antidote_config['hostname'] = "antidote-#{trimmed_version}"

### VAGRANT CONFIGURATION ###
Vagrant.configure("2") do |config|
  # Store the current version of Vagrant for use in conditionals when dealing
  # with possible backward compatible issues.
  vagrant_version = Vagrant::VERSION.sub(/^v/, '')

  # Configurations from 1.0.x can be placed in Vagrant 1.1.x specs like the following.
  config.vm.provider :virtualbox do |v|
    v.customize ["modifyvm", :id, "--memory", antidote_config['vm_config']['memory']]
    v.customize ["modifyvm", :id, "--cpus", antidote_config['vm_config']['cores']]
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    v.customize ["modifyvm", :id, "--nictype1", "virtio"]
    v.customize ["modifyvm", :id, "--rtcuseutc", "on"]
    v.customize ["modifyvm", :id, "--audio", "none"]
    v.customize ["modifyvm", :id, "--paravirtprovider", "kvm"]
  end

  # Configuration options for Hyper-V.
  config.vm.provider :hyperv do |v, override|
    v.memory = antidote_config['vm_config']['memory']
    v.cpus = antidote_config['vm_config']['cores']
  end


  # Configuration options for Parallels.
  config.vm.provider :parallels do |v|
    v.update_guest_tools = true
    v.customize ["set", :id, "--longer-battery-life", "off"]
    v.memory = antidote_config['vm_config']['memory']
    v.cpus = antidote_config['vm_config']['cores']
  end

  # Configuration options for VMware Fusion.
  config.vm.provider :vmware_fusion do |v|
    v.vmx["memsize"] = antidote_config['vm_config']['memory']
    v.vmx["numvcpus"] = antidote_config['vm_config']['cores']
  end

  # Configuration options for Libvirt.
  config.vm.provider :libvirt do |v, override|
    v.memory = antidote_config['vm_config']['memory']
    v.cpus = antidote_config['vm_config']['cores']
    v.nested = true
    override.vm.box = "generic/ubuntu1804"
  end


  # Base Ubuntu Box
  config.vm.box = "bento/ubuntu-18.04"

  config.vm.hostname = "antidote-#{antidote_config['version'].to_s.tr('.', '')}"

  config.vm.define "Antidote #{antidote_config['version']}"

  # Please see (https://github.com/cogitatio/vagrant-hostsupdater) for more information
  if defined?(VagrantPlugins::HostsUpdater)
     config.hostsupdater.aliases = ["antidote-local"]
     config.hostsupdater.remove_on_suspend = false
  end

  config.vm.network :private_network, id: "antidote_primary", ip: antidote_config['vm_config']['private_network_ip']

  config.vm.network "forwarded_port", guest: 30001, host: 30001
  # Temporary to enable webssh2 - should be made available via ingress ASAP
  config.vm.network "forwarded_port", guest: 30010, host: 30010

  # config.vm.provider :hyperv do |v, override|
  #   override.vm.network :private_network, id: "vvv_primary", ip: nil
  # end

  # /shared
  config.vm.synced_folder "../nrelabs-curriculum", "/curriculum"

  # Disable default synced folder
  config.vm.synced_folder ".", "/vagrant", disabled: true
  
  # Copy selfmedicate and the manifests folder to the VM.
  config.vm.provision "file", source: "selfmedicate.sh", destination: "$HOME/selfmedicate.sh"
  config.vm.provision "file", source: "container-start.sh", destination: "$HOME/container-start.sh"
  config.vm.synced_folder "manifests", "/home/vagrant/manifests"
  
  # Provisioning antidote vagrant vm
  # This will install docker, kubectl and minikube
  config.vm.provision "default", type: "shell", path: "vagrant-provision.sh", env: {CHANGE_MINIKUBE_NONE_USER: true}
  
  # Running initial selfmedicate script as the Vagrant user.
  $script = "/bin/bash --login $HOME/selfmedicate.sh start"
  config.vm.provision "custom", type: "shell", privileged: false, inline: $script
  
  # Start antidote on reload
  $script = "/bin/bash --login $HOME/selfmedicate.sh resume"
  config.vm.provision "reload", type: "shell", privileged: false, inline: $script, run: "always"

end

