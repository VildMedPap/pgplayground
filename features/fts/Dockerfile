# Build from the base PostgreSQL 18 image
FROM postgres_playground:latest

# Install additional packages for ICU support and locale generation
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    locales \
    && rm -rf /var/lib/apt/lists/*

# Generate en_US.UTF-8 locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# Set locale environment variables
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Set PostgreSQL to use ICU collation by default
ENV POSTGRES_INITDB_ARGS="--locale-provider=icu --icu-locale=en-US --locale=en_US.UTF-8"

# Copy initialization scripts
COPY ./init.sql /docker-entrypoint-initdb.d/

# Health check to ensure PostgreSQL is ready
HEALTHCHECK --interval=5s --timeout=3s --start-period=10s --retries=5 \
    CMD pg_isready -U testuser -d testdb || exit 1