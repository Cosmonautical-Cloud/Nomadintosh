#! /bin/zsh

# Deploy Nomad and Consul - Interactive Menu
setopt ERR_RETURN

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${BLUE}=== Nomadintosh Deployment Menu ===${NC}"
}

print_option() {
    echo -e "${YELLOW}$1${NC}"
}

print_info() {
    echo -e "${GREEN}$1${NC}"
}

# Present menu options
print_header
echo ""
print_option "Select hosts to target:"
echo "  1) All hosts"
echo "  2) cosmonautical group"
echo "  3) jellify group"
echo "  4) Specific host"
echo ""

read "?Enter your choice [1-4]: " host_choice

case $host_choice in
    1)
        limit=""
        print_info "Targeting all hosts"
        ;;
    2)
        limit="cosmonautical"
        print_info "Targeting cosmonautical group"
        ;;
    3)
        limit="jellify"
        print_info "Targeting jellify group"
        ;;
    4)
        read "?Enter host name: " host_input
        limit="$host_input"
        print_info "Targeting host: $limit"
        ;;
    *)
        echo -e "${RED}Invalid choice. Exiting.${NC}"
        exit 1
        ;;
esac

echo ""
print_option "Select deployment option:"
echo "  1) Full deployment (all components)"
echo "  2) Install Consul only"
echo "  3) Install Nomad only"
echo "  4) Install Consul + Nomad"
echo "  5) Install CockroachDB"
echo "  6) Install Container runtime (Docker Desktop or Podman)"
echo "  7) Install Software updates"
echo "  8) Custom component selection"
echo "  9) Exit"
echo ""

read "?Enter your choice [1-9]: " choice

# Build ansible-playbook command with optional limit
build_command() {
    local playbook=$1
    local tags=$2
    local cmd="ansible-playbook $playbook"
    
    [ -n "$limit" ] && cmd="$cmd --limit $limit"
    [ -n "$tags" ] && cmd="$cmd --tags $tags"
    
    echo "$cmd"
}

case $choice in
    1)
        print_info "Running full deployment..."
        $(build_command "playbooks/deploy.yml" "")
        ;;
    2)
        print_info "Installing Consul only..."
        $(build_command "playbooks/deploy.yml" "consul")
        ;;
    3)
        print_info "Installing Nomad only..."
        $(build_command "playbooks/deploy.yml" "nomad")
        ;;
    4)
        print_info "Installing Consul and Nomad..."
        $(build_command "playbooks/deploy.yml" "consul,nomad")
        ;;
    5)
        print_info "Installing CockroachDB..."
        $(build_command "playbooks/deploy.yml" "cockroachdb")
        ;;
    6)
        print_info "Installing Container runtime..."
        echo ""
        read "?Choose: (1) Docker Desktop or (2) Podman? [1-2]: " container_choice
        if [ "$container_choice" = "1" ]; then
            $(build_command "playbooks/deploy.yml" "docker")
        elif [ "$container_choice" = "2" ]; then
            $(build_command "playbooks/deploy.yml" "podman")
        else
            echo -e "${RED}Invalid choice${NC}"
            exit 1
        fi
        ;;
    7)
        print_info "Installing software updates..."
        $(build_command "playbooks/deploy.yml" "software_update")
        ;;
    8)
        print_info "Custom component selection"
        echo ""
        echo "Available tags:"
        echo "  - software_update"
        echo "  - homebrew"
        echo "  - container"
        echo "  - docker (installs Docker Desktop)"
        echo "  - podman"
        echo "  - consul"
        echo "  - nomad"
        echo "  - cockroachdb"
        echo ""
        read "?Enter tags (comma-separated, e.g., 'consul,nomad'): " tags
        print_info "Running deployment with tags: $tags"
        $(build_command "playbooks/deploy.yml" "$tags")
        ;;
    9)
        print_info "Exiting..."
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice. Exiting.${NC}"
        exit 1
        ;;
esac

print_info "Deployment complete!"
