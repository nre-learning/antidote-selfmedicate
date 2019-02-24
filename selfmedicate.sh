#!/bin/bash
# set -e

PROGNAME=$(basename $0)
SUBCOMMAND=$1
LESSON_DIRECTORY=$2

RED='\033[31m'
GREEN='\033[32m'
WHITE='\033[37m'
NC='\033[0m'

# Checking for prerequisites
command -v minikube > /dev/null
if [ $? -ne 0 ]; then
    echo "Minikube not found. Please follow installation instructions at: https://antidoteproject.readthedocs.io/en/latest/building/buildlocal.html"
    exit 1
fi
# TODO Also check for syrctl and virtualbox


sub_help(){
    echo "Usage: $PROGNAME <subcommand> [options]"
    echo "Subcommands:"
    echo "    start    Start local instance of Antidote"
    echo "    reload   Reload Antidote components"
    echo "    stop     Stop local instance of Antidote"
    echo "    resume   Resume stopped Antidote instance"
    echo ""
    echo "options:"
    echo "-h, --help                show brief help"
    echo ""
    echo "For help with each subcommand run:"
    echo "$PROGNAME <subcommand> -h|--help"
    echo ""
}
  
sub_resume(){
    minikube config set WantReportErrorPrompt false
    if [ ! -f $HOME/.minikube/config/config.json ]; then
        echo -e "${RED}No existing cluster detected.${NC}"
        echo -e "This subcommand is used to resume an existing selfmedicate setup."
        echo -e "Please use the ${WHITE}'start'${NC} subcommand instead."
        exit 1
    fi
    minikube start \
        --mount --mount-string="$LESSON_DIRECTORY:/antidote" \
        --cpus 4 --memory 8192 --network-plugin=cni --extra-config=kubelet.network-plugin=cni
}

sub_start(){
    echo "Running 'start' command."

    # TODO(mierdin) Make sure LESSON_DIRECTORY is set


    if [ -f $HOME/.minikube/config/config.json ]; then
        echo -e "${RED}WARNING - EXISTING MINIKUBE CONFIGURATION DETECTED${NC}"
        echo -e "This command is designed to start a new minikube cluster from scratch, and must delete any existing configurations in order to move forward."
        read -p "Press any key to DESTROY THE EXISTING CLUSTER and create a new one for antidote (Ctrl+C will escape)."
        minikube delete > /dev/null
    fi

    if [ ! -f ~/.kube/premselfmedicate_bkp ]; then
        echo "Backing up existing kubeconfig to ~/.kube/preminikube_bkp..."
        cp ~/.kube/config ~/.kube/premselfmedicate_bkp
    else
        echo "Existing kubeconfig backup found, not re-copying."
    fi

    echo "Creating minikube cluster. This can take a few minutes, please be patient..."
    minikube config set WantReportErrorPrompt false
    minikube start \
    --mount --mount-string="$LESSON_DIRECTORY:/antidote" \
    --cpus 4 --memory 8192 --network-plugin=cni --extra-config=kubelet.network-plugin=cni

    echo "Uploading multus configuration..."
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $(minikube ssh-key) \
        manifests/multus-cni.conf docker@$(minikube ip):/home/docker/multus.conf  > /dev/null
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $(minikube ssh-key) -t docker@$(minikube ip) \
        "sudo cp /home/docker/multus.conf /etc/cni/net.d/1-multus.conf"  > /dev/null
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $(minikube ssh-key) -t docker@$(minikube ip) \
        "sudo systemctl restart localkube"  > /dev/null
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $(minikube ssh-key) -t docker@$(minikube ip) \
        "sudo curl -L https://github.com/nre-learning/plugins/blob/master/bin/antibridge?raw=true -o /opt/cni/bin/antibridge && sudo chmod a+x /opt/cni/bin/antibridge"  > /dev/null

    echo "About to modify /etc/hosts to add record for 'antidote-local'. You will now be prompted for your sudo password."
    sudo sed -i '/antidote-local.*/d' /etc/hosts  > /dev/null
    echo "$(minikube ip)    antidote-local" | sudo tee -a /etc/hosts  > /dev/null

    echo "Adding additional infrastructure components..."
    kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')" > /dev/null
    kubectl create -f manifests/multusinstall.yml > /dev/null
    
    echo "Uploading platform manifests..."
    kubectl create -f manifests/nginx-controller.yaml > /dev/null
    kubectl create -f manifests/syringe-k8s.yaml > /dev/null
    kubectl create -f manifests/antidote-web.yaml > /dev/null

    echo -e "${GREEN}Finished!${NC} Antidote is being spun up right now. Soon, it will be available at:

    http://antidote-local:30001/"

}

sub_reload(){
    echo "Reloading lesson content, please wait..."
    kubectl delete pod $(kubectl get pods | grep syringe | awk '{ print $1 }') >> /dev/null
    echo -e "${GREEN}Done.${NC}"
}

sub_stop(){
    minikube stop
}

# Handle optional flags
while :; do
    case $1 in
        -h|--help)
            sub_help
            exit
            ;;
        *)
            break
    esac
    shift
done

# Direct to appropriate subcommand
subcommand=$1
case $subcommand in
    *)
        shift
        sub_${subcommand} $@
        if [ $? = 127 ]; then
            echo "Error: '$subcommand' is not a known subcommand." >&2
            echo "       Run '$PROGNAME --help' for a list of known subcommands." >&2
            exit 1
        fi
        ;;
esac

exit 0

