-- Q1 — Products with seller name brand name and category
SELECT
    p.id                AS product_id,
    p.name              AS product_name,
    p.base_price,
    sp.business_name    AS seller_name,
    b.name              AS brand_name,
    c.name              AS category_name
FROM products p
INNER JOIN users              u   ON u.id       = p.seller_id
INNER JOIN seller_profiles    sp  ON sp.user_id = u.id
INNER JOIN brands             b   ON b.id       = p.brand_id
INNER JOIN product_categories pc  ON pc.product_id = p.id
INNER JOIN categories         c   ON c.id       = pc.category_id
ORDER BY p.id;

-- Q1. Get all customers from the users table where role is customer. Show only id, email, and created_at.

SELECT id, email, created_at
FROM users
WHERE role = 'customer'

-- Q9. Count how many orders exist for each status. Show status and total count. Sort by count highest first.


select 
    o.status       as order_status,
    count(*)    as total_count
FROM ORDERS o
GROUP BY o.status


-- Q Find the average base price of all active products.

SELECT
    ROUND(AVG(p.base_price),2) AS average_base
FROM products p 
WHERE p.status = 'active'

-- q1 Find the number of orders placed each month. Show month, year, and order count. Sort chronologically.

SELECT
    DATE(created_at)                            as orders_placed,
    DATE_FORMAT(created_at, '%M %Y')          AS month_name,
    COUNT(*)                                  as total_orders_montly
    FROM ORDERS
    GROUP BY DATE(created_at), DATE_FORMAT(created_at, '%M %Y');

-- Find all products whose base price is above the overall average price of all products.

SELECT
    p.id            AS product_id,
    p.name          AS product_name,
    p.base_price
FROM products p
WHERE p.base_price > (SELECT ROUND(AVG(base_price),2) FROM products)

-- **Q31.** Use a CTE to find the top 3 customers by total amount spent on delivered orders.

WITH customer_spending AS (
    SELECT
        o.customer_id,
        SUM(o.total_amount) AS total_spent
    FROM orders_small o
    WHERE o.status = 'delivered'
    GROUP BY o.customer_id
)
SELECT
    u.email                     AS customer_email,
    cs.total_spent
FROM customer_spending cs
INNER JOIN users u ON u.id = cs.customer_id
ORDER BY cs.total_spent DESC
LIMIT 3;


-- **Q2.** Find all customers who have never placed an order. Use LEFT JOIN between users and orders and filter where order id is NULL.

SELECT * FROM ORDERS


SELECT
    u.id            AS customer_id,
    u.email         AS customer_email
FROM users u
LEFT JOIN orders o ON o.customer_id = u.id
WHERE o.id IS NULL  AND u.role = 'customer';


-- **Q3.** Show all orders with customer email, product name, quantity, and unit price. Join orders, users, order_items, and products.

SELECT 
    o.id           AS order_id,
    u.email        AS customer_email,
    p.name         AS product_name,
    oi.quantity    AS quantity,
    oi.unit_price  AS unit_price
FROM orders o
INNER JOIN users u        ON u.id = o.id
INNER JOIN order_items oi ON oi.order_id = o.id
INNER JOIN products p     ON p.id = oi.product_id
WHERE u.role = 'customer'
ORDER BY o.id;




SELECT 
    o.id    AS order_id,
    u.email AS customer_email
FROM orders o
INNER JOIN users u ON u.id = o.id
WHERE u.role = 'customer'
ORDER BY o.id;

--  Show all sellers with their total number of products. Include sellers who have listed zero products. Use LEFT JOIN.

SELECT
    sp.business_name    AS seller_name,
    COUNT(p.id)        AS total_products
FROM seller_profiles sp
LEFT JOIN products p ON p.seller_id = sp.user_id
GROUP BY sp.business_name
ORDER BY total_products DESC; 

-- **Q5.** Show all returned orders with customer email, product name, return reason, and refund amount. Join returns, users, order_items, products, and refunds.

SELECT 
    o.id as order_id,
    u.email as customer_mail,
    p.name as product_name,
    rt.reason_code as return_reason,
    rf.amount as return_amount
FROM orders o
INNER JOIN users u ON u.id = o.customer_id
INNER JOIN products p ON p.id = o.customer_id
INNER JOIN returns rt ON rt.order_id = o.customer_id
INNER JOIN refunds rf ON rf.return_id = o.customer_id
ORDER BY o.id;


