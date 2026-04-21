FROM postgres:16

ENV POSTGRES_DB=chat_system
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres

COPY docker/postgres/init/ /docker-entrypoint-initdb.d/
