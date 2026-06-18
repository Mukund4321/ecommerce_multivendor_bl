USE ecommerce;



-- W1 — Rank products by total revenue within each category

SELECT category_name, product_name, total_revenue, revenue_rank
FROM (
    SELECT
        c.name                                          AS category_name,
        p.name                                          AS product_name,
        ROUND(SUM(oi.unit_price * oi.quantity), 2)      AS total_revenue,
        RANK() OVER (
            PARTITION BY c.id
            ORDER BY SUM(oi.unit_price * oi.quantity) DESC
        )                                               AS revenue_rank
    FROM order_items_small oi
    INNER JOIN products           p  ON p.id          = oi.product_id
    INNER JOIN product_categories pc ON pc.product_id = p.id
    INNER JOIN categories         c  ON c.id          = pc.category_id
    GROUP BY c.id, c.name, p.id, p.name
) ranked
ORDER BY category_name, revenue_rank;


-- W2 — Top 5 best selling products per category

SELECT category_name, product_name, total_revenue, revenue_rank
FROM (
    SELECT
        c.name                                          AS category_name,
        p.name                                          AS product_name,
        ROUND(SUM(oi.unit_price * oi.quantity), 2)      AS total_revenue,
        RANK() OVER (
            PARTITION BY c.id
            ORDER BY SUM(oi.unit_price * oi.quantity) DESC
        )                                               AS revenue_rank
    FROM order_items_small oi
    INNER JOIN products           p  ON p.id          = oi.product_id
    INNER JOIN product_categories pc ON pc.product_id = p.id
    INNER JOIN categories         c  ON c.id          = pc.category_id
    GROUP BY c.id, c.name, p.id, p.name
) ranked
WHERE revenue_rank <= 5
ORDER BY category_name, revenue_rank;


-- W3 — ROW NUMBER on each customers orders to identify first and latest purchase

SELECT
    u.email,
    o.id            AS order_id,
    o.total_amount,
    o.created_at,
    ROW_NUMBER() OVER (
        PARTITION BY o.customer_id
        ORDER BY o.created_at ASC
    )               AS order_sequence,
    CASE
        WHEN ROW_NUMBER() OVER (
            PARTITION BY o.customer_id ORDER BY o.created_at ASC
        ) = 1 THEN 'First Order'
        ELSE 'Subsequent Order'
    END             AS order_label
FROM orders_small o
INNER JOIN users u ON u.id = o.customer_id
ORDER BY u.email, order_sequence
LIMIT 100;


-- W4 — Running total of revenue per seller ordered by month

