#!/bin/bash

# constants
BLUE='\033[0;34m'
NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
HOSTS_FILE="/etc/hosts"
SSH_CONFIG_FILE="$HOME/.ssh/config"
DELIMITER_START="#### start multipass routing ####"
DELIMITER_END="#### end multipass routing ####"
SSH_DELI_START="#### start multipass ssh config ####"
SSH_DELI_END="#### end multipass ssh config ####"

# Helper functions
log_info() {
    printf "${BLUE} [multipass] ${NC} %s\n" "$1"
}

log_success() {
    printf "${GREEN} [multipass] ${NC} %s\n" "$1"
}

log_error() {
    printf "${RED} [multipass] ${NC} %s\n" "$1"
}

log_warning() {
    printf "${YELLOW} [multipass] ${NC} %s\n" "$1"
}

check_multipass() {
    if ! command -v multipass >/dev/null 2>&1; then
        log_error "multipass is not installed. Please install it first"
        exit 1
    fi

    if ! multipass list >/dev/null 2>&1; then
        log_warning "Multipass authentication required. Please run 'multipass list' to authenticate"
        log_info "Running 'multipass authenticate' ..."
        
        if ! multipass authenticate; then
            log_error "Failed to authenticate multipass. Please run multipass authenticate manually"
            exit 1
        fi

        if ! multipass list >/dev/null 2>&1; then
            log_error "Authentication successful but cannot list VMs"
            log_error "Please ensure you have proper permissions and try again"
            exit 1
        fi
    fi
}

check_root() {
    if [ -z "$EUID" ] || [ "$EUID" -ne 0 ]; then
        log_info "Not running as root. Elevating privileges..."
        sudo -E bash "$0" "$@"
        exit $?
    fi
}

clean_existing_entries() {
    log_info "Creating or updating SSH config file: $SSH_CONFIG_FILE"
    mkdir -p "$(dirname "$SSH_CONFIG_FILE")" || {
        log_error "Failed to create ~/.ssh directory"
        exit 1
    }
    touch "$SSH_CONFIG_FILE" || {
        log_error "Failed to create SSH config file"
        exit 1
    }
    chmod 600 "$SSH_CONFIG_FILE" || {
        log_error "Failed to set permissions for SSH config file"
        exit 1
    }

    # Remove existing multipass SSH config entries
    if grep -q "${SSH_DELI_START}" "$SSH_CONFIG_FILE"; then
        log_info "Removing existing multipass SSH config entries"
        sed -i "/${SSH_DELI_START}/,/${SSH_DELI_END}/d" "$SSH_CONFIG_FILE"
    fi
}

updating_hosts_and_ssh() {
    # Add opening delimiter to hosts file
    echo -e "${DELIMITER_START}\n" >> "$HOSTS_FILE"

    # Add opening delimiter to SSH config file
    echo -e "\n${SSH_DELI_START}" >> "$SSH_CONFIG_FILE"

    # Process running VMs and update both files
    multipass list --format json | \
    jq -r '.list[] | select(.state == "Running") | [.ipv4[0], .name] | @tsv' | \
    while IFS=$'\t' read -r ip name; do
        # update hosts file
        domain="${name}.local"
        echo -e "${ip} ${domain}" >> "$HOSTS_FILE"
        log_success "$ip $domain"

        # update SSH config file
        log_info "Adding entry for ${name} with IP ${ip}"
        echo -e "\nHost ${name}" >> "$SSH_CONFIG_FILE"
        echo "    User ubuntu" >> "$SSH_CONFIG_FILE"
        echo "    Hostname ${ip}" >> "$SSH_CONFIG_FILE"
    done

    # Add closing delimiters
    echo -e "\n${DELIMITER_END}" >> "$HOSTS_FILE"
    echo -e "\n${SSH_DELI_END}" >> "$SSH_CONFIG_FILE"
}

main() {
    log_info "Updating /etc/hosts and SSH config file with multipass virtual machines"

    check_root "$@"
    check_multipass
    clean_existing_entries
    updating_hosts_and_ssh

    log_success "Successfully updated /etc/hosts and SSH config file with multipass virtual machines"
}

main "$@"