# Monitoring Stack

A Docker-based monitoring solution featuring LibreNMS for comprehensive network monitoring and infrastructure management.

## Overview

This repository provides a complete, production-ready LibreNMS deployment using Docker Compose. LibreNMS is an autodiscovering PHP/MySQL/SNMP based network monitoring which includes support for a wide range of network hardware and operating systems.

## Features

- **Complete LibreNMS Stack**: Web interface, database, caching, and background services
- **SNMP Monitoring**: Automatic device discovery and comprehensive monitoring
- **Syslog Collection**: Centralized log collection and analysis
- **SNMP Trap Reception**: Real-time trap processing and alerting
- **Performance Monitoring**: RRD-based graphing and historical data
- **Alert Management**: Configurable alerting system with multiple notification channels
- **Easy Deployment**: One-command Docker Compose deployment
- **Persistent Storage**: Data persistence across container restarts
- **Production Ready**: Optimized configuration with security considerations

## Quick Start

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd monitoring-stack
   ```

2. **Configure passwords**:
   Edit `docker-compose.yml` and update the following passwords:
   - `POSTGRES_PASSWORD` and `DB_PASSWORD` (both should match)

3. **Deploy the stack**:
   
   **Docker Compose:**
   ```bash
   docker-compose up -d
   ```
   
   **Docker Swarm:**
   ```bash
   docker stack deploy -c docker-compose.yml monitoring
   ```

4. **Access LibreNMS**:
   - Open http://localhost:7000
   - Follow the web installer
   - Create your admin account

## Services

- **LibreNMS**: Main monitoring application (port 7000)
- **PostgreSQL**: Database backend
- **Redis**: Caching and session storage
- **Dispatcher**: Background job processing
- **Syslog-ng**: Log collection service (port 514)
- **SNMP Trapd**: SNMP trap receiver (port 162)

## Documentation

- [Setup Guide](SETUP.md) - Detailed installation and configuration instructions
- [Changelog](CHANGELOG.md) - Version history and updates
- [LibreNMS Documentation](https://docs.librenms.org/) - Official documentation

## Requirements

- Docker Engine 20.10+
- Docker Compose 2.0+
- 2GB RAM minimum (4GB recommended)
- 10GB disk space minimum

## Security

- Change default passwords in `docker-compose.yml` before deployment
- Configure firewall rules for exposed ports
- Regular security updates recommended
- Use HTTPS in production environments

## Support

For issues and questions:
- Check the [Setup Guide](SETUP.md) for troubleshooting
- Review [LibreNMS Community](https://community.librenms.org/)
- Open an issue in this repository

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.