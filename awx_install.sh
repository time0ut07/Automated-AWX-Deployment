#!/bin/bash

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
RESET='\033[0m'  

set -e 

check_arg() {
    if [ $# -ne 1 ]; then
        echo -e "${YELLOW}[*] Usage: $0 <argument>${RESET}"
        echo -e "${YELLOW}[*] $0 -h to display help menu${RESET}"
        exit 1
    fi

    arg="$1"

    case "$arg" in
        -h)
            echo -e "${YELLOW}Usage: $0 <argument>${RESET}"
            echo "Argument      Description"
            echo "-h            Display help menu"
            echo "-int          AWX Internal"
            echo "-ext          AWX External"
            exit 1
            ;;
        -int)
            echo -e "${GREEN}[+] Argument Input: Internal (-int)"
            echo -e "[+] Script is going to configure AWX to be Internal facing...${RESET}"
            AWX_instance="int"
            ;;
        -ext)
            echo -e "${GREEN}[+] Argument Input: External (-ext)"
            echo -e "[+] Script is going to configure AWX to be External facing...${RESET}"
            AWX_instance="ext"
            ;;
        *)
            echo -e "${RED}[-] Invalid argument: $arg${RESET}"
            echo -e "${YELLOW}[*] Command: $0 -h for help menu${RESET}"
            exit 1
            ;;
    esac
}

check_linux() {
    echo -e "${YELLOW}[*] Checking OS...${RESET}"
    if [[ "$(uname)" != "Linux" ]]; then
        echo -e "${RED}[x] This script only works with Linux D:${RESET}"
        return 1
    else
        echo -e "${GREEN}[+] This script is running on Linux${RESET}"
    fi
}

check_internet() {
    echo -e "${YELLOW}[*] Checking for network connection...${RESET}"
    if ! ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        echo -e "${RED}[x] No Internet connection. Terminating...${RESET}"
        return 1
    else
        echo -e "${GREEN}[+] Internet is up. Continuing...${RESET}"
    fi
}

check_docker_installed() {
    echo -e "${YELLOW}[*] Checking if Docker is installed...${RESET}"
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}[+] Docker is already installed: $(docker --version)${RESET}"
        return 0
    else
        echo -e "${RED}[x] Docker is not installed${RESET}"
        return 1
    fi
}

remove_conflicting_packages() {
    echo -e "${YELLOW}[*] Removing conflicting packages...${RESET}"
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        sudo apt-get remove -y $pkg || echo -e "${RED}[x] Failed to remove $pkg${RESET}"
    done
}

install_docker() {
    echo -e "${YELLOW}[*] Setting up Docker's apt repo...${RESET}"
    sudo apt-get update -y
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y

    echo -e "${YELLOW}[*] Installing Docker packages...${RESET}"
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo -e "${YELLOW}[*] Verifying installation...${RESET}"
    if ! sudo docker run hello-world; then
        echo -e "${RED}[x] Docker installation verification failed${RESET}"
        exit 1
    fi

    echo -e "${GREEN}[+] Docker Installation successful${RESET}"
    echo -e "${YELLOW}[-] Adding $USER into Docker group...${RESET}"
    sudo groupadd docker 2>/dev/null || true
    sudo usermod -aG docker $USER
    echo -e "${GREEN}[+] $USER added to the docker group${RESET}"
    groups | grep docker || echo -e "${RED}[x] Failed to verify docker group membership${RESET}"

    sudo systemctl enable docker.service
    sudo systemctl enable containerd.service
}

