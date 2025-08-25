#!/bin/bash

# Test Script for LibreNMS Stack
# This script tests the deployment and provides health checks

set -e

echo "🧪 LIBRENMS STACK TESTING"
echo "========================="

echo ""
echo "1. 🔍 Service Status Check"
echo "──────────────────────────"
docker service ls | grep monitoring || echo "❌ No monitoring services found!"

echo ""
echo "2. 📊 Service Details"
echo "────────────────────"
services=("monitoring_mysql" "monitoring_redis" "monitoring_librenms" "monitoring_dispatcher" "monitoring_syslog")

for service in "${services[@]}"; do
    echo ""
    echo "🔸 $service:"
    if docker service inspect "$service" >/dev/null 2>&1; then
        echo "  Status: $(docker service ps "$service" --format "{{.CurrentState}}" | head -1)"
        echo "  Image: $(docker service inspect "$service" --format "{{.Spec.TaskTemplate.ContainerSpec.Image}}")"
        echo "  Replicas: $(docker service ls --filter name="$service" --format "{{.Replicas}}")"
    else
        echo "  ❌ Service not found"
    fi
done

echo ""
echo "3. 🌐 Network Connectivity Tests"
echo "───────────────────────────────"

# Test web interface
echo "Testing LibreNMS web interface..."
if curl -s -o /dev/null -w "%{http_code}" "http://192.168.1.240:7000" | grep -q "200\|302\|403"; then
    echo "✅ LibreNMS web interface is accessible"
else
    echo "⚠️ LibreNMS web interface may not be ready yet"
fi

# Test MySQL port
echo "Testing MySQL port..."
if timeout 5 bash -c '</dev/tcp/192.168.1.240/3306' 2>/dev/null; then
    echo "✅ MySQL port 3306 is open"
else
    echo "⚠️ MySQL port 3306 is not accessible"
fi

echo ""
echo "4. 📋 Recent Service Logs"
echo "────────────────────────"

for service in "${services[@]}"; do
    if docker service inspect "$service" >/dev/null 2>&1; then
        echo ""
        echo "🔸 $service (last 5 lines):"
        docker service logs "$service" --tail 5 2>/dev/null || echo "  No logs available"
    fi
done

echo ""
echo "5. 💾 Volume Status"
echo "─────────────────"
echo "Monitoring volumes:"
docker volume ls | grep monitoring || echo "No monitoring volumes found"

echo ""
echo "6. 🔗 Network Status"
echo "──────────────────"
echo "Monitoring networks:"
docker network ls | grep monitoring || echo "No monitoring networks found"

echo ""
echo "7. 📈 Resource Usage"
echo "──────────────────"
echo "Docker system info:"
echo "Images: $(docker image ls | wc -l) total"
echo "Containers: $(docker ps -a | wc -l) total"
echo "Volumes: $(docker volume ls | wc -l) total"
echo "Networks: $(docker network ls | wc -l) total"

echo ""
echo "8. 🎯 Service Health Summary"
echo "──────────────────────────"

total_services=0
running_services=0

for service in "${services[@]}"; do
    total_services=$((total_services + 1))
    if docker service inspect "$service" >/dev/null 2>&1; then
        status=$(docker service ps "$service" --format "{{.CurrentState}}" | head -1)
        if echo "$status" | grep -q "Running"; then
            running_services=$((running_services + 1))
            echo "✅ $service: Running"
        else
            echo "⚠️ $service: $status"
        fi
    else
        echo "❌ $service: Not found"
    fi
done

echo ""
echo "📊 Health Score: $running_services/$total_services services running"

if [ "$running_services" -eq "$total_services" ]; then
    echo "🎉 All services are healthy!"
    echo ""
    echo "🌐 Access LibreNMS at: http://192.168.1.240:7000"
    echo "🔧 Default login will be created during first setup"
elif [ "$running_services" -gt 0 ]; then
    echo "⚠️ Some services may still be starting. Wait a few minutes and run this test again."
    echo "🔍 Check logs with: docker service logs <service_name>"
else
    echo "❌ No services are running. Check deployment with: docker service ls"
fi

echo ""
echo "🔧 Useful Commands:"
echo "  Monitor logs: docker service logs monitoring_librenms -f"
echo "  Restart service: docker service update --force monitoring_librenms"
echo "  Scale service: docker service scale monitoring_librenms=2"
echo "  Remove stack: docker stack rm monitoring"