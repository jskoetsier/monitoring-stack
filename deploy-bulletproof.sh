to login #!/bin/bash

# Bulletproof LibreNMS Deployment
# This handles all common issues and provides extensive debugging

set -e

echo "🔥 BULLETPROOF LibreNMS Deployment Script"
echo "======================================"

# Function to wait for service to be ready
wait_for_service() {
    local service_name=$1
    local max_attempts=60
    local attempt=1

    echo "⏳ Waiting for $service_name to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if docker service ps $service_name --format "{{.CurrentState}}" | grep -q "Running"; then
            echo "✅ $service_name is ready!"
            return 0
        fi
        echo "   Attempt $attempt/$max_attempts - waiting..."
        sleep 5
        attempt=$((attempt + 1))
    done

    echo "❌ $service_name failed to start after $max_attempts attempts"
    docker service logs $service_name --tail 50
    return 1
}

# Clean up everything
echo "🧹 Performing complete cleanup..."
docker stack rm monitoring 2>/dev/null || true
sleep 15

# Remove all volumes
echo "🗑️  Removing all volumes..."
docker volume ls -q | grep -E "(monitoring|librenms|mysql)" | xargs docker volume rm 2>/dev/null || true

# Remove unused containers and networks
docker system prune -f

echo "🏗️  Creating optimized docker-compose configuration..."
cat > docker-compose-bulletproof.yml << 'EOF'
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
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
    environment:
      MYSQL_ROOT_PASSWORD: "SuperSecureRoot123!"
      MYSQL_DATABASE: "librenms"
      MYSQL_USER: "librenms"
      MYSQL_PASSWORD: "LibreNMSPass123!"
      MYSQL_INIT_CONNECT: "SET sql_mode=''"
      TZ: "UTC"
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - librenms_net
    command: >
      --default-authentication-plugin=mysql_native_password
      --innodb-buffer-pool-size=256M
      --innodb-log-file-size=48M
      --innodb-flush-log-at-trx-commit=1
      --innodb-lock-wait-timeout=50
      --lower-case-table-names=0
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-pSuperSecureRoot123!"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s

  redis:
    image: redis:7-alpine
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
        window: 60s
    networks:
      - librenms_net
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 10s

  librenms:
    image: librenms/librenms:latest
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 30s
        max_attempts: 10
        window: 120s
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G
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

      # Enable all cron jobs
      CRON_FPING: "true"
      CRON_DISCOVERY_ENABLE: "true"
      CRON_DAILY_ENABLE: "true"
      CRON_ALERTS_ENABLE: "true"
      CRON_BILLING_ENABLE: "true"
      CRON_BILLING_CALCULATE_ENABLE: "true"
      CRON_CHECK_SERVICES_ENABLE: "true"
      CRON_POLLER_ENABLE: "true"
      CRON_DISCOVERY_NEW_ENABLE: "true"

      # Additional settings for stability
      LIBRENMS_WEATHERMAP: "false"
      LIBRENMS_SMOKEPING: "false"
    volumes:
      - librenms_data:/data
      - librenms_logs:/opt/librenms/logs
      - librenms_rrd:/opt/librenms/rrd
      - librenms_storage:/opt/librenms/storage
    networks:
      - librenms_net
    depends_on:
      - mysql
      - redis
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/login"]
      interval: 60s
      timeout: 30s
      retries: 5
      start_period: 120s

networks:
  librenms_net:
    driver: overlay
    attachable: true
    driver_opts:
      com.docker.network.driver.mtu: 1500

volumes:
  mysql_data:
    driver: local
  redis_data:
    driver: local
  librenms_data:
    driver: local
  librenms_logs:
    driver: local
  librenms_rrd:
    driver: local
  librenms_storage:
    driver: local
EOF

echo "🚀 Deploying LibreNMS stack with health checks..."
docker stack deploy -c docker-compose-bulletproof.yml monitoring

echo "⏳ Waiting for MySQL to be ready..."
wait_for_service monitoring_mysql

echo "⏳ Waiting for Redis to be ready..."
wait_for_service monitoring_redis

echo "⏳ Waiting for LibreNMS to be ready (this takes longer)..."
sleep 60  # Give LibreNMS extra time to initialize

echo "📊 Current service status:"
docker service ls

echo "🔍 Service details:"
docker service ps monitoring_mysql --no-trunc
docker service ps monitoring_redis --no-trunc
docker service ps monitoring_librenms --no-trunc

echo "📋 Recent logs from all services:"
echo "=== MySQL Logs ==="
docker service logs monitoring_mysql --tail 10 2>/dev/null || echo "MySQL logs not available yet"

echo "=== Redis Logs ==="
docker service logs monitoring_redis --tail 10 2>/dev/null || echo "Redis logs not available yet"

echo "=== LibreNMS Logs ==="
docker service logs monitoring_librenms --tail 20 2>/dev/null || echo "LibreNMS logs not available yet"

echo ""
echo "🌐 LibreNMS Access Information:"
echo "   URL: http://192.168.1.240:7000"
echo "   Database: MySQL 8.0"
echo "   Database Name: librenms"
echo "   Database User: librenms"
echo "   Database Password: LibreNMSPass123!"
echo ""
echo "🔧 Debugging Commands:"
echo "   Check services: docker service ls"
echo "   View LibreNMS logs: docker service logs monitoring_librenms -f"
echo "   View MySQL logs: docker service logs monitoring_mysql -f"
echo "   Scale LibreNMS: docker service scale monitoring_librenms=0 && sleep 10 && docker service scale monitoring_librenms=1"
echo "   Access LibreNMS container: docker exec -it \$(docker ps -q -f name=monitoring_librenms) /bin/bash"
echo ""
echo "🎯 If LibreNMS is still exiting, run: docker service logs monitoring_librenms -f"
echo "   This will show you the exact error causing the exit."
echo ""
echo "✅ Deployment complete! Wait 2-3 minutes for full initialization."
echo "   If LibreNMS doesn't start, check logs with: docker service logs monitoring_librenms -f"
