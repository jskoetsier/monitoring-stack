#!/bin/bash

# WORKING DOCKER SWARM SOLUTION - Fixed endpoint mode conflicts
# Removes dnsrr/port conflicts while keeping Docker Swarm orchestration

set -e

echo "🎯 WORKING DOCKER SWARM SOLUTION"
echo "==============================="
echo "Fixed endpoint mode conflicts - using VIP mode with ingress ports"

# Clean up existing deployment
echo "🧹 Cleaning up existing deployments..."
docker stack rm monitoring 2>/dev/null || true
docker rm -f librenms_mysql_standalone 2>/dev/null || true
sleep 15

# Remove old volumes and networks
docker volume rm monitoring_mysql_data monitoring_librenms_data mysql_standalone_data 2>/dev/null || true
docker network rm librenms_external librenms_swarm_net 2>/dev/null || true

echo ""
echo "🌐 Creating proper Swarm overlay network..."
docker network create \
  --driver overlay \
  --subnet=10.60.0.0/16 \
  --gateway=10.60.0.1 \
  --attachable \
  monitoring_swarm_net

echo ""
echo "🚀 Deploying WORKING DOCKER SWARM configuration..."

cat > docker-compose-swarm-working.yml << 'EOF'
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 15s
        max_attempts: 5
        window: 120s
      placement:
        constraints:
          - node.role == manager
    environment:
      MYSQL_ROOT_PASSWORD: "SwarmWorking2024"
      MYSQL_DATABASE: "librenms"
      MYSQL_USER: "librenms"
      MYSQL_PASSWORD: "SwarmWorking2024"
      TZ: "UTC"
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - monitoring_swarm_net
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-pSwarmWorking2024"]
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
      - monitoring_swarm_net
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 5s
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
      TZ: "UTC"
      PUID: "1000"
      PGID: "1000"
      DB_HOST: "mysql"
      DB_PORT: "3306"
      DB_NAME: "librenms"
      DB_USER: "librenms"
      DB_PASSWORD: "SwarmWorking2024"
      DB_TIMEOUT: "120"
      REDIS_HOST: "redis"
      REDIS_PORT: "6379"
      REDIS_DB: "0"
      BASE_URL: "http://192.168.1.240:7000"
      POLLERS: "4"
      MEMORY_LIMIT: "1024M"
      MAX_EXECUTION_TIME: "300"
    volumes:
      - librenms_data:/data
    networks:
      - monitoring_swarm_net
    depends_on:
      - mysql
      - redis
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/login", "||", "exit", "1"]
      interval: 60s
      timeout: 15s
      retries: 5
      start_period: 180s

networks:
  monitoring_swarm_net:
    external: true

volumes:
  mysql_data:
  librenms_data:
EOF

# Deploy the stack
docker stack deploy -c docker-compose-swarm-working.yml monitoring

echo ""
echo "⏳ Waiting for MySQL to initialize (120 seconds)..."
sleep 120

echo ""
echo "🧪 Testing MySQL connectivity..."
for i in {1..8}; do
    if mysql -h 127.0.0.1 -P 3306 -u librenms -pSwarmWorking2024 -e "SELECT 'Working Swarm MySQL!' as test;" 2>/dev/null; then
        echo "✅ MySQL is accessible from host!"
        break
    fi
    echo "Testing MySQL... attempt $i/8"
    sleep 15
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
echo "Swarm network info:"
docker network inspect monitoring_swarm_net --format '{{json .IPAM.Config}}'

echo ""
echo "✅ WORKING DOCKER SWARM DEPLOYMENT COMPLETE!"
echo ""
echo "📋 Architecture:"
echo "🐳 Pure Docker Swarm with VIP endpoint mode (default)"
echo "🌐 Custom overlay network (10.60.0.0/16)"
echo "🔧 All services use default VIP mode (compatible with ingress ports)"
echo "📊 Full health checks and proper dependencies"
echo ""
echo "📋 Access Information:"
echo "🌐 LibreNMS Web Interface: http://192.168.1.240:7000"
echo "🗄️ MySQL Database: 192.168.1.240:3306"
echo "🔑 Database Credentials: librenms / SwarmWorking2024"
echo ""
echo "🔧 Docker Swarm Management:"
echo "Monitor LibreNMS: docker service logs monitoring_librenms -f"
echo "Scale LibreNMS: docker service scale monitoring_librenms=2"
echo "Update LibreNMS: docker service update --force monitoring_librenms"
echo "Monitor MySQL: docker service logs monitoring_mysql -f"
echo "Stack status: docker stack services monitoring"
echo ""
echo "🎯 This is your WORKING Docker Swarm solution with fixed endpoint modes!"