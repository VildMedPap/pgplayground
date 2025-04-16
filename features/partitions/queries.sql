-- Experiment 1: Bulk Loading Performance

-- Generate test data for partitioned table: ~35s
INSERT INTO products (category, name, description, price, stock_quantity, rating)
SELECT
    (ARRAY['electronics', 'clothing', 'home', 'books', 'toys'])[1 + (random() * 4)::INT] AS category,
    'Product ' || i AS name,
    'Description for product ' || i AS description,
    (random() * 990 + 10)::DECIMAL(10,2) AS price,
    (random() * 1000)::INTEGER AS stock_quantity,
    (random() * 5)::DECIMAL(3,2) AS rating
FROM generate_series(1, 5000000) AS i;

-- Generate test data for non-partitioned table: ~39s
INSERT INTO products_nonpartitioned (category, name, description, price, stock_quantity, rating)
SELECT
    (ARRAY['electronics', 'clothing', 'home', 'books', 'toys'])[1 + (random() * 4)::INT] AS category,
    'Product ' || i AS name,
    'Description for product ' || i AS description,
    (random() * 990 + 10)::DECIMAL(10,2) AS price,
    (random() * 1000)::INTEGER AS stock_quantity,
    (random() * 5)::DECIMAL(3,2) AS rating
FROM generate_series(1, 5000000) AS i;

-- Experiment 2: Query Performance

-- Clear cache
DISCARD ALL;

-- Query by category (partition elimination): ~42ms
EXPLAIN ANALYZE
SELECT 
    COUNT(*),
    AVG(price)::DECIMAL(10,2) AS avg_price,
    MAX(price) AS max_price,
    MIN(price) AS min_price
FROM products
WHERE category = 'electronics'
AND price BETWEEN 100 AND 500;

-- Same query on non-partitioned table: ~49ms
EXPLAIN ANALYZE
SELECT 
    COUNT(*),
    AVG(price)::DECIMAL(10,2) AS avg_price,
    MAX(price) AS max_price,
    MIN(price) AS min_price
FROM products_nonpartitioned
WHERE category = 'electronics'
AND price BETWEEN 100 AND 500;

-- Experiment 3: Maintenance Operations

-- Adding a new category partition
CREATE TABLE products_beauty PARTITION OF products
    FOR VALUES IN ('beauty');

-- Insert data into new partition
INSERT INTO products (category, name, description, price, stock_quantity, rating)
SELECT
    'beauty' AS category,
    'Beauty Product ' || i AS name,
    'Description for beauty product ' || i AS description,
    (random() * 200 + 5)::DECIMAL(10,2) AS price,
    (random() * 500)::INTEGER AS stock_quantity,
    (random() * 5)::DECIMAL(3,2) AS rating
FROM generate_series(1, 50000) AS i;

-- Remove an entire category (fast)
DROP TABLE products_toys;

-- Compare to deleting from non-partitioned table
DELETE FROM products_nonpartitioned WHERE category = 'toys';

-- Experiment 4: Index Maintenance

-- Compare index sizes
SELECT 
    pg_size_pretty(pg_relation_size('idx_products_category_price')) AS partitioned_index_size,
    pg_size_pretty(pg_relation_size('idx_products_nonpart_category_price')) AS nonpartitioned_index_size;

-- Rebuild indexes and compare time
REINDEX INDEX idx_products_category_price;
REINDEX INDEX idx_products_nonpart_category_price;

-- Experiment 5: VACUUM Performance

-- Delete some data from both tables
DELETE FROM products 
WHERE product_id % 10 = 0;

DELETE FROM products_nonpartitioned 
WHERE product_id % 10 = 0;

-- Time VACUUM operations
VACUUM VERBOSE ANALYZE products;
VACUUM VERBOSE ANALYZE products_nonpartitioned;

-- Experiment 6: Cross-Partition Operations

-- Query across multiple partitions: ~155ms
EXPLAIN ANALYZE
SELECT 
    category,
    COUNT(*),
    AVG(price)::DECIMAL(10,2) AS avg_price
FROM products
WHERE category IN ('electronics', 'home')
AND price > 200
GROUP BY category;

-- Query across multiple categories - unpartitioned: ~145ms
EXPLAIN ANALYZE
SELECT 
    category,
    COUNT(*),
    AVG(price)::DECIMAL(10,2) AS avg_price
FROM products_nonpartitioned
WHERE category IN ('electronics', 'home')
AND price > 200
GROUP BY category;
