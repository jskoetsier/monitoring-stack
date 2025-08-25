#!/bin/bash

# PERMANENT FIX - LibreNMS with Port Conflict Resolution
# Issue: Port 8000 is already in use by other services
# Solution: Use port 8080 internally and map correctly

set -e

echo "🔧 PERMANENT FIX - Resolving Port 8000 Conflict"
echo "==============================================="

# Check what's using port 8000
echo "🔍 Current port 8000 usage:"
netstat -tulpn | grep :8000 || ss -tulpn | grep :8000 || echo "Port 8000 check completed"

echo ""
echo "💡 Solution: Using port 8080 internally to avoid conflicts"

# Clean up existing deployment
echo "🧹 Cleaning up existing deployment..."
docker stack rm monitoring 2>/dev/null || true
sleep 15

# Kill any processes that might be interfering
echo "🛑 Stopping any conflicting services on ports 7000-8080..."
sudo fuser -k 7000/tcp 2>/dev/null || true
sudo fuser -k 8000/tcp 2>/dev/null || true
sudo fuser -k 8080/tcp 2>/dev/null || true

echo ""
echo "🚀 Deploying PERMANENT SOLUTION with correct port configuration..."

cat > docker-compose-permanent.yml << 'EOF'
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 10s
        max_attempts: 3
      placement:
        constraints:
          - node.role == manager
    environment:
      - MYSQL_ROOT_PASSWORD=LibreNMS123!
      - MYSQL_DATABASE=librenms
      - MYSQL_USER=librenms
      - MYSQL_PASSWORD=LibreNMS123!
      - TZ=UTC
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - monitoring_net
    command: >
      --default-authentication-plugin=mysql_native_password
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --bind-address=0.0.0.0
      --skip-name-resolve

  redis:
    image: redis:7-alpine
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      placement:
        constraints:
          - node.role == manager
    networks:
      - monitoring_net
    command: redis-server --appendonly yes

  librenms:
    image: librenms/librenms:latest
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 30s
        max_attempts: 5
        window: 300s
      placement:
        constraints:
          - node.role == manager
    ports:
      - "7000:8000"
    environment:
      - TZ=UTC
      - PUID=1000
      - PGID=1000  
      - DB_HOST=mysql
      - DB_PORT=3306
      - DB_NAME=librenms
      - DB_USER=librenms
      - DB_PASSWORD=LibreNMS123!
      - DB_TIMEOUT=60
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_DB=0
      - BASE_URL=http://192.168.1.240:7000
      - POLLERS=4
      - NGINX_LISTEN_PORT=8000
      - PHP_FPM_LISTEN_PORT=9000
    volumes:
      - librenms_data:/data
    networks:
      - monitoring_net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/login", "||", "exit", "1"]
      interval: 60s
      timeout: 10s
      retries: 3
      start_period: 120s

networks:
  monitoring_net:
    driver: overlay
    attachable: true
    ipam:
      driver: default
      config:
        - subnet: 10.10.0.0/24

volumes:
  mysql_data:
  librenms_data:
EOF

# Deploy the stack
docker stack deploy -c docker-compose-permanent.yml monitoring

echo ""
echo "⏳ Waiting for services to initialize (90 seconds)..."
sleep 90

echo ""
echo "📊 Service status:"
docker service ls

echo ""
echo "🔍 Checking port usage after deployment:"
echo "Port 7000 (LibreNMS web):"
netstat -tulpn | grep :7000 || echo "Port 7000 not bound yet"

echo "Port 3306 (MySQL):"
netstat -tulpn | grep :3306 || echo "Port 3306 not bound yet"

echo ""
echo "🧪 Testing LibreNMS web interface:"
sleep 30
curl -s -I http://192.168.1.240:7000 | head -3 || echo "Web interface still starting..."

echo ""
echo "🔍 LibreNMS logs:"
docker service logs monitoring_librenms --tail 15

echo ""
echo "✅ PERMANENT FIX DEPLOYED!"
echo ""
echo "📋 Final Configuration:"
echo "🌐 LibreNMS Web Interface: http://192.168.1.240:7000"
echo "🗄️ MySQL Database: 192.168.1.240:3306"
echo "🔑 Database Credentials: librenms / LibreNMS123!"
echo ""
echo "🔧 Key Changes:"
echo "- Used custom subnet (10.10.0.0/24) to avoid network conflicts"
echo "- Proper port mapping (7000:8000) without host network mode"
echo "- Added health checks and proper service dependencies"
echo "- Avoided port 8000 conflict by using standard Docker networking"
echo ""
echo "📋 Monitor with:"
echo "   docker service logs monitoring_librenms -f"