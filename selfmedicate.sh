#!/bin/bash

PROGNAME=$(basename $0)
SUBCOMMAND=$1

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
WHITE='\033[37m'
NC='\033[0m'

if [ -f $HOME/.antidote/config ]
then
    echo -e "${YELLOW}Reading your preferences from '$HOME/.antidote/config'.${NC}"
    . $HOME/.antidote/config
fi

CPUS=${CPUS:=2}
MEMORY=${MEMORY:=8192}
VMDRIVER=${VMDRIVER:="none"}
LESSON_DIRECTORY=${LESSON_DIRECTORY:="/antidote"}
MINIKUBE=${MINIKUBE:="sudo minikube"}
KUBECTL=${KUBECTL:="kubectl"}
PRELOADED_IMAGES=${PRELOADED_IMAGES:="vqfx-snap1 vqfx-snap2 vqfx-snap3 utility"}
ANTIDOTEVERSION=${ANTIDOTEVERSION:="release-v0.4.0"}
K8SVERSION=${K8SVERSION:="v1.14.0"}  # Needs to reflect the targeted version the Antidoteplatform was built against.

# Checking for prerequisites
command -v $MINIKUBE > /dev/null
if [ $? -ne 0 ]; then
    echo "Minikube not found. Please follow installation instructions at: https://antidoteproject.readthedocs.io/en/latest/building/buildlocal.html"
    exit 1
fi

set -e

sub_help(){
    echo "Usage: $PROGNAME <subcommand> [options]"
    echo "Subcommands:"
    echo "    start    Start local instance of Antidote"
    echo "    reload   Reload Antidote components"
    echo "    stop     Stop local instance of Antidote"
    echo "    resume   Resume stopped Antidote instance"
    echo ""
    echo "options:"
    echo "-h    show brief help"
    echo ""
    echo "For help with each subcommand run:"
    echo "$PROGNAME <subcommand> -h|--help"
    echo ""
}
  
sub_resume(){

    $MINIKUBE config set WantReportErrorPrompt false
    if [ ! -f $HOME/.minikube/config/config.json ]; then
        echo -e "${RED}No existing cluster detected.${NC}"
        echo -e "This subcommand is used to resume an existing selfmedicate setup."
        echo -e "Please use the ${WHITE}'start'${NC} subcommand instead."
        exit 1
    fi

    $MINIKUBE start \
        --cpus $CPUS \
        --memory $MEMORY \
        --vm-driver $VMDRIVER \
        --network-plugin=cni \
        --extra-config=kubelet.network-plugin=cni \
        --kubernetes-version=$K8SVERSION

    echo -e "${GREEN}Finished!${NC} Antidote should now be available at http://antidote-local:30001/"
}

