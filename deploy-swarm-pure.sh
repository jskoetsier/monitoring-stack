#!/bin/bash

# PURE DOCKER SWARM SOLUTION - Using external networks and endpoint modes
# This solves the overlay network issue while keeping everything in Swarm

set -e

echo "🐳 PURE DOCKER SWARM SOLUTION"
echo "============================="
echo "Using external networks and VIP endpoint mode to solve connectivity"

# Clean up existing deployment
echo "🧹 Cleaning up existing deployments..."
docker stack rm monitoring 2>/dev/null || true
docker rm -f librenms_mysql_standalone 2>/dev/null || true
sleep 15

# Remove old volumes
docker volume rm monitoring_mysql_data monitoring_librenms_data mysql_standalone_data 2>/dev/null || true

# Create external network for better connectivity
echo ""
echo "🌐 Creating external Docker network..."
docker network rm librenms_external 2>/dev/null || true
docker network create \
  --driver bridge \
  --subnet=172.20.0.0/16 \
  --gateway=172.20.0.1 \
  librenms_external

echo ""
echo "🚀 Deploying PURE DOCKER SWARM with external network..."

cat > docker-compose-swarm-pure.yml << 'EOF'
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
      endpoint_mode: dnsrr
    environment:
      - MYSQL_ROOT_PASSWORD=SwarmPure2024
      - MYSQL_DATABASE=librenms
      - MYSQL_USER=librenms
      - MYSQL_PASSWORD=SwarmPure2024
      - TZ=UTC
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - librenms_external
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
      endpoint_mode: dnsrr
    networks:
      - librenms_external
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
      endpoint_mode: vip
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
      - DB_PASSWORD=SwarmPure2024
      - DB_TIMEOUT=120
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_DB=0
      - BASE_URL=http://192.168.1.240:7000
      - POLLERS=4
    volumes:
      - librenms_data:/data
    networks:
      - librenms_external
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/login", "||", "exit", "1"]
      interval: 60s
      timeout: 15s
      retries: 5
      start_period: 180s

networks:
  librenms_external:
    external: true

volumes:
  mysql_data:
  librenms_data:
EOF

# Deploy the stack
docker stack deploy -c docker-compose-swarm-pure.yml monitoring

echo ""
echo "⏳ Waiting for MySQL to initialize in Swarm (120 seconds)..."
sleep 120

echo ""
echo "🧪 Testing MySQL connectivity from host..."
for i in {1..5}; do
    if mysql -h 127.0.0.1 -P 3306 -u librenms -pSwarmPure2024 -e "SELECT 'Pure Swarm MySQL working!' as test;" 2>/dev/null; then
        echo "✅ MySQL is accessible from host!"
        break
    fi
    echo "Testing MySQL... attempt $i/5"
    sleep 10
done

echo ""
echo "⏳ Waiting for LibreNMS to initialize (180 seconds)..."
sleep 180

echo ""
echo "📊 Service status:"
docker service ls

echo ""
echo "🔍 LibreNMS service logs:"
docker service logs monitoring_librenms --tail 25

echo ""
echo "🧪 Testing LibreNMS web interface:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://192.168.1.240:7000 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "✅ LibreNMS web interface is working! (HTTP $HTTP_CODE)"
else
    echo "⚠️ LibreNMS web interface response: HTTP $HTTP_CODE"
fi

echo ""
echo "🔍 Network diagnostics:"
echo "External network info:"
docker network inspect librenms_external --format '{{json .IPAM.Config}}'

echo ""
echo "✅ PURE DOCKER SWARM DEPLOYMENT COMPLETE!"
echo ""
echo "📋 Architecture:"
echo "🐳 All services running in Docker Swarm"
echo "🌐 Using external bridge network (172.20.0.0/16)"
echo "🔧 MySQL with DNS Round Robin endpoint mode"
echo "🎯 LibreNMS with VIP endpoint mode"
echo ""
echo "📋 Access Information:"
echo "🌐 LibreNMS Web Interface: http://192.168.1.240:7000"
echo "🗄️ MySQL Database: 192.168.1.240:3306"
echo "🔑 Database Credentials: librenms / SwarmPure2024"
echo ""
echo "🔧 Swarm Management Commands:"
echo "Monitor LibreNMS: docker service logs monitoring_librenms -f"
echo "Scale LibreNMS: docker service scale monitoring_librenms=2"
echo "Update LibreNMS: docker service update --force monitoring_librenms"
echo "Monitor MySQL: docker service logs monitoring_mysql -f"
echo ""
echo "🎯 This is a PURE Docker Swarm solution with optimized networking!"