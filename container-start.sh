#!/bin/bash

PROGNAME=$(basename $0)
SUBCOMMAND=$1

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
WHITE='\033[37m'
NC='\033[0m'

KUBECTL=${KUBECTL:="kubectl"}

sub_run(){
    $KUBECTL apply -f "https://cloud.weave.works/k8s/net?k8s-version=$($KUBECTL version | base64 | tr -d '\n')"
    $KUBECTL create -f manifests/multusinstall.yml
    sub_wait_system
    
    $KUBECTL create -f manifests/nginx-controller.yaml > /dev/null
    $KUBECTL create -f manifests/acore.yaml > /dev/null
    $KUBECTL create -f manifests/aweb.yaml > /dev/null
    $KUBECTL create -f manifests/webssh2.yaml > /dev/null
    $KUBECTL create -f manifests/jaeger.yaml > /dev/null
    sub_wait_platform
}
print_progress() {
    percentage=$1
    chars=$(echo "40 * $percentage"/1| bc)
    v=$(printf "%-${chars}s" "#")
    s=$(printf "%-$((40 - chars))s")
    echo "${v// /#}""${s// /-}"
}

sub_wait_system(){
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
}

sub_wait_platform(){
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
}

sub_help(){
    echo "Usage: $PROGNAME <subcommand> [options]"
    echo "Subcommands:"
    echo "    run            Start the Antidote containers"
    echo "    wait_system    Reload Antidote components"
    echo "    wait_platform  Stop local instance of Antidote"
    echo "    resume         Resume stopped Antidote instance"
    echo ""
    echo "options:"
    echo "-h    show brief help"
    echo ""
    echo "For help with each subcommand run:"
    echo "$PROGNAME <subcommand> -h|--help"
    echo ""
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