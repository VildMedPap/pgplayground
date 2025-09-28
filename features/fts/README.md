# PostgreSQL 18 Full Text Search

## Overview

This feature demonstrates PostgreSQL 18's Full Text Search capabilities with a focus on the new collation improvements. Using real conference data from PGConfEU 2025, we explore how FTS now respects the cluster's default collation provider instead of always using libc, providing better Unicode support and more consistent behavior.

## Key PostgreSQL 18 FTS Improvements

### 1. **Collation Provider Respect**
In PostgreSQL 18, Full Text Search uses the default collation provider of the cluster instead of always using libc. This means:
- Better Unicode handling (when ICU collation is chosen as the provider)
- Consistent behavior between FTS and other text operations
- Reduced mismatches between FTS and ILIKE results

### 2. **New PG_UNICODE_FAST Collation**
PostgreSQL 18 introduces the `PG_UNICODE_FAST` collation provider which offers:
- Full Unicode semantics for case transformations
- Accelerated text comparisons
- Better performance for international applications

### 3. **Enhanced Case-Insensitive Operations**
- New `casefold()` function for proper Unicode case folding
- Support for LIKE comparisons with nondeterministic collations
- More consistent case-insensitive searching across different methods

## ⚠️ Important: Collation Provider Selection

### Critical Considerations

The choice of collation provider has significant impacts on your database:

1. **Data Consistency**: Different collation providers may sort and compare text differently
2. **Index Compatibility**: Changing collation may require reindexing
3. **Upgrade Path**: After upgrading to PG18, you may need to reindex FTS and pg_trgm indexes
4. **Performance**: Different providers have different performance characteristics

### Collation Provider Comparison

| Provider | Pros | Cons | Use Case |
|----------|------|------|----------|
| **libc** | - System standard<br>- Widely compatible | - Limited Unicode support<br>- Platform-dependent | Legacy systems |
| **ICU** | - Excellent Unicode support<br>- Consistent across platforms<br>- Version stability | - Slightly slower<br>- Requires ICU library | International applications |
| **PG_UNICODE_FAST** | - Fast Unicode operations<br>- Built-in to PostgreSQL | - New in PG18<br>- Less tested | Modern PG18+ applications |

### Migration Warning

When migrating from pre-PG18 versions:
```sql
-- Check if reindexing is needed after upgrade
SELECT indexname, tablename
FROM pg_indexes
WHERE indexdef LIKE '%gin_trgm_ops%'
   OR indexdef LIKE '%to_tsvector%';

-- Reindex FTS indexes after collation changes
REINDEX INDEX idx_conference_events_search_gin;
```

## When to Use Full Text Search

### Use FTS When:
- Searching natural language text (articles, descriptions, comments)
- Need relevance ranking and result highlighting
- Require language-specific processing (stemming, stop words)
- Want fast searches on large text corpuses
- Need phrase and proximity searches

### Use Alternative Methods When:
- Exact substring matching is required (use LIKE/ILIKE)
- Searching structured data like codes or IDs
- Need simple contains checks without ranking
- Working with non-text data
- Semantic similarity is more important than lexical matching (use vector embeddings with pgvector)
- Handling multilingual content with significant typos/variations (embeddings capture meaning despite spelling)
- Cross-language search requirements (embeddings, depending on the model, can match concepts across languages)

## When NOT to Use Full Text Search

### Avoid FTS For:
- Small datasets (< 1000 rows) where ILIKE is sufficient
- Exact matching requirements
- Frequently updated text (indexing overhead)
- Simple prefix searches (use indexes on `text_pattern_ops`)

## Key Concepts

### Text Search Vectors (tsvector)
A `tsvector` is a sorted list of distinct lexemes (word variants) with positions. PostgreSQL normalizes words by:
- Converting to lowercase (respecting collation)
- Removing stop words
- Applying stemming rules

### Weight Priority
Our FTS configuration uses weighted priorities:
- **A (Highest)**: Title - Most important for relevance
- **B**: Abstract - Detailed content description
- **C**: Track - Category/topic information
- **D (Lowest)**: Speakers - Who's presenting the content

### Text Search Queries (tsquery)
A `tsquery` contains search terms with optional operators:
- `&` (AND), `|` (OR), `!` (NOT)
- `<->` (followed by)
- `<N>` (within N words)

### Search Configurations
Language-specific rules for processing text:
- `english`: English stemming and stop words
- `simple`: No linguistic processing
- Custom configurations for specific domains

## Best Practices

