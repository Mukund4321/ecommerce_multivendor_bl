USE ecommerce;

-- Q1 — Products with seller name brand name and category

SELECT
    p.id                AS product_id,
    p.name              AS product_name,
    p.base_price,
    sp.business_name    AS seller_name,
    b.name              AS brand_name,
    c.name              AS category_name
FROM products p
INNER JOIN users             u   ON u.id  = p.seller_id
INNER JOIN seller_profiles   sp  ON sp.user_id = u.id
INNER JOIN brands            b   ON b.id  = p.brand_id
INNER JOIN product_categories pc ON pc.product_id = p.id
INNER JOIN categories        c   ON c.id  = pc.category_id
ORDER BY p.id;


-- Q2 — Customers who have never placed an order

SELECT
    u.id            AS customer_id,
    u.email,
    u.created_at
FROM users u
LEFT JOIN orders o ON o.customer_id = u.id
WHERE u.role = 'customer'
  AND o.id   IS NULL
ORDER BY u.id;


-- Q3 — All sellers with total products including zero product sellers

SELECT
    sp.business_name,
    u.email          AS seller_email,
    COUNT(p.id)      AS total_products
FROM users u
INNER JOIN seller_profiles sp ON sp.user_id = u.id
LEFT  JOIN products        p  ON p.seller_id = u.id
WHERE u.role = 'seller'
GROUP BY u.id, sp.business_name, u.email
ORDER BY total_products DESC;


-- Q4 — Each order with customer name seller name and total amount

SELECT
    o.id                AS order_id,
    u.email             AS customer_email,
    sp.business_name    AS seller_name,
    o.status,
    o.total_amount,
    o.created_at
FROM orders o
INNER JOIN users           u   ON u.id       = o.customer_id
INNER JOIN order_items     oi  ON oi.order_id = o.id
INNER JOIN users           su  ON su.id      = oi.seller_id
INNER JOIN seller_profiles sp  ON sp.user_id  = su.id
GROUP BY
    o.id, u.email, sp.business_name,
    o.status, o.total_amount, o.created_at
ORDER BY o.id
LIMIT 100;


-- Q5 — Products ordered at least once using EXISTS

SELECT
    p.id,
    p.name,
    p.base_price,
    p.status
FROM products p
WHERE EXISTS (
    SELECT 1
    FROM order_items oi
    WHERE oi.product_id = p.id
)
ORDER BY p.id;


-- Q6 — Products never ordered using NOT EXISTS

SELECT
    p.id,
    p.name,
    p.base_price,
    p.status
FROM products p
WHERE NOT EXISTS (
    SELECT 1
    FROM order_items oi
    WHERE oi.product_id = p.id
)
ORDER BY p.id;


-- Q7 — Products priced above their category average using correlated subquery

SELECT
    p.id,
    p.name,
    p.base_price,
    c.name  AS category_name,
    ROUND((
        SELECT AVG(p2.base_price)
        FROM products p2
        INNER JOIN product_categories pc2
            ON pc2.product_id = p2.id
        WHERE pc2.category_id = pc.category_id
    ), 2)   AS category_avg_price
FROM products p
INNER JOIN product_categories pc ON pc.product_id = p.id
INNER JOIN categories         c  ON c.id = pc.category_id
WHERE p.base_price > (
    SELECT AVG(p3.base_price)
    FROM products p3
    INNER JOIN product_categories pc3
        ON pc3.product_id = p3.id
    WHERE pc3.category_id = pc.category_id
)
ORDER BY category_name, p.base_price DESC;


-- Q8 — Top 3 most expensive products per seller

SELECT
    seller_name,
    product_name,
    base_price,
    price_rank
FROM (
    SELECT
        sp.business_name    AS seller_name,
        p.name              AS product_name,
        p.base_price,
        ROW_NUMBER() OVER (
            PARTITION BY p.seller_id
            ORDER BY p.base_price DESC
        )                   AS price_rank
    FROM products p
    INNER JOIN users           u  ON u.id      = p.seller_id
    INNER JOIN seller_profiles sp ON sp.user_id = u.id
) ranked
WHERE price_rank <= 3
ORDER BY seller_name, price_rank;