check_arch() {
    echo -e "${YELLOW}[*] Checking OS Architecture...${RESET}"
    ARCH=$(uname -m)

    case "$ARCH" in
        x86_64)
            echo -e "${GREEN}[+] Detected x86_64 architecture${RESET}"
            echo -e "${YELLOW}[*] Downloading Minikube...${RESET}"
            curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
            sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
            ;;
        aarch64)
            echo -e "${GREEN}[+] Detected ARM64 architecture${RESET}"
            echo -e "${YELLOW}[*] Downloading Minikube...${RESET}"
            curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-arm64
            sudo install minikube-linux-arm64 /usr/local/bin/minikube && rm minikube-linux-arm64
            ;;
        armv7l)
            echo -e "${GREEN}[+] Detected ARMv7 architecture${RESET}"
            echo -e "${YELLOW}[*] Downloading Minikube...${RESET}"
            curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-arm
            sudo install minikube-linux-arm /usr/local/bin/minikube && rm minikube-linux-arm
            ;;
        ppc64le)
            echo -e "${GREEN}[+] Detected ppc64 architecture${RESET}"
            echo -e "${YELLOW}[*] Downloading Minikube...${RESET}"
            curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-ppc64le
            sudo install minikube-linux-ppc64le /usr/local/bin/minikube && rm minikube-linux-ppc64le
            ;;
        s390x)
            echo -e "${GREEN}[+] Detected s390x architecture${RESET}"
            echo -e "${YELLOW}[*] Downloading Minikube...${RESET}"
            curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-s390x
            sudo install minikube-linux-s390x /usr/local/bin/minikube && rm minikube-linux-s390x
            ;;
        *)
            echo -e "${RED}[-] Unsupported architecture '${ARCH}'${RESET}"
            return 1
            ;;
    esac
}

check_minikube_installed() {
    echo -e "${YELLOW}[*] Checking if Minikube is installed...${RESET}"
    if command -v minikube &> /dev/null; then
        echo -e "${GREEN}[+] Minikube is already installed${RESET}"
        return 0
    else
        echo -e "${RED}[-] Minikube is not installed yet${RESET}"
        return 1
    fi
}

download_minikube() {

    check_arch

    echo "Checking Minikube version..."
    if ! minikube version; then
        echo -e "${RED}[x] Failed to retrieve Minikube version!${RESET}"
        exit 1
    fi

    echo -e "${GREEN}[+] Minikube installed successfully!${RESET}"
}

start_minikube() {
    echo -e "${YELLOW}[*] Starting Minikube...${RESET}"
    minikube start
    echo -e "${GREEN}[+] Finished downloaded Minikube${RESET}"
}

check_minikube_running() {
    echo -e "${YELLOW}[*] Checking if Minikube is running...${RESET}"
    if docker ps --filter "name=minikube" --filter "status=running" | grep -q "minikube"; then
        echo -e "${GREEN}[+] Minikube is running${RESET}"
        return 0
    else
        echo -e "${RED}[-] Minikube is not running...${RESET}"
        return 1
    fi
}

countdown() {
    local seconds=$1
    while [ $seconds -gt 0 ]; do
        minutes=$((seconds / 60))
        secs=$((seconds % 60))
        printf "${RED}Time Remaining: \r%02d:%02d${RESET}" "$minutes" "$secs"
        sleep 1
        seconds=$((seconds - 1))
    done
}