1. **Choose the Right Collation**: Select your collation provider at database creation time based on your needs
2. **Use Generated Columns**: Store tsvectors as generated columns for automatic updates
3. **Apply Weights**: Use weight classes (A, B, C, D) to prioritize different text fields
4. **Index Appropriately**: Use GIN indexes for FTS, GiST for combined FTS+spatial queries
5. **Monitor Performance**: Use EXPLAIN ANALYZE to verify index usage
6. **Consider Trigrams**: Combine FTS with pg_trgm for fuzzy matching capabilities

## Performance Considerations

### Index Types
- **GIN (Generalized Inverted Index)**: Best for FTS, faster searches, slower updates
- **GiST (Generalized Search Tree)**: Supports proximity queries, faster updates, slower searches
- **BRIN**: Not suitable for FTS

### Query Optimization
- Limit result sets with LIMIT
- Use ts_rank for relevance, not for filtering
- Combine FTS with other filters to reduce search space
- Consider partial indexes for specific search domains

## Common Pitfalls

1. **Forgetting to Analyze**: Always run ANALYZE after bulk data loads
2. **Wrong Configuration**: Using 'simple' when language-specific processing is needed
3. **Over-indexing**: Creating too many FTS indexes on rarely-searched columns
4. **Ignoring Collation**: Not considering collation impacts on search results
5. **Missing Statistics**: Not creating multi-column statistics for correlated columns

## Getting Started

```bash
# Complete setup
make setup           # Builds, runs, downloads data, and loads it

# Or step by step:
make buildrun        # Start PostgreSQL 18 container
make download-schedule  # Download conference data
make load-data       # Load data into database

# Test and explore
make connect         # Connect with psql
make test-fts       # Run sample queries
make teardown       # Clean up when done
```

## Key Files

- `init.sql` - Database setup with ICU collation, tables, indexes, and functions
- `queries.sql` - Comprehensive FTS examples you can run in DBeaver
- Downloads are handled by curl in the Makefile
- `load_conference_data.py` - Parses XML and loads into PostgreSQL

## Example Searches

### Basic Text Search
```sql
-- Find talks about replication
SELECT title, ts_rank(search_vector, query) AS rank
FROM conference_events, plainto_tsquery('english', 'replication') query
WHERE search_vector @@ query
ORDER BY rank DESC;
```

### Case-Insensitive Comparison
```sql
-- FTS vs ILIKE - both handle case automatically with ICU
SELECT COUNT(*) FROM conference_events
WHERE search_vector @@ plainto_tsquery('english', 'postgresql');

SELECT COUNT(*) FROM conference_events
WHERE title ILIKE '%postgresql%';
```

### Advanced Features
```sql
-- Phrase search with highlighting
SELECT ts_headline('english', abstract,
                  phraseto_tsquery('english', 'query optimization'))
FROM conference_events
WHERE search_vector @@ phraseto_tsquery('english', 'query optimization');

-- Fuzzy matching with trigrams
SELECT title, similarity(title, 'Postgre SQL') AS score
FROM conference_events
WHERE title % 'Postgre SQL'
ORDER BY score DESC;
```

## Unaccent Extension

The `unaccent` extension is included for accent-insensitive searches:

```sql
-- Without unaccent: café ≠ cafe
-- With unaccent: café = cafe

SELECT unaccent('café') = 'cafe';  -- Returns true

-- Use in FTS
SELECT title FROM conference_events
WHERE search_vector @@ to_tsquery('english', unaccent('café'));
```

**Note**: While unaccent helps with diacritics, it has limitations:
- Performance overhead for large datasets
- May not handle all Unicode normalization cases
- Consider storing both accented and unaccented versions if critical

## Configured Synonyms

The following synonyms are configured for better search results:

- **AI/ML Terms**: AI ↔ LLM ↔ ML (machine learning, artificial intelligence, large language models)
- **Search Terms**: FTS ↔ lexical search ↔ keyword search
- **Database Terms**: postgres ↔ postgresql ↔ pg, database ↔ db ↔ rdbms
- **Technical Terms**: index ↔ idx ↔ indices, query ↔ sql ↔ statement

## Resources

- [PostgreSQL 18 Release Notes](https://www.postgresql.org/docs/18/release-18.html)
- [Full Text Search Documentation](https://www.postgresql.org/docs/current/textsearch.html)
- [ICU Collation Support](https://www.postgresql.org/docs/current/collation.html#COLLATION-ICU)
- [PGConfEU 2025](https://www.postgresql.eu/events/pgconfeu2025/)
