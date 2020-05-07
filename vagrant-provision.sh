#!/bin/bash
#
# provision.sh
#
# This file is specified in Vagrantfile and is loaded by Vagrant as the primary
# provisioning script whenever the commands `vagrant up`, `vagrant provision`,
# or `vagrant reload` are used. It provides all of the default packages and
# configurations included with Varying Vagrant Vagrants.

# By storing the date now, we can calculate the duration of provisioning at the
# end of this script.
start_seconds="$(date +%s)"

# PACKAGE INSTALLATION
#
# Build a bash array to pass all of the packages we want to install to a single
# apt-get command. This avoids doing all the leg work each time a package is
# set to install. It also allows us to easily comment out or add single
# packages.
apt_package_install_list=(
  # Please avoid apostrophes in these comments - they break vim syntax
  # highlighting.
  # 
  software-properties-common
  gnupg-agent
  bash-completion
  apt-transport-https
  ca-certificates
  curl
  bc
  docker-ce
  docker-ce-cli
  containerd.io
)

### FUNCTIONS

docker_repo() {
  # Docker
  #
  # apt-get does not have latest stable version of Docker CE,
  # so let's the use the docker repository instead.
  #
  # Install prerequisites.
  sudo apt-get install -y software-properties-common apt-transport-https ca-certificates curl gnupg-agent &>/dev/null
  # Get GPG Key
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  # Verifying key
  if [[ $(sudo apt-key fingerprint 0EBFCD88 | grep 'docker') = *Docker* ]]; then
        echo "Apt-Key verified..."
  else
        echo "Apt-Key verification failed, exiting."
		exit 1
  fi
  # Add Docker repo.
  echo "Adding Docker CE Stable repository..."
  sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable" &>/dev/null
  # Update apt-get info.
  sudo apt-get update &>/dev/null
}

package_install() {
  # Install required packages
  echo "Installing apt-get packages..."
  if ! apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew install --fix-missing --fix-broken ${apt_package_install_list[@]}; then
    apt-get clean
    return 1
  fi

  # Remove unnecessary packages
  echo "Removing unnecessary packages..."
  apt-get autoremove -y

  # Clean up apt caches
  apt-get clean
  
  return 0
}

setup_docker() {
  if ! [ -x "$(command -v docker)" ]; then
    echo "Error: docker was not installed properly. Exiting..."
    return 1
  fi

  echo " "
  echo "Setting up docker... "
  usermod -a -G docker vagrant
  systemctl enable docker
  return 0
}

install_kubectl() {
  # Download the latest version of kubectl
  echo "Installing Kubectl"
  curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl &>/dev/null
  # Make the kubectl binary executable
  chmod +x ./kubectl
  # Move the binary into the PATH
  sudo mv ./kubectl /usr/local/bin/kubectl

  # Enable kubectl autocompletion
  echo 'source <(kubectl completion bash)' >>/home/vagrant/.bashrc

  # Verify Kubectl is installed
  if hash kubectl 2>/dev/null; then
        echo "Successfully installed kubectl"
		return 0
  else
        echo "Failed to install kubectl, exiting"
		exit 1
  fi
}

install_minikube() {
  # Download the latest version
  curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 &>/dev/null \
  && chmod +x minikube &>/dev/null
  # Install into PATH
  sudo install minikube /usr/local/bin
  # Verify minikube installed
  if hash minikube 2>/dev/null; then
        echo "Successfully installed minikube"
		return 0
  else
        echo "Failed to install minikube, exiting"
		exit 1
  fi
}

### SCRIPT
echo " "
echo "Main packages check and install."
export DEBIAN_FRONTEND=noninteractive

docker_repo
if ! package_install; then
  echo "Main packages check and install failed, halting provision."
  exit 1
fi
setup_docker
install_kubectl
install_minikube
export CHANGE_MINIKUBE_NONE_USER
echo "export CHANGE_MINIKUBE_NONE_USER=true" >> /etc/profile.d/vagrant.sh
chmod +x /home/vagrant/selfmedicate.sh
chmod +x /home/vagrant/container-start.sh
echo "done"
