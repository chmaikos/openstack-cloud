# OpenStack Cloud Application - Deployment Flow

## Deployment Process Diagram

```mermaid
flowchart TD
    START(["Start Deployment"]) --> CHECK_ENV{"Check Environment"}
    CHECK_ENV -->|"OpenStack Ready"| CREATE_SG["Create Security Groups"]
    CHECK_ENV -->|"Not Ready"| ERROR_ENV["❌ Environment Error"]
    
    CREATE_SG --> CREATE_DB["Launch Database VM"]
    CREATE_DB --> WAIT_DB["Wait for DB VM Ready"]
    WAIT_DB --> CLOUD_INIT_DB["Execute DB Cloud-init"]
    
    CLOUD_INIT_DB --> INSTALL_PG["Install PostgreSQL"]
    INSTALL_PG --> CONFIG_PG["Configure PostgreSQL"]
    CONFIG_PG --> INIT_DB["Initialize Database Schema"]
    INIT_DB --> DB_READY{"Database Ready?"}
    
    DB_READY -->|"Yes"| CREATE_WEB["Launch Web VM"]
    DB_READY -->|"No"| ERROR_DB["❌ Database Setup Failed"]
    
    CREATE_WEB --> WAIT_WEB["Wait for Web VM Ready"]
    WAIT_WEB --> CLOUD_INIT_WEB["Execute Web Cloud-init"]
    
    CLOUD_INIT_WEB --> CLONE_REPO["Clone GitHub Repository"]
    CLONE_REPO --> INSTALL_DEPS["Install Python Dependencies"]
    INSTALL_DEPS --> SETUP_VENV["Setup Virtual Environment"]
    SETUP_VENV --> CONFIG_FASTAPI["Configure FastAPI"]
    CONFIG_FASTAPI --> SETUP_NGINX["Setup Nginx Proxy"]
    SETUP_NGINX --> START_SERVICES["Start Application Services"]
    
    START_SERVICES --> ALLOCATE_FIP["Allocate Floating IP"]
    ALLOCATE_FIP --> TEST_APP["Test Application Health"]
    
    TEST_APP --> APP_HEALTHY{"Application Healthy?"}
    APP_HEALTHY -->|"Yes"| SUCCESS["✅ Deployment Successful"]
    APP_HEALTHY -->|"No"| ERROR_APP["❌ Application Setup Failed"]
    
    SUCCESS --> SAVE_CONFIG["Save Configuration"]
    SAVE_CONFIG --> GENERATE_REPORT["Generate Deployment Report"]
    GENERATE_REPORT --> END(["Deployment Complete"])
    
    ERROR_ENV --> END
    ERROR_DB --> END
    ERROR_APP --> END
    
    %% Styling
    classDef success fill:#d4edda,stroke:#155724,color:#155724
    classDef error fill:#f8d7da,stroke:#721c24,color:#721c24
    classDef process fill:#d1ecf1,stroke:#0c5460,color:#0c5460
    classDef decision fill:#fff3cd,stroke:#856404,color:#856404
    
    class SUCCESS,END success
    class ERROR_ENV,ERROR_DB,ERROR_APP error
    class CREATE_SG,CREATE_DB,CREATE_WEB,CLOUD_INIT_DB,CLOUD_INIT_WEB,INSTALL_PG,CONFIG_PG,INIT_DB,CLONE_REPO,INSTALL_DEPS,SETUP_VENV,CONFIG_FASTAPI,SETUP_NGINX,START_SERVICES,ALLOCATE_FIP,TEST_APP,SAVE_CONFIG,GENERATE_REPORT process
    class CHECK_ENV,DB_READY,APP_HEALTHY decision
```

## Detailed Deployment Steps

### Phase 1: Environment Preparation
1. **Source OpenStack Credentials**
   - Load `cloud_app-openrc.sh`
   - Verify OpenStack CLI access

2. **Create Security Groups**
   - Web Security Group (ports 80, 8000, 22, ICMP)
   - Database Security Group (ports 5432, 22, ICMP)

### Phase 2: Database Server Deployment
3. **Launch Database VM**
   - Image: Ubuntu 20.04
   - Flavor: m1.small (2 vCPU, 4GB RAM)
   - Network: app_net (private)
   - Security Group: db-security-group

4. **Execute Cloud-init Script**
   - Install PostgreSQL 14
   - Configure database settings
   - Create database and user
   - Initialize schema with sample data

### Phase 3: Web Server Deployment
5. **Launch Web VM**
   - Image: Ubuntu 20.04
   - Flavor: m1.small (2 vCPU, 4GB RAM)
   - Network: app_net (private)
   - Security Group: web-security-group

6. **Execute Cloud-init Script**
   - Clone GitHub repository
   - Install Python 3.8+ and dependencies
   - Setup virtual environment
   - Configure FastAPI application
   - Setup Nginx proxy
   - Start systemd services

### Phase 4: Network Configuration
7. **Allocate Floating IP**
   - Assign public IP to web server
   - Configure routing

8. **Test Connectivity**
   - Verify database connection
   - Test application health endpoint
   - Validate API endpoints

### Phase 5: Verification & Documentation
9. **Health Checks**
   - Application status: `/health`
   - Database connectivity
   - API functionality: `/api/users`, `/api/posts`
   - Documentation: `/docs`

10. **Generate Reports**
    - Save configuration to `config.env`
    - Create deployment log
    - Document IP addresses and access details

## Deployment Timeline

| Phase | Duration | Description |
|-------|----------|-------------|
| Environment Setup | 2-3 min | Security groups, network verification |
| Database Deployment | 5-7 min | VM launch, PostgreSQL installation |
| Web Server Deployment | 8-10 min | VM launch, application setup |
| Network Configuration | 2-3 min | Floating IP allocation |
| Testing & Verification | 3-5 min | Health checks, API testing |
| **Total** | **20-28 min** | Complete deployment |

## Rollback Strategy

If deployment fails at any stage:

1. **Clean up resources** using `./cleanup.sh`
2. **Check logs** for specific error messages
3. **Verify OpenStack environment** and credentials
4. **Retry deployment** with `./deploy.sh`

## Success Criteria

- ✅ Both VMs are running and accessible
- ✅ Database server accepts connections on port 5432
- ✅ Web server responds on port 80 and 8000
- ✅ Application health endpoint returns status "healthy"
- ✅ Database connection shows "OK" in health check
- ✅ API endpoints return valid JSON responses
- ✅ Floating IP is accessible from external network 