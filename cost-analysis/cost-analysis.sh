#!/bin/bash

# Enhanced OpenStack Cloud Application Cost Analysis Script
# Εργασία Εξαμήνου - Διαχείριση Υπολογιστικού Νέφους
# 6. 💰 Προσομοίωση Χρέωσης (Chargeback) - Enhanced Cost Analysis

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Source OpenStack credentials
log "Sourcing OpenStack credentials..."
source ./cloud_app-openrc.sh

# Load configuration
if [ -f "config.env" ]; then
    source config.env
else
    error "Configuration file not found. Please run deploy.sh first."
    exit 1
fi

# Create cost analysis directory
mkdir -p logs/cost-analysis

# Enhanced Cost Rates (Realistic OpenStack pricing)
VCPU_RATE=0.05      # $0.05 per vCPU per hour
RAM_RATE=0.02       # $0.02 per GB RAM per hour
STORAGE_RATE=0.10   # $0.10 per GB storage per hour
FLOATING_IP_RATE=0.01  # $0.01 per floating IP per hour
NETWORK_RATE=0.005  # $0.005 per GB network transfer
BANDWIDTH_RATE=0.02 # $0.02 per GB bandwidth

# Function to get server details
get_server_details() {
    local server_name=$1
    local flavor_data=$(openstack server show $server_name -f value -c flavor)
    local flavor_name=$(echo "$flavor_data" | grep -o "'name': '[^']*'" | cut -d"'" -f4)
    local vcpus=$(echo "$flavor_data" | grep -o "'vcpus': [0-9]*" | cut -d" " -f2)
    local ram=$(echo "$flavor_data" | grep -o "'ram': [0-9]*" | cut -d" " -f2)
    local disk=$(echo "$flavor_data" | grep -o "'disk': [0-9]*" | cut -d" " -f2)
    local created=$(openstack server show $server_name -f value -c created)
    local server_id=$(openstack server show $server_name -f value -c id)
    
    echo "$vcpus|$ram|$disk|$created|$server_id|$flavor_name"
}

# Function to calculate hours since creation
calculate_hours() {
    local created_date=$1
    local current_date=$(date +%s)
    local created_timestamp=$(date -d "$created_date" +%s 2>/dev/null || echo $current_date)
    local diff_seconds=$((current_date - created_timestamp))
    local diff_hours=$((diff_seconds / 3600))
    echo $diff_hours
}