wait_for_pods() {
    echo -e "${YELLOW}[*] Pod status:"

    start_time=$(date +%s%N)
    declare -A timers

    echo -ne "${YELLOW}\033[2K\r[*] Operator: \033[0m\n"
    echo -ne "${YELLOW}\033[2K\r[*] Migration: \033[0m\n"
    echo -ne "${YELLOW}\033[2K\r[*] Postgres: \033[0m\n"
    echo -ne "${YELLOW}\033[2K\r[*] Task: \033[0m\n"
    echo -ne "${YELLOW}\033[2K\r[*] Web: \033[0m\n"

    while true; do
        OPERATOR_STATUS=$(minikube kubectl -- get pods --no-headers | grep 'awx-operator-controller-manager' | awk '{print $3}')
        MIGRATION_STATUS=$(minikube kubectl -- get pods --no-headers | grep 'awx-server-migration' | awk '{print $3}')
        POSTGRES_STATUS=$(minikube kubectl -- get pods --no-headers | grep 'awx-server-postgres' | awk '{print $3}')
        TASK_STATUS=$(minikube kubectl -- get pods --no-headers | grep 'awx-server-task' | awk '{print $3}')
        WEB_STATUS=$(minikube kubectl -- get pods --no-headers | grep 'awx-server-web' | awk '{print $3}')

        [[ "$OPERATOR_STATUS" != "Running" ]] && timers[operator]=$((timers[operator]+1))
        [[ "$MIGRATION_STATUS" != "Completed" ]] && timers[migration]=$((timers[migration]+1))
        [[ "$POSTGRES_STATUS" != "Running" ]] && timers[postgres]=$((timers[postgres]+1))
        [[ "$TASK_STATUS" != "Running" ]] && timers[task]=$((timers[task]+1))
        [[ "$WEB_STATUS" != "Running" ]] && timers[web]=$((timers[web]+1))

        echo -ne "\033[5A"

        OPERATOR_OUTPUT="${YELLOW}[*] awx-operator-controller-manager: $OPERATOR_STATUS (${timers[operator]}s)${RESET}"
        if [[ "$OPERATOR_STATUS" == "Running" ]]; then
            OPERATOR_OUTPUT="${GREEN}[+] awx-operator-controller-manager: $OPERATOR_STATUS (${timers[operator]}s)${RESET}"
        fi

        MIGRATION_OUTPUT="${YELLOW}[*] awx-server-migration: $MIGRATION_STATUS (${timers[migration]}s)${RESET}"
        if [[ "$MIGRATION_STATUS" == "Completed" ]]; then
            MIGRATION_OUTPUT="${GREEN}[+] awx-server-migration: $MIGRATION_STATUS (${timers[migration]}s)${RESET}"
        fi

        POSTGRES_OUTPUT="${YELLOW}[*] awx-server-postgres: $POSTGRES_STATUS (${timers[postgres]}s)${RESET}"
        if [[ "$POSTGRES_STATUS" == "Running" ]]; then
            POSTGRES_OUTPUT="${GREEN}[+] awx-server-postgres: $POSTGRES_STATUS (${timers[postgres]}s)${RESET}"
        fi

        TASK_OUTPUT="${YELLOW}[*] awx-server-task: $TASK_STATUS (${timers[task]}s)${RESET}"
        if [[ "$TASK_STATUS" == "Running" ]]; then
            TASK_OUTPUT="${GREEN}[+] awx-server-task: $TASK_STATUS (${timers[task]}s)${RESET}"
        fi

        WEB_OUTPUT="${YELLOW}[*] awx-server-web: $WEB_STATUS (${timers[web]}s)${RESET}"
        if [[ "$WEB_STATUS" == "Running" ]]; then
            WEB_OUTPUT="${GREEN}[+] awx-server-web: $WEB_STATUS (${timers[web]}s)${RESET}"
        fi

        echo -ne "\033[2K\r$OPERATOR_OUTPUT\n"
        echo -ne "\033[2K\r$MIGRATION_OUTPUT\n"
        echo -ne "\033[2K\r$POSTGRES_OUTPUT\n"
        echo -ne "\033[2K\r$TASK_OUTPUT\n"
        echo -ne "\033[2K\r$WEB_OUTPUT\n"

        if [[ "$OPERATOR_STATUS" == "Running" && 
              "$MIGRATION_STATUS" == "Completed" && 
              "$POSTGRES_STATUS" == "Running" && 
              "$TASK_STATUS" == "Running" && 
              "$WEB_STATUS" == "Running" ]]; then
            
            end_time=$(date +%s%N)
            elapsed_time=$(( (end_time - start_time)/1000000000 ))

            echo -e "${GREEN}[+] All required pods are ready (Time taken: ${elapsed_time} s)${RESET}"
            break
        else
            echo -ne "${YELLOW}[*] Waiting for all required pods to be ready...${RESET}\r"
            sleep 1
        fi
    done
}