-- Q9 — Customers who ordered every month for the last 6 months

SELECT
    u.id            AS customer_id,
    u.email,
    COUNT(DISTINCT DATE_FORMAT(o.created_at, '%Y-%m')) AS months_active
FROM users u
INNER JOIN orders o ON o.customer_id = u.id
WHERE o.created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
  AND u.role = 'customer'
GROUP BY u.id, u.email
HAVING COUNT(DISTINCT DATE_FORMAT(o.created_at, '%Y-%m')) = 6
ORDER BY months_active DESC;


-- Q10 — Coupons never used by any customer

SELECT
    c.id,
    c.code,
    c.type,
    c.discount_value,
    c.max_uses,
    c.used_count,
    c.expires_at
FROM coupons c
LEFT JOIN coupon_usage cu ON cu.coupon_id = c.id
WHERE cu.id IS NULL
ORDER BY c.id;


-- Q11 — Each sellers best selling product by quantity sold

WITH seller_product_qty AS (
    SELECT
        oi.seller_id,
        oi.product_id,
        SUM(oi.quantity) AS total_qty_sold
    FROM order_items oi
    GROUP BY oi.seller_id, oi.product_id
),
ranked_products AS (
    SELECT
        seller_id,
        product_id,
        total_qty_sold,
        RANK() OVER (
            PARTITION BY seller_id
            ORDER BY total_qty_sold DESC
        ) AS rnk
    FROM seller_product_qty
)
SELECT
    sp.business_name        AS seller_name,
    p.name                  AS best_selling_product,
    rp.total_qty_sold
FROM ranked_products rp
INNER JOIN products        p  ON p.id      = rp.product_id
INNER JOIN users           u  ON u.id      = rp.seller_id
INNER JOIN seller_profiles sp ON sp.user_id = u.id
WHERE rp.rnk = 1
ORDER BY rp.total_qty_sold DESC;


-- Q12 — Orders where payment failed

SELECT
    o.id            AS order_id,
    u.email         AS customer_email,
    o.status        AS order_status,
    o.total_amount,
    pay.method      AS payment_method,
    pay.status      AS payment_status,
    pt.attempt_number,
    pt.response_code,
    pt.attempted_at
FROM orders o
INNER JOIN users                u   ON u.id         = o.customer_id
INNER JOIN payments             pay ON pay.order_id  = o.id
INNER JOIN payment_transactions pt  ON pt.payment_id = pay.id
WHERE pay.status = 'failed'
ORDER BY o.id
LIMIT 100;


-- Q13 — Products with average rating and total review count

SELECT
    p.id,
    p.name,
    p.base_price,
    COUNT(DISTINCT rv.id)    AS total_reviews,
    COUNT(DISTINCT rt.id)    AS total_ratings,
    ROUND(AVG(rt.stars), 2)  AS avg_rating
FROM products p
LEFT JOIN reviews rv ON rv.product_id = p.id
LEFT JOIN ratings rt ON rt.product_id = p.id
GROUP BY p.id, p.name, p.base_price
ORDER BY avg_rating DESC, total_reviews DESC;


-- Q14 — CTE sellers earning above overall average revenue

WITH seller_revenue AS (
    SELECT
        oi.seller_id,
        SUM(oi.unit_price * oi.quantity) AS total_revenue
    FROM order_items oi
    INNER JOIN orders o ON o.id = oi.order_id
    WHERE o.status = 'delivered'
    GROUP BY oi.seller_id
),
overall_avg AS (
    SELECT AVG(total_revenue) AS avg_revenue
    FROM seller_revenue
)
SELECT
    sp.business_name,
    ROUND(sr.total_revenue, 2) AS total_revenue,
    ROUND(oa.avg_revenue,   2) AS platform_avg
FROM seller_revenue  sr
CROSS JOIN overall_avg oa
INNER JOIN users           u  ON u.id      = sr.seller_id
INNER JOIN seller_profiles sp ON sp.user_id = u.id
WHERE sr.total_revenue > oa.avg_revenue
ORDER BY sr.total_revenue DESC;


