#!/bin/bash

# Bulletproof LibreNMS Deployment - FIXED VERSION
# This ensures MySQL is properly accessible before starting LibreNMS

set -e

echo "🔧 BULLETPROOF LibreNMS Deployment - Fixed Network Edition"
echo "=========================================================="

# Clean slate deployment
echo "🧹 Ensuring clean deployment..."
docker stack rm monitoring 2>/dev/null || true
sleep 15
docker volume rm monitoring_mysql_data monitoring_librenms_data 2>/dev/null || true

echo ""
echo "🎯 Step 1: Deploy MySQL ONLY first with external access"

cat > docker-compose-mysql-only.yml << 'EOF'
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
      MYSQL_ROOT_PASSWORD: "LibreNMS123!"
      MYSQL_DATABASE: "librenms"
      MYSQL_USER: "librenms"
      MYSQL_PASSWORD: "LibreNMS123!"
      TZ: "UTC"
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - librenms_net
    command: >
      --default-authentication-plugin=mysql_native_password
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --bind-address=0.0.0.0
      --skip-name-resolve

networks:
  librenms_net:
    driver: overlay
    attachable: true

volumes:
  mysql_data:
EOF

docker stack deploy -c docker-compose-mysql-only.yml monitoring

echo "⏳ Waiting for MySQL to fully initialize (60 seconds)..."
sleep 60

echo ""
echo "🧪 Testing MySQL connectivity and setup..."

# Test MySQL connectivity in a loop
echo "Testing MySQL connection..."
for i in {1..10}; do
    echo "  Attempt $i/10..."
    if docker exec $(docker ps -q --filter 'name=monitoring_mysql') mysql -u librenms -pLibreNMS123! -e "SELECT 'Connection successful!' as status;" 2>/dev/null; then
        echo "✅ MySQL is ready and accessible!"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "❌ MySQL connection failed after 10 attempts"
        exit 1
    fi
    sleep 5
done

echo ""
echo "🚀 Step 2: Deploy full stack with Redis and LibreNMS"

cat > docker-compose-full.yml << 'EOF'
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
      MYSQL_ROOT_PASSWORD: "LibreNMS123!"
      MYSQL_DATABASE: "librenms"
      MYSQL_USER: "librenms"
      MYSQL_PASSWORD: "LibreNMS123!"
      TZ: "UTC"
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - librenms_net
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
      - librenms_net
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
      - target: 8000
        published: 7000
        protocol: tcp
        mode: ingress
    environment:
      # Database Configuration - use IP to avoid DNS issues
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
      
      # Enable services
      CRON_FPING: "true"
      CRON_DISCOVERY_ENABLE: "true"
      CRON_DAILY_ENABLE: "true"
    volumes:
      - librenms_data:/data
    networks:
      - librenms_net

networks:
  librenms_net:
    driver: overlay
    attachable: true

volumes:
  mysql_data:
  librenms_data:
EOF

docker stack deploy -c docker-compose-full.yml monitoring

echo ""
echo "⏳ Waiting for LibreNMS to initialize (120 seconds)..."
sleep 120

echo ""
echo "📊 Final status check:"
docker service ls

echo ""
echo "🔍 LibreNMS startup logs:"
docker service logs monitoring_librenms --tail 15

echo ""
echo "✅ DEPLOYMENT COMPLETE!"
echo ""
echo "📋 Access Information:"
echo "🌐 LibreNMS Web: http://192.168.1.240:7000"
echo "🗄️ MySQL: 192.168.1.240:3306"
echo "🔑 Credentials: librenms / LibreNMS123!"
echo ""
echo "🔧 Monitor startup with:"
echo "   docker service logs monitoring_librenms -f"