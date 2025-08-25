#!/bin/bash

# LibreNMS Database Connection Debug & Fix
# This will diagnose and fix the database connection issue

set -e

echo "🔍 DEBUGGING LibreNMS Database Connection Issue"
echo "=============================================="

echo "1. 📊 Current service status:"
docker service ls

echo ""
echo "2. 🔍 Checking MySQL service details:"
docker service ps monitoring_mysql --no-trunc

echo ""
echo "3. 🧪 Testing MySQL connectivity from external container..."

# Test MySQL connectivity
echo "   Testing MySQL root connection..."
if docker run --rm --network monitoring_librenms_net mysql:8.0 mysql -h mysql -u root -pLibreNMS123! -e "SELECT 'Root connection works!' as test;" 2>/dev/null; then
    echo "   ✅ Root connection successful!"
else
    echo "   ❌ Root connection failed!"
fi

echo "   Testing LibreNMS user connection..."
if docker run --rm --network monitoring_librenms_net mysql:8.0 mysql -h mysql -u librenms -pLibreNMS123! -e "SELECT 'LibreNMS user works!' as test;" 2>/dev/null; then
    echo "   ✅ LibreNMS user connection successful!"
else
    echo "   ❌ LibreNMS user connection failed!"
fi

echo ""
echo "4. 🔍 Checking MySQL grants and users..."
echo "   Showing MySQL users:"
docker run --rm --network monitoring_librenms_net mysql:8.0 mysql -h mysql -u root -pLibreNMS123! -e "SELECT User, Host FROM mysql.user;" 2>/dev/null || echo "Could not query users"

echo ""
echo "5. 🔧 FIXING MySQL permissions..."

# Fix MySQL user permissions
docker run --rm --network monitoring_librenms_net mysql:8.0 mysql -h mysql -u root -pLibreNMS123! -e "
CREATE USER IF NOT EXISTS 'librenms'@'%' IDENTIFIED BY 'LibreNMS123!';
GRANT ALL PRIVILEGES ON librenms.* TO 'librenms'@'%';
FLUSH PRIVILEGES;
SELECT 'MySQL permissions updated!' as status;
" 2>/dev/null || echo "Could not update permissions"

echo ""
echo "6. 🧪 Testing connection again after fix..."
if docker run --rm --network monitoring_librenms_net mysql:8.0 mysql -h mysql -u librenms -pLibreNMS123! librenms -e "SELECT 'Connection to librenms DB works!' as test;" 2>/dev/null; then
    echo "   ✅ LibreNMS database connection now works!"
else
    echo "   ❌ Still having connection issues"
fi

echo ""
echo "7. 🚀 Restarting LibreNMS service..."
docker service update --force monitoring_librenms

echo ""
echo "8. ⏳ Waiting 60 seconds for LibreNMS to restart..."
sleep 60

echo ""
echo "9. 🔍 Checking LibreNMS logs after restart:"
docker service logs monitoring_librenms --tail 15

echo ""
echo "🎯 If you still see database connection errors, the issue might be:"
echo "   1. MySQL container not fully ready (wait longer)"
echo "   2. LibreNMS connecting to wrong host (check DB_HOST)"
echo "   3. Password mismatch (verify MYSQL_PASSWORD = DB_PASSWORD)"
echo ""
echo "💡 Run this to monitor LibreNMS startup in real-time:"
echo "   docker service logs monitoring_librenms -f"