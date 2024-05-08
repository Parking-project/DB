FROM mysql:latest
COPY ./create_db.sql /docker-entrypoint-initdb.d/