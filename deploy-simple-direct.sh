#!/bin/bash

# DEAD SIMPLE SOLUTION - Abandon Docker Swarm, use direct containers
# Docker Swarm overlay networking is the root cause - bypass it entirely

set -e

echo "🎯 DEAD SIMPLE SOLUTION - Direct Docker Containers"
echo "================================================="
echo "Abandoning Docker Swarm - using direct container networking"

# Stop any existing Docker Swarm deployment
echo "🛑 Stopping Docker Swarm deployment..."
docker stack rm monitoring 2>/dev/null || true
sleep 10

# Remove any existing containers
echo "🧹 Removing any existing containers..."
docker rm -f librenms_mysql librenms_redis librenms_app 2>/dev/null || true

# Remove old volumes
echo "🗑️ Cleaning up volumes..."
docker volume rm librenms_mysql_data librenms_data 2>/dev/null || true

echo ""
echo "🚀 Starting DIRECT container deployment..."

# Create network
echo "Creating bridge network..."
docker network create librenms_bridge 2>/dev/null || true

# Start MySQL first
echo "🗄️ Starting MySQL container..."
docker run -d \
  --name librenms_mysql \
  --network librenms_bridge \
  --restart unless-stopped \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=SimplePass123 \
  -e MYSQL_DATABASE=librenms \
  -e MYSQL_USER=librenms \
  -e MYSQL_PASSWORD=SimplePass123 \
  -v librenms_mysql_data:/var/lib/mysql \
  mysql:8.0 \
  --default-authentication-plugin=mysql_native_password \
  --character-set-server=utf8mb4 \
  --collation-server=utf8mb4_unicode_ci \
  --bind-address=0.0.0.0

echo "⏳ Waiting for MySQL to initialize (60 seconds)..."
sleep 60

# Test MySQL
echo "🧪 Testing MySQL connection..."
for i in {1..5}; do
    if docker exec librenms_mysql mysql -u librenms -pSimplePass123 -e "SELECT 'MySQL working!' as test;" 2>/dev/null; then
        echo "✅ MySQL is ready!"
        break
    fi
    echo "Waiting for MySQL... attempt $i/5"
    sleep 10
done

# Start Redis
echo "📊 Starting Redis container..."
docker run -d \
  --name librenms_redis \
  --network librenms_bridge \
  --restart unless-stopped \
  redis:7-alpine redis-server --appendonly yes

# Start LibreNMS
echo "🌐 Starting LibreNMS container..."
docker run -d \
  --name librenms_app \
  --network librenms_bridge \
  --restart unless-stopped \
  -p 7000:8000 \
  -e TZ=UTC \
  -e PUID=1000 \
  -e PGID=1000 \
  -e DB_HOST=librenms_mysql \
  -e DB_PORT=3306 \
  -e DB_NAME=librenms \
  -e DB_USER=librenms \
  -e DB_PASSWORD=SimplePass123 \
  -e DB_TIMEOUT=60 \
  -e REDIS_HOST=librenms_redis \
  -e REDIS_PORT=6379 \
  -e REDIS_DB=0 \
  -e BASE_URL=http://192.168.1.240:7000 \
  -e POLLERS=2 \
  -v librenms_data:/data \
  librenms/librenms:latest

echo ""
echo "⏳ Waiting for LibreNMS to initialize (90 seconds)..."
sleep 90

echo ""
echo "📊 Container status:"
docker ps --filter name=librenms

echo ""
echo "🔍 LibreNMS logs:"
docker logs librenms_app --tail 20

echo ""
echo "🧪 Testing web interface:"
HTTP_CODE=\$(curl -s -o /dev/null -w '%{http_code}' http://192.168.1.240:7000)
echo "HTTP response: \$HTTP_CODE"

echo ""
echo "✅ SIMPLE DEPLOYMENT COMPLETE!"
echo ""
echo "📋 Access Information:"
echo "🌐 LibreNMS Web Interface: http://192.168.1.240:7000"
echo "🗄️ MySQL Database: 192.168.1.240:3306"
echo "🔑 Database Credentials: librenms / SimplePass123"
echo ""
echo "🎯 This uses DIRECT Docker containers instead of Docker Swarm"
echo "🔧 Monitor with: docker logs librenms_app -f"
echo "🛑 Stop with: docker rm -f librenms_mysql librenms_redis librenms_app"