-- Q15 — CTE repeat customers with more than 5 completed orders

WITH repeat_customers AS (
    SELECT
        customer_id,
        COUNT(*) AS completed_orders
    FROM orders
    WHERE status = 'delivered'
    GROUP BY customer_id
    HAVING COUNT(*) > 5
)
SELECT
    u.id            AS customer_id,
    u.email,
    rc.completed_orders
FROM repeat_customers rc
INNER JOIN users u ON u.id = rc.customer_id
ORDER BY rc.completed_orders DESC
LIMIT 50;


-- Q16 — Recursive CTE full category hierarchy path from root to leaf

WITH RECURSIVE category_tree AS (
    SELECT
        id,
        name,
        parent_id,
        CAST(name AS CHAR(500)) AS full_path,
        0                       AS depth
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    SELECT
        c.id,
        c.name,
        c.parent_id,
        CAST(CONCAT(ct.full_path, ' → ', c.name) AS CHAR(500)) AS full_path,
        ct.depth + 1 AS depth
    FROM categories c
    INNER JOIN category_tree ct ON ct.id = c.parent_id
)
SELECT
    id,
    name,
    depth,
    full_path
FROM category_tree
ORDER BY full_path;


-- Q17 — Returned orders with customer product return reason and refund amount

SELECT
    o.id                AS order_id,
    u.email             AS customer_email,
    p.name              AS product_name,
    rt.reason_code,
    rt.item_condition,
    ROUND(rf.amount, 2) AS refund_amount,
    rf.method           AS refund_method
FROM returns rt
INNER JOIN orders      o  ON o.id  = rt.order_id
INNER JOIN users       u  ON u.id  = rt.customer_id
INNER JOIN order_items oi ON oi.id = rt.order_item_id
INNER JOIN products    p  ON p.id  = oi.product_id
LEFT  JOIN refunds     rf ON rf.return_id = rt.id
ORDER BY o.id;


-- Q18 — Sellers who received at least one 1 star review

SELECT DISTINCT
    sp.business_name    AS seller_name,
    u.email             AS seller_email,
    p.name              AS product_with_1star,
    rt.stars
FROM ratings rt
INNER JOIN products        p  ON p.id      = rt.product_id
INNER JOIN users           u  ON u.id      = p.seller_id
INNER JOIN seller_profiles sp ON sp.user_id = u.id
WHERE rt.stars = 1
ORDER BY sp.business_name;


-- Q19 — CTE sellers ranked by unique customers served top 10

WITH seller_customer_count AS (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT o.customer_id) AS unique_customers
    FROM order_items oi
    INNER JOIN orders o ON o.id = oi.order_id
    GROUP BY oi.seller_id
),
ranked_sellers AS (
    SELECT
        seller_id,
        unique_customers,
        RANK() OVER (
            ORDER BY unique_customers DESC
        ) AS customer_rank
    FROM seller_customer_count
)
SELECT
    rs.customer_rank,
    sp.business_name,
    rs.unique_customers
FROM ranked_sellers    rs
INNER JOIN users           u  ON u.id      = rs.seller_id
INNER JOIN seller_profiles sp ON sp.user_id = u.id
WHERE rs.customer_rank <= 10
ORDER BY rs.customer_rank;


-- Q20 — Cart items never converted to an order with cart age in days

SELECT
    u.email                         AS customer_email,
    p.name                          AS product_name,
    ci.quantity,
    ci.added_at,
    DATEDIFF(NOW(), ci.added_at)    AS cart_age_days
FROM cart_items ci
INNER JOIN cart     ct ON ct.id = ci.cart_id
INNER JOIN users    u  ON u.id  = ct.user_id
INNER JOIN products p  ON p.id  = ci.product_id
WHERE NOT EXISTS (
    SELECT 1
    FROM   orders o
    WHERE  o.customer_id = ct.user_id
      AND  o.created_at  >= ci.added_at
)
ORDER BY cart_age_days DESC
LIMIT 100;