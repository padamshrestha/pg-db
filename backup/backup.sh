#!/bin/sh
set -e

# Load PostgreSQL password securely
PGPASSWORD=$(cat /run/secrets/postgres_password)

# Get a list of all databases, excluding system databases
DB_LIST=$(PGPASSWORD=$PGPASSWORD psql -h "$PG_HOST" -U "$PG_USER" -d postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres');" | tr -d ' ')

# Define the backup root and log directory
BACKUP_ROOT="/backups"
LOG_DIR="/backups/logs"

# Ensure backup and log directories exist
mkdir -p "$BACKUP_ROOT"
mkdir -p "$LOG_DIR"

# Log file for this backup run
LOG_FILE="$LOG_DIR/backup_$(date +%Y%m%d_%H%M%S).log"

# Log start time
echo "Starting database backup at $(date)" | tee -a "$LOG_FILE"

# Loop through each database and create a backup in its own folder
for DB in $DB_LIST; do
  BACKUP_DIR="$BACKUP_ROOT/$DB"
  mkdir -p "$BACKUP_DIR"  # Create database-specific folder if it doesn't exist
  
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  BACKUP_FILE="$BACKUP_DIR/${DB}_$TIMESTAMP.sql.gz"
  DB_LOG_FILE="$BACKUP_DIR/${DB}_$TIMESTAMP.log"

  echo "Backing up database: $DB" | tee -a "$LOG_FILE" "$DB_LOG_FILE"

  if ! PGPASSWORD=$PGPASSWORD pg_dump -h "$PG_HOST" -U "$PG_USER" -d "$DB" | gzip > "$BACKUP_FILE" 2>>"$DB_LOG_FILE"; then
    echo "Backup failed for database: $DB" | tee -a "$LOG_FILE" "$DB_LOG_FILE"
    exit 1
  fi

  echo "Backup completed: $BACKUP_FILE" | tee -a "$LOG_FILE" "$DB_LOG_FILE"
done

# Delete backups older than 60 days inside each database folder
echo "Deleting old backups..." | tee -a "$LOG_FILE"
for DB in $DB_LIST; do
  if [ -d "$BACKUP_ROOT/$DB" ]; then
    find "$BACKUP_ROOT/$DB" -type f -name "*.sql.gz" -mtime +59 -exec rm {} \; -exec echo "Deleted old backup: {}" >> "$LOG_FILE" \;
  fi
done

# Delete logs older than 60 days
echo "Deleting old logs..." | tee -a "$LOG_FILE"
find "$LOG_DIR" -type f -name "*.log" -mtime +59 -exec rm {} \; -exec echo "Deleted old log: {}" >> "$LOG_FILE" \;

# Verify backup integrity
for DB in $DB_LIST; do
  LATEST_BACKUP=$(ls -t "$BACKUP_ROOT/$DB"/*.sql.gz | head -n 1 2>/dev/null)
  if [ -n "$LATEST_BACKUP" ]; then
    if ! gzip -t "$LATEST_BACKUP"; then
      echo "Backup verification failed for $DB!" | tee -a "$LOG_FILE"
      exit 1
    fi
    echo "Backup verification successful for $DB" | tee -a "$LOG_FILE"
  fi
done

echo "All database backups completed successfully." | tee -a "$LOG_FILE"
