#!/bin/bash

# Simple Docker Compose Deployment (Non-Swarm)
# Sometimes Docker Compose works better than Swarm for complex networking

set -e

echo "🐳 SIMPLE Docker Compose Deployment"
echo "===================================="

# Clean up any existing deployment
echo "🧹 Cleaning up existing deployment..."
docker stack rm monitoring 2>/dev/null || true
sleep 10

# Remove old volumes
docker volume rm monitoring_mysql_data monitoring_librenms_data 2>/dev/null || true

echo ""
echo "🚀 Creating simple docker-compose.yml for regular Docker Compose..."

cat > docker-compose-simple.yml << 'EOF'
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: librenms_mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: "LibreNMS123!"
      MYSQL_DATABASE: "librenms"
      MYSQL_USER: "librenms"
      MYSQL_PASSWORD: "LibreNMS123!"
      TZ: "UTC"
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    command: >
      --default-authentication-plugin=mysql_native_password
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --bind-address=0.0.0.0
      --skip-name-resolve
    networks:
      - librenms

  redis:
    image: redis:7-alpine
    container_name: librenms_redis
    restart: unless-stopped
    command: redis-server --appendonly yes
    networks:
      - librenms

  librenms:
    image: librenms/librenms:latest
    container_name: librenms_app
    restart: unless-stopped
    ports:
      - "7000:8000"
    depends_on:
      - mysql
      - redis
    environment:
      # Database Configuration
      DB_HOST: "mysql"
      DB_PORT: "3306"
      DB_NAME: "librenms"
      DB_USER: "librenms"
      DB_PASSWORD: "LibreNMS123!"
      DB_TIMEOUT: "60"
      
      # Redis Configuration
      REDIS_HOST: "redis"
      REDIS_PORT: "6379"
      REDIS_DB: "0"
      
      # LibreNMS Configuration
      TZ: "UTC"
      PUID: "1000"
      PGID: "1000"
      BASE_URL: "http://192.168.1.240:7000"
      POLLERS: "4"
    volumes:
      - librenms_data:/data
    networks:
      - librenms

networks:
  librenms:
    driver: bridge

volumes:
  mysql_data:
  librenms_data:
EOF

echo "🎯 Starting services with Docker Compose..."
docker-compose -f docker-compose-simple.yml up -d

echo ""
echo "⏳ Waiting for services to initialize (60 seconds)..."
sleep 60

echo ""
echo "📊 Service status:"
docker-compose -f docker-compose-simple.yml ps

echo ""
echo "🧪 Testing MySQL connectivity..."
if docker exec librenms_mysql mysql -u librenms -pLibreNMS123! -e "SELECT 'MySQL is working!' as status;" 2>/dev/null; then
    echo "✅ MySQL connection successful!"
else
    echo "⚠️ MySQL connection test failed"
fi

echo ""
echo "🔍 LibreNMS logs:"
docker-compose -f docker-compose-simple.yml logs librenms --tail 15

echo ""
echo "✅ DEPLOYMENT COMPLETE!"
echo ""
echo "📋 Access Information:"
echo "🌐 LibreNMS Web: http://192.168.1.240:7000"
echo "🗄️ MySQL: 192.168.1.240:3306"
echo "🔑 Credentials: librenms / LibreNMS123!"
echo ""
echo "🔧 Monitor logs with:"
echo "   docker-compose -f docker-compose-simple.yml logs -f librenms"
echo ""
echo "🛑 To stop:"
echo "   docker-compose -f docker-compose-simple.yml down"