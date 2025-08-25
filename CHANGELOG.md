# Changelog

All notable changes to this monitoring stack project will be documented in this file.

## [1.2.1] - MariaDB Environment Variables Fix

### Fixed
- Updated MariaDB environment variables from `MYSQL_*` to `MARIADB_*` format
- Fixed database initialization error for MariaDB 10.11+
- Updated all documentation to reference correct environment variable names

### Changed
- `MYSQL_ROOT_PASSWORD` → `MARIADB_ROOT_PASSWORD`
- `MYSQL_DATABASE` → `MARIADB_DATABASE` 
- `MYSQL_USER` → `MARIADB_USER`
- `MYSQL_PASSWORD` → `MARIADB_PASSWORD`

## [1.2.0] - Docker Swarm Compatibility

### Changed
- Removed `.env` file dependency for Docker Swarm compatibility
- Moved all environment variables directly into `docker-compose.yml`
- Updated all documentation to reference `docker-compose.yml` instead of `.env`
- Improved password security with more descriptive default placeholders

### Removed
- `.env` file (configuration now embedded in docker-compose.yml)

## [1.1.0] - Port Update

### Changed
- Updated LibreNMS web interface port from 8001 to 7000
- Updated BASE_URL configuration to reflect new port
- Updated all documentation to reference new port 7000

## [1.0.0] - Initial Release

### Added
- Complete LibreNMS Docker Compose stack
- MariaDB database backend with optimized configuration
- Redis caching service for improved performance
- Background dispatcher service for job processing
- Syslog-ng service for centralized log collection
- SNMP trapd service for trap reception
- Environment-based configuration with `.env` file
- Comprehensive setup documentation
- Production-ready security considerations
- Persistent data storage with Docker volumes
- Network monitoring capabilities with SNMP autodiscovery
- Web interface accessible on configurable port (default: 7000)
- Alert management system
- Performance monitoring with RRD graphing

### Configuration
- LibreNMS web interface exposed on port 7000
- Syslog collection on port 514 (UDP/TCP)
- SNMP trap reception on port 162 (UDP)
- Customizable polling intervals and worker processes
- Secure default database configuration
- Automated cron job scheduling for maintenance tasks

### Documentation
- Initial README with project overview
- Detailed setup guide with troubleshooting
- Environment configuration examples
- Security best practices
- Backup and maintenance procedures