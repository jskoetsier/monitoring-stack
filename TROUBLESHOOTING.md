# LibreNMS Docker Troubleshooting Guide

## MariaDB "Database is uninitialized and password option is not specified" Error

If you encounter this error during deployment, try these solutions in order:

### Solution 1: Clean Start with Volume Removal

#### For Docker Compose:
```bash
# Stop all containers and remove volumes
docker-compose down -v

# Remove any existing LibreNMS data directories
sudo rm -rf librenms/

# Pull latest images
docker-compose pull

# Start services
docker-compose up -d
```

#### For Docker Swarm:
```bash
# Remove the stack (replace 'monitoring' with your stack name)
docker stack rm monitoring

# Wait for stack to be completely removed
docker stack ls

# Remove volumes (list them first to see what exists)
docker volume ls | grep monitoring
docker volume rm $(docker volume ls -q | grep monitoring)

# Remove any existing LibreNMS data directories
sudo rm -rf librenms/

# Prune unused containers, networks, and images
docker system prune -f

# Pull latest images on all nodes
docker-compose pull

# Redeploy the stack
docker stack deploy -c docker-compose.yml monitoring
```

### Solution 2: Check Environment Variables
Verify the MariaDB environment variables in `docker-compose.yml`:
```yaml
environment:
  MARIADB_ROOT_PASSWORD: "your_secure_password_here"
  MARIADB_DATABASE: "librenms"
  MARIADB_USER: "librenms"
  MARIADB_PASSWORD: "your_librenms_password_here"
```

**Important**: Ensure both `MARIADB_PASSWORD` and `DB_PASSWORD` match across all services.

### Solution 3: Manual Container Testing
Test the MariaDB container independently:
```bash
# Run MariaDB container manually to test
docker run --rm -e MARIADB_ROOT_PASSWORD="test123" -e MARIADB_DATABASE="test" mariadb:10.11

# If successful, the issue is with the docker-compose configuration
```

### Solution 4: Alternative MariaDB Configuration
If the issue persists, try using the legacy MySQL environment variables:
```yaml
# In docker-compose.yml, replace MariaDB environment section with:
environment:
  MYSQL_ROOT_PASSWORD: "secure_root_password_change_me"
  MYSQL_DATABASE: "librenms"
  MYSQL_USER: "librenms"
  MYSQL_PASSWORD: "secure_librenms_password_change_me"
  TZ: "UTC"
```

### Solution 5: Use MariaDB 10.6 (Stable)
If MariaDB 10.11 continues to cause issues, use the stable 10.6 version:
```yaml
# Change the image line in docker-compose.yml
image: mariadb:10.6
```

## Common LibreNMS Issues

### "DB_HOST must be defined" Error
- Ensure environment variables use dictionary format (`KEY: value`)
- Check that all LibreNMS containers have matching database credentials
- Verify the database container name matches `DB_HOST` value

### Container Won't Start

#### For Docker Compose:
```bash
# Check container logs
docker-compose logs [service_name]

# Check container status
docker-compose ps

# Restart specific service
docker-compose restart [service_name]
```

#### For Docker Swarm:
```bash
# Check service status
docker service ls

# Check service logs (replace 'monitoring_librenms' with your service name)
docker service logs monitoring_librenms

# Check service details
docker service inspect monitoring_librenms

# Scale service (restart by scaling to 0 then back to 1)
docker service scale monitoring_librenms=0
docker service scale monitoring_librenms=1

# Update service to force restart
docker service update --force monitoring_librenms
```

### Performance Issues
- Increase `POLLERS` value in LibreNMS environment
- Allocate more memory to Docker
- Use SSD storage for better performance

### Network Issues
```bash
# Check network connectivity between containers
docker-compose exec librenms ping db
docker-compose exec librenms ping redis
```

## Quick Fixes

### Reset Everything (Nuclear Option)
```bash
docker-compose down -v
sudo rm -rf librenms/
docker system prune -f
docker-compose up -d
```

### Check Service Dependencies
```bash
# Ensure services start in correct order
docker-compose up db redis
# Wait for database to be ready, then:
docker-compose up librenms
```

### Verify Database Connection
```bash
# Once LibreNMS is running, test database connectivity
docker-compose exec librenms php artisan migrate:status
```

## Getting Help

If issues persist:
1. Check the logs: `docker-compose logs -f`
2. Verify system resources: `docker stats`
3. Review LibreNMS documentation: https://docs.librenms.org/
4. Join the LibreNMS community: https://community.librenms.org/
