# Fully automate Timescaledb (pg-db)

## Run
```console
docker compose up --build
```

With rebuild
```console
docker compose up --build
```

![timescaledb and backup containers](image.png)

## Backup should be running every mid night with 60 days of backup policy

## How to:
1. To migrate remote in to backup_container, check the db settings for source and target and run
```console
./migrate.sh
```
2. For manual backup, remote in to backup_container and run
```console
./backup.sh
```
3. For manual restore, remote in to backup_container and run
```console
./restore.sh
```

## Commands used for setup


chmod -R 777 /Volumes/SG-RAID/media.warehouse/db_backup
ls /Volumes/SG-RAID/media.warehouse/db_backup

chmod +x backup/backup.sh

echo -n "YoutubeStudio@1" > postgres_password.txt
chmod 600 postgres_password.txt

YoutubeStudio@1

## Backup

🕛 Runs at midnight daily (0 0 * * * /backup.sh)
🧹 Old backups are deleted (older than 7 days)
```
/backups/
  ├── db1/
  │   ├── db1_20240131_000000.sql.gz
  │   ├── db1_20240130_000000.sql.gz
  │   └── ...
  ├── db2/
  │   ├── db2_20240131_000000.sql.gz
  │   ├── db2_20240130_000000.sql.gz
  ├── logs/
  │   ├── restore_db1_db_20240201_120000.log
  │   ├── restore_db2_db_20240131_120000.log
  └── ...

```

Manually execute the script inside the container:
```console
docker ps | grep backup
docker exec -it 123456789abc sh -c "/backup.sh"
```
From host machine
```python
chmod +x backup/backup.sh
./backup/backup.sh
ls -R /Volumes/SG-RAID/media.warehouse/db_backup
```


Check if cron is running
```console
docker exec -it $(docker ps -q -f name=backup) sh -c "ps aux | grep crond"
```

## Restore DB
```python

chmod +x restore.sh
docker exec -it <backup_container_id> sh -c "/restore.sh test_db"

docker exec -it <backup_container_id> sh -c "/restore.sh test_db test_db_20240130_150000.sql.gz"
./restore.sh test_db
```

OR locally
```console
./restore.sh test_db

./restore.sh test_db test_db_20240130_150000.sql.gz
```

Expected Output
```console
Using specified backup file: /backups/test_db/test_db_20240130_150000.sql.gz
Dropping existing database (if it exists)...
Creating new database 'test_db'...
Restoring data into 'test_db'...
Database 'test_db' restored successfully!

```

🚀 Automating Database Restore in Docker
```console
docker exec -it <backup_container_id> sh -c "/restore.sh test_db"
```


## Migrate db
Test the connection from the target container
```console
PGPASSWORD="Tradesmart@1" psql -h host.docker.internal -p 5433 -U tradesmart -d videodb
```
Expected Output:
```console
/ # PGPASSWORD="Tradesmart@1" psql -h host.docker.internal -p 5433 -U tradesmart -d videodb
psql (15.10, server 15.8)
Type "help" for help.

videodb=# 
```


Make sure to update user, password and db name and in the target console (IMPORTANT!)
```console
chmod +x ./backup/migrate.sh
./backup/migrate.sh
```

Expected Output:
```console
Backing up database 'mydatabase' from localhost:5432...
Restoring backup into new database 'mydatabase' on localhost:5434...
Migration completed successfully!
```

psql -h localhost -p 5433 -U tradesmart -d mydatabase


chmod +x init-db.sh

ALTER USER admin WITH PASSWORD 'YoutubeStudio@1';



# Important password set from Docker  is not working somehow. So once the container start we might (in Docker console)need to do it
```console
/ # psql -U admin -d postgres
psql (15.8)
Type "help" for help.

postgres=# echo $POSTGRES_USER
postgres-# echo $POSTGRES_PASSWORD
postgres-# cat /run/secrets/postgres_password
postgres-# ALTER USER admin WITH PASSWORD 'YoutubeStudio@1';
postgres-# CREATE EXTENSION IF NOT EXISTS timescaledb WITH SCHEMA public;
```



