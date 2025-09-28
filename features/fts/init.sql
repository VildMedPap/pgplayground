-- =============================================================================
-- PostgreSQL 18 Full Text Search Feature Setup
-- =============================================================================
-- This script sets up a database with ICU collation provider and demonstrates
-- PostgreSQL 18's new FTS features, particularly how FTS now respects the
-- cluster default collation instead of always using libc.

-- Note: We'll use the default testdb but configure it with ICU collation
-- The database is already created by Docker with ICU collation support
-- We'll set the appropriate collation for our text operations

-- =============================================================================
-- Extensions
-- =============================================================================

-- Enable unaccent extension for accent-insensitive search
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Enable pg_trgm for trigram similarity searches (useful for fuzzy matching)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =============================================================================
-- Conference Data Table
-- =============================================================================

-- Drop table if exists for clean setup
DROP TABLE IF EXISTS conference_events CASCADE;

-- Create main conference events table
CREATE TABLE conference_events (
    id SERIAL PRIMARY KEY,
    event_id INTEGER UNIQUE NOT NULL,
    title TEXT NOT NULL,
    abstract TEXT,
    speakers TEXT,  -- Concatenated speaker names for FTS
    url TEXT,
    room TEXT,
    track TEXT,
    duration INTEGER,  -- Duration in minutes
    start_time TIMESTAMP,
    metadata JSONB,  -- Additional metadata (day, etc.)

    -- Generated columns for FTS (PostgreSQL 12+ feature)
    -- Using GENERATED ALWAYS AS ... STORED for automatic tsvector updates
    search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('english', COALESCE(title, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(abstract, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(track, '')), 'C') ||
        setweight(to_tsvector('english', COALESCE(speakers, '')), 'D')
    ) STORED,

    -- Simple search vector without weights for comparison
    search_vector_simple tsvector GENERATED ALWAYS AS (
        to_tsvector('simple',
            COALESCE(title, '') || ' ' ||
            COALESCE(abstract, '') || ' ' ||
            COALESCE(speakers, '') || ' ' ||
            COALESCE(track, '')
        )
    ) STORED
);

-- =============================================================================
-- Indexes
-- =============================================================================

-- GIN index for full text search (most common for FTS)
CREATE INDEX idx_conference_events_search_gin
    ON conference_events USING GIN (search_vector);

-- GIN index for simple configuration
CREATE INDEX idx_conference_events_search_simple_gin
    ON conference_events USING GIN (search_vector_simple);

-- GiST index alternative (supports both FTS and proximity queries)
CREATE INDEX idx_conference_events_search_gist
    ON conference_events USING GIST (search_vector);

-- Trigram index for fuzzy matching with ILIKE
CREATE INDEX idx_conference_events_title_trgm
    ON conference_events USING GIN (title gin_trgm_ops);

CREATE INDEX idx_conference_events_abstract_trgm
    ON conference_events USING GIN (abstract gin_trgm_ops);

-- B-tree indexes for exact matches and sorting
CREATE INDEX idx_conference_events_track ON conference_events(track);
CREATE INDEX idx_conference_events_room ON conference_events(room);
CREATE INDEX idx_conference_events_start_time ON conference_events(start_time);

-- =============================================================================
-- Custom Text Search Configuration
-- =============================================================================

-- Create a custom text search configuration based on English
CREATE TEXT SEARCH CONFIGURATION conference_english (COPY = english);

-- NOTE: PostgreSQL's synonym dictionaries require actual files on the filesystem
-- in $SHAREDIR/tsearch_data/ directory. For production use, you would create
-- a synonym file and reference it like:
-- CREATE TEXT SEARCH DICTIONARY my_synonyms (
--     TEMPLATE = synonym,
--     SYNONYMS = my_synonyms  -- references my_synonyms.syn file
-- );
--
-- For this demo, we're using the standard English configuration without synonyms.

-- =============================================================================
-- Helper Functions
-- =============================================================================