sub_start(){

    if [ -z "$LESSON_DIRECTORY" ]
    then
        echo -e "${RED}Error${NC} - Must provide lesson directory as the final parameter"
    fi

    if [ ! -d "$LESSON_DIRECTORY/lessons" ]; then
        echo -e "${RED}Error${NC} - $LESSON_DIRECTORY doesn't look like a proper curriculum directory."
        echo -e "Either this directory wasn't found, or the subdirectory 'lessons' within that directory wasn't found.\n"
        echo -e "In either case, this script cannot continue. Please either place the appropriate directory in place, or"
        echo -e "edit the LESSON_DIRECTORY variable at the top of this script."
        exit 1
    fi

    if [ -f $HOME/.minikube/config/config.json ]; then
        echo -e "${RED}WARNING - EXISTING MINIKUBE CONFIGURATION DETECTED${NC}"
        echo -e "This command is designed to start a new minikube cluster from scratch, and must delete any existing configurations in order to move forward."
        read -p "Press any key to DESTROY THE EXISTING CLUSTER and create a new one for antidote (Ctrl+C will escape)."
        set +e
        $MINIKUBE delete > /dev/null
        set -e
    fi

    if [ -d "~/.kube/config" ]; then
        if [ ! -f ~/.kube/premselfmedicate_bkp ]; then
            echo "Backing up existing kubeconfig to ~/.kube/premselfmedicate_bkp..."
            cp ~/.kube/config ~/.kube/premselfmedicate_bkp
        else
            echo "Existing kubeconfig backup found, not re-copying."
        fi
    fi

	sudo mkdir -p /opt/cni/bin  > /dev/null 2>&1
	curl -L -o cniplugins.tgz https://github.com/containernetworking/plugins/releases/download/v0.8.1/cni-plugins-linux-amd64-v0.8.1.tgz  > /dev/null 2>&1
	sudo tar zxvf cniplugins.tgz -C /opt/cni/bin  > /dev/null 2>&1
	sudo curl -L https://github.com/nre-learning/plugins/blob/master/bin/antibridge?raw=true -o /opt/cni/bin/antibridge  > /dev/null 2>&1 && sudo chmod a+x /opt/cni/bin/antibridge > /dev/null 2>&1
	rm -f cniplugins.tgz  > /dev/null 2>&1
	
	sudo mkdir -p /etc/cni/net.d
	sudo cp manifests/multus-cni.conf /etc/cni/net.d/1-multus.conf
    echo "Creating minikube cluster. This can take a few minutes, please be patient..."
    $MINIKUBE config set WantReportErrorPrompt false
    $MINIKUBE start \
    --cpus $CPUS \
    --memory $MEMORY \
    --vm-driver $VMDRIVER \
    --network-plugin=cni \
    --extra-config=kubelet.network-plugin=cni \
    --kubernetes-version=$K8SVERSION  # Needs to reflect the targeted version the platform was built against.

    echo -e "\nThe minikube cluster ${WHITE}is now online${NC}. Now, we need to add some additional infrastructure components.\n"
    echo -e "\n${YELLOW}This will take some time${NC} - this script will pre-download large images so that you don't have to later. BE PATIENT.\n"
	
	sudo chown -R $USER $HOME/.kube $HOME/.minikube
	
    $KUBECTL apply -f "https://cloud.weave.works/k8s/net?k8s-version=$($KUBECTL version | base64 | tr -d '\n')"
    $KUBECTL create -f manifests/multusinstall.yml

    print_progress() {
        percentage=$1
        chars=$(echo "40 * $percentage"/1| bc)
        v=$(printf "%-${chars}s" "#")
        s=$(printf "%-$((40 - chars))s")
        echo "${v// /#}""${s// /-}"
    }

    running_system_pods=0
    total_system_pods=$($KUBECTL get pods -n=kube-system | tail -n +2 | wc -l)
    while [ $running_system_pods -lt $total_system_pods ]
    do
        running_system_pods=$($KUBECTL get pods -n=kube-system | grep Running | wc -l)
        percentage="$( echo "$running_system_pods/$total_system_pods" | bc -l )"
        echo -ne $(print_progress $percentage) "${YELLOW}Installing additional infrastructure components...${NC}\r"
        sleep 5
    done

    # Clear line and print finished progress
    echo -ne "$pc%\033[0K\r"
    echo -ne $(print_progress 1) "${GREEN}Done.${NC}\n"

    $KUBECTL create -f manifests/nginx-controller.yaml > /dev/null
    $KUBECTL create -f manifests/syringe-k8s.yaml > /dev/null
    $KUBECTL create -f manifests/antidote-web.yaml > /dev/null
    $KUBECTL create -f manifests/webssh2.yaml > /dev/null

    running_platform_pods=0
    total_platform_pods=$($KUBECTL get pods | tail -n +2 | wc -l)
    while [ $running_platform_pods -lt $total_platform_pods ]
    do
        running_platform_pods=$($KUBECTL get pods | grep Running | wc -l)
        percentage="$( echo "$running_platform_pods/$total_platform_pods" | bc -l )"
        echo -ne $(print_progress $percentage) "${YELLOW}Starting the antidote platform...${NC}\r"
        sleep 5
    done

    # Clear line and print finished progress
    echo -ne "$pc%\033[0K\r"
    echo -ne $(print_progress 1) "${GREEN}Done.${NC}\n"
	# Moved antidote up message to before image pull due to docker timeout issues.
    echo -e "${GREEN}Finished!${NC} Antidote should now be available at http://antidote-local:30001/"

    # Pre-download large common images
    for i in $(echo $PRELOADED_IMAGES)
    do
        echo -e "${YELLOW}Pre-emptively pulling image antidotelabs/$i...${NC}\n"
		sudo docker pull antidotelabs/$i > /dev/null 2>&1
		# Add 3 second sleep due to docker timeout issue
		sleep 3
    done
    
}

sub_reload(){
    echo "Reloading lesson content, please wait..."
    $KUBECTL delete pod $($KUBECTL get pods | grep syringe | awk '{ print $1 }') >> /dev/null
    while [ $($KUBECTL get ns -L syringeManaged | grep yes | wc -l) -gt 0 ]
    do
        echo "Waiting for running lessons to terminate..."
        sleep 1
    done
    echo -e "${GREEN}Reload complete.${NC}"
}

sub_stop(){
    echo -e "About to stop minikube. You may safely ignore any messages that say 'Errors occurred deleting mount process'"
    $MINIKUBE stop
}

sub_debug(){
    debugs=(
        "ls -lha $LESSON_DIRECTORY"

        "docker run -v $LESSON_DIRECTORY:/antidote antidotelabs/syringe:$ANTIDOTEVERSION syrctl validate /antidote"

        "kubectl describe pods --all-namespaces"
        "kubectl describe services --all-namespaces"
        "kubectl describe network-attachment-definitions --all-namespaces"
        "kubectl logs $(kubectl get pods | awk '/syringe/ {print $1;exit}')"

        "kubectl -n=kube-system logs $(kubectl -n=kube-system get pods | awk '/multus/ {print $1;exit}')"
    )

    echo "Please wait while selfmedicate debug information is gathered..."

    for i in "${debugs[@]}"
    do
        echo -e "\n=============================="
        echo "$i"
        echo -e "==============================\n"

        eval $i
    done

    echo "Selfmedicate debug report complete."
}

while getopts "h" OPTION
do
	case $OPTION in
		h)
            sub_help
            exit
            ;;
		\?)
			sub_help
			exit
			;;
	esac
done

# Direct to appropriate subcommand
subcommand=$1
case $subcommand in
    "")
        sub_help
        ;;
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

