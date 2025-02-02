#!/bin/sh
set -e

echo "⏳ Waiting for database to become available..."
until PGPASSWORD=$(cat /run/secrets/postgres_password) psql -h "timescaledb" -U "tradesmart" -d "postgres" -c "SELECT 1"; do
  echo "Waiting for database..."
  sleep 5
done
echo "✅ Database is ready!"

# Ensure directories and permissions
mkdir -p /backups/logs
chmod +x /scripts/*.sh

# ✅ Capture runtime environment variables dynamically at container startup
printenv > /etc/environment

# Ensure cron jobs are registered from mounted file
CRON_FILE="/etc/cron.d/bk-crons"
if [ -f "$CRON_FILE" ]; then
    echo "Registering cron jobs from mounted file..."
    cat "$CRON_FILE" > /var/spool/cron/crontabs/root
    chmod 0600 /var/spool/cron/crontabs/root
else
    echo "⚠ WARNING: Cron jobs file not found at $CRON_FILE! Skipping cron registration."
fi

echo "🔍 Current cron jobs:"
crontab -l

# Start 'crond' in the foreground so Docker keeps the container alive.
echo "🔄 Starting cron daemon (foreground)..."
exec crond -f -l 8

# Keep container running
echo "👂 Listening for cron logs..."
touch /backups/logs/cron_backup.log
tail -f /backups/logs/cron_backup.log
