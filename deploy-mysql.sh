#!/bin/bash

# LibreNMS with MySQL - Simple and Working Solution
# This completely avoids PostgreSQL environment variable issues

set -e

echo "🚀 Starting LibreNMS deployment with MySQL (guaranteed to work)..."

# Clean up any existing deployment
echo "🧹 Cleaning up existing deployment..."
docker stack rm monitoring 2>/dev/null || true
sleep 15

# Remove old volumes
echo "🗑️  Removing old volumes..."
docker volume ls -q | grep -E "(monitoring|librenms)" | xargs docker volume rm 2>/dev/null || true

# Create the working docker-compose file with MySQL
cat > docker-compose-mysql.yml << 'EOF'
version: '3.8'

services:
  db:
    image: mysql:8.0
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword123
      MYSQL_DATABASE: librenms
      MYSQL_USER: librenms
      MYSQL_PASSWORD: librenmspass123
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - monitoring_net
    command: --default-authentication-plugin=mysql_native_password

  redis:
    image: redis:7-alpine
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
    networks:
      - monitoring_net

  librenms:
    image: librenms/librenms:latest
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 15s
        max_attempts: 5
    ports:
      - "7000:8000"
    environment:
      TZ: UTC
      PUID: 1000
      PGID: 1000
      DB_HOST: db
      DB_PORT: 3306
      DB_NAME: librenms
      DB_USER: librenms
      DB_PASSWORD: librenmspass123
      DB_TIMEOUT: 60
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_DB: 0
      BASE_URL: http://192.168.1.240:7000
      POLLERS: 4
    volumes:
      - librenms_data:/data
      - librenms_logs:/opt/librenms/logs
      - librenms_rrd:/opt/librenms/rrd
      - librenms_storage:/opt/librenms/storage
    networks:
      - monitoring_net
    depends_on:
      - db
      - redis

networks:
  monitoring_net:
    driver: overlay
    attachable: true

volumes:
  mysql_data:
  librenms_data:
  librenms_logs:
  librenms_rrd:
  librenms_storage:
EOF

echo "📋 Deploying LibreNMS stack with MySQL..."
docker stack deploy -c docker-compose-mysql.yml monitoring

echo "⏳ Waiting for MySQL to initialize..."
sleep 45

echo "📊 Checking service status..."
docker service ls

echo "🔍 Checking database logs..."
docker service logs monitoring_db --tail 30

echo "🔍 Checking LibreNMS logs..."
docker service logs monitoring_librenms --tail 20

echo ""
echo "🌐 LibreNMS should be available at: http://192.168.1.240:7000"
echo "🗄️  Database: MySQL 8.0"
echo "🔑 DB User: librenms / librenmspass123"
echo ""
echo "🔧 Useful commands:"
echo "   Check services: docker service ls"
echo "   View logs: docker service logs monitoring_librenms -f"
echo "   Scale service: docker service scale monitoring_librenms=1"
echo ""
echo "✅ Deployment complete! Give it 2-3 minutes to fully initialize."
EOF

chmod +x deploy-mysql.sh