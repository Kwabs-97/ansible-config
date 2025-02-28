#!/bin/bash

# Constants
BLUE='\033[0;34m'
NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
HOSTS_FILE="/etc/hosts"
# Store the real user's home directory before sudo
REAL_USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
SSH_CONFIG_FILE="${REAL_USER_HOME}/.ssh/config"
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
        log_error "multipass is not installed. Please install it first."
        exit 1
    fi

    if ! multipass list >/dev/null 2>&1; then
        log_warning "Multipass authentication required. Please run 'multipass list' to authenticate."
        if ! multipass authenticate; then
            log_error "Failed to authenticate multipass. Please run multipass authenticate manually."
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
    log_info "Ensuring SSH config file exists: $SSH_CONFIG_FILE"
    mkdir -p "$(dirname "$SSH_CONFIG_FILE")"
    touch "$SSH_CONFIG_FILE"
    # Ensure correct ownership of SSH config file
    chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$SSH_CONFIG_FILE"
    chmod 600 "$SSH_CONFIG_FILE"

    # Force remove existing multipass SSH config entries
    log_info "Resetting multipass SSH config section"
    sed -i "/${SSH_DELI_START}/,/${SSH_DELI_END}/d" "$SSH_CONFIG_FILE"
    echo -e "\n${SSH_DELI_START}\n${SSH_DELI_END}" >> "$SSH_CONFIG_FILE"
    
    # Remove existing multipass hosts entries
    if grep -q "${DELIMITER_START}" "$HOSTS_FILE"; then
        log_info "Removing old multipass hosts entries."
        sed -i "/${DELIMITER_START}/,/${DELIMITER_END}/d" "$HOSTS_FILE"
    fi
}

update_hosts_and_ssh() {
    log_info "Updating hosts and SSH config with running Multipass VMs."
    echo -e "${DELIMITER_START}\n" | tee -a "$HOSTS_FILE" > /dev/null

    multipass list --format json | \
    jq -r '.list[] | select(.state == "Running") | [.ipv4[0], .name] | @tsv' | \
    while IFS=$'\t' read -r ip name; do
        domain="${name}.local"
        echo -e "${ip} ${domain}" | tee -a "$HOSTS_FILE" > /dev/null
        log_success "Added: ${ip} ${domain}"

        # Add SSH config with proper indentation
        sed -i "/${SSH_DELI_END}/d" "$SSH_CONFIG_FILE"
        {
            echo -e "\nHost ${name}"
            echo -e "    HostName ${ip}"
            echo -e "    User ubuntu"
            echo -e "    StrictHostKeyChecking no"
            echo -e "    UserKnownHostsFile /dev/null"
        } >> "$SSH_CONFIG_FILE"
        echo -e "${SSH_DELI_END}" >> "$SSH_CONFIG_FILE"
    done
    echo -e "\n${DELIMITER_END}" | tee -a "$HOSTS_FILE" > /dev/null
    
    # Ensure correct ownership of SSH config file after updates
    chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$SSH_CONFIG_FILE"
}

main() {
    log_info "Starting Multipass hosts and SSH config update."
    check_root "$@"
    check_multipass
    clean_existing_entries
    update_hosts_and_ssh
    log_success "Update complete!"
}

main "$@"