-- **Q1.** Find all products whose base price is higher than the average base price of all products. Use a subquery in WHERE.

select 
    p.id  as product_id,
    p.name as product_name,
    p.base_price
FROM PRODUCTS p
WHERE base_price > (SELECT ROUND(AVG(base_price),2) FROM products)
ORDER BY p.id;

-- **Q2.** Find all customers who have placed at least one order using EXISTS subquery.

SELECT
    u.id            AS customer_id,
    u.email         AS customer_email   
FROM users u
WHERE u.role = 'customer' AND EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.customer_id = u.id
);


-- Find all products that have never been ordered using NOT EXISTS subquery.

SELECT
    p.id            AS product_id,
    p.name          AS product_name
FROM products p
WHERE NOT EXISTS (
    SELECT 1
    FROM order_items oi
    WHERE oi.product_id = p.id
)   ORDER BY p.id;

-- **Q4.** Find all orders whose total amount is above the average total amount of all delivered orders. Use a subquery in WHERE.

SELECT
    o.id as order_id,
    o.customer_id as customer,
    o.total_amount as total_amount
FROM ORDERS o
WHERE total_amount > (SELECT
ROUND(AVG(total_amount),2)
FROM orders)
ORDER BY o.id

-- **Q5.** For each product show its name and how many times it has been ordered. Use a subquery in the SELECT clause.

select 
    p.id as product_id,
    p.name as product_name,
    (SELECT 
    COUNT(*)
    FROM order_items oi
    WHERE p.id = oi.product_id) as times_ordered
FROM products p

--  Use a CTE to calculate total revenue per seller. Then in the main query show only sellers who earned above the overall average revenue

WITH seller_revenue as (
    SELECT 
    sp.business_name as seller_name,
    SUM(oi.quantity * oi.unit_price) as total_revenue
FROM order_items oi
INNER JOIN products p ON p.id = oi.product_id
INNER JOIN seller_profiles sp ON sp.user_id = p.seller_id
GROUP BY sp.business_name
)
Select 
    sr.seller_name,
    sr.total_revenue
FROM seller_revenue sr
WHERE total_revenue > (SELECT
    ROUND(AVG(total_revenue),2)
    FROM seller_revenue sr)
    ORDER BY sr.total_revenue DESC

-- **Q3.** Use two CTEs — first find total orders per customer, second find customers with more than 5 orders. Show their email and order count.
WITH customer_orders AS (
    SELECT
        o.customer_id,
        COUNT(*) AS total_orders
    FROM orders o
    GROUP BY o.customer_id
),
frequent_customers AS (
    SELECT
        customer_id,
        total_orders
    FROM customer_orders
    WHERE total_orders > 5
)
SELECT
    u.email         AS customer_email,
    fc.total_orders AS order_count  
FROM frequent_customers fc
INNER JOIN users u ON u.id = fc.customer_id 
ORDER BY fc.total_orders DESC;

-- **Q5.** Use a CTE to find the best selling product per seller by total quantity sold. Show seller name and product name.\

WITH seller_product_sales AS (
    SELECT
        sp.business_name AS seller_name,
        p.name AS product_name,
        SUM(oi.quantity) AS total_quantity_sold
    FROM order_items oi
    INNER JOIN products p ON p.id = oi.product_id
    INNER JOIN seller_profiles sp ON sp.user_id = p.seller_id
    GROUP BY sp.business_name, p.name
),
best_selling_products AS (
    SELECT
        seller_name,
        product_name,
        total_quantity_sold,
        ROW_NUMBER() OVER (PARTITION BY seller_name ORDER BY total_quantity_sold DESC) AS rn
    FROM seller_product_sales
)
SELECT
    seller_name,
    product_name,
    total_quantity_sold AS quantity_sold
FROM best_selling_products
WHERE rn = 1            
ORDER BY quantity_sold DESC;


select count(*) from returns


-- Create orders_small
CREATE TABLE orders_small AS
SELECT * FROM orders LIMIT 10000;

-- Create order_items_small using only products that have categories
CREATE TABLE order_items_small AS
SELECT oi.*
FROM order_items oi
INNER JOIN product_categories pc ON pc.product_id = oi.product_id
LIMIT 50000;

