# PostgreSQL partitioning

## What is Partitioning?

Partitioning splits a large table into smaller physical pieces based on specified criteria while maintaining a single logical table for queries.

## When to Use Partitioning

- Tables exceeding 100GB
- Time-series data with clear date boundaries
- Data with natural categorical divisions
- Tables with frequent bulk deletions of identifiable segments
- When you need different storage policies for different data segments

## When NOT to Use Partitioning

- Small to medium-sized tables (<10GB)
- Tables without a clear partition key
- When queries rarely filter on the potential partition key
- When most queries span across multiple partitions
- When complex joins across partitions are common

## Partition Types and When to Use Them

### LIST Partitioning
```sql
PARTITION BY LIST (category)
```
- **Best for**: Categorical data with discrete values (regions, product categories)
- **Example use case**: E-commerce product catalog by department

### RANGE Partitioning
```sql
PARTITION BY RANGE (created_at)
```
- **Best for**: Time-series data, numerical ranges with clear boundaries
- **Example use case**: Orders by month, sensor readings by date range

### HASH Partitioning
```sql
PARTITION BY HASH (customer_id) PARTITIONS 32  -- example number of partitions
```
- **Best for**: Evenly distributing data across partitions when you have many distinct values
- **Example use case**: High-volume order system with thousands of customers, partitioned to balance I/O and query load

## Partitioning Best Practices

1. **Choose the right partition key**
   - Must align with common query filters
   - Should distribute data relatively evenly (except for LIST)
   - Ideally has low update frequency

2. **Partition granularity matters**
   - Too many partitions: Management overhead
   - Too few partitions: Limited benefits
   - Aim for dozens to hundreds, not thousands of partitions

3. **Indexing strategy**
   - Local indexes on each partition are more efficient than global indexes
   - Don't create single-column indexes on just the partition key
   - Create indexes that are relevant to each partition's query patterns

4. **Plan for growth**
   - Create partitions in advance of needing them
   - Use default partitions to catch unexpected values
   - Consider automating partition management

## Performance Benefits

- **Query speedup**: 3-100x faster for partition-pruned queries
- **Maintenance efficiency**: VACUUM, REINDEX run on smaller tables
- **Parallel query**: Operations can run in parallel across partitions
- **Index efficiency**: Smaller, more efficient indexes per partition

## Migration Path

To partition an existing table:
1. Create new partitioned table with same schema
2. Create required partitions
3. Copy data across (can be done in batches)
4. Rename tables to switch them
5. Recreate indexes and constraints
6. Validate and drop old table

## Rules of Thumb

1. **Start with simple schemes**: Range by date or list by category are easiest
2. **Plan partition boundaries**: Too granular creates overhead, too coarse limits benefits
3. **Create indexes after loading data**: Speeds up initial loads significantly
4. **Monitor partition counts**: Keep below 1000 for manageable administration
5. **Test query patterns**: Ensure common queries benefit from partition pruning
6. **Use partitioning with other techniques**: Combine with materialized views or table inheritance for complex scenarios
7. **Match partition boundaries to query patterns**: Align time partitions with reporting periods
8. **Consider read/write patterns**: Heavily modified data might benefit from smaller partitions
9. **Avoid dynamic partition keys**: Fields frequently updated make poor partition keys
