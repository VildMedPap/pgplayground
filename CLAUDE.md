# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

PostgreSQL Playground - A modular project for experimenting with PostgreSQL features in isolated Docker containers. Each feature is self-contained in the `features/` directory.

## Common Commands

### Setup
```bash
# Initial setup
cp .env.template .env
uv sync  # Install Python dependencies using uv package manager
```

### Feature Development
Navigate to a feature directory (e.g., `cd features/queues/`) then:
```bash
make help        # Show all available targets with descriptions
make buildrun    # Build and run the PostgreSQL container
make stop-container  # Stop the running container
make teardown    # Complete cleanup (stop + delete image)

# Common feature-specific targets:
make insert-tasks    # Insert test data (queues feature)
make process-tasks   # Run processing logic
make NUM_WORKERS=5 process-tasks  # Override default parameters
```

### Creating New Features
```bash
# Copy the template
cp -r features/00_template features/your_feature_name
# Update the Makefile variables (IMAGE_NAME, CONTAINER_NAME)
# Follow these patterns:
#   - Add NUM_* parameters with defaults (e.g., NUM_TASKS ?= 100)
#   - Create insert-* and process-* targets for data operations
#   - Use init.sql for schema, queries.sql for examples
```

## Architecture

### Directory Structure
- **features/** - Self-contained feature implementations
  - Each feature has: Dockerfile, Makefile, init.sql, queries.sql, README.md
  - Features extend `Makefile.base` and `Dockerfile.base` for consistency
- **Shared Infrastructure**:
  - `Makefile.base` - Common Make targets (build, run, stop, teardown)
  - `Dockerfile.base` - PostgreSQL 17.4 base image
  - `help.sh` - Colorized help system for Makefiles

### Key Patterns
- **Modular Features**: Each feature is completely isolated with its own container
- **Make-based Workflow**: All operations use Make targets with consistent naming
- **Environment Configuration**: Uses `.env` file for database credentials (never commit this)
- **Template-driven Development**: Use `00_template/` as starting point for new features
- **Parametric Execution**: Use `NUM_*` variables to control feature behavior (e.g., `make NUM_WORKERS=10 process-tasks`)
- **Transaction Patterns**: Features use explicit transaction control with `conn.autocommit = False`

### Database Connection
All features use standard PostgreSQL connection parameters from `.env`:
- POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD
- Default port: 5432 (mapped from container)

**Python Connection Pattern**:
```python
load_dotenv("../../.env")
conn_params = {
    "dbname": os.getenv("DB_NAME"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "host": os.getenv("DB_HOST"),
    "port": int(os.getenv("DB_PORT", 5432)),
}
```

## Technology Stack
- **PostgreSQL**: 18 with various extensions (pgvector for vectors feature)
- **Python**: 3.12+ with uv package manager
- **Docker**: Multi-stage builds with health checks
- **Make**: GNU Make with sophisticated help system

### Dependency Management Strategy

**All Python dependencies use uv's inline script feature**:
- No project-wide dependencies in `pyproject.toml` (kept empty)
- Each script declares its own dependencies using uv's inline metadata
- This ensures complete isolation between features
- Scripts are run with `uv run` which automatically handles the environment

Example of inline dependencies:
```python
#!/usr/bin/env python3
# /// script
# dependencies = [
#   "psycopg2-binary>=2.9.9",
#   "python-dotenv>=1.0.0",
#   "ujson>=5.10.0",
# ]
# ///
```

Common dependencies by use case:
- **Database operations**: `psycopg2-binary`, `python-dotenv`
- **Data processing**: `pandas`, `numpy`, `ujson`
- **Web/XML parsing**: `lxml`, `httpx`, `requests`
- **Configuration**: `pydantic`, `pydantic-settings`

## Development Notes
- No formal test framework - features are experimental/educational
- Each feature includes `queries.sql` with example SQL queries
- Python scripts demonstrate feature functionality
- Use `make help` in any feature directory to see available operations
- Feature-specific parameters can be passed as Make variables (e.g., `make NUM_WORKERS=5 process-tasks`)

## Common Feature Patterns

### PostgreSQL Features Demonstrated
- **queues**: `FOR UPDATE SKIP LOCKED` for concurrent task processing
- **vectors**: pgvector extension for similarity search (requires `CREATE EXTENSION vector`)
- **partitions**: LIST, RANGE, HASH partitioning for large tables (>100GB)
- **indexes**: B-tree, Hash, GIN, GiST, BRIN comparison with `EXPLAIN ANALYZE`
- **stored_routines**: Functions vs procedures, triggers, transaction control
- **fts**: Full Text Search with PostgreSQL 18's ICU collation improvements

### Performance Patterns
- **Bulk inserts**: Use `execute_values()` instead of individual inserts (10x+ faster)
- **Batch processing**: Process large datasets in chunks to manage memory
- **Index testing**: Always use `EXPLAIN ANALYZE` before/after index creation
- **Concurrent operations**: Use row-level locking with `FOR UPDATE SKIP LOCKED`

### Error Handling Pattern
```python
try:
    # Operation
    conn.commit()
except Exception as e:
    conn.rollback()
    # Handle partial state
finally:
    conn.close()
```