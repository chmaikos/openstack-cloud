# OpenStack Cloud Application - Test Cases

## Test Cases Overview

This document outlines comprehensive test cases for the OpenStack cloud application, including expected results and validation criteria.

## 1. Infrastructure Tests

### 1.1 OpenStack Environment
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| OpenStack Access | `openstack token issue` | Valid token returned | ✅ |
| Network Availability | `openstack network list` | `app_net` network exists | ✅ |
| Image Availability | `openstack image list` | `ubuntu-base` image exists | ✅ |
| Flavor Availability | `openstack flavor list` | `m1.small` flavor exists | ✅ |

### 1.2 Security Groups
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| Web Security Group | `openstack security group show web-security-group` | Ports 80, 8000, 22, ICMP allowed | ✅ |
| DB Security Group | `openstack security group show db-security-group` | Port 5432 allowed from 192.168.128.0/24 | ✅ |

## 2. Deployment Tests

### 2.1 VM Creation
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| Database VM Status | `openstack server show db-server` | Status: ACTIVE | ✅ |
| Web VM Status | `openstack server show web-server` | Status: ACTIVE | ✅ |
| Floating IP Assignment | `openstack server show web-server` | Floating IP assigned | ✅ |

### 2.2 Cloud-init Execution
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| DB Cloud-init | SSH to db-server | PostgreSQL running on port 5432 | ✅ |
| Web Cloud-init | SSH to web-server | FastAPI running on port 8000 | ✅ |
| Nginx Status | `systemctl status nginx` | Active (running) | ✅ |

## 3. Application Tests

### 3.1 Health Check Endpoint
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| Health Status | `curl http://<FLOATING_IP>/health` | Status: "healthy" | ✅ |
| Database Status | `curl http://<FLOATING_IP>/health` | Database: "OK" | ❌ (ERROR) |
| System Metrics | `curl http://<FLOATING_IP>/health` | CPU, Memory, Disk metrics | ✅ |
| Response Time | `time curl http://<FLOATING_IP>/health` | < 2 seconds | ✅ |

### 3.2 API Endpoints

#### 3.2.1 Users API
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| Get Users | `curl http://<FLOATING_IP>/api/users` | JSON array of users | ✅ |
| Users Schema | `curl http://<FLOATING_IP>/api/users` | id, username, email, created_at fields | ✅ |
| Empty Response | `curl http://<FLOATING_IP>/api/users` | `[]` if no users | ✅ |

#### 3.2.2 Posts API
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| Get Posts | `curl http://<FLOATING_IP>/api/posts` | JSON array of posts | ✅ |
| Posts Schema | `curl http://<FLOATING_IP>/api/posts` | id, user_id, title, content, created_at fields | ✅ |
| Create Post | `curl -X POST http://<FLOATING_IP>/api/posts -H "Content-Type: application/json" -d '{"user_id": 1, "title": "Test", "content": "Test content"}'` | Success response with post ID | ✅ |

#### 3.2.3 System Stats API
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| Get Stats | `curl http://<FLOATING_IP>/api/stats` | System statistics JSON | ✅ |
| Stats Schema | `curl http://<FLOATING_IP>/api/stats` | CPU, Memory, Disk, Network metrics | ✅ |

### 3.3 Documentation
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| API Docs | `curl http://<FLOATING_IP>/docs` | Swagger UI HTML | ✅ |
| OpenAPI JSON | `curl http://<FLOATING_IP>/openapi.json` | OpenAPI specification | ✅ |

## 4. Database Tests

### 4.1 Connection Tests
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| Direct DB Connection | `ssh ubuntu@<FLOATING_IP> "psql -h <DB_IP> -U cloudapp -d cloudapp -c 'SELECT 1'"` | Connection successful | ✅ |
| Application DB Access | Health endpoint | Database: "OK" | ❌ (ERROR) |
| Database Schema | `ssh ubuntu@<FLOATING_IP> "psql -h <DB_IP> -U cloudapp -d cloudapp -c '\dt'"` | users, posts tables exist | ✅ |

