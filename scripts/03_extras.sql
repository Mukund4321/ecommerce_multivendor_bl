USE ecommerce;

-- DCL — Create user and grant permissions

CREATE USER 'analyst'@'localhost' IDENTIFIED BY 'analyst123';
GRANT SELECT ON ecommerce.* TO 'analyst'@'localhost';
REVOKE SELECT ON ecommerce.* FROM 'analyst'@'localhost';


-- CAST examples

SELECT
    id,
    CAST(total_amount AS UNSIGNED)  AS amount_integer,
    CAST(created_at   AS DATE)      AS order_date,
    CAST(total_amount AS CHAR)      AS amount_text
FROM orders LIMIT 10;


-- Copy command — INSERT INTO SELECT

CREATE TABLE IF NOT EXISTS orders_archive LIKE orders;

INSERT INTO orders_archive
SELECT * FROM orders WHERE status = 'delivered';

SELECT COUNT(*) AS archived_orders FROM orders_archive;


-- Custom function — calculate tax amount

DELIMITER $$

CREATE FUNCTION calculate_tax(amount DECIMAL(10,2))
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    RETURN ROUND(amount * 0.18, 2);
END$$

DELIMITER ;

SELECT id, total_amount, calculate_tax(total_amount) AS tax_amount
FROM orders LIMIT 10;


-- Custom function — get discount amount

DELIMITER $$

CREATE FUNCTION get_discount(amount DECIMAL(10,2), pct DECIMAL(5,2))
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    RETURN ROUND(amount * pct / 100, 2);
END$$

DELIMITER ;

SELECT id, total_amount, get_discount(total_amount, 10) AS ten_pct_discount
FROM orders LIMIT 10;
