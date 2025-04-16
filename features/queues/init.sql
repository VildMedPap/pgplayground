-- Initialize the task queue table structure
CREATE TABLE tasks (
    id SERIAL PRIMARY KEY,
    status TEXT NOT NULL DEFAULT 'pending',
    payload JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMP,
    processing_time INTEGER DEFAULT NULL,
    worker_id TEXT DEFAULT NULL
);

-- Optional: Add an index to speed up the FOR UPDATE SKIP LOCKED query
CREATE INDEX idx_tasks_status_created ON tasks(status, created_at);
