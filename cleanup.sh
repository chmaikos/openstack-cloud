#!/bin/bash

# OpenStack Cleanup Script
# Εργασία Εξαμήνου - Διαχείριση Υπολογιστικού Νέφους

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Source OpenStack credentials
log "Sourcing OpenStack credentials..."
source ./cloud_app-openrc.sh

# Variables
PROJECT_NAME="cloud_app"
WEB_VM_NAME="web-server"
DB_VM_NAME="db-server"
WEB_SG_NAME="web-security-group"
DB_SG_NAME="db-security-group"

log "Starting cleanup of OpenStack resources..."

# 1. Delete servers
log "Deleting servers..."

# Delete web server
if openstack server show $WEB_VM_NAME > /dev/null 2>&1; then
    log "Deleting web server: $WEB_VM_NAME"
    openstack server delete $WEB_VM_NAME
    # Wait for server to be deleted
    while openstack server show $WEB_VM_NAME > /dev/null 2>&1; do
        log "Waiting for web server to be deleted..."
        sleep 5
    done
else
    log "Web server $WEB_VM_NAME not found"
fi

# Delete database server
if openstack server show $DB_VM_NAME > /dev/null 2>&1; then
    log "Deleting database server: $DB_VM_NAME"
    openstack server delete $DB_VM_NAME
    # Wait for server to be deleted
    while openstack server show $DB_VM_NAME > /dev/null 2>&1; do
        log "Waiting for database server to be deleted..."
        sleep 5
    done
else
    log "Database server $DB_VM_NAME not found"
fi

# 2. Delete floating IPs
log "Deleting floating IPs..."
FLOATING_IPS=$(openstack floating ip list -f value -c "Floating IP Address")
for ip in $FLOATING_IPS; do
    if [ ! -z "$ip" ]; then
        log "Deleting floating IP: $ip"
        openstack floating ip delete $ip
    fi
done

# 3. Delete security groups
log "Deleting security groups..."

# Delete web security group
if openstack security group show $WEB_SG_NAME > /dev/null 2>&1; then
    log "Deleting web security group: $WEB_SG_NAME"
    openstack security group delete $WEB_SG_NAME
else
    log "Web security group $WEB_SG_NAME not found"
fi

# Delete database security group
if openstack security group show $DB_SG_NAME > /dev/null 2>&1; then
    log "Deleting database security group: $DB_SG_NAME"
    openstack security group delete $DB_SG_NAME
else
    log "Database security group $DB_SG_NAME not found"
fi

# 4. Clean up configuration files
log "Cleaning up configuration files..."
if [ -f config.env ]; then
    rm config.env
    log "Removed config.env"
fi

if [ -f logs/deployment.log ]; then
    rm logs/deployment.log
    log "Removed deployment.log"
fi

log "Cleanup completed successfully!"
log "All OpenStack resources have been removed." 