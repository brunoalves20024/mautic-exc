#!/bin/bash
set -e

echo "Starting Mautic Entrypoint..."

# Ensure critical directories exist and have correct permissions
mkdir -p /var/www/html/var/cache /var/www/html/var/logs /var/www/html/var/tmp /var/www/html/media/assets
chown -R www-data:www-data /var/www/html/var /var/www/html/media /var/www/html/config /var/www/html/translations 2>/dev/null || true

# Dump essential environment variables so Cron can see them.
# Mautic commands run via cron MUST have these variables (especially MAUTIC_URL)
# to avoid generating invalid localhost links in emails and tracking pixels.
echo "Exporting environment variables for cron..."
printenv | grep -E '^(MAUTIC_|MYSQL_|DB_|APP_)' > /etc/environment

# Fix Git ownership issue for Composer
git config --global --add safe.directory /var/www/html

# Run Composer if vendor is missing
if [ ! -d "/var/www/html/vendor" ]; then
    echo "Vendor directory not found. Running composer install..."
    # We install dependencies but avoid scripts that might need DB access initially
    sudo -u www-data composer install --no-interaction --optimize-autoloader
fi

# Clear cache if Symfony is fully formed
if [ -f "/var/www/html/bin/console" ]; then
    echo "Clearing Mautic cache..."
    sudo -u www-data php bin/console cache:clear --env=prod || true
fi

echo "Starting services via Supervisor..."
exec "$@"
