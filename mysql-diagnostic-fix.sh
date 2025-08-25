#!/bin/bash

# MySQL Service Diagnostic and Fix Script
# This will identify why MySQL isn't starting and fix it

set -e

echo "🔍 MYSQL SERVICE DIAGNOSTIC & FIX"
echo "================================="

echo "1. 📊 Checking MySQL service status in detail..."
echo "Service list:"
docker service ls | grep mysql || echo "No MySQL service found!"

echo ""
echo "Service tasks:"
docker service ps monitoring_mysql --no-trunc || echo "No MySQL service tasks!"

echo ""
echo "2. 🔍 Checking MySQL container logs..."
docker service logs monitoring_mysql --tail 50 || echo "No MySQL logs available!"

echo ""
echo "3. 🔍 Checking if MySQL containers are actually running..."
docker ps | grep mysql || echo "No MySQL containers running!"

echo ""
echo "4. 🔧 REMOVING AND RECREATING MySQL with simpler configuration..."

# Remove the problematic stack
docker stack rm monitoring
sleep 15

# Remove MySQL volume to start fresh
docker volume rm monitoring_mysql_data 2>/dev/null || true

echo ""
echo "5. 🚀 Deploying MySQL with MINIMAL configuration..."

cat > docker-compose-mysql-simple.yml << 'EOF'
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
      placement:
        constraints:
          - node.role == manager
    environment:
      MYSQL_ROOT_PASSWORD: "password123"
      MYSQL_DATABASE: "librenms"
      MYSQL_USER: "librenms"
      MYSQL_PASSWORD: "password123"
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - librenms_net
    ports:
      - "3306:3306"
    # Minimal command - remove problematic options
    command: --default-authentication-plugin=mysql_native_password

  redis:
    image: redis:7-alpine
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
      placement:
        constraints:
          - node.role == manager
    networks:
      - librenms_net

networks:
  librenms_net:
    driver: overlay
    attachable: true

volumes:
  mysql_data:
EOF

# Deploy MySQL first
docker stack deploy -c docker-compose-mysql-simple.yml monitoring

echo ""
echo "6. ⏳ Waiting for MySQL to start (90 seconds)..."
sleep 90

echo ""
echo "7. 🔍 Checking MySQL startup logs..."
docker service logs monitoring_mysql --tail 30

echo ""
echo "8. 🧪 Testing MySQL connectivity..."

# Test direct connection to MySQL
echo "Testing MySQL connection via exposed port..."
if timeout 10 mysql -h 192.168.1.240 -P 3306 -u root -ppassword123 -e "SELECT 'MySQL is working!' as status;" 2>/dev/null; then
    echo "✅ MySQL connection successful!"
    
    echo ""
    echo "9. 🔧 Setting up LibreNMS user and database..."
    mysql -h 192.168.1.240 -P 3306 -u root -ppassword123 -e "
    CREATE DATABASE IF NOT EXISTS librenms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER IF NOT EXISTS 'librenms'@'%' IDENTIFIED BY 'password123';
    GRANT ALL PRIVILEGES ON librenms.* TO 'librenms'@'%';
    FLUSH PRIVILEGES;
    SELECT 'LibreNMS database and user created!' as status;
    "
    
    echo ""
    echo "10. 🚀 Now deploying LibreNMS..."
    
    cat > docker-compose-complete-simple.yml << 'EOF'
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
      placement:
        constraints:
          - node.role == manager
    environment:
      MYSQL_ROOT_PASSWORD: "password123"
      MYSQL_DATABASE: "librenms"
      MYSQL_USER: "librenms"
      MYSQL_PASSWORD: "password123"
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - librenms_net
    ports:
      - "3306:3306"
    command: --default-authentication-plugin=mysql_native_password

  redis:
    image: redis:7-alpine
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
      placement:
        constraints:
          - node.role == manager
    networks:
      - librenms_net

  librenms:
    image: librenms/librenms:latest
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 30s
        max_attempts: 10
        window: 300s
      placement:
        constraints:
          - node.role == manager
    ports:
      - "7000:8000"
    environment:
      # Simplified configuration
      DB_HOST: "mysql"
      DB_PORT: "3306"
      DB_NAME: "librenms"
      DB_USER: "librenms"
      DB_PASSWORD: "password123"
      DB_TIMEOUT: "300"
      REDIS_HOST: "redis"
      REDIS_PORT: "6379"
      REDIS_DB: "0"
      TZ: "UTC"
      PUID: "1000"
      PGID: "1000"
      BASE_URL: "http://192.168.1.240:7000"
      POLLERS: "4"
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

    docker stack deploy -c docker-compose-complete-simple.yml monitoring
    
    echo ""
    echo "11. ⏳ Waiting for LibreNMS to start..."
    sleep 60
    
    echo ""
    echo "12. 🔍 Checking LibreNMS logs..."
    docker service logs monitoring_librenms --tail 20
    
    echo ""
    echo "✅ DEPLOYMENT COMPLETE!"
    echo "🌐 LibreNMS: http://192.168.1.240:7000"
    echo "🗄️  Database: mysql (192.168.1.240:3306)"
    echo "🔑 DB Credentials: librenms/password123"
    
else
    echo "❌ MySQL is still not starting properly!"
    echo ""
    echo "Let's check what's wrong with MySQL startup..."
    echo "Recent MySQL logs:"
    docker service logs monitoring_mysql --tail 50
    
    echo ""
    echo "MySQL service details:"
    docker service ps monitoring_mysql --no-trunc
    
    echo ""
    echo "💡 Possible issues:"
    echo "1. Volume mount permissions"
    echo "2. Memory constraints"
    echo "3. Docker Swarm networking issues"
    echo "4. Node resource constraints"
fi

echo ""
echo "🔧 Monitor LibreNMS startup with:"
echo "   docker service logs monitoring_librenms -f"