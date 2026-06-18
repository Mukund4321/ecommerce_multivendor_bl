USE ecommerce;

-- B-Tree indexes on all foreign key columns
-- Run each line one at a time and skip duplicate key errors

CREATE INDEX idx_orders_customer        ON orders       (customer_id);
CREATE INDEX idx_orders_address        ON orders       (shipping_address_id);
CREATE INDEX idx_order_items_order     ON order_items  (order_id);
CREATE INDEX idx_order_items_product   ON order_items  (product_id);
CREATE INDEX idx_order_items_seller    ON order_items  (seller_id);
CREATE INDEX idx_payments_order        ON payments     (order_id);
CREATE INDEX idx_inventory_product     ON inventory    (product_id);
CREATE INDEX idx_inventory_warehouse   ON inventory    (warehouse_id);
CREATE INDEX idx_reviews_product       ON reviews      (product_id);
CREATE INDEX idx_reviews_customer      ON reviews      (customer_id);
CREATE INDEX idx_ratings_product       ON ratings      (product_id);
CREATE INDEX idx_returns_order         ON returns      (order_id);
CREATE INDEX idx_returns_customer      ON returns      (customer_id);
CREATE INDEX idx_coupon_usage_coupon   ON coupon_usage (coupon_id);
CREATE INDEX idx_coupon_usage_customer ON coupon_usage (customer_id);


-- Composite index to optimise seller dashboard date range queries

CREATE INDEX idx_orders_customer_date
    ON orders (customer_id, created_at DESC);


-- Covering index on order_items to enable index only scans

CREATE INDEX idx_order_items_covering
    ON order_items (order_id, product_id, quantity, unit_price);


-- EXPLAIN before indexes to record original query cost

EXPLAIN SELECT id, total_amount, created_at
FROM orders WHERE customer_id = 1 ORDER BY created_at DESC;


-- EXPLAIN ANALYZE after indexes to show improvement

EXPLAIN ANALYZE SELECT id, total_amount, created_at
FROM orders WHERE customer_id = 1 ORDER BY created_at DESC;


-- Partitioned orders table by year

CREATE TABLE IF NOT EXISTS orders_partitioned (
    id                  INT             NOT NULL,
    customer_id         INT             NOT NULL,
    shipping_address_id INT,
    status              ENUM('pending','confirmed','shipped','delivered','cancelled') DEFAULT 'pending',
    total_amount        DECIMAL(10,2),
    created_at          DATE            NOT NULL,
    delivered_at        DATE            NULL,
    PRIMARY KEY (id, created_at)
)
PARTITION BY RANGE (YEAR(created_at)) (
    PARTITION p2024    VALUES LESS THAN (2025),
    PARTITION p2025    VALUES LESS THAN (2026),
    PARTITION p2026    VALUES LESS THAN (2027),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

INSERT INTO orders_partitioned
    (id, customer_id, shipping_address_id, status, total_amount, created_at)
SELECT id, customer_id, shipping_address_id, status, total_amount, DATE(created_at)
FROM orders_small;

EXPLAIN SELECT * FROM orders_partitioned WHERE YEAR(created_at) = 2025;


-- Show all indexes

SHOW INDEX FROM orders;
SHOW INDEX FROM order_items;
SHOW INDEX FROM payments;
SHOW INDEX FROM inventory;
