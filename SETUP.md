# LibreNMS Docker Setup

This Docker Compose configuration provides a complete LibreNMS installation with all necessary components.

## Services Included

- **LibreNMS**: Main web interface accessible on port 8001
- **MariaDB**: Database backend for LibreNMS data
- **Redis**: Caching and session storage
- **Dispatcher**: Background job processing
- **Syslog-ng**: Syslog message collection (port 514 UDP/TCP)
- **SNMP Trapd**: SNMP trap receiver (port 162 UDP)

## Quick Start

1. **Clone or download** this configuration to your desired directory

2. **Edit the .env file** to customize your installation:
   ```bash
   nano .env
   ```
   
   **IMPORTANT**: Change the default passwords in the `.env` file before starting:
   - `MYSQL_ROOT_PASSWORD`
   - `MYSQL_PASSWORD`

3. **Start the services**:
   ```bash
   docker-compose up -d
   ```

4. **Wait for initialization** (this may take a few minutes on first run):
   ```bash
   docker-compose logs -f librenms
   ```

5. **Access LibreNMS**:
   - Open your web browser to: http://localhost:8001
   - Follow the web installer to complete setup

## Initial Setup

After accessing the web interface:

1. Complete the web installer wizard
2. Create an admin user account
3. Configure your first devices to monitor

## Directory Structure

The following directories will be created for persistent data:
```
librenms/
├── data/          # LibreNMS configuration and data
├── logs/          # Application logs
├── rrd/           # RRD database files
├── storage/       # File storage
├── mysql/         # Database files
└── syslog/        # Syslog files
```

## Useful Commands

### View logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f librenms
docker-compose logs -f db
```

### Restart services
```bash
docker-compose restart
```

### Update containers
```bash
docker-compose pull
docker-compose up -d
```

### Stop and remove
```bash
docker-compose down

# Remove volumes as well (WARNING: This deletes all data!)
docker-compose down -v
```

## Port Configuration

- **8001**: LibreNMS web interface
- **514**: Syslog receiver (UDP/TCP)
- **162**: SNMP trap receiver (UDP)

## Security Considerations

1. **Change default passwords** in the `.env` file
2. **Configure firewall rules** to restrict access to necessary ports
3. **Use HTTPS** in production (consider adding a reverse proxy like nginx)
4. **Regular backups** of the `librenms/` directory
5. **Keep containers updated** regularly

## Troubleshooting

### Container won't start
```bash
# Check container status
docker-compose ps

# View detailed logs
docker-compose logs librenms
```

### Database connection issues
```bash
# Check database status
docker-compose logs db

# Verify database connectivity
docker-compose exec librenms php artisan migrate:status
```

### Performance tuning
- Adjust `POLLERS` in `.env` file based on your monitoring needs
- Monitor resource usage: `docker stats`

## Backup

Create a backup of your LibreNMS installation:
```bash
# Stop services
docker-compose down

# Backup data
tar -czf librenms-backup-$(date +%Y%m%d).tar.gz librenms/

# Restart services
docker-compose up -d
```

## Support

- LibreNMS Documentation: https://docs.librenms.org/
- LibreNMS Community: https://community.librenms.org/