SELECT
    sp.business_name,
    order_month,
    ROUND(monthly_revenue, 2)   AS monthly_revenue,
    ROUND(SUM(monthly_revenue) OVER (
        PARTITION BY seller_id
        ORDER BY order_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2)                       AS running_total
FROM (
    SELECT
        oi.seller_id,
        DATE_FORMAT(o.created_at, '%Y-%m')  AS order_month,
        SUM(oi.unit_price * oi.quantity)    AS monthly_revenue
    FROM order_items_small oi
    INNER JOIN orders_small o ON o.id = oi.order_id
    GROUP BY oi.seller_id, DATE_FORMAT(o.created_at, '%Y-%m')
) monthly
INNER JOIN users           u  ON u.id       = monthly.seller_id
INNER JOIN seller_profiles sp ON sp.user_id = u.id
ORDER BY sp.business_name, order_month;


-- W5 — Month over month revenue change per seller using LAG

SELECT
    sp.business_name,
    order_month,
    ROUND(monthly_revenue, 2)   AS monthly_revenue,
    ROUND(LAG(monthly_revenue) OVER (
        PARTITION BY seller_id ORDER BY order_month
    ), 2)                       AS prev_month_revenue,
    ROUND(monthly_revenue - LAG(monthly_revenue) OVER (
        PARTITION BY seller_id ORDER BY order_month
    ), 2)                       AS revenue_change
FROM (
    SELECT
        oi.seller_id,
        DATE_FORMAT(o.created_at, '%Y-%m')  AS order_month,
        SUM(oi.unit_price * oi.quantity)    AS monthly_revenue
    FROM order_items_small oi
    INNER JOIN orders_small o ON o.id = oi.order_id
    GROUP BY oi.seller_id, DATE_FORMAT(o.created_at, '%Y-%m')
) monthly
INNER JOIN users           u  ON u.id       = monthly.seller_id
INNER JOIN seller_profiles sp ON sp.user_id = u.id
ORDER BY sp.business_name, order_month;


-- W6 — Month over month revenue growth percentage

SELECT
    sp.business_name,
    order_month,
    ROUND(monthly_revenue, 2) AS monthly_revenue,
    ROUND(
        (monthly_revenue - LAG(monthly_revenue) OVER (
            PARTITION BY seller_id ORDER BY order_month
        ))
        / NULLIF(LAG(monthly_revenue) OVER (
            PARTITION BY seller_id ORDER BY order_month
        ), 0) * 100
    , 2)                      AS growth_percentage
FROM (
    SELECT
        oi.seller_id,
        DATE_FORMAT(o.created_at, '%Y-%m')  AS order_month,
        SUM(oi.unit_price * oi.quantity)    AS monthly_revenue
    FROM order_items_small oi
    INNER JOIN orders_small o ON o.id = oi.order_id
    GROUP BY oi.seller_id, DATE_FORMAT(o.created_at, '%Y-%m')
) monthly
INNER JOIN users           u  ON u.id       = monthly.seller_id
INNER JOIN seller_profiles sp ON sp.user_id = u.id
ORDER BY sp.business_name, order_month;


-- W7 — Sellers whose revenue dropped compared to previous month

WITH monthly_revenue AS (
    SELECT
        oi.seller_id,
        DATE_FORMAT(o.created_at, '%Y-%m')  AS order_month,
        SUM(oi.unit_price * oi.quantity)    AS monthly_revenue
    FROM order_items_small oi
    INNER JOIN orders_small o ON o.id = oi.order_id
    GROUP BY oi.seller_id, DATE_FORMAT(o.created_at, '%Y-%m')
),
with_lag AS (
    SELECT
        seller_id, order_month, monthly_revenue,
        LAG(monthly_revenue) OVER (
            PARTITION BY seller_id ORDER BY order_month
        ) AS prev_revenue
    FROM monthly_revenue
)
SELECT
    sp.business_name,
    wl.order_month,
    ROUND(wl.monthly_revenue, 2)                    AS this_month,
    ROUND(wl.prev_revenue,    2)                    AS last_month,
    ROUND(wl.monthly_revenue - wl.prev_revenue, 2)  AS change
FROM with_lag wl
INNER JOIN users           u  ON u.id       = wl.seller_id
INNER JOIN seller_profiles sp ON sp.user_id = u.id
WHERE wl.monthly_revenue < wl.prev_revenue
  AND wl.prev_revenue    IS NOT NULL
ORDER BY change ASC;


-- W8 — 7 day rolling average order value

SELECT
    order_date,
    ROUND(daily_revenue, 2) AS daily_revenue,
    ROUND(AVG(daily_revenue) OVER (
        ORDER BY order_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2)                   AS rolling_7day_avg
FROM (
    SELECT DATE(created_at) AS order_date, SUM(total_amount) AS daily_revenue
    FROM orders_small
    GROUP BY DATE(created_at)
) daily
ORDER BY order_date;


-- W9 — Rank customers by total lifetime spend using DENSE RANK

SELECT
    u.email,
    ROUND(total_spend, 2) AS lifetime_spend,
    DENSE_RANK() OVER (ORDER BY total_spend DESC) AS spend_rank
FROM (
    SELECT customer_id, SUM(total_amount) AS total_spend
    FROM orders_small
    WHERE status = 'delivered'
    GROUP BY customer_id
) spend
INNER JOIN users u ON u.id = spend.customer_id
ORDER BY spend_rank
LIMIT 50;


-- W10 — NTILE 4 to split all products into four revenue quartiles

SELECT
    p.name,
    ROUND(total_revenue, 2)     AS total_revenue,
    NTILE(4) OVER (ORDER BY total_revenue DESC) AS revenue_quartile,
    CASE NTILE(4) OVER (ORDER BY total_revenue DESC)
        WHEN 1 THEN 'Top 25 percent'
        WHEN 2 THEN 'Upper Mid 25 percent'
        WHEN 3 THEN 'Lower Mid 25 percent'
        WHEN 4 THEN 'Bottom 25 percent'
    END                         AS quartile_label
FROM (
    SELECT product_id, SUM(unit_price * quantity) AS total_revenue
    FROM order_items_small
    GROUP BY product_id
) rev
INNER JOIN products p ON p.id = rev.product_id
ORDER BY revenue_quartile, total_revenue DESC;


-- W11 — First and most recent order date per customer

SELECT
    u.email,
    MIN(o.created_at) OVER (PARTITION BY o.customer_id) AS first_order_date,
    MAX(o.created_at) OVER (PARTITION BY o.customer_id) AS latest_order_date,
    COUNT(o.id)       OVER (PARTITION BY o.customer_id) AS total_orders
FROM orders_small o
INNER JOIN users u ON u.id = o.customer_id
GROUP BY o.customer_id, u.email, o.created_at, o.id
ORDER BY u.email
LIMIT 50;


-- W12 — Each order item as percentage of the order total

SELECT
    oi.order_id,
    p.name                                          AS product_name,
    oi.quantity,
    ROUND(oi.unit_price * oi.quantity, 2)           AS line_total,
    ROUND(SUM(oi.unit_price * oi.quantity) OVER (
        PARTITION BY oi.order_id
    ), 2)                                           AS order_total,
    ROUND(
        oi.unit_price * oi.quantity
        / SUM(oi.unit_price * oi.quantity) OVER (PARTITION BY oi.order_id)
        * 100
    , 2)                                            AS pct_of_order
FROM order_items_small oi
INNER JOIN products p ON p.id = oi.product_id
ORDER BY oi.order_id, pct_of_order DESC
LIMIT 100;


-- W13 — LEAD to find next order date and days between orders

SELECT
    u.email,
    o.id            AS order_id,
    o.created_at    AS this_order_date,
    LEAD(o.created_at) OVER (
        PARTITION BY o.customer_id ORDER BY o.created_at
    )               AS next_order_date,
    DATEDIFF(
        LEAD(o.created_at) OVER (
            PARTITION BY o.customer_id ORDER BY o.created_at
        ),
        o.created_at
    )               AS days_until_next_order
FROM orders_small o
INNER JOIN users u ON u.id = o.customer_id
ORDER BY u.email, o.created_at
LIMIT 100;


-- W14 — Best selling month per seller

SELECT business_name, order_month, ROUND(monthly_revenue, 2) AS monthly_revenue, month_rank
FROM (
    SELECT
        sp.business_name,
        DATE_FORMAT(o.created_at, '%Y-%m')  AS order_month,
        SUM(oi.unit_price * oi.quantity)    AS monthly_revenue,
        RANK() OVER (
            PARTITION BY oi.seller_id
            ORDER BY SUM(oi.unit_price * oi.quantity) DESC
        )                                   AS month_rank
    FROM order_items_small oi
    INNER JOIN orders_small    o  ON o.id       = oi.order_id
    INNER JOIN users           u  ON u.id       = oi.seller_id
    INNER JOIN seller_profiles sp ON sp.user_id = u.id
    GROUP BY oi.seller_id, sp.business_name, DATE_FORMAT(o.created_at, '%Y-%m')
) ranked
WHERE month_rank = 1
ORDER BY monthly_revenue DESC;


-- W15 — Products whose sales rank improved from last month to this month

WITH monthly_product_sales AS (
    SELECT
        oi.product_id,
        DATE_FORMAT(o.created_at, '%Y-%m')  AS order_month,
        SUM(oi.quantity)                    AS total_qty
    FROM order_items_small oi
    INNER JOIN orders_small o ON o.id = oi.order_id
    WHERE o.created_at >= DATE_SUB(NOW(), INTERVAL 2 MONTH)
    GROUP BY oi.product_id, DATE_FORMAT(o.created_at, '%Y-%m')
),
ranked AS (
    SELECT
        product_id, order_month, total_qty,
        RANK() OVER (PARTITION BY order_month ORDER BY total_qty DESC) AS sales_rank
    FROM monthly_product_sales
)
SELECT
    p.name,
    this_month.order_month                              AS current_month,
    this_month.sales_rank                               AS current_rank,
    last_month.sales_rank                               AS previous_rank,
    last_month.sales_rank - this_month.sales_rank       AS rank_improvement
FROM ranked this_month
INNER JOIN ranked last_month
    ON  last_month.product_id  = this_month.product_id
    AND last_month.order_month < this_month.order_month
INNER JOIN products p ON p.id = this_month.product_id
WHERE this_month.sales_rank < last_month.sales_rank
ORDER BY rank_improvement DESC;


-- W16 — Cumulative number of orders placed per day

SELECT
    order_date,
    daily_orders,
    SUM(daily_orders) OVER (
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_orders
FROM (
    SELECT DATE(created_at) AS order_date, COUNT(*) AS daily_orders
    FROM orders_small
    GROUP BY DATE(created_at)
) daily
ORDER BY order_date;


-- W17 — PERCENT RANK to show where each seller stands by revenue

SELECT
    sp.business_name,
    ROUND(total_revenue, 2)     AS total_revenue,
    ROUND(PERCENT_RANK() OVER (ORDER BY total_revenue) * 100, 2) AS percentile_rank
FROM (
    SELECT seller_id, SUM(unit_price * quantity) AS total_revenue
    FROM order_items_small
    GROUP BY seller_id
) rev
INNER JOIN users           u  ON u.id       = rev.seller_id
INNER JOIN seller_profiles sp ON sp.user_id = u.id
ORDER BY percentile_rank DESC;


-- W18 — Top 3 sellers by revenue within each product category

SELECT category_name, business_name, ROUND(category_revenue, 2) AS category_revenue, seller_rank
FROM (
    SELECT
        c.name                                  AS category_name,
        sp.business_name,
        SUM(oi.unit_price * oi.quantity)        AS category_revenue,
        DENSE_RANK() OVER (
            PARTITION BY c.id
            ORDER BY SUM(oi.unit_price * oi.quantity) DESC
        )                                       AS seller_rank
    FROM order_items_small oi
    INNER JOIN products           p  ON p.id          = oi.product_id
    INNER JOIN product_categories pc ON pc.product_id = p.id
    INNER JOIN categories         c  ON c.id          = pc.category_id
    INNER JOIN users              u  ON u.id           = oi.seller_id
    INNER JOIN seller_profiles    sp ON sp.user_id     = u.id
    GROUP BY c.id, c.name, oi.seller_id, sp.business_name
) ranked
WHERE seller_rank <= 3
ORDER BY category_name, seller_rank;


-- W19 — Each customers average order value compared to platform average

SELECT
    u.email,
    ROUND(customer_avg, 2)                              AS customer_avg_order_value,
    ROUND(AVG(customer_avg) OVER (), 2)                 AS platform_avg_order_value,
    ROUND(customer_avg - AVG(customer_avg) OVER (), 2)  AS difference
FROM (
    SELECT customer_id, AVG(total_amount) AS customer_avg
    FROM orders_small
    WHERE status = 'delivered'
    GROUP BY customer_id
) cust_avg
INNER JOIN users u ON u.id = cust_avg.customer_id
ORDER BY customer_avg DESC
LIMIT 50;


-- W20 — ROW NUMBER to deduplicate cart items keeping only latest per product

SELECT cart_id, product_id, quantity, added_at
FROM (
    SELECT
        cart_id, product_id, quantity, added_at,
        ROW_NUMBER() OVER (
            PARTITION BY cart_id, product_id
            ORDER BY added_at DESC
        ) AS rn
    FROM cart_items
) deduped
WHERE rn = 1
ORDER BY cart_id, product_id
LIMIT 100;
