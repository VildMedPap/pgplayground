# PostgreSQL Playground

A collection of PostgreSQL features and experiments organized in a modular structure.

## Environment Setup

Before using any of the features, you need to set up your environment:

1. Copy the environment template file:

   ```bash
   cp .env.template .env
   ```

2. Adjust the values in the `.env` file as needed.

3. Install dependencies using uv:
   ```bash
   uv sync
   ```

## Features

### Vanilla

A simple PostgreSQL setup without any special features or initialization. Perfect for quick experiments or when you just need a clean PostgreSQL instance.

### Queues

A PostgreSQL implementation of a task queue system. Demonstrates how to use PostgreSQL for task management, including task insertion and processing with multiple workers.

### Vectors

A PostgreSQL implementation using the pgvector extension for vector similarity search. Includes functionality for inserting both simulated and real vector embeddings.

### Indexes

A guide to PostgreSQL indexing strategies, including different index types (B-tree, Hash, GIN, GiST, BRIN), compound indexes, partial indexes, and best practices for index maintenance and performance monitoring.

### Partitions

A guide to PostgreSQL table partitioning strategies, covering LIST, RANGE, and HASH partitioning types, along with best practices for partition management, performance optimization, and migration strategies.

## Project Structure

Each feature is organized in its own directory with a consistent structure:

- `Makefile` - Feature-specific build and run commands
- `Dockerfile` - Feature-specific Docker configuration
- `init.sql` - Database initialization scripts
- Python scripts for interacting with the database

## Shared Components

### Shared Makefile

The project uses a shared `Makefile.base` that provides common functionality for all features:

- `build-base` - Builds the base PostgreSQL image
- `build` - Builds the feature-specific Docker image
- `run` - Runs the PostgreSQL container
- `stop-container` - Stops the running container
- `delete-image` - Deletes the Docker image
- `teardown` - Stops container and deletes image

Each feature's Makefile includes this base Makefile and extends it with feature-specific targets:

```makefile
# Include shared Makefile
include ../../Makefile.base

# Define project-specific variables
IMAGE_NAME = postgres_feature_name
CONTAINER_NAME = postgres_feature_name_container

# Project-specific targets
.PHONY: feature-specific-target
feature-specific-target: ## Description of the target
	@echo "Running feature-specific target..."
	@uv run feature_script.py
```

### Shared Dockerfile

The project uses a shared `Dockerfile.base` that provides a common PostgreSQL setup:

```dockerfile
# Use the official Postgres image as a base
FROM postgres:17.4

# Set environment variables
ENV POSTGRES_DB=testdb
ENV POSTGRES_USER=testuser
ENV POSTGRES_PASSWORD=testpassword
```

Each feature's Dockerfile extends this base image with feature-specific configurations:

```dockerfile
# Use our base PostgreSQL image
FROM postgres_playground:latest

# Feature-specific setup
# ...

# Copy the project-specific init script
COPY ./init.sql /docker-entrypoint-initdb.d/
```

## Usage

### Quick Start - Vanilla PostgreSQL

If you just need a clean PostgreSQL instance without any special features:

```bash
cd features/vanilla
make buildrun
```

This will give you a PostgreSQL instance with:
- Database: `testdb`
- Username: `testuser`
- Password: `testpassword`
- Port: `5432`

When you're done, clean up with:
```bash
make teardown
```

### Running a Feature

1. Navigate to the feature directory:

   ```bash
   cd features/queues
   ```

2. Build and run the feature:

   ```bash
   make buildrun
   ```

3. View available targets:

   ```bash
   make help  # or simply just: make
   ```

4. Run feature-specific targets:

   ```bash
   # For queues
   make insert-tasks NUM_TASKS=50
   make process-tasks NUM_WORKERS=3
   ```

5. Clean up when done:
   ```bash
   make teardown
   ```
