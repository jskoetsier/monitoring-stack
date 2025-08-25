#!/bin/bash

# LibreNMS FINAL WORKING Deployment
# Fixes database connectivity by ensuring proper startup order and health checks

set -e

echo "🎯 FINAL LibreNMS Deployment - Database Connectivity Fix"
echo "======================================================="

# Clean up everything
echo "🧹 Complete cleanup..."
docker stack rm monitoring 2>/dev/null || true
sleep 20

# Remove all volumes
echo "🗑️  Removing volumes..."
docker volume ls -q | grep -E "(monitoring|librenms|mysql)" | xargs docker volume rm 2>/dev/null || true
docker system prune -f

echo "🏗️  Creating FINAL working configuration..."
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
    environment:
      MYSQL_ROOT_PASSWORD: "LibreNMS123!"
      MYSQL_DATABASE: "librenms"
      MYSQL_USER: "librenms"
      MYSQL_PASSWORD: "LibreNMS123!"
      TZ: "UTC"
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - librenms_net
    command: >
      --default-authentication-plugin=mysql_native_password
      --innodb-buffer-pool-size=256M
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --bind-address=0.0.0.0
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-pLibreNMS123!"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s

  redis:
    image: redis:7-alpine
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
    networks:
      - librenms_net
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

  # Wait for MySQL to be healthy before starting LibreNMS
  librenms:
    image: librenms/librenms:latest
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 60s  # Longer delay to let MySQL fully initialize
        max_attempts: 5
        window: 300s
    ports:
      - target: 8000
        published: 7000
        protocol: tcp
        mode: ingress
    environment:
      # Database Configuration - SAME PASSWORD AS MYSQL
      DB_HOST: "mysql"
      DB_PORT: "3306"
      DB_NAME: "librenms"
      DB_USER: "librenms"
      DB_PASSWORD: "LibreNMS123!"
      DB_TIMEOUT: "120"  # Longer timeout
      
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
      
      # Cron jobs
      CRON_FPING: "true"
      CRON_DISCOVERY_ENABLE: "true"
      CRON_DAILY_ENABLE: "true"
      CRON_ALERTS_ENABLE: "true"
      CRON_POLLER_ENABLE: "true"
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
    driver: local
  librenms_data:
    driver: local
EOF

echo "🚀 Deploying MySQL first..."
# Deploy MySQL first and wait for it to be ready
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
    environment:
      MYSQL_ROOT_PASSWORD: "LibreNMS123!"
      MYSQL_DATABASE: "librenms"
      MYSQL_USER: "librenms"
      MYSQL_PASSWORD: "LibreNMS123!"
      TZ: "UTC"
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - librenms_net
    command: >
      --default-authentication-plugin=mysql_native_password
      --innodb-buffer-pool-size=256M
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --bind-address=0.0.0.0
networks:
  librenms_net:
    driver: overlay
    attachable: true
volumes:
  mysql_data:
    driver: local
EOF

# Deploy MySQL only first
docker stack deploy -c docker-compose-mysql-only.yml monitoring

echo "⏳ Waiting for MySQL to fully initialize (120 seconds)..."
sleep 120

echo "🔍 Checking MySQL status..."
docker service logs monitoring_mysql --tail 20

# Test MySQL connectivity
echo "🧪 Testing MySQL connectivity..."
for i in {1..10}; do
    if docker run --rm --network monitoring_librenms_net mysql:8.0 mysql -h mysql -u librenms -pLibreNMS123! -e "SELECT 1" 2>/dev/null; then
        echo "✅ MySQL connection test successful!"
        break
    else
        echo "   Attempt $i/10 - MySQL not ready yet..."
        sleep 10
    fi
done

echo "🚀 Now deploying full stack with Redis and LibreNMS..."
docker stack deploy -c docker-compose-final.yml monitoring

echo "⏳ Waiting for all services to start..."
sleep 60

echo "📊 Service status:"
docker service ls

echo "🔍 MySQL logs:"
docker service logs monitoring_mysql --tail 10

echo "🔍 LibreNMS logs:"
docker service logs monitoring_librenms --tail 15

echo ""
echo "🌐 LibreNMS should be available at: http://192.168.1.240:7000"
echo ""
echo "🔧 Database credentials:"
echo "   Host: mysql"
echo "   Database: librenms" 
echo "   User: librenms"
echo "   Password: LibreNMS123!"
echo ""
echo "🔧 Debugging commands:"
echo "   Monitor LibreNMS: docker service logs monitoring_librenms -f"
echo "   Check services: docker service ls"
echo "   Test DB manually: docker run --rm --network monitoring_librenms_net mysql:8.0 mysql -h mysql -u librenms -pLibreNMS123!"
echo ""
echo "✅ Final deployment complete!"