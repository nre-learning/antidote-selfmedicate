echo "Welcome to antidote-selfmedicate. Take the red pill, it's more fun!"

GREEN='\033[1;32m'
NC='\033[0m'

command -v minikube > /dev/null
if [ $? -ne 0 ]; then
    echo "Minikube not found. Please follow installation instructions at: https://antidoteproject.readthedocs.io/en/latest/building/buildlocal.html"
    exit 1
fi

read -p "WARNING, this will delete any existing minikube cluster. Press enter to continue..."

if [ ! -f ~/.kube/premselfmedicate_bkp ]; then
    echo "Backing up existing kubeconfig to ~/.kube/preminikube_bkp..."
    cp ~/.kube/config ~/.kube/premselfmedicate_bkp
else
    echo "Existing kubeconfig backup found, not re-copying."
fi

echo "Creating minikube cluster. This can take a few minutes, please be patient..."
sudo minikube stop # > /dev/null
sudo minikube delete # > /dev/null
sudo rm -rf /var/lib/minikube/certs/
sudo rm -rf /etc/kubernetes/
sudo minikube start --vm-driver=none --cpus 4 --memory 8192 --network-plugin=cni --extra-config=kubelet.network-plugin=cni # > /dev/null

echo "Uploading multus configuration..."
#scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $(minikube ssh-key) multus-cni.conf docker@$(minikube ip):/home/docker/multus.conf  > /dev/null
#ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $(minikube ssh-key) -t docker@$(minikube ip) "sudo cp /home/docker/multus.conf /etc/cni/net.d/1-multus.conf"  > /dev/null
#ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $(minikube ssh-key) -t docker@$(minikube ip) "sudo systemctl restart localkube"  > /dev/null

sudo cp multus-cni.conf /etc/cni/net.d/1-multus.conf
sudo systemctl restart kubelet

echo "About to modify /etc/hosts to add record for 'antidote-local'. You will now be prompted for your sudo password."
sudo sed -i '' '/antidote-local.*/d' /etc/hosts # > /dev/null
echo "$(minikube ip)    antidote-local" | sudo tee -a /etc/hosts # > /dev/null

echo "Uploading platform manifests..."
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
kubectl create -f multusinstall.yml #> /dev/null
kubectl create -f nginx-controller.yaml #> /dev/null
kubectl create -f syringe.yml #> /dev/null
kubectl create -f antidote-web.yaml #> /dev/null

echo "${GREEN}Finished!${NC} Antidote is being spun up right now. Soon, it will be available at:

https://antidote-local:30002/"


# For linux, running without a VM, make sure user is in docker group, or otherwise doesn't need to run sudo for docker
# run minikube as sudo with linux
 