FROM alpine:3.21

# Install PostgreSQL client for version 16
RUN apk add --no-cache postgresql16-client curl

COPY backup.sh restore.sh entrypoint.sh migrate.sh /scripts/

# Set permissions for script files
RUN chmod +x /scripts/*

WORKDIR /scripts
ENTRYPOINT ["/scripts/entrypoint.sh"]
