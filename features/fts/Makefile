# Include shared Makefile
include ../../Makefile.base

# Define project-specific variables
IMAGE_NAME = postgres_fts
CONTAINER_NAME = postgres_fts_container

# Project-specific targets
.PHONY: download-schedule
download-schedule: ## Download the PGConfEU 2025 schedule XML
	@echo "Downloading PGConfEU 2025 schedule..."
	@mkdir -p data
	@curl -L -o data/schedule.xml https://www.postgresql.eu/events/pgconfeu2025/schedule.xml
	@echo "✓ Schedule downloaded to data/schedule.xml"

.PHONY: load-data
load-data: ## Load conference data into PostgreSQL
	@echo "Loading conference data into PostgreSQL..."
	@uv run load_conference_data.py

.PHONY: test-fts
test-fts: ## Run sample FTS queries to test functionality
	@echo "Testing FTS functionality..."
	@docker exec -i $(CONTAINER_NAME) psql -U testuser -d testdb -f /docker-entrypoint-initdb.d/queries.sql

.PHONY: setup
setup: buildrun download-schedule load-data ## Complete setup: build, run, download, and load data
	@echo "FTS feature setup complete!"

.PHONY: connect
connect: ## Connect to PostgreSQL using psql
	@docker exec -it $(CONTAINER_NAME) psql -U testuser -d testdb