### 4.2 Data Integrity
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| Sample Data | `curl http://<FLOATING_IP>/api/users` | Sample users returned | ✅ |
| Foreign Key Constraints | Create post with invalid user_id | Error response | ✅ |

## 5. Network Tests

### 5.1 Connectivity
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| External Access | `curl http://<FLOATING_IP>` | HTML response | ✅ |
| Internal Communication | SSH to web-server, ping db-server | Successful ping | ✅ |
| Port Accessibility | `nmap <FLOATING_IP>` | Ports 80, 8000 open | ✅ |

### 5.2 Security
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| Database Port Blocked | `telnet <FLOATING_IP> 5432` | Connection refused | ✅ |
| SSH Access | `ssh ubuntu@<FLOATING_IP>` | Successful login | ✅ |

## 6. Performance Tests

### 6.1 Response Times
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| Homepage Load | `time curl http://<FLOATING_IP>/` | < 3 seconds | ✅ |
| API Response | `time curl http://<FLOATING_IP>/api/users` | < 2 seconds | ✅ |
| Health Check | `time curl http://<FLOATING_IP>/health` | < 1 second | ✅ |

### 6.2 Load Testing
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| Concurrent Requests | `ab -n 100 -c 10 http://<FLOATING_IP>/health` | All requests successful | ✅ |
| Database Queries | Multiple simultaneous API calls | Consistent response times | ✅ |

## 7. Monitoring Tests

### 7.1 Resource Monitoring
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| CPU Usage | `./monitoring/monitor.sh` | CPU metrics displayed | ✅ |
| Memory Usage | `./monitoring/monitor.sh` | Memory metrics displayed | ✅ |
| Disk Usage | `./monitoring/monitor.sh` | Disk metrics displayed | ✅ |
| Network I/O | `./monitoring/monitor.sh` | Network metrics displayed | ✅ |

### 7.2 Cost Analysis
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| Cost Calculation | `./cost-analysis/cost-analysis.sh` | Cost breakdown generated | ✅ |
| Resource Usage | `./cost-analysis/cost-analysis.sh` | Usage statistics displayed | ✅ |

## 8. Error Handling Tests

### 8.1 Application Errors
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| Invalid Endpoint | `curl http://<FLOATING_IP>/invalid` | 404 Not Found | ✅ |
| Database Down | Stop PostgreSQL service | Health check shows database error | ✅ |
| Invalid JSON | `curl -X POST http://<FLOATING_IP>/api/posts -d 'invalid'` | 422 Validation Error | ✅ |

### 8.2 Network Errors
| Test Case | Command | Expected Result | Status |
|-----------|---------|-----------------|--------|
| Server Unreachable | `curl http://invalid-ip/` | Connection timeout | ✅ |
| Port Closed | `telnet <FLOATING_IP> 9999` | Connection refused | ✅ |

## Test Execution Summary

### Automated Tests
```bash
#!/bin/bash
# Test script for automated validation

FLOATING_IP=$(grep FLOATING_IP config.env | cut -d'=' -f2)

echo "Running automated tests..."

# Health check
echo "1. Testing health endpoint..."
curl -s "http://$FLOATING_IP/health" | jq '.status' | grep -q "healthy" && echo "✅ Health check passed" || echo "❌ Health check failed"

# API endpoints
echo "2. Testing API endpoints..."
curl -s "http://$FLOATING_IP/api/users" | jq '.' > /dev/null && echo "✅ Users API passed" || echo "❌ Users API failed"
curl -s "http://$FLOATING_IP/api/posts" | jq '.' > /dev/null && echo "✅ Posts API passed" || echo "❌ Posts API failed"

# Documentation
echo "3. Testing documentation..."
curl -s "http://$FLOATING_IP/docs" | grep -q "Swagger" && echo "✅ Documentation passed" || echo "❌ Documentation failed"

echo "Test execution completed!"
```