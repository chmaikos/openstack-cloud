#!/bin/bash

# OpenStack Metrics Monitoring Script
# Focused on collecting OpenStack metrics using openstack commands

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Create logs directory
mkdir -p logs/monitoring

# Function to get server ID
get_server_id() {
    local server_name=$1
    openstack server show $server_name -f value -c id 2>/dev/null
}

# Function to get available metrics for a resource
get_available_metrics() {
    local resource_id=$1
    
    if command -v openstack >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        # Get actual available metrics for this resource using JSON format
        local metrics=$(openstack metric list --format json 2>/dev/null | jq -r ".[] | select(.resource_id == \"$resource_id\") | .name" 2>/dev/null | sort | uniq)
        if [ -n "$metrics" ]; then
            echo "Resource found: $resource_id"
            echo "Available metrics:"
            echo "$metrics" | while read metric; do
                if [ -n "$metric" ]; then
                    echo "  - $metric"
                fi
            done
        else
            echo "No metrics available for resource $resource_id"
        fi
    elif command -v openstack >/dev/null 2>&1; then
        # Fallback without jq
        echo "Resource found: $resource_id"
        echo "Available metrics: cpu, memory, disk.root.size, disk.ephemeral.size, vcpus, power.state"
    else
        echo "OpenStack CLI not available"
    fi
}

# Function to get metric data using openstack commands
get_metric_data() {
    local resource_id=$1
    local metric_name=$2
    local limit=${3:-10}
    
    if command -v openstack >/dev/null 2>&1; then
        # Use openstack metric commands
        local result=$(openstack metric measures show --resource-id $resource_id $metric_name 2>/dev/null)
        if [ -n "$result" ]; then
            echo "$result"
        else
            echo "No $metric_name data available for resource $resource_id"
        fi
    else
        echo "OpenStack CLI not available"
    fi
}

# Function to format CPU usage in a readable way
format_cpu_usage() {
    local cpu_ns=$1
    if [ -n "$cpu_ns" ] && [ "$cpu_ns" != "N/A" ]; then
        # Convert nanoseconds to percentage (assuming 1 CPU core = 1 second = 1,000,000,000 nanoseconds)
        # The CPU metric is cumulative, so we need to calculate the rate
        local cpu_percent=$(echo "scale=2; $cpu_ns / 1000000000" | bc -l 2>/dev/null || echo "0")
        echo "${cpu_percent} CPU-seconds"
    else
        echo "N/A"
    fi
}

# Function to format memory usage in MB/GB
format_memory_usage() {
    local memory_mb=$1
    if [ -n "$memory_mb" ] && [ "$memory_mb" != "N/A" ]; then
        local comparison=$(echo "$memory_mb > 1024" | bc -l 2>/dev/null || echo "0")
        if [ "$comparison" = "1" ]; then
            local memory_gb=$(echo "scale=2; $memory_mb / 1024" | bc -l 2>/dev/null || echo "0")
            echo "${memory_gb} GB"
        else
            echo "${memory_mb} MB"
        fi
    else
        echo "N/A"
    fi
}

# Function to format disk size in GB
format_disk_size() {
    local disk_gb=$1
    echo "${disk_gb} GB"
}

# Function to get latest metric value
get_latest_metric_value() {
    local resource_id=$1
    local metric_name=$2
    
    if command -v openstack >/dev/null 2>&1; then
        local result=$(openstack metric measures show --resource-id $resource_id $metric_name --format value 2>/dev/null | tail -1 | awk '{print $3}')
        if [ -n "$result" ]; then
            echo "$result"
        else
            echo "N/A"
        fi
    else
        echo "N/A"
    fi
}

