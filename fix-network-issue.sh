#!/bin/bash

# LibreNMS Network Connectivity Fix
# The issue is Docker Swarm network naming and connectivity

set -e

echo "🔧 FIXING LibreNMS Network Connectivity Issue"
echo "============================================="

echo "1. 🔍 Identifying the actual network name..."
echo "   Available networks:"
docker network ls | grep monitoring

# Get the actual network name created by Docker Swarm
ACTUAL_NETWORK=$(docker network ls --format "{{.Name}}" | grep monitoring | grep librenms || echo "")

if [ -z "$ACTUAL_NETWORK" ]; then
    echo "   ❌ No monitoring network found! Creating it..."
    # The network doesn't exist, so let's redeploy to create it properly
    docker stack rm monitoring
    sleep 15
    
    echo "2. 🚀 Redeploying stack to fix network issues..."
    cat > docker-compose-network-fixed.yml << 'EOF'
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
      --innodb-buffer-pool-size=512M
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --bind-address=0.0.0.0
    ports:
      - target: 3306
        published: 3306
        protocol: tcp
        mode: host

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
        delay: 60s
        max_attempts: 5
        window: 300s
    ports:
      - target: 8000
        published: 7000
        protocol: tcp
        mode: ingress
    environment:
      # Database Configuration - Use service name for internal communication
      DB_HOST: "mysql"
      DB_PORT: "3306"
      DB_NAME: "librenms"
      DB_USER: "librenms"
      DB_PASSWORD: "LibreNMS123!"
      DB_TIMEOUT: "300"
      
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
    depends_on:
      - mysql
      - redis

networks:
  librenms_net:
    driver: overlay
    attachable: true
    driver_opts:
      encrypted: "false"

volumes:
  mysql_data:
    driver: local
  librenms_data:
    driver: local
EOF

    docker stack deploy -c docker-compose-network-fixed.yml monitoring
    
    echo "⏳ Waiting for MySQL to start (60 seconds)..."
    sleep 60
    
    # Update the network name after redeployment
    ACTUAL_NETWORK=$(docker network ls --format "{{.Name}}" | grep monitoring | grep librenms || echo "")
fi

if [ ! -z "$ACTUAL_NETWORK" ]; then
    echo "   ✅ Found network: $ACTUAL_NETWORK"
    
    echo ""
    echo "3. 🧪 Testing MySQL connectivity with correct network..."
    
    # Test using localhost since we exposed port 3306
    echo "   Testing MySQL via localhost (exposed port)..."
    if docker run --rm mysql:8.0 mysql -h 192.168.1.240 -P 3306 -u root -pLibreNMS123! -e "SELECT 'MySQL accessible via localhost!' as test;" 2>/dev/null; then
        echo "   ✅ MySQL accessible via exposed port!"
    else
        echo "   ❌ MySQL not accessible via exposed port"
    fi
    
    # Test using the overlay network
    echo "   Testing MySQL via overlay network..."
    if docker run --rm --network $ACTUAL_NETWORK mysql:8.0 mysql -h mysql -u root -pLibreNMS123! -e "SELECT 'MySQL accessible via overlay!' as test;" 2>/dev/null; then
        echo "   ✅ MySQL accessible via overlay network!"
        
        echo ""
        echo "4. 🔧 Fixing MySQL user permissions..."
        docker run --rm --network $ACTUAL_NETWORK mysql:8.0 mysql -h mysql -u root -pLibreNMS123! -e "
        CREATE USER IF NOT EXISTS 'librenms'@'%' IDENTIFIED BY 'LibreNMS123!';
        GRANT ALL PRIVILEGES ON librenms.* TO 'librenms'@'%';
        FLUSH PRIVILEGES;
        SELECT 'MySQL permissions updated!' as status;
        " 2>/dev/null && echo "   ✅ Permissions updated successfully!"
        
    else
        echo "   ❌ MySQL still not accessible via overlay network"
    fi
else
    echo "   ❌ Still no network found after redeployment"
fi

echo ""
echo "5. 📊 Current service status:"
docker service ls

echo ""
echo "6. 🔍 Checking LibreNMS logs:"
docker service logs monitoring_librenms --tail 10

echo ""
echo "🎯 MySQL should now be accessible at:"
echo "   Internal (container-to-container): mysql:3306"
echo "   External: 192.168.1.240:3306"
echo ""
echo "🌐 LibreNMS should be available at: http://192.168.1.240:7000"
echo ""
echo "💡 Monitor LibreNMS startup with:"
echo "   docker service logs monitoring_librenms -f"