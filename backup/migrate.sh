#!/bin/sh
set -e

# 🚀 Load PostgreSQL password securely from Docker secrets
SOURCE_PASSWORD=$(cat /run/secrets/postgres_password)
NEW_PASSWORD=$(cat /run/secrets/postgres_password)

# Define Source PostgreSQL (Old Instance Running on Host)
SOURCE_HOST="host.docker.internal"
SOURCE_PORT="5433"
SOURCE_USER="tradesmart"
SOURCE_DB="videodb"

# Define Destination PostgreSQL (Running Inside Target Container)
NEW_HOST="timescaledb"
NEW_PORT="5432"
NEW_USER="tradesmart"
NEW_DB="videodb"

# Backup File Location
BACKUP_FILE="/backups/backup.dump"

# 🛠️ **Step 1: Verify Network Connectivity**
echo "🔍 Checking network connectivity to PostgreSQL instances..."
if ! ping -c 2 "$NEW_HOST" >/dev/null 2>&1; then
  echo "❌ ERROR: Unable to reach target database ($NEW_HOST). Check network settings!"
  exit 1
fi
echo "✅ Network connection to $NEW_HOST verified."

# 🛠️ **Step 2: Test Database Connections Before Proceeding**
echo "🔍 Testing connection to SOURCE database..."
if ! PGPASSWORD=$SOURCE_PASSWORD psql -h "$SOURCE_HOST" -p "$SOURCE_PORT" -U "$SOURCE_USER" -d "$SOURCE_DB" -c "SELECT 1;" >/dev/null 2>&1; then
  echo "❌ ERROR: Unable to connect to SOURCE database ($SOURCE_DB). Check credentials!"
  exit 1
fi
echo "✅ Connection to SOURCE database verified."

echo "🔍 Testing connection to TARGET database..."
if ! PGPASSWORD=$NEW_PASSWORD psql -h "$NEW_HOST" -p "$NEW_PORT" -U "$NEW_USER" -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
  echo "❌ ERROR: Unable to connect to TARGET database ($NEW_DB). Check credentials!"
  exit 1
fi
echo "✅ Connection to TARGET database verified."

# 🛠️ **Step 3: Backup the Database (Excluding TimescaleDB system tables)**
echo "📦 Backing up database '$SOURCE_DB' from $SOURCE_HOST:$SOURCE_PORT..."
PGPASSWORD=$SOURCE_PASSWORD pg_dump -h $SOURCE_HOST -p $SOURCE_PORT -U $SOURCE_USER -F c --no-owner --disable-triggers \
    --exclude-table='_timescaledb_catalog.*' --exclude-table='_timescaledb_config.*' \
    --exclude-schema='_timescaledb_catalog' --exclude-schema='_timescaledb_config' \
    -d $SOURCE_DB -f $BACKUP_FILE

if [ ! -f "$BACKUP_FILE" ]; then
  echo "❌ ERROR: Backup file not created! Check pg_dump command."
  exit 1
fi

echo "✅ Backup completed successfully: $BACKUP_FILE"

# 🛠️ **Step 4: Verify Backup Contents Before Restoring**
echo "🔍 Checking backup contents..."
pg_restore -l $BACKUP_FILE | grep -E "TABLE DATA|TABLE" || {
  echo "❌ ERROR: Backup file does not contain tables or data!"
  exit 1
}

# 🛠️ **Step 5: Ensure a Clean PostgreSQL Instance**
echo "🗑️ Dropping existing database (if it exists) and recreating '$NEW_DB'..."
PGPASSWORD=$NEW_PASSWORD psql -h $NEW_HOST -p $NEW_PORT -U $NEW_USER -d postgres -c "DROP DATABASE IF EXISTS \"$NEW_DB\";"
PGPASSWORD=$NEW_PASSWORD psql -h $NEW_HOST -p $NEW_PORT -U $NEW_USER -d postgres -c "CREATE DATABASE \"$NEW_DB\";"
echo "✅ New database '$NEW_DB' created successfully."

# 🛠️ **Step 6: Ensure TimescaleDB is Installed (Without Recreating It)**
echo "⚙️ Ensuring TimescaleDB extension is installed before restore..."
PGPASSWORD=$NEW_PASSWORD psql -h $NEW_HOST -p $NEW_PORT -U $NEW_USER -d $NEW_DB -c \
"DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb') THEN CREATE EXTENSION timescaledb CASCADE; END IF; END \$\$;"
echo "✅ TimescaleDB extension verified."

# 🛠️ **Step 7: Drop TimescaleDB Extension Before Restore (To Avoid Conflicts)**
echo "🔄 Dropping TimescaleDB extension before restoring..."
PGPASSWORD=$NEW_PASSWORD psql -h $NEW_HOST -p $NEW_PORT -U $NEW_USER -d $NEW_DB -c "DROP EXTENSION IF EXISTS timescaledb CASCADE;"

# 🛠️ **Step 8: Restore the Database (Without TimescaleDB Conflicts)**
echo "📂 Restoring backup into new database '$NEW_DB' on $NEW_HOST:$NEW_PORT..."
PGPASSWORD=$NEW_PASSWORD pg_restore -h $NEW_HOST -p $NEW_PORT -U $NEW_USER -d $NEW_DB --clean --if-exists --no-owner --disable-triggers -F c $BACKUP_FILE \
    --exclude-schema='_timescaledb_catalog' --exclude-schema='_timescaledb_config'

echo "✅ Database restore completed successfully!"

# 🛠️ **Step 9: Verify Tables Exist in Target Database**
echo "🔍 Verifying restored tables in '$NEW_DB'..."
PGPASSWORD=$NEW_PASSWORD psql -h $NEW_HOST -p $NEW_PORT -U $NEW_USER -d $NEW_DB -c "\dt" || {
  echo "❌ ERROR: No tables found in target database after restore!"
  exit 1
}

# 🎉 **Final Success Message**
echo "🎯 Migration from PostgreSQL $SOURCE_HOST:$SOURCE_DB to $NEW_HOST:$NEW_DB completed successfully!"
