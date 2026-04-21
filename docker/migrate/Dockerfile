FROM postgres:16

WORKDIR /app

COPY migrations /app/migrations
COPY docker/migrate/migrate.sh /app/migrate.sh

RUN chmod +x /app/migrate.sh

ENTRYPOINT ["/app/migrate.sh"]
