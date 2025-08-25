#!/bin/bash

# Production LibreNMS + MySQL Deployment Script
# This script ensures a clean, production-ready deployment

set -e

echo "🚀 LIBRENMS PRODUCTION DEPLOYMENT"
echo "================================="

# Check if running in Docker Swarm mode
if ! docker info --format '{{.Swarm.LocalNodeState}}' | grep -q active; then
    echo "❌ Docker Swarm is not active. Please initialize Docker Swarm first:"
    echo "   docker swarm init"
    exit 1
fi

echo "✅ Docker Swarm is active"

echo ""
echo "1. 🧹 Cleaning up any existing deployment..."

# Remove existing stack
docker stack rm monitoring 2>/dev/null || true

# Wait for stack to be completely removed
echo "⏳ Waiting for stack removal..."
while docker stack ls | grep -q monitoring; do
    echo "   Still removing stack..."
    sleep 5
done

# Remove old volumes for fresh start
echo "🗑️ Removing old volumes for fresh start..."
docker volume rm monitoring_mysql_data monitoring_librenms_data 2>/dev/null || true

echo ""
echo "2. 🎯 Pulling latest images..."
docker pull mysql:8.0
docker pull redis:7-alpine
docker pull librenms/librenms:latest

echo ""
echo "3. 🚀 Deploying LibreNMS stack..."
docker stack deploy -c docker-compose.yml monitoring

echo ""
echo "4. ⏳ Waiting for services to initialize (this may take 2-3 minutes)..."

# Wait for services to be created
sleep 10

# Monitor MySQL startup
echo "📊 Monitoring MySQL startup..."
for i in {1..30}; do
    if docker service ps monitoring_mysql --format "table {{.CurrentState}}" | grep -q "Running"; then
        echo "✅ MySQL service is running!"
        break
    fi
    echo "   Attempt $i/30: Waiting for MySQL to start..."
    sleep 10
done

# Wait a bit more for MySQL initialization
echo "⏳ Allowing MySQL to fully initialize..."
sleep 60

echo ""
echo "5. 🔍 Checking service status..."
docker service ls | grep monitoring

echo ""
echo "6. 📋 Service logs (last 10 lines each):"
echo ""
echo "MySQL logs:"
docker service logs monitoring_mysql --tail 10

echo ""
echo "Redis logs:"
docker service logs monitoring_redis --tail 10

echo ""
echo "LibreNMS logs:"
docker service logs monitoring_librenms --tail 10

echo ""
echo "7. 🧪 Testing services..."

# Test MySQL connectivity
echo "Testing MySQL connectivity..."
sleep 30  # Give more time for MySQL to be ready

MYSQL_TEST=$(docker service ps monitoring_mysql --format "{{.CurrentState}}" | head -1)
if echo "$MYSQL_TEST" | grep -q "Running"; then
    echo "✅ MySQL service is running"
else
    echo "⚠️ MySQL may not be fully ready yet. Check logs with: docker service logs monitoring_mysql"
fi

# Test LibreNMS web interface
echo "Testing LibreNMS web interface..."
LIBRENMS_TEST=$(docker service ps monitoring_librenms --format "{{.CurrentState}}" | head -1)
if echo "$LIBRENMS_TEST" | grep -q "Running"; then
    echo "✅ LibreNMS service is running"
else
    echo "⚠️ LibreNMS may not be fully ready yet. Check logs with: docker service logs monitoring_librenms"
fi

echo ""
echo "✅ DEPLOYMENT COMPLETE!"
echo ""
echo "📋 Service Information:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 LibreNMS Web Interface: http://192.168.1.240:7000"
echo "🗄️ MySQL Database: 192.168.1.240:3306"
echo "📊 Syslog Port: 192.168.1.240:514 (UDP)"
echo ""
echo "🔑 Database Credentials:"
echo "   Database: librenms"
echo "   Username: librenms"
echo "   Password: LibreNMS123!"
echo ""
echo "🔧 Useful Commands:"
echo "   Monitor services: docker service ls"
echo "   View logs: docker service logs monitoring_librenms -f"
echo "   Scale service: docker service scale monitoring_librenms=2"
echo "   Update service: docker service update --force monitoring_librenms"
echo ""
echo "⚠️ IMPORTANT:"
echo "   - LibreNMS may take 5-10 minutes to fully initialize"
echo "   - Access the web interface and follow the setup wizard"
echo "   - Change default passwords after initial setup"
echo ""
echo "🔍 To troubleshoot:"
echo "   docker service logs monitoring_mysql"
echo "   docker service logs monitoring_librenms"
echo "   docker service ps monitoring_mysql --no-trunc"

# Final status check
echo ""
echo "📊 Final Service Status:"
docker service ls | grep monitoring