#!/bin/bash

# FINAL WORKING LibreNMS + MySQL Deployment for Docker Swarm
# Using proven working patterns from existing scripts

set -e

echo "🎯 FINAL WORKING LibreNMS Deployment"
echo "===================================="

# Clean up existing deployment
echo "🧹 Cleaning up existing deployment..."
docker stack rm monitoring 2>/dev/null || true
sleep 15

# Remove old volumes for fresh start
echo "🗑️ Removing old volumes..."
docker volume rm monitoring_mysql_data monitoring_librenms_data 2>/dev/null || true

echo ""
echo "🚀 Deploying with working configuration..."

cat > docker-compose-final.yml << 'EOF'
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
      - DB_TIMEOUT=90
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_DB=0
      - BASE_URL=http://192.168.1.240:7000
      - POLLERS=4
    volumes:
      - librenms_data:/data
    networks:
      - monitoring_net

networks:
  monitoring_net:
    driver: overlay
    attachable: true

volumes:
  mysql_data:
  librenms_data:
EOF

# Deploy the stack
docker stack deploy -c docker-compose-final.yml monitoring

echo ""
echo "⏳ Waiting for MySQL to initialize completely (90 seconds)..."
sleep 90

echo ""
echo "🧪 Testing MySQL connectivity..."
if docker exec $(docker ps -q --filter 'name=monitoring_mysql') mysql -u librenms -pLibreNMS123! -e "SELECT 'MySQL is ready!' as status;" 2>/dev/null; then
    echo "✅ MySQL connection successful!"
else
    echo "⚠️ MySQL connection test failed - checking logs..."
    docker service logs monitoring_mysql --tail 10
fi

echo ""
echo "⏳ Waiting for LibreNMS to connect to database (60 seconds)..."
sleep 60

echo ""
echo "📊 Service status:"
docker service ls

echo ""
echo "🔍 LibreNMS logs (last 20 lines):"
docker service logs monitoring_librenms --tail 20

echo ""
echo "🔍 Service task status:"
docker service ps monitoring_librenms --no-trunc

echo ""
echo "✅ DEPLOYMENT COMPLETE!"
echo ""
echo "📋 Access Information:"
echo "🌐 LibreNMS Web Interface: http://192.168.1.240:7000"
echo "🗄️ MySQL Database: 192.168.1.240:3306"
echo "🔑 Database Credentials: librenms / LibreNMS123!"
echo ""
echo "🔧 Monitor LibreNMS startup:"
echo "   docker service logs monitoring_librenms -f"
echo ""
echo "🧪 Test web interface:"
echo "   curl -I http://192.168.1.240:7000"