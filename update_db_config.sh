#!/bin/bash

# Script to update database configuration on web server
# This script should be run after both servers are deployed

set -e

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Source OpenStack credentials
source ./cloud_app-openrc.sh

# Get server IPs
DB_VM_IP=$(openstack server show db-server -f value -c addresses | grep -oE '192\.[0-9]+\.[0-9]+\.[0-9]+')
WEB_VM_IP=$(openstack server show web-server -f value -c addresses | grep -oE '192\.[0-9]+\.[0-9]+\.[0-9]+')
FLOATING_IP=$(openstack server show web-server -f value -c addresses | grep -oE '192\.[0-9]+\.[0-9]+\.[0-9]+')

log "Database server IP: $DB_VM_IP"
log "Web server internal IP: $WEB_VM_IP"
log "Web server floating IP: $FLOATING_IP"

# Create a configuration update script
cat > /tmp/update_db_config.sh << EOF
#!/bin/bash
# Update database host in systemd service
sudo sed -i 's/DB_HOST=10.0.0.10/DB_HOST=$DB_VM_IP/' /etc/systemd/system/cloudapp.service

# Update environment variable
sudo sed -i 's/export DB_HOST=10.0.0.10/export DB_HOST=$DB_VM_IP/' /home/ubuntu/.bashrc

# Reload systemd and restart service
sudo systemctl daemon-reload
sudo systemctl restart cloudapp

echo "Database configuration updated successfully"
echo "New DB_HOST: $DB_VM_IP"
EOF

log "Updating database configuration on web server..."
log "Note: You may need to manually SSH to the web server and run the update script"
log "SSH command: ssh ubuntu@$FLOATING_IP"
log "Then run: sudo bash /tmp/update_db_config.sh"

# Alternative: Try to use SSH if available
if command -v ssh >/dev/null 2>&1; then
    log "Attempting to update configuration via SSH..."
    scp /tmp/update_db_config.sh ubuntu@$FLOATING_IP:/tmp/
    ssh ubuntu@$FLOATING_IP "sudo bash /tmp/update_db_config.sh"
    log "Configuration updated successfully!"
else
    log "SSH not available. Please manually update the configuration."
fi

# Cleanup
rm -f /tmp/update_db_config.sh

log "Update script completed!" 