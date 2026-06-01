USE ecommerce;

-- Helper table for average rating per product

CREATE TABLE product_avg_ratings AS
SELECT
    product_id,
    ROUND(AVG(stars), 2)    AS avg_rating,
    COUNT(*)                AS total_ratings
FROM ratings
GROUP BY product_id;

SELECT COUNT(*) AS total FROM product_avg_ratings;


-- Helper table for top selling product per seller

CREATE TABLE top_products_per_seller AS
SELECT seller_id, top_product
FROM (
    SELECT
        oi.seller_id,
        p.name              AS top_product,
        SUM(oi.quantity)    AS total_qty,
        ROW_NUMBER() OVER (
            PARTITION BY oi.seller_id
            ORDER BY SUM(oi.quantity) DESC
        )                   AS rn
    FROM order_items_small oi
    INNER JOIN products p ON p.id = oi.product_id
    GROUP BY oi.seller_id, oi.product_id, p.name
) t
WHERE t.rn = 1;

SELECT * FROM top_products_per_seller;


-- V1 — Seller dashboard showing revenue orders rating and top product

CREATE OR REPLACE VIEW seller_dashboard_view AS
SELECT
    sp.business_name                                AS seller_name,
    COUNT(DISTINCT o.id)                            AS total_orders,
    ROUND(SUM(oi.unit_price * oi.quantity), 2)      AS total_revenue,
    ROUND(AVG(par.avg_rating), 2)                   AS avg_rating,
    tp.top_product                                  AS top_product_by_units
FROM order_items_small            oi
INNER JOIN orders_small            o   ON o.id          = oi.order_id
INNER JOIN users                   u   ON u.id           = oi.seller_id
INNER JOIN seller_profiles         sp  ON sp.user_id     = u.id
LEFT  JOIN product_avg_ratings     par ON par.product_id = oi.product_id
LEFT  JOIN top_products_per_seller tp  ON tp.seller_id   = oi.seller_id
GROUP BY oi.seller_id, sp.business_name, tp.top_product;

SELECT * FROM seller_dashboard_view;


-- V2 — Monthly revenue per seller

CREATE OR REPLACE VIEW monthly_revenue_view AS
SELECT
    sp.business_name,
    DATE_FORMAT(o.created_at, '%Y-%m')              AS order_month,
    ROUND(SUM(oi.unit_price * oi.quantity), 2)      AS monthly_revenue
FROM order_items_small oi
INNER JOIN orders_small    o  ON o.id       = oi.order_id
INNER JOIN users           u  ON u.id       = oi.seller_id
INNER JOIN seller_profiles sp ON sp.user_id = u.id
GROUP BY oi.seller_id, sp.business_name,
         DATE_FORMAT(o.created_at, '%Y-%m');

SELECT * FROM monthly_revenue_view
ORDER BY business_name, order_month;


-- V3 — Products below reorder threshold with warehouse location

CREATE OR REPLACE VIEW low_stock_view AS
SELECT
    p.name                                          AS product_name,
    w.name                                          AS warehouse_name,
    w.location                                      AS warehouse_location,
    inv.quantity_available,
    inv.reorder_threshold,
    inv.reorder_threshold - inv.quantity_available  AS units_below_threshold
FROM inventory inv
INNER JOIN products   p ON p.id = inv.product_id
INNER JOIN warehouses w ON w.id = inv.warehouse_id
WHERE inv.quantity_available < inv.reorder_threshold
ORDER BY units_below_threshold DESC;

SELECT * FROM low_stock_view;


-- V4 — All orders per customer with payment and return status

CREATE OR REPLACE VIEW customer_order_history_view AS
SELECT
    u.email             AS customer_email,
    o.id                AS order_id,
    o.status            AS order_status,
    o.total_amount,
    o.created_at,
    pay.method          AS payment_method,
    pay.status          AS payment_status,
    CASE
        WHEN r.id IS NOT NULL THEN 'Returned'
        ELSE 'No Return'
    END                 AS return_status,
    rf.amount           AS refund_amount
FROM orders_small o
INNER JOIN users    u   ON u.id         = o.customer_id
LEFT  JOIN payments pay ON pay.order_id = o.id
LEFT  JOIN returns  r   ON r.order_id   = o.id
LEFT  JOIN refunds  rf  ON rf.return_id = r.id;

SELECT * FROM customer_order_history_view
ORDER BY customer_email, order_id
LIMIT 100;


-- V5 — Carts inactive for more than 24 hours

CREATE OR REPLACE VIEW abandoned_cart_view AS
SELECT
    u.email                                     AS customer_email,
    ct.id                                       AS cart_id,
    COUNT(ci.id)                                AS item_count,
    ROUND(SUM(p.base_price * ci.quantity), 2)   AS total_cart_value,
    ct.created_at                               AS cart_created_at,
    DATEDIFF(NOW(), ct.created_at)              AS cart_age_days
FROM cart ct
INNER JOIN users      u  ON u.id       = ct.user_id
INNER JOIN cart_items ci ON ci.cart_id = ct.id
INNER JOIN products   p  ON p.id       = ci.product_id
WHERE ct.created_at < DATE_SUB(NOW(), INTERVAL 24 HOUR)
GROUP BY ct.id, u.email, ct.created_at
ORDER BY cart_age_days DESC;

SELECT * FROM abandoned_cart_view LIMIT 50;


-- B-Tree indexes on all foreign key columns
-- Run each line one at a time and skip any duplicate key errors

CREATE INDEX idx_orders_customer       ON orders       (customer_id);
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

EXPLAIN SELECT
    id,
    total_amount,
    created_at
FROM orders
WHERE  customer_id = 1
ORDER BY created_at DESC;


-- EXPLAIN ANALYZE after indexes to show improvement

EXPLAIN ANALYZE SELECT
    id,
    total_amount,
    created_at
FROM orders
WHERE  customer_id = 1
ORDER BY created_at DESC;


-- Partitioned orders table by year for partition pruning demo

CREATE TABLE IF NOT EXISTS orders_partitioned (
    id                  INT             NOT NULL,
    customer_id         INT             NOT NULL,
    shipping_address_id INT,
    status              ENUM('pending','confirmed','shipped',
                             'delivered','cancelled') DEFAULT 'pending',
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


-- Insert sample data into partitioned table

INSERT INTO orders_partitioned
    (id, customer_id, shipping_address_id, status, total_amount, created_at)
SELECT
    id,
    customer_id,
    shipping_address_id,
    status,
    total_amount,
    DATE(created_at)
FROM orders_small;


-- Verify partition pruning is working

EXPLAIN SELECT *
FROM   orders_partitioned
WHERE  YEAR(created_at) = 2025;


-- Show all views created

SHOW FULL TABLES WHERE Table_type = 'VIEW';


-- Show all indexes on key tables

SHOW INDEX FROM orders;
SHOW INDEX FROM order_items;
SHOW INDEX FROM payments;
SHOW INDEX FROM inventory;