# Function to get resource usage statistics
get_resource_usage() {
    local server_ip=$1
    local username=$2
    
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no $username@$server_ip "
        echo 'CPU: \$(top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d'%' -f1)'
        echo 'Memory: \$(free | grep Mem | awk '{printf \"%.1f\", \$3/\$2 * 100.0}')'
        echo 'Disk: \$(df / | awk 'NR==2 {print \$3}')'
        echo 'Network RX: \$(cat /proc/net/dev | grep eth0 | awk '{print \$2}')'
        echo 'Network TX: \$(cat /proc/net/dev | grep eth0 | awk '{print \$10}')'
    " 2>/dev/null || echo "0|0|0|0|0"
}

# Function to calculate bandwidth costs
calculate_bandwidth_cost() {
    local server_ip=$1
    local username=$2
    local hours=$3
    
    local usage_data=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no $username@$server_ip "
        cat /proc/net/dev | grep eth0 | awk '{print \$2 + \$10}'
    " 2>/dev/null || echo "0")
    
    # Convert bytes to GB
    local bandwidth_gb=$(echo "scale=4; $usage_data / 1024 / 1024 / 1024" | bc -l 2>/dev/null || echo "0")
    local bandwidth_cost=$(echo "scale=4; $bandwidth_gb * $BANDWIDTH_RATE * $hours / 24" | bc -l 2>/dev/null || echo "0")
    
    echo "$bandwidth_gb|$bandwidth_cost"
}

# Function to generate detailed cost breakdown
generate_cost_breakdown() {
    local server_name=$1
    local server_details=$2
    local hours=$3
    
    # Parse server details
    local vcpus=$(echo $server_details | cut -d'|' -f1)
    local ram=$(echo $server_details | cut -d'|' -f2)
    local disk=$(echo $server_details | cut -d'|' -f3)
    local server_id=$(echo $server_details | cut -d'|' -f5)
    local flavor_name=$(echo $server_details | cut -d'|' -f6)
    
    # Calculate costs
    local vcpu_cost=$(echo "scale=4; $vcpus * $VCPU_RATE * $hours" | bc -l 2>/dev/null || echo "0")
    local ram_cost=$(echo "scale=4; $ram / 1024 * $RAM_RATE * $hours" | bc -l 2>/dev/null || echo "0")
    local storage_cost=$(echo "scale=4; $disk * $STORAGE_RATE * $hours / 24" | bc -l 2>/dev/null || echo "0")
    
    # Get bandwidth cost
    local server_ip=$(openstack server show $server_name -f value -c addresses | grep -oE '192\.[0-9]+\.[0-9]+\.[0-9]+')
    local bandwidth_data=$(calculate_bandwidth_cost $server_ip ubuntu $hours)
    local bandwidth_gb=$(echo $bandwidth_data | cut -d'|' -f1)
    local bandwidth_cost=$(echo $bandwidth_data | cut -d'|' -f2)
    
    local total_cost=$(echo "scale=4; $vcpu_cost + $ram_cost + $storage_cost + $bandwidth_cost" | bc -l 2>/dev/null || echo "0")
    
    echo "$vcpu_cost|$ram_cost|$storage_cost|$bandwidth_cost|$total_cost|$bandwidth_gb"
}

# Function to generate cost report
generate_cost_report() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local report_file="logs/cost-analysis/cost_report_${timestamp}.html"
    
    # Get server details
    local db_details=$(get_server_details $DB_VM_NAME)
    local web_details=$(get_server_details $WEB_VM_NAME)
    
    # Calculate hours
    local db_created=$(echo $db_details | cut -d'|' -f4)
    local web_created=$(echo $web_details | cut -d'|' -f4)
    local db_hours=$(calculate_hours "$db_created")
    local web_hours=$(calculate_hours "$web_created")
    
    # Calculate costs
    local db_costs=$(generate_cost_breakdown $DB_VM_NAME "$db_details" $db_hours)
    local web_costs=$(generate_cost_breakdown $WEB_VM_NAME "$web_details" $web_hours)
    
    # Parse costs
    local db_vcpu_cost=$(echo $db_costs | cut -d'|' -f1)
    local db_ram_cost=$(echo $db_costs | cut -d'|' -f2)
    local db_storage_cost=$(echo $db_costs | cut -d'|' -f3)
    local db_bandwidth_cost=$(echo $db_costs | cut -d'|' -f4)
    local db_total=$(echo $db_costs | cut -d'|' -f5)
    
    local web_vcpu_cost=$(echo $web_costs | cut -d'|' -f1)
    local web_ram_cost=$(echo $web_costs | cut -d'|' -f2)
    local web_storage_cost=$(echo $web_costs | cut -d'|' -f3)
    local web_bandwidth_cost=$(echo $web_costs | cut -d'|' -f4)
    local web_total=$(echo $web_costs | cut -d'|' -f5)
    
    # Floating IP cost
    local floating_ip_cost=$(echo "scale=4; $FLOATING_IP_RATE * $web_hours" | bc -l 2>/dev/null || echo "0")
    
    # Total cost
    local grand_total=$(echo "scale=4; $db_total + $web_total + $floating_ip_cost" | bc -l 2>/dev/null || echo "0")
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>OpenStack Cost Analysis Report - $(date)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 10px; border: 1px solid #ddd; border-radius: 5px; }
        .cost-table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        .cost-table th, .cost-table td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        .cost-table th { background-color: #f2f2f2; }
        .total-row { background-color: #e6f3ff; font-weight: bold; }
        .grand-total { background-color: #ffeb3b; font-weight: bold; font-size: 1.2em; }
        .rate-info { background-color: #f9f9f9; padding: 10px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>OpenStack Cloud Application Cost Analysis Report</h1>
        <p>Generated: $(date)</p>
        <p>Project: $PROJECT_NAME</p>
        <p>Analysis Period: Database Server ($db_hours hours), Web Server ($web_hours hours)</p>
    </div>
    
    <div class="rate-info">
        <h3>Cost Rates (per hour)</h3>
        <p>vCPU: \$$VCPU_RATE | RAM: \$$RAM_RATE/GB | Storage: \$$STORAGE_RATE/GB | Floating IP: \$$FLOATING_IP_RATE | Bandwidth: \$$BANDWIDTH_RATE/GB</p>
    </div>
    
    <div class="section">
        <h2>Database Server Cost Breakdown</h2>
        <table class="cost-table">
            <tr><th>Resource</th><th>Allocation</th><th>Hours</th><th>Rate</th><th>Cost</th></tr>
            <tr><td>vCPU</td><td>$(echo $db_details | cut -d'|' -f1) cores</td><td>$db_hours</td><td>\$$VCPU_RATE/hour</td><td>\$$(printf "%.4f" $db_vcpu_cost)</td></tr>
            <tr><td>RAM</td><td>$(echo $db_details | cut -d'|' -f2) MB</td><td>$db_hours</td><td>\$$RAM_RATE/GB/hour</td><td>\$$(printf "%.4f" $db_ram_cost)</td></tr>
            <tr><td>Storage</td><td>$(echo $db_details | cut -d'|' -f3) GB</td><td>$db_hours</td><td>\$$STORAGE_RATE/GB/hour</td><td>\$$(printf "%.4f" $db_storage_cost)</td></tr>
            <tr><td>Bandwidth</td><td>$(echo $db_costs | cut -d'|' -f6) GB</td><td>$db_hours</td><td>\$$BANDWIDTH_RATE/GB/hour</td><td>\$$(printf "%.4f" $db_bandwidth_cost)</td></tr>
            <tr class="total-row"><td colspan="4">Database Server Total</td><td>\$$(printf "%.4f" $db_total)</td></tr>
        </table>
    </div>
    
    <div class="section">
        <h2>Web Server Cost Breakdown</h2>
        <table class="cost-table">
            <tr><th>Resource</th><th>Allocation</th><th>Hours</th><th>Rate</th><th>Cost</th></tr>
            <tr><td>vCPU</td><td>$(echo $web_details | cut -d'|' -f1) cores</td><td>$web_hours</td><td>\$$VCPU_RATE/hour</td><td>\$$(printf "%.4f" $web_vcpu_cost)</td></tr>
            <tr><td>RAM</td><td>$(echo $web_details | cut -d'|' -f2) MB</td><td>$web_hours</td><td>\$$RAM_RATE/GB/hour</td><td>\$$(printf "%.4f" $web_ram_cost)</td></tr>
            <tr><td>Storage</td><td>$(echo $web_details | cut -d'|' -f3) GB</td><td>$web_hours</td><td>\$$STORAGE_RATE/GB/hour</td><td>\$$(printf "%.4f" $web_storage_cost)</td></tr>
            <tr><td>Bandwidth</td><td>$(echo $web_costs | cut -d'|' -f6) GB</td><td>$web_hours</td><td>\$$BANDWIDTH_RATE/GB/hour</td><td>\$$(printf "%.4f" $web_bandwidth_cost)</td></tr>
            <tr class="total-row"><td colspan="4">Web Server Total</td><td>\$$(printf "%.4f" $web_total)</td></tr>
        </table>
    </div>
    
    <div class="section">
        <h2>Network Costs</h2>
        <table class="cost-table">
            <tr><th>Service</th><th>Details</th><th>Hours</th><th>Rate</th><th>Cost</th></tr>
            <tr><td>Floating IP</td><td>$FLOATING_IP</td><td>$web_hours</td><td>\$$FLOATING_IP_RATE/hour</td><td>\$$(printf "%.4f" $floating_ip_cost)</td></tr>
        </table>
    </div>
    
    <div class="section">
        <h2>Cost Summary</h2>
        <table class="cost-table">
            <tr><th>Component</th><th>Cost</th></tr>
            <tr><td>Database Server</td><td>\$$(printf "%.4f" $db_total)</td></tr>
            <tr><td>Web Server</td><td>\$$(printf "%.4f" $web_total)</td></tr>
            <tr><td>Floating IP</td><td>\$$(printf "%.4f" $floating_ip_cost)</td></tr>
            <tr class="grand-total"><td>GRAND TOTAL</td><td>\$$(printf "%.4f" $grand_total)</td></tr>
        </table>
    </div>
    
    <div class="section">
        <h2>Resource Utilization</h2>
        <p>This report shows the cost breakdown for your OpenStack cloud application.</p>
        <p>For cost optimization, consider:</p>
        <ul>
            <li>Right-sizing instances based on actual usage</li>
            <li>Using spot instances for non-critical workloads</li>
            <li>Implementing auto-scaling to reduce costs during low usage</li>
            <li>Monitoring bandwidth usage to optimize network costs</li>
        </ul>
    </div>
</body>
</html>
EOF
    
    echo "Cost analysis report generated: $report_file"
}

# Main cost analysis function
analyze_costs() {
    echo "=========================================="
    echo "  Enhanced OpenStack Cloud Application Cost Analysis"
    echo "  Εργασία Εξαμήνου - Χρέωση Χρήσης"
    echo "=========================================="
    echo "Analysis Date: $(date)"
    echo "Project: $PROJECT_NAME"
    echo ""
    
    # Get server details
    local db_details=$(get_server_details $DB_VM_NAME)
    local web_details=$(get_server_details $WEB_VM_NAME)
    
    # Parse details
    local db_vcpus=$(echo $db_details | cut -d'|' -f1)
    local db_ram=$(echo $db_details | cut -d'|' -f2)
    local db_disk=$(echo $db_details | cut -d'|' -f3)
    local db_created=$(echo $db_details | cut -d'|' -f4)
    local db_flavor=$(echo $db_details | cut -d'|' -f6)
    
    local web_vcpus=$(echo $web_details | cut -d'|' -f1)
    local web_ram=$(echo $web_details | cut -d'|' -f2)
    local web_disk=$(echo $web_details | cut -d'|' -f3)
    local web_created=$(echo $web_details | cut -d'|' -f4)
    local web_flavor=$(echo $web_details | cut -d'|' -f6)
    
    # Calculate hours
    local db_hours=$(calculate_hours "$db_created")
    local web_hours=$(calculate_hours "$web_created")
    
    echo "📊 RESOURCE ALLOCATION"
    echo "======================"
    echo "Database Server ($DB_VM_NAME):"
    echo "  Flavor: $db_flavor"
    echo "  vCPUs: $db_vcpus"
    echo "  RAM: $db_ram MB"
    echo "  Disk: $db_disk GB"
    echo "  Running Hours: $db_hours"
    echo ""
    
    echo "Web Server ($WEB_VM_NAME):"
    echo "  Flavor: $web_flavor"
    echo "  vCPUs: $web_vcpus"
    echo "  RAM: $web_ram MB"
    echo "  Disk: $web_disk GB"
    echo "  Running Hours: $web_hours"
    echo "  Floating IP: $FLOATING_IP"
    echo ""
    
    # Calculate costs
    echo "💰 DETAILED COST BREAKDOWN"
    echo "=========================="
    
    # Database server costs
    local db_costs=$(generate_cost_breakdown $DB_VM_NAME "$db_details" $db_hours)
    local db_vcpu_cost=$(echo $db_costs | cut -d'|' -f1)
    local db_ram_cost=$(echo $db_costs | cut -d'|' -f2)
    local db_storage_cost=$(echo $db_costs | cut -d'|' -f3)
    local db_bandwidth_cost=$(echo $db_costs | cut -d'|' -f4)
    local db_total=$(echo $db_costs | cut -d'|' -f5)
    local db_bandwidth_gb=$(echo $db_costs | cut -d'|' -f6)
    
    echo "Database Server Costs:"
    echo "  vCPU ($db_vcpus cores × $db_hours hours × \$$VCPU_RATE): \$$(printf "%.4f" $db_vcpu_cost)"
    echo "  RAM ($db_ram MB × $db_hours hours × \$$RAM_RATE/GB): \$$(printf "%.4f" $db_ram_cost)"
    echo "  Storage ($db_disk GB × $db_hours hours × \$$STORAGE_RATE/GB): \$$(printf "%.4f" $db_storage_cost)"
    echo "  Bandwidth ($(printf "%.2f" $db_bandwidth_gb) GB × \$$BANDWIDTH_RATE/GB): \$$(printf "%.4f" $db_bandwidth_cost)"
    echo "  Total: \$$(printf "%.4f" $db_total)"
    echo ""
    
    # Web server costs
    local web_costs=$(generate_cost_breakdown $WEB_VM_NAME "$web_details" $web_hours)
    local web_vcpu_cost=$(echo $web_costs | cut -d'|' -f1)
    local web_ram_cost=$(echo $web_costs | cut -d'|' -f2)
    local web_storage_cost=$(echo $web_costs | cut -d'|' -f3)
    local web_bandwidth_cost=$(echo $web_costs | cut -d'|' -f4)
    local web_total=$(echo $web_costs | cut -d'|' -f5)
    local web_bandwidth_gb=$(echo $web_costs | cut -d'|' -f6)
    
    echo "Web Server Costs:"
    echo "  vCPU ($web_vcpus cores × $web_hours hours × \$$VCPU_RATE): \$$(printf "%.4f" $web_vcpu_cost)"
    echo "  RAM ($web_ram MB × $web_hours hours × \$$RAM_RATE/GB): \$$(printf "%.4f" $web_ram_cost)"
    echo "  Storage ($web_disk GB × $web_hours hours × \$$STORAGE_RATE/GB): \$$(printf "%.4f" $web_storage_cost)"
    echo "  Bandwidth ($(printf "%.2f" $web_bandwidth_gb) GB × \$$BANDWIDTH_RATE/GB): \$$(printf "%.4f" $web_bandwidth_cost)"
    echo "  Total: \$$(printf "%.4f" $web_total)"
    echo ""
    
    # Floating IP cost
    local floating_ip_cost=$(echo "scale=4; $FLOATING_IP_RATE * $web_hours" | bc -l 2>/dev/null || echo "0")
    echo "Floating IP Cost:"
    echo "  $FLOATING_IP × $web_hours hours × \$$FLOATING_IP_RATE: \$$(printf "%.4f" $floating_ip_cost)"
    echo ""
    
    # Total cost
    local total_cost=$(echo "scale=4; $db_total + $web_total + $floating_ip_cost" | bc -l 2>/dev/null || echo "0")
    echo "💵 GRAND TOTAL: \$$(printf "%.4f" $total_cost)"
    echo ""
    
    # Resource usage statistics
    echo "📈 RESOURCE USAGE STATISTICS"
    echo "============================"
    
    # Get current resource usage
    local db_usage=$(get_resource_usage $DB_VM_IP ubuntu)
    local web_usage=$(get_resource_usage $WEB_VM_IP ubuntu)
    
    if [ "$db_usage" != "0|0|0|0|0" ]; then
        local db_cpu_usage=$(echo $db_usage | cut -d'|' -f1)
        local db_memory_usage=$(echo $db_usage | cut -d'|' -f2)
        local db_disk_usage=$(echo $db_usage | cut -d'|' -f3)
        
        echo "Database Server Current Usage:"
        echo "  CPU: ${db_cpu_usage:-0}%"
        echo "  Memory: ${db_memory_usage:-0}%"
        echo "  Disk Used: ${db_disk_usage:-0} MB"
        echo ""
    fi
    
    if [ "$web_usage" != "0|0|0|0|0" ]; then
        local web_cpu_usage=$(echo $web_usage | cut -d'|' -f1)
        local web_memory_usage=$(echo $web_usage | cut -d'|' -f2)
        local web_disk_usage=$(echo $web_usage | cut -d'|' -f3)
        
        echo "Web Server Current Usage:"
        echo "  CPU: ${web_cpu_usage:-0}%"
        echo "  Memory: ${web_memory_usage:-0}%"
        echo "  Disk Used: ${web_disk_usage:-0} MB"
        echo ""
    fi
    
    # Cost optimization recommendations
    echo "💡 COST OPTIMIZATION RECOMMENDATIONS"
    echo "===================================="
    echo "1. Monitor actual resource usage vs allocation"
    echo "2. Consider right-sizing instances based on usage patterns"
    echo "3. Implement auto-scaling for variable workloads"
    echo "4. Use spot instances for non-critical workloads"
    echo "5. Monitor and optimize bandwidth usage"
    echo "6. Consider reserved instances for predictable workloads"
    echo ""
    
    # Generate HTML report
    echo "📄 Generating detailed cost report..."
    generate_cost_report
    
    # Save cost data to file
    local cost_data_file="logs/cost-analysis/cost_data_$(date +%Y%m%d_%H%M%S).json"
    cat > "$cost_data_file" << EOF
{
    "analysis_date": "$(date -Iseconds)",
    "project": "$PROJECT_NAME",
    "cost_rates": {
        "vcpu_per_hour": $VCPU_RATE,
        "ram_per_gb_per_hour": $RAM_RATE,
        "storage_per_gb_per_hour": $STORAGE_RATE,
        "floating_ip_per_hour": $FLOATING_IP_RATE,
        "bandwidth_per_gb_per_hour": $BANDWIDTH_RATE
    },
    "database_server": {
        "name": "$DB_VM_NAME",
        "flavor": "$db_flavor",
        "vcpus": $db_vcpus,
        "ram_mb": $db_ram,
        "disk_gb": $db_disk,
        "running_hours": $db_hours,
        "costs": {
            "vcpu": $db_vcpu_cost,
            "ram": $db_ram_cost,
            "storage": $db_storage_cost,
            "bandwidth": $db_bandwidth_cost,
            "total": $db_total
        },
        "bandwidth_gb": $db_bandwidth_gb
    },
    "web_server": {
        "name": "$WEB_VM_NAME",
        "flavor": "$web_flavor",
        "vcpus": $web_vcpus,
        "ram_mb": $web_ram,
        "disk_gb": $web_disk,
        "running_hours": $web_hours,
        "floating_ip": "$FLOATING_IP",
        "costs": {
            "vcpu": $web_vcpu_cost,
            "ram": $web_ram_cost,
            "storage": $web_storage_cost,
            "bandwidth": $web_bandwidth_cost,
            "total": $web_total
        },
        "bandwidth_gb": $web_bandwidth_gb
    },
    "network_costs": {
        "floating_ip": $floating_ip_cost
    },
    "total_cost": $total_cost
}
EOF
    
    echo "Cost data saved to: $cost_data_file"
    echo ""
    echo "✅ Cost analysis completed successfully!"
    echo "📊 Reports saved to logs/cost-analysis/"
}

# Check if servers exist
if ! openstack server show $DB_VM_NAME > /dev/null 2>&1; then
    error "Database server $DB_VM_NAME not found. Please run deploy.sh first."
    exit 1
fi

if ! openstack server show $WEB_VM_NAME > /dev/null 2>&1; then
    error "Web server $WEB_VM_NAME not found. Please run deploy.sh first."
    exit 1
fi

# Start cost analysis
log "Starting enhanced cost analysis with detailed chargeback..."
analyze_costs 