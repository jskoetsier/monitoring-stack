#!/bin/bash

# Fix LibreNMS Network Connectivity Issue
# The issue: LibreNMS can ping MySQL but can't connect to port 3306

set -e

echo "🔧 FIXING LibreNMS Network Connectivity"
echo "======================================="

echo "Issue identified: LibreNMS can ping MySQL but can't connect to port 3306"
echo "Solution: Fix MySQL network binding and add proper healthchecks"

# Clean up existing deployment
echo "🧹 Cleaning up existing deployment..."
docker stack rm monitoring 2>/dev/null || true
sleep 15

echo "🚀 Deploying FIXED configuration with proper MySQL network binding..."

cat > docker-compose-network-fixed.yml << 'EOF'
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
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "librenms", "-pLibreNMS123!"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    command: >
      --default-authentication-plugin=mysql_native_password
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --bind-address=0.0.0.0
      --skip-name-resolve
      --port=3306
      --socket=/var/run/mysqld/mysqld.sock
      --datadir=/var/lib/mysql
      --secure-file-priv=/var/lib/mysql-files

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
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
    command: redis-server --appendonly yes

  librenms:
    image: librenms/librenms:latest
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 60s
        max_attempts: 8
        window: 600s
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
      - DB_TIMEOUT=120
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_DB=0
      - BASE_URL=http://192.168.1.240:7000
      - POLLERS=4
      - MEMORY_LIMIT=1024M
      - MAX_EXECUTION_TIME=300
    volumes:
      - librenms_data:/data
    networks:
      - monitoring_net
    depends_on:
      - mysql
      - redis
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/login", "||", "exit", "1"]
      interval: 60s
      timeout: 30s
      retries: 5
      start_period: 300s

networks:
  monitoring_net:
    driver: overlay
    attachable: true
    driver_opts:
      encrypted: "false"

volumes:
  mysql_data:
  librenms_data:
EOF

# Deploy the stack
docker stack deploy -c docker-compose-network-fixed.yml monitoring

echo ""
echo "⏳ Waiting for MySQL to be fully ready (90 seconds)..."
sleep 90

echo ""
echo "🧪 Testing MySQL service health..."
for i in {1..10}; do
    if docker service ps monitoring_mysql --format "{{.CurrentState}}" | grep -q "Running"; then
        echo "✅ MySQL service is running"
        break
    fi
    echo "Waiting for MySQL... attempt $i/10"
    sleep 10
done

echo ""
echo "🔍 Testing network connectivity from LibreNMS to MySQL..."
sleep 60  # Give LibreNMS time to start

CONTAINER_ID=$(docker ps --filter 'name=monitoring_librenms' --format '{{.ID}}' | head -1)
if [ -n "$CONTAINER_ID" ]; then
    echo "Testing from LibreNMS container: $CONTAINER_ID"
    
    echo "1. Testing ping to MySQL:"
    docker exec $CONTAINER_ID ping -c 2 mysql || echo "Ping failed"
    
    echo "2. Testing port connectivity:"
    docker exec $CONTAINER_ID nc -zv mysql 3306 || echo "Port test failed"
    
    echo "3. Testing MySQL client connection:"
    docker exec $CONTAINER_ID mysql -h mysql -u librenms -pLibreNMS123! -e "SELECT 'Connection successful!' as result;" 2>/dev/null || echo "MySQL connection failed"
    
else
    echo "No LibreNMS container found yet"
fi

echo ""
echo "📊 Service status:"
docker service ls

echo ""
echo "🔍 LibreNMS logs:"
docker service logs monitoring_librenms --tail 15

echo ""
echo "✅ NETWORK FIX DEPLOYED!"
echo ""
echo "📋 Next steps:"
echo "1. Monitor LibreNMS logs: docker service logs monitoring_librenms -f"
echo "2. Check web interface: http://192.168.1.240:7000"
echo "3. If still issues, run: docker service ps monitoring_librenms --no-trunc"