# Function to get metric trend (increasing, decreasing, stable)
get_metric_trend() {
    local resource_id=$1
    local metric_name=$2
    
    if command -v openstack >/dev/null 2>&1; then
        local values=$(openstack metric measures show --resource-id $resource_id $metric_name --format value 2>/dev/null | tail -3 | awk '{print $3}')
        if [ -n "$values" ]; then
            local val1=$(echo "$values" | head -1)
            local val3=$(echo "$values" | tail -1)
            if [ -n "$val1" ] && [ -n "$val3" ]; then
                local diff=$(echo "$val3 - $val1" | bc -l 2>/dev/null || echo "0")
                local diff_positive=$(echo "$diff > 0" | bc -l 2>/dev/null || echo "0")
                local diff_negative=$(echo "$diff < 0" | bc -l 2>/dev/null || echo "0")
                if [ "$diff_positive" = "1" ]; then
                    echo "↗️  Increasing"
                elif [ "$diff_negative" = "1" ]; then
                    echo "↘️  Decreasing"
                else
                    echo "➡️  Stable"
                fi
            else
                echo "➡️  Stable"
            fi
        else
            echo "➡️  Stable"
        fi
    else
        echo "➡️  Stable"
    fi
}

# Function to get CPU metrics
get_cpu_metrics() {
    local resource_id=$1
    local limit=${2:-5}
    
    local cpu_value=$(get_latest_metric_value $resource_id "cpu")
    local cpu_trend=$(get_metric_trend $resource_id "cpu")
    
    if [ "$cpu_value" != "N/A" ]; then
        local cpu_formatted=$(format_cpu_usage $cpu_value)
        echo "🖥️  CPU Usage: ${cpu_formatted} | Trend: ${cpu_trend}"
    else
        echo "🖥️  CPU Usage: No data available"
    fi
}

# Function to get memory metrics
get_memory_metrics() {
    local resource_id=$1
    local limit=${2:-5}
    
    local memory_value=$(get_latest_metric_value $resource_id "memory")
    local memory_usage_value=$(get_latest_metric_value $resource_id "memory.usage")
    local memory_resident_value=$(get_latest_metric_value $resource_id "memory.resident")
    local memory_trend=$(get_metric_trend $resource_id "memory")
    
    echo "🧠 Memory Status:"
    if [ "$memory_value" != "N/A" ]; then
        local memory_formatted=$(format_memory_usage $memory_value)
        echo "   📊 Total: ${memory_formatted} | Trend: ${memory_trend}"
    fi
    
    if [ "$memory_usage_value" != "N/A" ]; then
        local usage_formatted=$(format_memory_usage $memory_usage_value)
        echo "   💾 Used: ${usage_formatted}"
    fi
    
    if [ "$memory_resident_value" != "N/A" ]; then
        local resident_formatted=$(format_memory_usage $memory_resident_value)
        echo "   🏠 Resident: ${resident_formatted}"
    fi
    
    # Check swap usage
    local swap_in_value=$(get_latest_metric_value $resource_id "memory.swap.in")
    local swap_out_value=$(get_latest_metric_value $resource_id "memory.swap.out")
    
    if [ "$swap_in_value" != "N/A" ] || [ "$swap_out_value" != "N/A" ]; then
        echo "   💿 Swap Activity:"
        if [ "$swap_in_value" != "N/A" ]; then
            local swap_in_formatted=$(format_memory_usage $swap_in_value)
            echo "      ↙️  Swap In: ${swap_in_formatted}"
        fi
        if [ "$swap_out_value" != "N/A" ]; then
            local swap_out_formatted=$(format_memory_usage $swap_out_value)
            echo "      ↗️  Swap Out: ${swap_out_formatted}"
        fi
    fi
}

# Function to get disk metrics
get_disk_metrics() {
    local resource_id=$1
    local limit=${2:-5}
    
    local root_size_value=$(get_latest_metric_value $resource_id "disk.root.size")
    local ephemeral_size_value=$(get_latest_metric_value $resource_id "disk.ephemeral.size")
    
    echo "💾 Disk Storage:"
    if [ "$root_size_value" != "N/A" ]; then
        local root_formatted=$(format_disk_size $root_size_value)
        echo "   🗂️  Root Disk: ${root_formatted}"
    fi
    
    if [ "$ephemeral_size_value" != "N/A" ]; then
        local ephemeral_formatted=$(format_disk_size $ephemeral_size_value)
        echo "   📁 Ephemeral Disk: ${ephemeral_formatted}"
    fi
}

# Function to get network metrics
get_network_metrics() {
    local resource_id=$1
    local limit=${2:-5}
    
    echo "🌐 Network: No real-time network metrics available"
    echo "   ℹ️  Network metrics are typically collected by the hypervisor"
}

