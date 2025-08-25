#!/bin/bash

# Host Network Mode Fix for LibreNMS Database Connectivity
# Final solution: Use host networking to bypass Docker Swarm overlay network issues

set -e

echo "🌐 HOST NETWORK FIX for LibreNMS Database Connectivity"
echo "====================================================="

echo "Problem: Docker Swarm overlay network prevents LibreNMS from connecting to MySQL"
echo "Solution: Use host network mode and localhost connections"

# Clean up existing deployment
echo "🧹 Cleaning up existing deployment..."
docker stack rm monitoring 2>/dev/null || true
sleep 15

echo "🚀 Deploying with HOST NETWORK mode..."

cat > docker-compose-host-network.yml << 'EOF'
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
      - mode: host
        target: 3306
        published: 3306
        protocol: tcp
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - host
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
    ports:
      - mode: host
        target: 6379
        published: 6379
        protocol: tcp
    networks:
      - host
    command: redis-server --appendonly yes

  librenms:
    image: librenms/librenms:latest
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 60s
        max_attempts: 5
        window: 600s
      placement:
        constraints:
          - node.role == manager
    ports:
      - mode: host
        target: 8000
        published: 7000
        protocol: tcp
    environment:
      - TZ=UTC
      - PUID=1000
      - PGID=1000
      - DB_HOST=127.0.0.1
      - DB_PORT=3306
      - DB_NAME=librenms
      - DB_USER=librenms
      - DB_PASSWORD=LibreNMS123!
      - DB_TIMEOUT=60
      - REDIS_HOST=127.0.0.1
      - REDIS_PORT=6379
      - REDIS_DB=0
      - BASE_URL=http://192.168.1.240:7000
      - POLLERS=4
    volumes:
      - librenms_data:/data
    networks:
      - host

networks:
  host:
    external: true
    name: host

volumes:
  mysql_data:
  librenms_data:
EOF

# Deploy the stack
docker stack deploy -c docker-compose-host-network.yml monitoring

echo ""
echo "⏳ Waiting for MySQL to start with host networking (60 seconds)..."
sleep 60

echo ""
echo "🧪 Testing MySQL connectivity via localhost..."
if mysql -h 127.0.0.1 -P 3306 -u librenms -pLibreNMS123! -e "SELECT 'Host network MySQL working!' as result;" 2>/dev/null; then
    echo "✅ MySQL is accessible via localhost!"
else
    echo "⚠️ MySQL localhost connection test failed"
fi

echo ""
echo "⏳ Waiting for LibreNMS to connect (90 seconds)..."
sleep 90

echo ""
echo "📊 Service status:"
docker service ls

echo ""
echo "🔍 LibreNMS logs:"
docker service logs monitoring_librenms --tail 20

echo ""
echo "🧪 Testing web interface:"
curl -s -I http://127.0.0.1:7000 | head -3 || echo "Web interface not ready yet"

echo ""
echo "✅ HOST NETWORK DEPLOYMENT COMPLETE!"
echo ""
echo "📋 Access Information:"
echo "🌐 LibreNMS Web: http://192.168.1.240:7000"
echo "🗄️ MySQL: 127.0.0.1:3306 (host network)"
echo "🔑 Credentials: librenms / LibreNMS123!"
echo ""
echo "🔧 This deployment uses host networking to bypass Docker Swarm overlay network issues"