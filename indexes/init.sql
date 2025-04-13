-- Create a test table
CREATE TABLE customer_orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    order_date DATE NOT NULL,
    quantity INTEGER NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(50),
    category VARCHAR(100),
    region VARCHAR(50)
);

-- Generate 500,000 rows of meaningful test data
INSERT INTO customer_orders (customer_id, product_id, order_date, quantity, amount, payment_method, category, region)
SELECT 
    (random() * 10000)::INTEGER AS customer_id,
    (random() * 1000)::INTEGER AS product_id,
    CURRENT_DATE - ((random() * 1095)::INTEGER) AS order_date,
    (random() * 10 + 1)::INTEGER AS quantity,
    (random() * 500 + 10)::DECIMAL(10,2) AS amount,
    (ARRAY['Credit Card', 'PayPal', 'Bank Transfer', 'Cash', 'Crypto'])[(random() * 4 + 1)::INTEGER] AS payment_method,
    (ARRAY['Electronics', 'Clothing', 'Food', 'Books', 'Home', 'Sports', 'Beauty', 'Toys'])[(random() * 7 + 1)::INTEGER] AS category,
    (ARRAY['North', 'South', 'East', 'West', 'Central'])[(random() * 4 + 1)::INTEGER] AS region
FROM generate_series(1, 500000);

-- Create statistics to ensure the query planner has accurate information
ANALYZE customer_orders;