installing_awx() {
    sudo mkdir -p awx_files 
    cd awx_files
    echo -e "${YELLOW}[*] Creating kuztomization.yaml & awx-server.yml...${RESET}"
    sudo touch kustomization.yaml awx-server.yml
    if [[ -f "kustomization.yaml" && -f "awx-server.yml" ]]; then
    echo -e "${GREEN}[+] Both files were created successfully${RESET}"
    else
        echo "${RED}[x] Failed to create kustomization.yaml and awx-server.yml${RESET}"
        return 1
    fi

    VERSION=$(curl -s https://api.github.com/repos/ansible/awx-operator/releases/latest | jq -r .tag_name)

    echo -e "${YELLOW}[*] Writing kustomization.yaml...${RESET}"
    sudo printf '---\napiVersion: kustomize.config.k8s.io/v1beta1\nkind: Kustomization\nresources:\n  - github.com/ansible/awx-operator/config/default?ref=%s\n  - awx-server.yml\nimages:\n  - name: quay.io/ansible/awx-operator\n    newTag: %s\nnamespace: awx' "$VERSION" "$VERSION" | sudo tee kustomization.yaml > /dev/null
    
    if [[ -f "kustomization.yaml" ]]; then
        echo -e "${GREEN}[+] Successfully written kustomization.yaml${RESET}"
    else
        echo -e "${RED}[-] Failed to write kustomization.yaml${RESET}"
        return 1
    fi

    echo -e "${YELLOW}[*] Writing awx-server.yml...${RESET}"
    sudo printf '---\napiVersion: awx.ansible.com/v1beta1\nkind: AWX\nmetadata:\n  name: awx-server\nspec:\n  service_type: nodeport' | sudo tee awx-server.yml > /dev/null

    if [[ -f "awx-server.yml" ]]; then
        echo -e "${GREEN}[+] Successfully written awx-server.yml${RESET}"
    else
        echo -e "${RED}[-] Failed to write awx-server.yml${RESET}"
        return 1
    fi

    echo -e "${YELLOW}[*] Setting name space...${RESET}"
    minikube kubectl -- config set-context --current --namespace=awx
    echo -e "${YELLOW}[*] Setting up Kubernetes resources...${RESET}"
    minikube kubectl -- apply -k .

    wait_for_pods
}

clean_up() {
    echo -e "${YELLOW}[*] Cleaning up...${RESET}"
    docker ps -a -q --filter "ancestor=hello-world" | xargs -r docker rm
    echo -e "${YELLOW}[+] Successfully cleaned up${RESET}"
}

AWX_internal() {
    echo -e "${YELLOW}[*] Finding Address for you...${RESET}"
    Minikube_IP=$(minikube ip)
    AWX_port=$(minikube kubectl -- get svc awx-server-service -o jsonpath='{.spec.ports[0].nodePort}')
    echo -e "${GREEN}[+] Find me @ http://${Minikube_IP}:${AWX_port}${RESET}"
    pw=$(minikube kubectl -- get secret awx-server-admin-password -o jsonpath="{.data.password}" | base64 --decode)
    echo -e "${GREEN}[+] Credentials admin:${pw}${RESET}"
}

AWX_external() {
    server_ip_ens160=$(ip addr show ens160 | awk '/inet / {print $2}' | cut -d'/' -f1)
    echo -e "${YELLOW}[*] Portforwarding AWX from ${awx_internal} to <SERVER_IP>:30080"
    minikube kubectl -- port-forward service/awx-server-service --address 0.0.0.0 30080:80 &
    echo -e "${GREEN}[+] Find me @ http://${server_ip_ens160}:30080${RESET}"
    pw=$(minikube kubectl -- get secret awx-server-admin-password -o jsonpath="{.data.password}" | base64 --decode)
    echo -e "${GREEN}[+] Credentials admin:${pw}${RESET}"
}

check_arg "$@"
check_linux
check_internet

if ! check_docker_installed; then
    echo -e "${YELLOW}[*] Installing Docker...${RESET}"
    remove_conflicting_packages
    install_docker
fi

if ! check_minikube_installed; then
    download_minikube
fi

if ! check_minikube_running; then
    start_minikube
fi

installing_awx
clean_up

if [ "$AWX_instance" = "int" ]; then
    echo -e "${YELLOW}[*] Making AWX Internal Facing...${RESET}"
    AWX_internal
else
    echo -e "${YELLOW}[*] Making AWX External Facing...${RESET}"
    AWX_external
fi