docker compose up --build


In backup_container
```console
crontab -l

should see

0 0 * * * /scripts/backup.sh >> /backups/logs/cron_backup.log 2>&1
```

📌 Final Check
To manually trigger a cron job and verify it works:

```console
docker exec -it backup_container sh -c "/scripts/backup.sh"
```

Then, check the logs:

```console
cat /backups/logs/cron_backup.log
```

## Migrate from prior timescaledb to new one
Remove into backup_container terminal and run
```console
/scripts # ./migrate.sh
🔍 Checking network connectivity to PostgreSQL instances...
✅ Network connection to timescaledb verified.
🔍 Testing connection to SOURCE database...
✅ Connection to SOURCE database verified.
/scripts # ./migrate.sh
🔍 Checking network connectivity to PostgreSQL instances...
✅ Network connection to timescaledb verified.
🔍 Testing connection to SOURCE database...
✅ Connection to SOURCE database verified.
🔍 Testing connection to TARGET database...
✅ Connection to TARGET database verified.
📦 Backing up database 'videodb' from host.docker.internal:5433...
✅ Backup completed successfully: /backups/backup.dump
🔍 Checking backup contents...
279; 1259 19489 TABLE public requests tradesmart
277; 1259 18586 TABLE public videos tradesmart
283; 1259 48599 TABLE public video_status tradesmart
3951; 0 19489 TABLE DATA public requests tradesmart
3953; 0 48599 TABLE DATA public video_status tradesmart
3949; 0 18586 TABLE DATA public videos tradesmart
🗑️ Dropping existing database (if it exists) and recreating 'videodb'...
DROP DATABASE
CREATE DATABASE
✅ New database 'videodb' created successfully.
⚙️ Ensuring TimescaleDB extension is installed before restore...
DO
✅ TimescaleDB extension verified.
🔄 Dropping TimescaleDB extension before restoring...
DROP EXTENSION
📂 Restoring backup into new database 'videodb' on timescaledb:5432...
✅ Database restore completed successfully!
🔍 Verifying restored tables in 'videodb'...
             List of relations
 Schema |     Name     | Type  |   Owner    
--------+--------------+-------+------------
 public | requests     | table | tradesmart
 public | video_status | table | tradesmart
 public | videos       | table | tradesmart
(3 rows)

🎯 Migration from PostgreSQL host.docker.internal:videodb to timescaledb:videodb completed successfully!
```


### Helpful commands

🛠️ Step 1: Verify That Tables Exist
```console
psql -U tradesmart -d videodb -c "\dt"
```
✅ Expected Output (if tables exist):
```console
             List of relations
 Schema |     Name     | Type  |   Owner    
--------+--------------+-------+------------
 public | requests     | table | tradesmart
 public | video_status | table | tradesmart
 public | videos       | table | tradesmart
(3 rows)

```

🛠️ Step 2: Check If Tables Contain Data
```console
psql -U tradesmart -d videodb -c "SELECT COUNT(*) FROM requests;"
psql -U tradesmart -d videodb -c "SELECT COUNT(*) FROM video_status;"
psql -U tradesmart -d videodb -c "SELECT COUNT(*) FROM videos;"

```
✅ Expected Output (if tables exist):
```console
 count  
-------
  12345
(1 row)

 count  
-------
  67890
(1 row)

 count  
-------
  54321
(1 row)
```

🛠️ Step 3: Verify What Was Actually Restored
```console
docker exec -it backup_container pg_restore -l /backups/backup.dump | grep "TABLE DATA"
```

✅ Expected Output (if data was backed up):
```console
3951; 0 19489 TABLE DATA public requests tradesmart
3953; 0 48599 TABLE DATA public video_status tradesmart
3949; 0 18586 TABLE DATA public videos tradesmart
```