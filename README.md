# OpenStack Cloud Application Assignment

## Εργασία Εξαμήνου - Διαχείριση Υπολογιστικού Νέφους

### Project Overview
This project implements a two-tier cloud application (Web/API + Database) on OpenStack with automated deployment, monitoring, and cost analysis.

### Architecture

Detailed architecture diagrams are available in the `architecture/` directory:

- **Network Architecture**: `architecture/network-architecture.md` - Network topology, security groups, and connectivity
- **System Architecture**: `architecture/system-architecture.md` - Application components, technology stack, and data flow
- **Deployment Flow**: `architecture/deployment-flow.md` - Step-by-step deployment process
- **Test Cases**: `architecture/test-cases.md` - Comprehensive test cases and validation criteria

#### Quick Overview
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Floating IP   │    │   Web/API VM    │    │   Database VM   │
│   (Public)      │◄──►│   (Port 80)     │◄──►│   (Port 5432)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │                        │
                              └────────┐               │
                                       ▼               ▼
                              ┌─────────────────────────────────┐
                              │        Private Network          │
                              │      (app_net)                  │
                              └─────────────────────────────────┘
```

### Components
1. **Web/API Server**: FastAPI application with REST API
2. **Database Server**: PostgreSQL 14 database
3. **Network**: Private network with floating IP access
4. **Security**: Custom security groups for each tier
5. **Monitoring**: Resource usage tracking
6. **Automation**: Cloud-init scripts for automated deployment

### Implementation Steps

#### 1. Network & Security Setup ✅
- Project: `cloud_app`
- Network: `app_net`


#### 2. Database Server Setup
- VM with PostgreSQL 14
- Cloud-init automation
- Security group for port 5432

#### 3. Web/API Server Setup
- VM with FastAPI application
- Cloud-init automation
- Security group for port 80

#### 4. Floating IP Configuration
- Public access to web server
- SSH tunnel to database

#### 5. Monitoring & Cost Analysis
- Resource usage tracking
- Cost calculation based on usage

### Files Structure
```
cloud-openstack/
├── README.md
├── architecture/
│   ├── network-architecture.md
│   ├── system-architecture.md
│   ├── deployment-flow.md
│   └── test-cases.md
├── cloud-init/
│   ├── db-server.yaml
│   └── web-server.yaml
├── application/
│   ├── app.py
│   ├── config.py
│   ├── requirements.txt
│   └── init_db.py
├── monitoring/
│   └── monitor.sh
├── cost-analysis/
│   └── cost-analysis.sh
├── scripts/
├── screenshots/
├── logs/
│   ├── deployment.log
│   └── monitoring/
├── deploy.sh
├── cleanup.sh
└── cloud_app-openrc.sh
```

### Usage

#### 1. Deploy the Application
```bash
./deploy.sh
```
This will:
- Create security groups for web and database tiers
- Launch database server with PostgreSQL 14
- Launch web server with FastAPI application
- Allocate floating IP for public access
- Configure network connectivity between tiers

#### 2. Monitor the Application
```bash
./monitoring/monitor.sh
```
This provides real-time monitoring of:
- Server status and health
- Application connectivity
- System resource usage (CPU, Memory, Disk)
- Network connectivity
- Security group rules
- Application statistics

#### 3. Analyze Costs
```bash
./cost-analysis/cost-analysis.sh
```
This calculates:
- Resource allocation costs (vCPU, RAM, Storage)
- Floating IP costs
- Usage-based cost breakdown
- Cost optimization recommendations
- Resource utilization statistics

#### 4. Clean Up Resources
```bash
./cleanup.sh
```
This removes all created OpenStack resources:
- Virtual machines
- Floating IPs
- Security groups
- Configuration files

### Testing the Application

After deployment, you can test the application:

#### 1. Access the Web Interface
```bash
# Get the floating IP from the deployment output
curl http://<FLOATING_IP>
```

#### 2. Test API Endpoints
```bash
# Health check
curl http://<FLOATING_IP>/health

# Get users
curl http://<FLOATING_IP>/api/users

# Get posts
curl http://<FLOATING_IP>/api/posts

# Get system stats
curl http://<FLOATING_IP>/api/stats
```

#### 3. Access API Documentation
```bash
# Open in browser
http://<FLOATING_IP>/docs
```

#### 4. SSH Access
```bash
# SSH to web server
ssh ubuntu@<FLOATING_IP>

# SSH tunnel to database (from web server)
ssh -L 5432:<DB_IP>:5432 ubuntu@<FLOATING_IP>
```

### Requirements
- OpenStack DevStack environment
- Ubuntu base image
- Python 3.8+
- PostgreSQL 14
- OpenStack RC file (`cloud_app-openrc.sh`) downloaded from the OpenStack dashboard 