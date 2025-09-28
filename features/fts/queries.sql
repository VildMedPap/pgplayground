-- =============================================================================
-- PostgreSQL Full Text Search: A Practical Introduction
-- =============================================================================
-- This file demonstrates the benefits of Full Text Search (FTS) in PostgreSQL
-- by comparing traditional search methods with FTS capabilities.
-- We'll use real PGConfEU 2025 conference data for practical examples.
-- =============================================================================

-- =============================================================================
-- SECTION 1: EXPLORING OUR DATA
-- =============================================================================

-- First, let's see what data we're working with
SELECT COUNT(*) AS total_events FROM conference_events;

-- Sample of our conference data
SELECT
    event_id,
    LEFT(title, 60) AS title,
    LEFT(speakers, 40) AS speakers,
    track,
    room
FROM conference_events
LIMIT 10;

-- What tracks do we have?
SELECT
    track,
    COUNT(*) as event_count
FROM conference_events
WHERE track IS NOT NULL
GROUP BY track
ORDER BY event_count DESC;

-- =============================================================================
-- SECTION 2: THE PROBLEM - SEARCHING WITHOUT FTS
-- =============================================================================

-- Let's say we want to find all talks about "performance"
-- Traditional approach using ILIKE (case-insensitive LIKE)

-- Method 1: Basic ILIKE search
SELECT
    title,
    abstract,
    track
FROM conference_events
WHERE title ILIKE '%performance%'
   OR abstract ILIKE '%performance%'
ORDER BY title;

-- Problems with ILIKE:
-- 1. It's slow on large datasets (full table scan)
-- 2. No ranking - all matches are equal
-- 3. Can't handle word variations (perform, performing, performed)
-- 4. Searches for substrings, not words (would match "nonperformance")

-- Let's measure the performance
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM conference_events
WHERE title ILIKE '%performance%'
   OR abstract ILIKE '%performance%';

-- =============================================================================
-- SECTION 3: INTRODUCTION TO FULL TEXT SEARCH
-- =============================================================================

-- PostgreSQL FTS converts text into a special format called tsvector
-- Let's see what this looks like:

-- Example of text to tsvector conversion
SELECT
    'Optimizing PostgreSQL Performance for Large Databases' AS original_text,
    to_tsvector('english', 'Optimizing PostgreSQL Performance for Large Databases') AS tsvector_format;

-- Notice how:
-- - Words are reduced to their root forms (stemming): "optimizing" → "optim"
-- - Common words (stop words) like "for" are removed
-- - Position information is stored
-- - Everything is lowercase

-- Our table already has pre-computed tsvector columns (search_vector)
-- Let's see what they contain:
SELECT
    title,
    search_vector
FROM conference_events
WHERE title ILIKE '%performance%'
LIMIT 2;

-- =============================================================================
-- SECTION 4: BASIC FTS QUERIES
-- =============================================================================

-- Now let's search using FTS
-- The @@ operator checks if a tsvector matches a tsquery

-- Simple FTS search for "performance"
SELECT
    title,
    track
FROM conference_events
WHERE search_vector @@ plainto_tsquery('english', 'performance')
ORDER BY title;

-- Benefits already visible:
-- 1. Finds "perform", "performance", "performing" automatically
-- 2. Uses the GIN index (much faster)
-- 3. Ignores case automatically

-- Let's check the performance improvement
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM conference_events
WHERE search_vector @@ plainto_tsquery('english', 'performance');

-- =============================================================================
-- SECTION 5: RANKING SEARCH RESULTS
-- =============================================================================

-- Unlike ILIKE, FTS can rank results by relevance
-- ts_rank gives each result a relevance score

SELECT
    title,
    ts_rank(search_vector, plainto_tsquery('english', 'performance')) AS relevance_score
FROM conference_events
WHERE search_vector @@ plainto_tsquery('english', 'performance')
ORDER BY relevance_score DESC
LIMIT 10;

-- Higher scores mean better matches
-- Factors affecting rank:
-- - Word frequency in document
-- - Document length
-- - Weight of matched terms (we weighted title > abstract > track > speakers)

-- =============================================================================
-- SECTION 6: MULTI-WORD SEARCHES
-- =============================================================================

-- Searching for multiple terms

-- With ILIKE (very cumbersome for multiple terms)
SELECT title
FROM conference_events
WHERE (title ILIKE '%backup%' OR abstract ILIKE '%backup%')
  AND (title ILIKE '%recovery%' OR abstract ILIKE '%recovery%')
LIMIT 5;

-- With FTS (clean and simple)
SELECT
    title,
    ts_rank(search_vector, plainto_tsquery('english', 'backup recovery')) AS rank
FROM conference_events
WHERE search_vector @@ plainto_tsquery('english', 'backup recovery')
ORDER BY rank DESC
LIMIT 5;

-- =============================================================================
-- SECTION 7: SEARCH OPERATORS (OR, AND, NOT)
-- =============================================================================

-- FTS supports boolean logic in searches

-- Find talks about "replication" OR "backup"
SELECT
    title,
    track
FROM conference_events
WHERE search_vector @@ to_tsquery('english', 'replication | backup')
LIMIT 10;

-- Find talks about "index" but NOT "btree"
SELECT
    title
FROM conference_events
WHERE search_vector @@ to_tsquery('english', 'index & !btree')
LIMIT 5;

-- =============================================================================
-- SECTION 8: PHRASE SEARCHES
-- =============================================================================

-- Sometimes you want to find exact phrases

