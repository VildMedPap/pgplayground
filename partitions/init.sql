-- Create parent table (partitioned by category)
CREATE TABLE products (
    product_id SERIAL,
    category TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INTEGER,
    rating DECIMAL(3,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) PARTITION BY LIST (category);

-- Create child partitions by category
CREATE TABLE products_electronics PARTITION OF products
    FOR VALUES IN ('electronics');
    
CREATE TABLE products_clothing PARTITION OF products
    FOR VALUES IN ('clothing');
    
CREATE TABLE products_home PARTITION OF products
    FOR VALUES IN ('home');
    
CREATE TABLE products_books PARTITION OF products
    FOR VALUES IN ('books');
    
CREATE TABLE products_toys PARTITION OF products
    FOR VALUES IN ('toys');

-- Create non-partitioned table for comparison
CREATE TABLE products_nonpartitioned (
    product_id SERIAL PRIMARY KEY,
    category TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INTEGER,
    rating DECIMAL(3,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_products_category_price ON products(category, price);
CREATE INDEX idx_products_nonpart_category_price ON products_nonpartitioned(category, price);
