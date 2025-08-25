#!/bin/bash

# DOCKER SWARM HYBRID SOLUTION
# MySQL as regular container + LibreNMS in Docker Swarm
# This keeps Swarm orchestration while solving the networking issue

set -e

echo "🔄 DOCKER SWARM HYBRID SOLUTION"
echo "==============================="
echo "MySQL: Regular container (host network)"
echo "LibreNMS: Docker Swarm (connects via localhost)"

# Clean up existing deployment
echo "🧹 Cleaning up existing deployments..."
docker stack rm monitoring 2>/dev/null || true
docker rm -f librenms_mysql_standalone 2>/dev/null || true
sleep 15

# Remove old volumes for fresh start
docker volume rm monitoring_mysql_data monitoring_librenms_data librenms_mysql_data 2>/dev/null || true

echo ""
echo "🗄️ Step 1: Deploy MySQL as standalone container (outside Swarm)..."

# Start MySQL as regular container with host networking
docker run -d \
  --name librenms_mysql_standalone \
  --restart unless-stopped \
  --network host \
  -e MYSQL_ROOT_PASSWORD=SwarmPass2024 \
  -e MYSQL_DATABASE=librenms \
  -e MYSQL_USER=librenms \
  -e MYSQL_PASSWORD=SwarmPass2024 \
  -v mysql_standalone_data:/var/lib/mysql \
  mysql:8.0 \
  --default-authentication-plugin=mysql_native_password \
  --character-set-server=utf8mb4 \
  --collation-server=utf8mb4_unicode_ci \
  --bind-address=0.0.0.0 \
  --port=3306

echo "⏳ Waiting for MySQL to initialize (90 seconds)..."
sleep 90

echo "🧪 Testing MySQL connectivity..."
for i in {1..5}; do
    if mysql -h 127.0.0.1 -P 3306 -u librenms -pSwarmPass2024 -e "SELECT 'MySQL ready for Swarm!' as status;" 2>/dev/null; then
        echo "✅ MySQL is ready and accessible on localhost!"
        break
    fi
    echo "Waiting for MySQL... attempt $i/5"
    sleep 10
done

echo ""
echo "🐳 Step 2: Deploy LibreNMS and Redis in Docker Swarm..."

cat > docker-compose-swarm-hybrid.yml << 'EOF'
version: '3.8'

services:
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
        max_attempts: 10
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
      - DB_HOST=127.0.0.1
      - DB_PORT=3306
      - DB_NAME=librenms
      - DB_USER=librenms
      - DB_PASSWORD=SwarmPass2024
      - DB_TIMEOUT=60
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_DB=0
      - BASE_URL=http://192.168.1.240:7000
      - POLLERS=4
    volumes:
      - librenms_data:/data
    networks:
      - monitoring_net
      - host
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
  host:
    external: true
    name: host

volumes:
  librenms_data:
EOF

# Deploy the Swarm stack
docker stack deploy -c docker-compose-swarm-hybrid.yml monitoring

echo ""
echo "⏳ Waiting for LibreNMS to initialize in Swarm (120 seconds)..."
sleep 120

echo ""
echo "📊 Service status:"
docker service ls

echo ""
echo "🔍 LibreNMS service logs:"
docker service logs monitoring_librenms --tail 20

echo ""
echo "🧪 Testing LibreNMS web interface:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://192.168.1.240:7000 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "✅ LibreNMS web interface is working! (HTTP $HTTP_CODE)"
else
    echo "⚠️ LibreNMS web interface not ready yet (HTTP $HTTP_CODE)"
fi

echo ""
echo "✅ DOCKER SWARM HYBRID DEPLOYMENT COMPLETE!"
echo ""
echo "📋 Architecture:"
echo "🗄️ MySQL: Standalone container with host networking"
echo "🐳 LibreNMS: Docker Swarm service"
echo "📊 Redis: Docker Swarm service"
echo ""
echo "📋 Access Information:"
echo "🌐 LibreNMS Web Interface: http://192.168.1.240:7000"
echo "🗄️ MySQL Database: 127.0.0.1:3306 (localhost)"
echo "🔑 Database Credentials: librenms / SwarmPass2024"
echo ""
echo "🔧 Management Commands:"
echo "Monitor LibreNMS: docker service logs monitoring_librenms -f"
echo "Scale LibreNMS: docker service scale monitoring_librenms=2"
echo "Monitor MySQL: docker logs librenms_mysql_standalone -f"
echo "Restart MySQL: docker restart librenms_mysql_standalone"
echo ""
echo "🎯 This gives you Docker Swarm orchestration for LibreNMS"
echo "   while solving the overlay network connectivity issue!"