# Function to get instance metrics
get_instance_metrics() {
    local resource_id=$1
    local limit=${2:-5}
    
    local vcpus_value=$(get_latest_metric_value $resource_id "vcpus")
    local power_state_value=$(get_latest_metric_value $resource_id "power.state")
    local boot_time_value=$(get_latest_metric_value $resource_id "compute.instance.booting.time")
    
    echo "🖥️  Instance Details:"
    if [ "$vcpus_value" != "N/A" ]; then
        echo "   🔢 vCPUs: ${vcpus_value}"
    fi
    
    if [ "$power_state_value" != "N/A" ]; then
        local power_icon="⚡"
        case $power_state_value in
            1) power_icon="🟢"; power_text="Running" ;;
            0) power_icon="🔴"; power_text="Stopped" ;;
            *) power_icon="⚡"; power_text="Unknown" ;;
        esac
        echo "   ${power_icon} Power State: ${power_text}"
    fi
    
    if [ "$boot_time_value" != "N/A" ]; then
        echo "   ⏱️  Boot Time: ${boot_time_value} seconds"
    fi
}

# Function to get all available metrics for a server
get_all_server_metrics() {
    local server_name=$1
    local limit=${2:-5}
    
    local server_id=$(get_server_id $server_name)
    
    if [ -z "$server_id" ]; then
        error "Could not get server ID for $server_name"
        return 1
    fi
    
    # Get server status
    local server_status=$(openstack server show $server_name -f value -c status 2>/dev/null || echo "Unknown")
    local server_ip=$(openstack server show $server_name -f value -c addresses 2>/dev/null | grep -oE '192\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "N/A")
    
    echo "🖥️  ${server_name}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 ID: ${server_id}"
    echo "🔗 IP: ${server_ip}"
    echo "📊 Status: ${server_status}"
    echo ""
    
    # Get specific metrics
    get_cpu_metrics $server_id $limit
    echo ""
    
    get_memory_metrics $server_id $limit
    echo ""
    
    get_disk_metrics $server_id $limit
    echo ""
    
    get_network_metrics $server_id $limit
    echo ""
    
    get_instance_metrics $server_id $limit
    echo ""
    
    # Add summary section
    echo "📈 Quick Summary:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local cpu_value=$(get_latest_metric_value $server_id "cpu")
    local memory_value=$(get_latest_metric_value $server_id "memory")
    local power_state=$(get_latest_metric_value $server_id "power.state")
    
    if [ "$cpu_value" != "N/A" ]; then
        local cpu_formatted=$(format_cpu_usage $cpu_value)
        echo "🖥️  CPU: ${cpu_formatted}"
    fi
    
    if [ "$memory_value" != "N/A" ]; then
        local memory_formatted=$(format_memory_usage $memory_value)
        echo "🧠 Memory: ${memory_formatted}"
    fi
    
    if [ "$power_state" != "N/A" ]; then
        case $power_state in
            1) echo "🟢 Status: Running" ;;
            0) echo "🔴 Status: Stopped" ;;
            *) echo "⚡ Status: Unknown" ;;
        esac
    else
        echo "⚡ Status: Unknown"
    fi
    echo ""
}

# Function to save metrics to log file
save_metrics_to_log() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local log_file="logs/monitoring/metrics_${timestamp}.log"
    
    {
        echo "=== OpenStack Metrics Report - $(date) ==="
        echo "Project: $PROJECT_NAME"
        echo ""
        
        # Get metrics for database server
        if openstack server show $DB_VM_NAME >/dev/null 2>&1; then
            echo "=== DATABASE SERVER METRICS ==="
            get_all_server_metrics $DB_VM_NAME 10
        else
            echo "Database server $DB_VM_NAME not found"
        fi
        
        echo ""
        
        # Get metrics for web server
        if openstack server show $WEB_VM_NAME >/dev/null 2>&1; then
            echo "=== WEB SERVER METRICS ==="
            get_all_server_metrics $WEB_VM_NAME 10
        else
            echo "Web server $WEB_VM_NAME not found"
        fi
        
        echo ""
        echo "=== END OF METRICS REPORT ==="
        
    } > "$log_file" 2>&1
    
    echo "Metrics saved to: $log_file"
}