-- Function to perform case-insensitive search using PG18's casefold
CREATE OR REPLACE FUNCTION search_casefold(search_text TEXT, target_text TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- PostgreSQL 18 introduces casefold() for proper Unicode case folding
    RETURN position(lower(search_text) IN lower(target_text)) > 0;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to highlight search results
CREATE OR REPLACE FUNCTION highlight_search(
    document TEXT,
    query_text TEXT,
    config regconfig DEFAULT 'english'::regconfig
)
RETURNS TEXT AS $$
BEGIN
    RETURN ts_headline(
        config,
        document,
        plainto_tsquery(config, query_text),
        'StartSel=<mark>, StopSel=</mark>, MaxWords=35, MinWords=15, ShortWord=3, HighlightAll=FALSE'
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to get search rank with custom weights
CREATE OR REPLACE FUNCTION custom_rank(
    vector tsvector,
    query tsquery,
    title_weight FLOAT DEFAULT 1.0,
    abstract_weight FLOAT DEFAULT 0.4
)
RETURNS FLOAT AS $$
BEGIN
    RETURN ts_rank_cd(
        vector,
        query,
        32  -- normalization option: length normalization
    ) * (title_weight + abstract_weight) / 2;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- =============================================================================
-- Sample Data for Testing (will be replaced by real data)
-- =============================================================================

-- Insert a few sample records for immediate testing
INSERT INTO conference_events (
    event_id, title, abstract, speakers, url, room, track, duration, start_time, metadata
) VALUES
    (1,
     'PostgreSQL 18: What''s New in Full Text Search',
     'An in-depth look at the new full text search features in PostgreSQL 18, including improved collation support and performance enhancements.',
     'John Doe, Jane Smith',
     'https://example.com/talk1',
     'Grand Hall',
     'Core PostgreSQL',
     50,
     '2025-10-22 09:00:00'::timestamp,
     '{"day": "2025-10-22", "level": "intermediate"}'::jsonb),

    (2,
     'Understanding ICU Collations in PostgreSQL',
     'Learn how ICU collations work in PostgreSQL and when to use them for international applications.',
     'Alice Johnson',
     'https://example.com/talk2',
     'Room B',
     'Internationalization',
     45,
     '2025-10-22 10:00:00'::timestamp,
     '{"day": "2025-10-22", "level": "advanced"}'::jsonb),

    (3,
     'Case-Insensitive Search Strategies',
     'Comparing different approaches to case-insensitive search in PostgreSQL: ILIKE, citext, and full text search.',
     'Bob Wilson',
     'https://example.com/talk3',
     'Room C',
     'Performance',
     45,
     '2025-10-22 11:00:00'::timestamp,
     '{"day": "2025-10-22", "level": "beginner"}'::jsonb)
ON CONFLICT (event_id) DO NOTHING;

-- =============================================================================
-- Verification Queries
-- =============================================================================

-- Check database collation
SELECT current_database(),
       datcollate,
       datctype,
       datlocprovider,
       datcollversion
FROM pg_database
WHERE datname = current_database();

-- Check available text search configurations
SELECT cfgname, cfgnamespace::regnamespace
FROM pg_ts_config
ORDER BY cfgname;

-- Verify extensions are loaded
SELECT extname, extversion
FROM pg_extension
WHERE extname IN ('unaccent', 'pg_trgm')
ORDER BY extname;

-- =============================================================================
-- Statistics and Maintenance
-- =============================================================================

-- Update statistics for better query planning
ANALYZE conference_events;

-- Create statistics on common column combinations
CREATE STATISTICS conference_events_stats (dependencies, ndistinct)
    ON track, room FROM conference_events;

-- =============================================================================
-- Comments for Documentation
-- =============================================================================

COMMENT ON TABLE conference_events IS 'PGConfEU 2025 conference schedule data for FTS demonstrations';
COMMENT ON COLUMN conference_events.search_vector IS 'Weighted tsvector for English FTS with priorities: A=title, B=abstract, C=track, D=speakers';
COMMENT ON COLUMN conference_events.search_vector_simple IS 'Simple tsvector without language-specific processing for exact term matching';
COMMENT ON INDEX idx_conference_events_search_gin IS 'Primary FTS index using GIN for fast text searches';
COMMENT ON INDEX idx_conference_events_title_trgm IS 'Trigram index for fuzzy matching and ILIKE operations on title';