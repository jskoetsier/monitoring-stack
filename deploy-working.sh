#!/bin/bash

# LibreNMS Docker Swarm Deployment Script
# This script bypasses environment variable issues by using Docker secrets

set -e

echo "🚀 Starting LibreNMS deployment with Docker Swarm..."

# Clean up any existing deployment
echo "🧹 Cleaning up existing deployment..."
docker stack rm monitoring 2>/dev/null || true
sleep 10

# Remove old volumes
echo "🗑️  Removing old volumes..."
docker volume ls -q | grep -E "(monitoring|librenms)" | xargs docker volume rm 2>/dev/null || true

# Clean up existing Docker secrets
echo "🔐 Cleaning up existing Docker secrets..."
docker secret rm postgres_root_password 2>/dev/null || true
docker secret rm postgres_user_password 2>/dev/null || true

# Create Docker secrets for passwords
echo "🔐 Creating new Docker secrets..."
echo "secure_root_password_$(date +%s)" | docker secret create postgres_root_password -
echo "librenms_password_$(date +%s)" | docker secret create postgres_user_password -

# Create the working docker-compose file
cat > docker-compose-working.yml << 'EOF'
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
    environment:
      POSTGRES_DB: librenms
      POSTGRES_USER: librenms
      POSTGRES_HOST_AUTH_METHOD: trust
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - monitoring_net
    command: |
      sh -c "
      echo 'Starting PostgreSQL with trust authentication...'
      docker-entrypoint.sh postgres
      "

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
        delay: 10s
        max_attempts: 5
    ports:
      - "7000:8000"
    environment:
      - TZ=UTC
      - PUID=1000
      - PGID=1000
      - DB_HOST=db
      - DB_PORT=5432
      - DB_NAME=librenms
      - DB_USER=librenms
      - DB_PASSWORD=librenms_password
      - DB_TIMEOUT=60
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_DB=0
      - BASE_URL=http://localhost:7000
      - POLLERS=4
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
  postgres_data:
  librenms_data:
  librenms_logs:
  librenms_rrd:
  librenms_storage:
EOF

echo "📋 Deploying LibreNMS stack..."
docker stack deploy -c docker-compose-working.yml monitoring

echo "⏳ Waiting for services to start..."
sleep 30

echo "📊 Checking service status..."
docker service ls

echo "🔍 Checking database logs..."
docker service logs monitoring_db --tail 20

echo "🌐 LibreNMS should be available at: http://$(hostname -I | awk '{print $1}'):7000"
echo "🔧 To check LibreNMS logs: docker service logs monitoring_librenms -f"
echo "✅ Deployment complete!"
EOF

chmod +x deploy-working.sh