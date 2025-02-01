FROM timescale/timescaledb:latest-pg16

WORKDIR /docker-entrypoint-initdb.d

COPY init-db.sh /docker-entrypoint-initdb.d/init-db.sh

RUN chmod +x /docker-entrypoint-initdb.d/init-db.sh

# Correct CMD to pass only the arguments expected by the entrypoint script
CMD ["postgres"]