-- Find talks with the exact phrase "full text search"
SELECT
    title,
    ts_rank(search_vector, phraseto_tsquery('english', 'full text search')) AS rank
FROM conference_events
WHERE search_vector @@ phraseto_tsquery('english', 'full text search')
ORDER BY rank DESC;

-- This is different from searching for the words separately
-- Compare with:
SELECT
    title
FROM conference_events
WHERE search_vector @@ plainto_tsquery('english', 'full text search')
LIMIT 5;

-- =============================================================================
-- SECTION 9: HIGHLIGHTING SEARCH RESULTS
-- =============================================================================

-- FTS can highlight matching terms in results - great for search interfaces!

SELECT
    title,
    ts_headline(
        'english',
        abstract,
        plainto_tsquery('english', 'performance'),
        'StartSel=>>>, StopSel=<<<, MaxWords=30, MinWords=15'
    ) AS highlighted_abstract
FROM conference_events
WHERE search_vector @@ plainto_tsquery('english', 'performance')
  AND abstract IS NOT NULL
LIMIT 3;

-- The >>> and <<< markers show where matches occur
-- You can customize these markers (e.g., use HTML tags for web display)

-- =============================================================================
-- SECTION 10: WEIGHTED SEARCH
-- =============================================================================

-- Our search_vector uses weights: A (title), B (abstract), C (track), D (speakers)
-- This means matches in titles score higher than matches in abstracts

-- Let's see this in action
SELECT
    title,
    track,
    ts_rank(search_vector, plainto_tsquery('english', 'postgresql')) AS weighted_rank,
    CASE
        WHEN title ILIKE '%postgresql%' THEN 'Title match'
        WHEN abstract ILIKE '%postgresql%' THEN 'Abstract match'
        WHEN track ILIKE '%postgresql%' THEN 'Track match'
        ELSE 'Speaker match'
    END AS match_location
FROM conference_events
WHERE search_vector @@ plainto_tsquery('english', 'postgresql')
ORDER BY weighted_rank DESC
LIMIT 10;

-- =============================================================================
-- SECTION 11: PRACTICAL USE CASES
-- =============================================================================

-- Use Case 1: Find beginner-friendly talks
SELECT
    title,
    track,
    ts_rank(search_vector, query) AS relevance
FROM conference_events,
    to_tsquery('english', 'introduction | beginner | basics | getting & started | tutorial') AS query
WHERE search_vector @@ query
ORDER BY relevance DESC
LIMIT 10;

-- Use Case 2: Find talks by topic area with ranking
WITH topic_search AS (
    SELECT
        title,
        track,
        speakers,
        ts_rank(search_vector, plainto_tsquery('english', 'security encryption ssl tls')) AS relevance
    FROM conference_events
    WHERE search_vector @@ plainto_tsquery('english', 'security encryption ssl tls')
)
SELECT * FROM topic_search
WHERE relevance > 0.01  -- Filter out weak matches
ORDER BY relevance DESC;

-- Use Case 3: Speaker search with fuzzy matching
-- First, let's see the limitation of exact matching
SELECT title, speakers
FROM conference_events
WHERE speakers ILIKE '%tom lane%';  -- Might miss "Thomas Lane" or "T. Lane"

-- FTS handles variations better
SELECT title, speakers
FROM conference_events
WHERE to_tsvector('english', speakers) @@ plainto_tsquery('english', 'tom lane')
LIMIT 5;

-- =============================================================================
-- SECTION 12: PERFORMANCE COMPARISON SUMMARY
-- =============================================================================

-- Let's do a final performance comparison for a complex search

-- Complex search with ILIKE (slow)
EXPLAIN (ANALYZE, TIMING, BUFFERS)
SELECT COUNT(*)
FROM conference_events
WHERE (title ILIKE '%database%' OR abstract ILIKE '%database%')
  AND (title ILIKE '%performance%' OR abstract ILIKE '%performance%')
  AND (title NOT ILIKE '%mysql%' AND abstract NOT ILIKE '%mysql%');

-- Same search with FTS (fast)
EXPLAIN (ANALYZE, TIMING, BUFFERS)
SELECT COUNT(*)
FROM conference_events
WHERE search_vector @@ to_tsquery('english', 'database & performance & !mysql');

-- =============================================================================
-- KEY TAKEAWAYS
-- =============================================================================
/*
1. FTS vs ILIKE:
   - FTS is MUCH faster (uses indexes)
   - FTS handles word variations automatically
   - FTS provides ranking/relevance scores
   - FTS supports complex boolean queries
   - FTS can highlight matches

2. When to use FTS:
   - Searching large text fields
   - Need relevance ranking
   - Want to handle word variations
   - Building search features for applications

3. When ILIKE might be better:
   - Simple substring matching
   - Very small datasets
   - Need exact character matches
   - Searching for codes/IDs rather than natural language

4. PostgreSQL 18 Improvement:
   - FTS now respects the database's collation (ICU in our case)
   - Better Unicode support for international text
   - More consistent case-insensitive behavior
*/

-- =============================================================================
-- BONUS: CHECKING OUR FTS CONFIGURATION
-- =============================================================================

-- What search configurations are available?
SELECT cfgname, cfgnamespace::regnamespace AS schema
FROM pg_ts_config
ORDER BY cfgname;

-- What does our GIN index look like?
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE tablename = 'conference_events'
  AND indexname LIKE '%gin%';

-- Database collation (PostgreSQL 18 FTS respects this)
SELECT
    current_database() AS database,
    datcollate AS lc_collate,
    datlocprovider AS provider,
    datlocale AS locale
FROM pg_database
WHERE datname = current_database();