# Function to display metrics in real-time
display_metrics() {
    local interval=${1:-30}
    
    while true; do
        clear
        echo "╔════════════════════════════════════════════════════════════════════════════╗"
        echo "║                    🚀 OpenStack Cloud Metrics Monitor 🚀                   ║"
        echo "╠════════════════════════════════════════════════════════════════════════════╣"
        echo "║ 📅 $(date)                                                                 ║"
        echo "║ 🏢 Project: $PROJECT_NAME                                                  ║"
        echo "║ ⏱️  Refresh: ${interval}s intervals                                        ║"
        echo "╚════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        
        # Check if servers exist
        if openstack server show $DB_VM_NAME >/dev/null 2>&1; then
            echo "🗄️  DATABASE SERVER"
            echo "══════════════════════════════════════════════════════════════════════════"
            get_all_server_metrics $DB_VM_NAME 3
        else
            warning "❌ Database server $DB_VM_NAME not found"
        fi
        
        echo ""
        
        if openstack server show $WEB_VM_NAME >/dev/null 2>&1; then
            echo "🌐 WEB SERVER"
            echo "═══════════════════════════════════════════════════════════════════════════"
            get_all_server_metrics $WEB_VM_NAME 3
        else
            warning "❌ Web server $WEB_VM_NAME not found"
        fi
        
        echo ""
        echo "╔═════════════════════════════════════════════════════════════════════════════╗"
        echo "║ 💡 Press Ctrl+C to exit • Refreshing in ${interval} seconds...              ║"
        echo "╚═════════════════════════════════════════════════════════════════════════════╝"
        sleep $interval
    done
}

# Function to get one-time metrics snapshot
get_metrics_snapshot() {
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    📊 OpenStack Metrics Snapshot 📊                          ║"
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    echo "║ 📅 $(date)                                                                   ║"
    echo "║ 🏢 Project: $PROJECT_NAME                                                    ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Check if servers exist
    if openstack server show $DB_VM_NAME >/dev/null 2>&1; then
        echo "🗄️  DATABASE SERVER"
        echo "══════════════════════════════════════════════════════════════════════════════"
        get_all_server_metrics $DB_VM_NAME 5
    else
        error "❌ Database server $DB_VM_NAME not found"
    fi
    
    echo ""
    
    if openstack server show $WEB_VM_NAME >/dev/null 2>&1; then
        echo "🌐 WEB SERVER"
        echo "══════════════════════════════════════════════════════════════════════════════"
        get_all_server_metrics $WEB_VM_NAME 5
    else
        error "❌ Web server $WEB_VM_NAME not found"
    fi
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║ 💾 Metrics saved to logs/monitoring/                                         ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    
    # Save to log file
    save_metrics_to_log
}

# Main function
main() {
    case "${1:-snapshot}" in
        "snapshot")
            log "Getting one-time metrics snapshot..."
            get_metrics_snapshot
            ;;
        "monitor")
            local interval=${2:-30}
            log "Starting continuous metrics monitoring with ${interval}s interval..."
            display_metrics $interval
            ;;
        "save")
            log "Saving metrics to log file..."
            save_metrics_to_log
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  snapshot [default] - Get one-time metrics snapshot"
            echo "  monitor [interval] - Start continuous monitoring (default: 30s)"
            echo "  save              - Save metrics to log file"
            echo "  help              - Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # Get one-time snapshot"
            echo "  $0 monitor            # Monitor with 30s refresh"
            echo "  $0 monitor 60         # Monitor with 60s refresh"
            echo "  $0 save               # Save metrics to log file"
            ;;
        *)
            error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Check if OpenStack CLI is available
if ! command -v openstack >/dev/null 2>&1; then
    error "OpenStack CLI not found. Please install openstackclient."
    exit 1
fi

# Check if we can authenticate
if ! openstack token issue >/dev/null 2>&1; then
    error "OpenStack authentication failed. Please check your credentials."
    exit 1
fi

# Run main function with all arguments
main "$@" 