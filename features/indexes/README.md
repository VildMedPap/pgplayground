# PostgreSQL indexing

## When to Use Indexes

- **High-cardinality columns**: Columns with many unique values benefit most from indexing
- **Frequently queried columns**: Focus on columns that appear often in WHERE, JOIN, and ORDER BY clauses
- **Foreign keys**: Always index foreign key columns to speed up joins
- **Primary keys**: PostgreSQL automatically creates indexes for primary keys

## When NOT to Use Indexes

- **Small tables**: Tables with few rows (under ~1000) often don't benefit from indexes
- **Tables that are predominantly write-heavy**: Indexes slow down INSERT, UPDATE, and DELETE operations
- **Low-cardinality columns**: Columns with few unique values (like boolean flags) often don't benefit from indexing
- **Columns rarely used in queries**: Don't index columns that aren't frequently searched or joined

## Index Types and When to Use Them

### B-tree Index (Default)
```sql
CREATE INDEX idx_name ON table(column);
```
- **Best for**: Most scenarios - equality, range queries, sorting, and pattern matching (with a leading wildcard)
- **Use when**: You're not sure which index type to use (it's the default for good reason)

### Hash Index
```sql
CREATE INDEX idx_name ON table USING HASH (column);
```
- **Best for**: Equality operations only (`column = value`)
- **Use when**: You only need to perform exact match lookups and no range queries

### GIN (Generalized Inverted Index)
```sql
CREATE INDEX idx_name ON table USING GIN (column);
```
- **Best for**: Composite data types (arrays, jsonb, tsvector)
- **Use when**: Querying inside JSON, arrays, or performing full-text search

### GiST (Generalized Search Tree)
```sql
CREATE INDEX idx_name ON table USING GIST (column);
```
- **Best for**: Geometric data types, full-text search
- **Use when**: Working with spatial data or complex data structures

### BRIN (Block Range Index)
```sql
CREATE INDEX idx_name ON table USING BRIN (column);
```
- **Best for**: Very large tables with naturally clustered data (like timestamps)
- **Use when**: Tables are huge and query patterns align with the natural ordering of data

## Compound Index Strategies

### Key Ordering Rules
```sql
CREATE INDEX idx_name ON table(col1, col2, col3);
```

1. **Put equality columns first**: Columns used with `=` or `IN` should come before range columns
2. **Put highly selective columns first**: Columns that filter out more rows should come earlier
3. **Put frequently used columns first**: Columns used in queries without all the preceding columns

### Covering Indexes
```sql
CREATE INDEX idx_name ON table(col1) INCLUDE (col2, col3);
```
- Include additional columns to enable index-only scans
- Can dramatically improve performance by avoiding table lookups

## Partial Indexes for Targeted Performance

```sql
CREATE INDEX idx_active_users ON users(last_login) WHERE status = 'active';
```
- Index only a subset of rows to reduce index size and improve insert performance
- Extremely effective when queries consistently filter on the same condition

## Index Maintenance

```sql
-- Rebuild an index
REINDEX INDEX idx_name;

-- Analyze a table to update statistics
ANALYZE table_name;

-- Find unused indexes
SELECT * FROM pg_stat_user_indexes WHERE idx_scan = 0;
```

- Regularly ANALYZE tables to keep statistics current
- Monitor and remove unused indexes
- Consider REINDEX after major data changes

## Performance Monitoring

```sql
-- Test index effectiveness
EXPLAIN ANALYZE SELECT * FROM table WHERE condition;
```

Look for:
- "Index Scan" or "Index Only Scan" (good) vs. "Sequential Scan" (potentially bad)
- "Bitmap Index Scan" often appears for larger result sets
- Execution time differences before and after indexing

## Rules of Thumb

1. **Start with the minimum**: Don't over-index initially; add indexes based on real query patterns
2. **Test, don't guess**: Always use EXPLAIN ANALYZE to confirm index usage
3. **Column order matters**: In compound indexes, leftmost columns should match query filters
4. **Watch for writes**: Every index slows down writes, so balance read vs. write performance
5. **Favor high-cardinality**: Columns with more unique values make better index candidates
6. **Consider covering indexes**: Including columns can enable index-only scans
7. **Monitor index usage**: Regularly check for and remove unused indexes
8. **Update statistics**: Run ANALYZE after significant data changes
9. **B-tree first**: When in doubt, start with a B-tree index before trying specialized index types
10. **Think beyond queries**: Indexes also impact constraints, sorting operations, and joins
