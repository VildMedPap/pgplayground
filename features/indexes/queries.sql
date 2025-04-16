-- Test Scenario 1 - Exact Match Lookup

-- Scenario 1A: Exact match lookup WITHOUT any index: ~20ms
EXPLAIN ANALYZE
SELECT * FROM customer_orders 
WHERE customer_id = 5000;

-- Scenario 1B: Create an appropriate B-tree index
CREATE INDEX idx_customer_id ON customer_orders(customer_id);
ANALYZE customer_orders;

-- Run the same query WITH the B-tree index: ~0.5ms
EXPLAIN ANALYZE
SELECT * FROM customer_orders 
WHERE customer_id = 5000;

-- Scenario 1C: Create a Hash index (also appropriate for equality)
DROP INDEX idx_customer_id;
CREATE INDEX idx_customer_id_hash ON customer_orders USING HASH (customer_id);
ANALYZE customer_orders;

-- Run with Hash index: ~0.5ms
EXPLAIN ANALYZE
SELECT * FROM customer_orders 
WHERE customer_id = 5000;

-- Cleanup
DROP INDEX idx_customer_id_hash;

-- Test Scenario 2 - Range Query

-- Scenario 2A: Range query WITHOUT any index: ~22ms
EXPLAIN ANALYZE
SELECT * FROM customer_orders 
WHERE order_date BETWEEN '2023-01-01' AND '2023-01-31';

-- Scenario 2B: Create an appropriate B-tree index
CREATE INDEX idx_order_date ON customer_orders(order_date);
ANALYZE customer_orders;

-- Run with B-tree index: ~15ms
EXPLAIN ANALYZE
SELECT * FROM customer_orders 
WHERE order_date BETWEEN '2023-01-01' AND '2023-01-31';

-- Scenario 2C: Create a Hash index (inappropriate for ranges)
DROP INDEX idx_order_date;
CREATE INDEX idx_order_date_hash ON customer_orders USING HASH (order_date);
ANALYZE customer_orders;

-- Run with Hash index (should fall back to sequential scan): ~22ms
EXPLAIN ANALYZE
SELECT * FROM customer_orders 
WHERE order_date BETWEEN '2023-01-01' AND '2023-01-31';

-- Cleanup
DROP INDEX idx_order_date_hash;

-- Test Scenario 3 - Multi-Column Conditions

-- Scenario 3A: Combined filter WITHOUT any index: ~27ms
EXPLAIN ANALYZE
SELECT * FROM customer_orders 
WHERE category = 'Electronics' AND payment_method = 'Credit Card';

-- Scenario 3B: Create an appropriate compound index
CREATE INDEX idx_category_payment ON customer_orders(category, payment_method);
ANALYZE customer_orders;

-- Run with proper compound index: ~7ms
EXPLAIN ANALYZE
SELECT * FROM customer_orders 
WHERE category = 'Electronics' AND payment_method = 'Credit Card';

-- Scenario 3C: Create a compound index with columns in reverse order
DROP INDEX idx_category_payment;
CREATE INDEX idx_payment_category ON customer_orders(payment_method, category);
ANALYZE customer_orders;

-- Run with reversed compound index: ~7ms
EXPLAIN ANALYZE
SELECT * FROM customer_orders 
WHERE category = 'Electronics' AND payment_method = 'Credit Card';

-- Scenario 3D: Query using only the second part of a compound index: ~15ms
EXPLAIN ANALYZE
SELECT * FROM customer_orders 
WHERE category = 'Electronics';

-- Scenario 3E: Query using only the first part of a compound index: ~25ms
EXPLAIN ANALYZE
SELECT * FROM customer_orders 
WHERE payment_method = 'Credit Card';

-- Cleanup
DROP INDEX idx_payment_category;

-- Test Scenario 4 - Low-Selectivity Column

-- Scenario 4A: Query on low-cardinality column WITHOUT index: ~60ms
EXPLAIN ANALYZE
SELECT * FROM customer_orders 
WHERE region = 'East';

-- Scenario 4B: Add an index on the low-cardinality column
CREATE INDEX idx_region ON customer_orders(region);
ANALYZE customer_orders;

-- Run the same query with index: ~40ms
EXPLAIN ANALYZE
SELECT * FROM customer_orders 
WHERE region = 'East';

-- Cleanup
DROP INDEX idx_region;
