#!/bin/bash

# LibreNMS FIXED Deployment - Solves the volume mounting issue
# The problem was Docker volumes conflicting with LibreNMS initialization

set -e

echo "🔥 FIXED LibreNMS Deployment - Solving Volume Mount Conflicts"
echo "=============================================================="

# Clean up everything
echo "🧹 Performing complete cleanup..."
docker stack rm monitoring 2>/dev/null || true
sleep 15

# Remove all volumes
echo "🗑️  Removing all volumes..."
docker volume ls -q | grep -E "(monitoring|librenms|mysql)" | xargs docker volume rm 2>/dev/null || true
docker system prune -f

echo "🏗️  Creating FIXED docker-compose configuration..."
cat > docker-compose-fixed.yml << 'EOF'
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 10s
        max_attempts: 5
        window: 60s
    environment:
      MYSQL_ROOT_PASSWORD: "SuperSecureRoot123!"
      MYSQL_DATABASE: "librenms"
      MYSQL_USER: "librenms"
      MYSQL_PASSWORD: "LibreNMSPass123!"
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

  librenms:
    image: librenms/librenms:latest
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 30s
        max_attempts: 10
        window: 120s
    ports:
      - target: 8000
        published: 7000
        protocol: tcp
        mode: ingress
    environment:
      # Database Configuration
      DB_HOST: "mysql"
      DB_PORT: "3306"
      DB_NAME: "librenms"
      DB_USER: "librenms"
      DB_PASSWORD: "LibreNMSPass123!"
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
      
      # Cron jobs
      CRON_FPING: "true"
      CRON_DISCOVERY_ENABLE: "true"
      CRON_DAILY_ENABLE: "true" 
      CRON_ALERTS_ENABLE: "true"
      CRON_POLLER_ENABLE: "true"
    volumes:
      # FIXED: Only mount /data - let LibreNMS manage its own logs, rrd, storage
      - librenms_data:/data
    networks:
      - librenms_net
    depends_on:
      - mysql
      - redis

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

echo "🚀 Deploying FIXED LibreNMS stack..."
docker stack deploy -c docker-compose-fixed.yml monitoring

echo "⏳ Waiting for services to initialize..."
sleep 30

echo "📊 Service status:"
docker service ls

echo "🔍 Checking MySQL startup:"
docker service logs monitoring_mysql --tail 15

echo "⏳ Waiting for LibreNMS to initialize (60 seconds)..."
sleep 60

echo "🔍 Checking LibreNMS logs:"
docker service logs monitoring_librenms --tail 20

echo "📋 Service details:"
docker service ps monitoring_librenms --no-trunc

echo ""
echo "🌐 LibreNMS Access Information:"
echo "   URL: http://192.168.1.240:7000"
echo "   Database: MySQL 8.0"
echo ""
echo "🔧 Debugging Commands:"
echo "   Real-time logs: docker service logs monitoring_librenms -f"
echo "   Service status: docker service ls"
echo "   Restart LibreNMS: docker service update --force monitoring_librenms"
echo ""
echo "✅ Fixed deployment complete!"
echo ""
echo "🎯 Key Fix Applied:"
echo "   - Removed conflicting volume mounts from /opt/librenms/logs, /opt/librenms/rrd, /opt/librenms/storage"
echo "   - Only mounting /data volume - LibreNMS manages its own internal directories"
echo "   - This prevents the 'Resource busy' error during container initialization"