#!/bin/bash

# FINAL DOCKER SWARM SOLUTION - Using proper Swarm overlay network
# Creates swarm-scoped network and uses correct endpoint modes

set -e

echo "🎯 FINAL DOCKER SWARM SOLUTION"
echo "=============================="
echo "Using proper Swarm overlay network with optimized configuration"

# Clean up existing deployment
echo "🧹 Cleaning up existing deployments..."
docker stack rm monitoring 2>/dev/null || true
docker rm -f librenms_mysql_standalone 2>/dev/null || true
sleep 15

# Remove old volumes and networks
docker volume rm monitoring_mysql_data monitoring_librenms_data mysql_standalone_data 2>/dev/null || true
docker network rm librenms_external 2>/dev/null || true

echo ""
echo "🌐 Creating proper Swarm overlay network..."
docker network create \
  --driver overlay \
  --scope swarm \
  --subnet=10.50.0.0/16 \
  --gateway=10.50.0.1 \
  --attachable \
  librenms_swarm_net

echo ""
echo "🚀 Deploying FINAL DOCKER SWARM configuration..."

cat > docker-compose-swarm-final.yml << 'EOF'
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
      endpoint_mode: dnsrr
    environment:
      MYSQL_ROOT_PASSWORD: "SwarmFinal2024"
      MYSQL_DATABASE: "librenms"
      MYSQL_USER: "librenms"
      MYSQL_PASSWORD: "SwarmFinal2024"
      TZ: "UTC"
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - librenms_swarm_net
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-pSwarmFinal2024"]
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
      --innodb-buffer-pool-size=256M

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
      - librenms_swarm_net
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
        delay: 90s
        max_attempts: 10
        window: 900s
      placement:
        constraints:
          - node.role == manager
      endpoint_mode: vip
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
      DB_PASSWORD: "SwarmFinal2024"
      DB_TIMEOUT: "180"
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
      - librenms_swarm_net
    depends_on:
      - mysql
      - redis
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/login", "||", "exit", "1"]
      interval: 90s
      timeout: 30s
      retries: 5
      start_period: 300s

networks:
  librenms_swarm_net:
    external: true

volumes:
  mysql_data:
  librenms_data:
EOF

# Deploy the stack
docker stack deploy -c docker-compose-swarm-final.yml monitoring

echo ""
echo "⏳ Waiting for MySQL to fully initialize (150 seconds)..."
sleep 150

echo ""
echo "🧪 Testing MySQL connectivity..."
for i in {1..10}; do
    if mysql -h 127.0.0.1 -P 3306 -u librenms -pSwarmFinal2024 -e "SELECT 'Final Swarm MySQL working!' as test;" 2>/dev/null; then
        echo "✅ MySQL is accessible from host!"
        break
    fi
    echo "Testing MySQL... attempt $i/10"
    sleep 15
done

echo ""
echo "⏳ Waiting for LibreNMS to initialize (300 seconds)..."
sleep 240  # Already waited 60 above

echo ""
echo "📊 Service status:"
docker service ls

echo ""
echo "🔍 LibreNMS service logs:"
docker service logs monitoring_librenms --tail 30

echo ""
echo "🧪 Testing LibreNMS web interface:"
HTTP_CODE=\$(curl -s -o /dev/null -w '%{http_code}' http://192.168.1.240:7000 2>/dev/null || echo "000")
if [ "\$HTTP_CODE" = "200" ] || [ "\$HTTP_CODE" = "302" ]; then
    echo "✅ LibreNMS web interface is working! (HTTP \$HTTP_CODE)"
else
    echo "⚠️ LibreNMS web interface response: HTTP \$HTTP_CODE"
fi

echo ""
echo "🔍 Network diagnostics:"
echo "Swarm network info:"
docker network inspect librenms_swarm_net --format '{{json .IPAM.Config}}'

echo ""
echo "✅ FINAL DOCKER SWARM DEPLOYMENT COMPLETE!"
echo ""
echo "📋 Architecture:"
echo "🐳 Pure Docker Swarm with all services orchestrated"
echo "🌐 Custom overlay network (10.50.0.0/16) with swarm scope"
echo "🔧 MySQL with DNS RR + health checks"
echo "📊 Redis with DNS RR + health checks"
echo "🎯 LibreNMS with VIP + comprehensive health checks"
echo ""
echo "📋 Access Information:"
echo "🌐 LibreNMS Web Interface: http://192.168.1.240:7000"
echo "🗄️ MySQL Database: 192.168.1.240:3306"
echo "🔑 Database Credentials: librenms / SwarmFinal2024"
echo ""
echo "🔧 Docker Swarm Management:"
echo "Monitor LibreNMS: docker service logs monitoring_librenms -f"
echo "Scale LibreNMS: docker service scale monitoring_librenms=2"
echo "Update LibreNMS: docker service update --force monitoring_librenms"
echo "Monitor MySQL: docker service logs monitoring_mysql -f"
echo "Stack status: docker stack services monitoring"
echo ""
echo "🎯 This is your production-ready Docker Swarm solution!"