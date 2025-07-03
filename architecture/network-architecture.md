# OpenStack Cloud Application - Network Architecture

## Network Topology Diagram

```mermaid
graph TB
    subgraph "Public Network (Internet)"
        INTERNET[🌐 Internet]
    end
    
    subgraph "OpenStack Public Network"
        PUBLIC_NET[Public Network<br/>External Gateway]
    end
    
    subgraph "OpenStack Private Network (app_net)"
        subgraph "Security Groups"
            WEB_SG[Web Security Group<br/>Ports: 80, 8000, 22, ICMP<br/>Source: 0.0.0.0/0]
            DB_SG[Database Security Group<br/>Ports: 5432, 22, ICMP<br/>Source: 192.168.128.0/24]
        end
        
        subgraph "Virtual Machines"
            WEB_VM[🖥️ Web Server VM<br/>Hostname: web-server<br/>IP: 192.168.128.x<br/>OS: Ubuntu<br/>Services: FastAPI, Nginx]
            DB_VM[💾 Database Server VM<br/>Hostname: db-server<br/>IP: 192.168.128.x<br/>OS: Ubuntu<br/>Service: PostgreSQL 14]
        end
        
        subgraph "Application Stack"
            FASTAPI[FastAPI Application<br/>Port: 8000]
            NGINX[Nginx Proxy<br/>Port: 80]
            POSTGRES[PostgreSQL Database<br/>Port: 5432]
        end
    end
    
    subgraph "Floating IP"
        FLOATING_IP[🌍 Floating IP<br/>Public Access]
    end
    
    %% Connections
    INTERNET --> PUBLIC_NET
    PUBLIC_NET --> FLOATING_IP
    FLOATING_IP --> WEB_SG
    WEB_SG --> WEB_VM
    WEB_VM --> DB_SG
    DB_SG --> DB_VM
    
    %% Internal connections
    WEB_VM --> FASTAPI
    FASTAPI --> NGINX
    WEB_VM --> POSTGRES
    
    %% Styling
    classDef public fill:#e1f5fe
    classDef private fill:#f3e5f5
    classDef vm fill:#e8f5e8
    classDef service fill:#fff3e0
    
    class INTERNET,PUBLIC_NET,FLOATING_IP public
    class WEB_SG,DB_SG private
    class WEB_VM,DB_VM vm
    class FASTAPI,NGINX,POSTGRES service
```

## Security Groups Configuration

### Web Server Security Group
- **Name:** `web-security-group`
- **Description:** Security group for web server
- **Rules:**
  - TCP Port 80 (HTTP) - Source: 0.0.0.0/0
  - TCP Port 8000 (FastAPI) - Source: 0.0.0.0/0
  - TCP Port 22 (SSH) - Source: 0.0.0.0/0
  - ICMP (Ping) - Source: 0.0.0.0/0

### Database Server Security Group
- **Name:** `db-security-group`
- **Description:** Security group for database server
- **Rules:**
  - TCP Port 5432 (PostgreSQL) - Source: 192.168.128.0/24
  - TCP Port 22 (SSH) - Source: 192.168.128.0/24
  - ICMP (Ping) - Source: 192.168.128.0/24

## Network Flow

1. **External Access:** Internet → Public Network → Floating IP → Web Server
2. **Internal Communication:** Web Server → Database Server (via private network)
3. **Load Balancing:** Nginx (Port 80) → FastAPI (Port 8000)
4. **Database Access:** FastAPI → PostgreSQL (Port 5432)

## IP Addressing Scheme

- **Public Network:** External gateway provided by OpenStack
- **Private Network:** 192.168.128.0/24
- **Web Server:** 192.168.128.x (dynamically assigned)
- **Database Server:** 192.168.128.x (dynamically assigned)
- **Floating IP:** Public IP (dynamically allocated) 