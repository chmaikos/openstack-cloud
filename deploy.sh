#!/bin/bash

# OpenStack Cloud Application Deployment Script
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
NETWORK_NAME="app_net"
WEB_SG_NAME="web-security-group"
DB_SG_NAME="db-security-group"
WEB_VM_NAME="web-server"
DB_VM_NAME="db-server"
IMAGE_NAME="ubuntu-base"
FLAVOR_NAME="m1.small"

log "Starting deployment of two-tier cloud application..."

# 1. Create Security Groups
log "Creating security groups..."

# Web Security Group
log "Creating web security group..."
if ! openstack security group show $WEB_SG_NAME > /dev/null 2>&1; then
    openstack security group create $WEB_SG_NAME --description "Security group for web server"
    openstack security group rule create $WEB_SG_NAME --protocol tcp --dst-port 80 --remote-ip 0.0.0.0/0
    openstack security group rule create $WEB_SG_NAME --protocol tcp --dst-port 8000 --remote-ip 0.0.0.0/0
    openstack security group rule create $WEB_SG_NAME --protocol tcp --dst-port 22 --remote-ip 0.0.0.0/0
    openstack security group rule create $WEB_SG_NAME --protocol icmp --remote-ip 0.0.0.0/0
else
    log "Web security group already exists"
fi

# Database Security Group
log "Creating database security group..."
if ! openstack security group show $DB_SG_NAME > /dev/null 2>&1; then
    openstack security group create $DB_SG_NAME --description "Security group for database server"
    openstack security group rule create $DB_SG_NAME --protocol tcp --dst-port 5432 --remote-ip 192.168.128.0/24
    openstack security group rule create $DB_SG_NAME --protocol tcp --dst-port 22 --remote-ip 192.168.128.0/24
    openstack security group rule create $DB_SG_NAME --protocol icmp --remote-ip 192.168.128.0/24
else
    log "Database security group already exists"
fi

# 2. Get Network and Image IDs
log "Getting network and image information..."
NETWORK_ID=$(openstack network show $NETWORK_NAME -f value -c id)
IMAGE_ID=$(openstack image show $IMAGE_NAME -f value -c id)
FLAVOR_ID=$(openstack flavor show $FLAVOR_NAME -f value -c id)

log "Network ID: $NETWORK_ID"
log "Image ID: $IMAGE_ID"
log "Flavor ID: $FLAVOR_ID"

# 3. Create Database Server
log "Creating database server..."
openstack server create \
    --image $IMAGE_ID \
    --flavor $FLAVOR_ID \
    --network $NETWORK_ID \
    --security-group $DB_SG_NAME \
    --user-data cloud-init/db-server.yaml \
    --wait \
    $DB_VM_NAME

DB_VM_IP=$(openstack server show $DB_VM_NAME -f value -c addresses | grep -oE '192\.[0-9]+\.[0-9]+\.[0-9]+')
log "Database server IP: $DB_VM_IP"

# 4. Create Web Server with database IP
log "Creating web server with database IP: $DB_VM_IP..."
# Create a temporary cloud-init file with the correct database IP
sed "s/DB_HOST=db-server/DB_HOST=$DB_VM_IP/g" cloud-init/web-server.yaml > cloud-init/web-server-temp.yaml

openstack server create \
    --image $IMAGE_ID \
    --flavor $FLAVOR_ID \
    --network $NETWORK_ID \
    --security-group $WEB_SG_NAME \
    --user-data cloud-init/web-server-temp.yaml \
    --wait \
    $WEB_VM_NAME

# Clean up temporary file
rm -f cloud-init/web-server-temp.yaml

WEB_VM_IP=$(openstack server show $WEB_VM_NAME -f value -c addresses | grep -oE '192\.[0-9]+\.[0-9]+\.[0-9]+')
log "Web server IP: $WEB_VM_IP"

# 5. Allocate Floating IP
log "Allocating floating IP for web server..."
FLOATING_IP=$(openstack floating ip create public -f value -c floating_ip_address)
openstack server add floating ip $WEB_VM_NAME $FLOATING_IP

log "Floating IP allocated: $FLOATING_IP"

# 6. Wait for cloud-init to complete and configure database connection
log "Waiting for cloud-init to complete on both servers..."
log "This may take 3-5 minutes for full application setup..."

# Wait for cloud-init to complete (internal IPs are not accessible from host)
log "Waiting for cloud-init to complete on both servers..."
log "Note: Internal IPs ($DB_VM_IP, $WEB_VM_IP) are not accessible from host"
log "Waiting for application to be ready via floating IP..."
sleep 120

# 7. Test application connectivity
log "Testing application connectivity..."
for i in {1..20}; do
    if curl -s "http://$FLOATING_IP/health" >/dev/null 2>&1; then
        log "✅ Application is running and accessible!"
        break
    fi
    log "Waiting for application to be ready... (attempt $i/20)"
    sleep 15
done

if [ $i -eq 20 ]; then
    warning "Application may not be fully ready yet. Please check manually:"
    warning "SSH to web server: ssh ubuntu@$FLOATING_IP"
    warning "Check application status: sudo supervisorctl status cloudapp"
    warning "Check application logs: tail -f /var/log/cloudapp.out.log"
fi

# 8. Save configuration
log "Saving configuration..."
cat > config.env << EOF
# OpenStack Configuration
PROJECT_NAME=$PROJECT_NAME
NETWORK_NAME=$NETWORK_NAME
WEB_VM_NAME=$WEB_VM_NAME
DB_VM_NAME=$DB_VM_NAME
WEB_VM_IP=$WEB_VM_IP
DB_VM_IP=$DB_VM_IP
FLOATING_IP=$FLOATING_IP
WEB_SG_NAME=$WEB_SG_NAME
DB_SG_NAME=$DB_SG_NAME
EOF

log "Configuration saved to config.env"

# 9. Generate deployment report
log "Generating deployment report..."
cat > logs/deployment.log << EOF
OpenStack Cloud Application Deployment Report
============================================
Date: $(date)
Project: $PROJECT_NAME

Infrastructure:
- Network: $NETWORK_NAME ($NETWORK_ID)
- Web Server: $WEB_VM_NAME ($WEB_VM_IP)
- Database Server: $DB_VM_NAME ($DB_VM_IP)
- Floating IP: $FLOATING_IP

Security Groups:
- Web: $WEB_SG_NAME (Ports: 80, 22, ICMP)
- Database: $DB_SG_NAME (Ports: 5432, 22, ICMP)

Deployment Status: SUCCESS
EOF

log "Deployment completed successfully!"
log ""
log "🎉 APPLICATION DEPLOYMENT SUMMARY:"
log "=================================="
log "🌐 Web Application: http://$FLOATING_IP"
log "📚 API Documentation: http://$FLOATING_IP/docs"
log "🏥 Health Check: http://$FLOATING_IP/health"
log "🔗 SSH Access: ssh ubuntu@$FLOATING_IP"
log "🗄️  Database Tunnel: ssh -L 5432:$DB_VM_IP:5432 ubuntu@$FLOATING_IP"
log "📡 Internal Network: $DB_VM_IP (database), $WEB_VM_IP (web)"
log ""
log "📊 MONITORING & ANALYSIS:"
log "========================="
log "📈 Monitor Resources: ./monitoring/monitor.sh"
log "💰 Cost Analysis: ./cost-analysis/cost-analysis.sh"
log "🧹 Cleanup Resources: ./cleanup.sh"
log ""
log "✅ Your two-tier cloud application is now running!" 