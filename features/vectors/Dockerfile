# Use our base PostgreSQL image
FROM postgres_playground:latest

# Install pgvector extension
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    postgresql-server-dev-17 \
    && git clone https://github.com/pgvector/pgvector.git \
    && cd pgvector \
    && make \
    && make install \
    && cd .. \
    && rm -rf pgvector \
    && apt-get remove -y build-essential git postgresql-server-dev-17 \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy the project-specific init script
COPY ./init.sql /docker-entrypoint-initdb.d/

