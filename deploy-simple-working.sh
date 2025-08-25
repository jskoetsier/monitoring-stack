#!/bin/bash

# LibreNMS SIMPLE WORKING Deployment
# MySQL is ready, now just deploy LibreNMS with proper timing

set -e

echo "🎯 SIMPLE LibreNMS Deployment - MySQL is Ready!"
echo "=============================================="

# Since MySQL is already running and ready, just deploy the full stack
echo "🚀 Deploying full LibreNMS stack..."

cat > docker-compose-simple.yml << 'EOF'
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
        window: 300s
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
      DB_PASSWORD: "LibreNMS123!"
      DB_TIMEOUT: "180"
      
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
  librenms_data:
EOF

# Deploy the complete stack
docker stack deploy -c docker-compose-simple.yml monitoring

echo "⏳ Waiting for LibreNMS to initialize (90 seconds)..."
sleep 90

echo "📊 Service status:"
docker service ls

echo "🔍 LibreNMS logs:"
docker service logs monitoring_librenms --tail 25

echo ""
echo "🌐 LibreNMS should now be available at: http://192.168.1.240:7000"
echo ""
echo "✅ If you see 'Database connection successful' in the logs above, LibreNMS is working!"
echo ""
echo "🔧 Continue monitoring with:"
echo "   docker service logs monitoring_librenms -f"
echo ""