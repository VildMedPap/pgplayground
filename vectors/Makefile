# Include shared Makefile
include ../Makefile.base

# Define project-specific variables
IMAGE_NAME = postgres_vectors
CONTAINER_NAME = postgres_vectors_container
NUM_VECTORS ?= 1000

# Project-specific targets
.PHONY: insert-simulated-vectors
insert-simulated-vectors: ## Insert simulated vectors (NUM_VECTORS=1000)
	@echo "Inserting simulated vectors..."
	@uv run insert_simulated_vectors.py --num-vectors $(NUM_VECTORS)

.PHONY: insert-real-vectors
insert-real-vectors: ## Insert real vectors
	@echo "Inserting real vectors..."
	@uv run insert_real_vectors.py
