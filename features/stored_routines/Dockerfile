# Use our base PostgreSQL image
FROM postgres_playground:latest

# Copy the project-specific init script
COPY ./init.sql /docker-entrypoint-initdb.d/
