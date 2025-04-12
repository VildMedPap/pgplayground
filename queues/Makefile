# Include shared Makefile
include ../Makefile.base

# Define project-specific variables
IMAGE_NAME = postgres_queues
CONTAINER_NAME = postgres_queues_container
NUM_TASKS ?= 30
NUM_WORKERS ?= 1

# Project-specific targets
.PHONY: insert-tasks
insert-tasks: ## Insert tasks into the database (NUM_TASKS=30)
	@echo "Inserting tasks..."
	@uv run insert_tasks.py --num-tasks $(NUM_TASKS)

.PHONY: process-tasks
process-tasks: ## Process tasks with specified number of workers (NUM_WORKERS=1)
	@echo "Starting $(NUM_WORKERS) worker(s) to process tasks..."
	@for i in $$(seq 1 $(NUM_WORKERS)); do \
		uv run process_tasks.py & \
	done; \
	wait
