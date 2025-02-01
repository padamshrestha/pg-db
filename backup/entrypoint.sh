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

# ✅ Define cron job for 8 AM UTC => 12 AM PST
CRON_TIME="0 8 * * *"
BACKUP_COMMAND="/scripts/backup.sh >> /backups/logs/cron_backup.log 2>&1"

# ✅ Set up the cron job
echo "⏳ Configuring scheduled backups..."
echo "🕒 Scheduled backup time (UTC): $CRON_TIME"
echo "SHELL=/bin/sh" > /etc/crontabs/root  # Ensure cron uses the correct shell
echo "$CRON_TIME $BACKUP_COMMAND" >> /etc/crontabs/root  # Write to cron file

# ✅ Verify cron jobs before starting
echo "🔍 Current cron jobs:"
crontab -l

# Start cron daemon in foreground
echo "🔄 Starting cron daemon..."
crond &  # ✅ Run in background so script continues

# Keep container running
echo "👂 Listening for cron logs..."
touch /backups/logs/cron_backup.log
tail -f /backups/logs/cron_backup.log
