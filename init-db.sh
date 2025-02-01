#!/bin/sh
set -e

echo "🛠️ Running PostgreSQL setup script..."

# Load environment variables
export PGPASSWORD="${POSTGRES_PASSWORD:-YoutubeStudio@1}"
POSTGRES_USER="${POSTGRES_USER:-tradesmart}"
MAX_RETRIES=30
RETRY_DELAY=2

wait_for_db() {
    local retry_count=0
    until psql -h /var/run/postgresql -U "$POSTGRES_USER" -d postgres -c '\q' >/dev/null 2>&1 || [ $retry_count -eq $MAX_RETRIES ]; do
        echo "⏳ Waiting for PostgreSQL (attempt $((retry_count+1))/$MAX_RETRIES)..."
        retry_count=$((retry_count+1))
        sleep $RETRY_DELAY
    done
    
    if [ $retry_count -eq $MAX_RETRIES ]; then
        echo "❌ ERROR: PostgreSQL not ready after $((MAX_RETRIES*RETRY_DELAY)) seconds"
        exit 1
    fi
}

wait_for_db

echo "✅ PostgreSQL is ready. Running setup..."

psql -v ON_ERROR_STOP=1 -h /var/run/postgresql -U "$POSTGRES_USER" -d postgres <<-EOSQL
  -- Create admin user if not exists
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'admin') THEN
      CREATE ROLE admin WITH SUPERUSER LOGIN PASSWORD 'YoutubeStudio@1';
      RAISE NOTICE '✅ User admin created';
    END IF;
  END \$\$;

  -- Ensure tradesmart user exists
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'tradesmart') THEN
      CREATE ROLE tradesmart WITH LOGIN SUPERUSER PASSWORD 'YoutubeStudio@1';
      RAISE NOTICE '✅ User tradesmart created';
    END IF;
  END \$\$;

  -- Create videodb if not exists
  SELECT 'CREATE DATABASE videodb OWNER tradesmart'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'videodb')\gexec

  -- Grant privileges
  DO \$\$
  BEGIN
    GRANT ALL PRIVILEGES ON DATABASE videodb TO tradesmart, admin;
    RAISE NOTICE '✅ Privileges granted';
  END \$\$;
EOSQL

# Enable TimescaleDB extension with proper error handling
echo "🛠️ Enabling TimescaleDB extension..."
psql -v ON_ERROR_STOP=1 -h /var/run/postgresql -U "$POSTGRES_USER" -d videodb <<-EOSQL
  DO \$\$
  BEGIN
    CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
    RAISE NOTICE '✅ TimescaleDB extension enabled';
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'ℹ️ TimescaleDB extension already exists';
  END \$\$;
EOSQL

echo "🚀 Database setup completed successfully!"