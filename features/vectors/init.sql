-- Create the pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create a table for vector embeddings
CREATE TABLE IF NOT EXISTS embeddings (
    id SERIAL PRIMARY KEY,
    embedding_id VARCHAR(255) NOT NULL,
    embedding vector(384)
);

-- Create an index for vector similarity search
CREATE INDEX ON embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Create a function to calculate cosine similarity between two vectors
CREATE OR REPLACE FUNCTION cosine_similarity(vector1 vector, vector2 vector)
RETURNS float AS $$
BEGIN
    -- Cosine similarity = 1 - cosine distance
    RETURN 1 - (vector1 <=> vector2);
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
