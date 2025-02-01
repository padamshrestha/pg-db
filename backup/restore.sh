#!/bin/sh
set -e

# Ensure correct usage
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 <database_name> [backup_filename]"
  exit 1
fi

# Database name parameter
DB_NAME=$1
BACKUP_FILE=$2  # Optional parameter

# Load PostgreSQL password securely
PGPASSWORD=$(cat /run/secrets/postgres_password)

# Define directories
BACKUP_ROOT="/backups"
DB_BACKUP_DIR="$BACKUP_ROOT/$DB_NAME"
LOG_DIR="$BACKUP_ROOT/logs"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Create log file with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/restore_${DB_NAME}_$TIMESTAMP.log"

# Start logging
echo "Starting restore for database '$DB_NAME' at $(date)" | tee -a "$LOG_FILE"

# Check if backup directory exists
if [ ! -d "$DB_BACKUP_DIR" ]; then
  echo "Backup directory for database '$DB_NAME' not found!" | tee -a "$LOG_FILE"
  exit 1
fi

# If no backup filename is provided, find the latest one
if [ -z "$BACKUP_FILE" ]; then
  BACKUP_FILE=$(ls -t "$DB_BACKUP_DIR"/*.sql.gz 2>/dev/null | head -n 1)
  if [ -z "$BACKUP_FILE" ]; then
    echo "No backup files found for database '$DB_NAME'!" | tee -a "$LOG_FILE"
    exit 1
  fi
  echo "Using latest backup: $BACKUP_FILE" | tee -a "$LOG_FILE"
else
  BACKUP_FILE="$DB_BACKUP_DIR/$BACKUP_FILE"
  if [ ! -f "$BACKUP_FILE" ]; then
    echo "Specified backup file '$BACKUP_FILE' does not exist!" | tee -a "$LOG_FILE"
    exit 1
  fi
  echo "Using specified backup file: $BACKUP_FILE" | tee -a "$LOG_FILE"
fi

# Drop the existing database if it exists
echo "Dropping existing database (if it exists)..." | tee -a "$LOG_FILE"
if ! PGPASSWORD=$PGPASSWORD psql -h "$PG_HOST" -U "$PG_USER" -d postgres -c "DROP DATABASE IF EXISTS \"$DB_NAME\";" 2>>"$LOG_FILE"; then
  echo "Failed to drop database '$DB_NAME'!" | tee -a "$LOG_FILE"
  exit 1
fi

# Create the database again
echo "Creating new database '$DB_NAME'..." | tee -a "$LOG_FILE"
if ! PGPASSWORD=$PGPASSWORD psql -h "$PG_HOST" -U "$PG_USER" -d postgres -c "CREATE DATABASE \"$DB_NAME\";" 2>>"$LOG_FILE"; then
  echo "Failed to create database '$DB_NAME'!" | tee -a "$LOG_FILE"
  exit 1
fi

# Restore the database from the backup file
echo "Restoring data into '$DB_NAME' from '$BACKUP_FILE'..." | tee -a "$LOG_FILE"
if ! gunzip -c "$BACKUP_FILE" | PGPASSWORD=$PGPASSWORD psql -h "$PG_HOST" -U "$PG_USER" -d "$DB_NAME" 2>>"$LOG_FILE"; then
  echo "Restore failed for database '$DB_NAME'!" | tee -a "$LOG_FILE"
  exit 1
fi

# Verify restore success
echo "Verifying restore..." | tee -a "$LOG_FILE"
if ! PGPASSWORD=$PGPASSWORD psql -h "$PG_HOST" -U "$PG_USER" -d "$DB_NAME" -c "\dt" 2>>"$LOG_FILE"; then
  echo "Verification failed for database '$DB_NAME'!" | tee -a "$LOG_FILE"
  exit 1
fi

echo "Database '$DB_NAME' restored successfully from '$BACKUP_FILE'!" | tee -a "$LOG_FILE"
