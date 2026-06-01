USE ecommerce;

-- ═══════════════════════════════════════════════════════
-- IMPORTANT — RUN THIS BEFORE ANYTHING ELSE
-- Changes the statement terminator so MySQL does not
-- confuse semicolons inside procedures with end of query
-- ═══════════════════════════════════════════════════════


-- P1 and P2 — place_order procedure with FOR UPDATE to prevent race conditions and full ROLLBACK on failure

DELIMITER $$


CREATE PROCEDURE place_order(
    IN  p_customer_id    INT,
    IN  p_address_id     INT,
    IN  p_product_id     INT,
    IN  p_warehouse_id   INT,
    IN  p_quantity       INT,
    IN  p_coupon_code    VARCHAR(50),
    IN  p_payment_method VARCHAR(50),
    OUT p_order_id       INT,
    OUT p_message        VARCHAR(255)
)
BEGIN
    DECLARE v_price       DECIMAL(10,2);
    DECLARE v_stock       INT;
    DECLARE v_total       DECIMAL(10,2);
    DECLARE v_coupon_id   INT DEFAULT NULL;
    DECLARE v_discount    DECIMAL(10,2) DEFAULT 0;
    DECLARE v_coupon_type VARCHAR(20);
    DECLARE v_coupon_val  DECIMAL(10,2);
    DECLARE v_min_order   DECIMAL(10,2);
    DECLARE v_seller_id   INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_order_id = NULL;
        SET p_message  = 'Order failed — everything rolled back';
    END;

    START TRANSACTION;

    -- Lock the inventory row so no other transaction can touch it
    SELECT quantity_available
    INTO   v_stock
    FROM   inventory
    WHERE  product_id   = p_product_id
      AND  warehouse_id = p_warehouse_id
    FOR UPDATE;

    -- Check if enough stock exists
    IF v_stock < p_quantity THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Not enough stock available';
    END IF;

    -- Get product price and seller
    SELECT base_price, seller_id
    INTO   v_price, v_seller_id
    FROM   products
    WHERE  id = p_product_id;

    SET v_total = v_price * p_quantity;

    -- Apply coupon if one was provided
    IF p_coupon_code IS NOT NULL THEN
        SELECT id, type, discount_value, min_order_value
        INTO   v_coupon_id, v_coupon_type, v_coupon_val, v_min_order
        FROM   coupons
        WHERE  code       = p_coupon_code
          AND  expires_at > NOW()
          AND  used_count < max_uses;

        IF v_coupon_id IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Coupon is invalid or expired';
        END IF;

        IF v_total < v_min_order THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Order total is below coupon minimum value';
        END IF;

        IF v_coupon_type = 'flat' THEN
            SET v_discount = v_coupon_val;
        ELSE
            SET v_discount = v_total * v_coupon_val / 100;
        END IF;

        SET v_total = v_total - v_discount;

        UPDATE coupons
        SET    used_count = used_count + 1
        WHERE  id = v_coupon_id;
    END IF;

    -- Insert the order
    INSERT INTO orders
        (customer_id, shipping_address_id, status, total_amount)
    VALUES
        (p_customer_id, p_address_id, 'confirmed', v_total);

    SET p_order_id = LAST_INSERT_ID();

    -- Insert order item
    INSERT INTO order_items
        (order_id, product_id, seller_id, quantity, unit_price)
    VALUES
        (p_order_id, p_product_id, v_seller_id, p_quantity, v_price);

    -- Deduct inventory
    UPDATE inventory
    SET    quantity_available = quantity_available - p_quantity
    WHERE  product_id   = p_product_id
      AND  warehouse_id = p_warehouse_id;

    -- Log stock movement
    INSERT INTO stock_movements
        (product_id, warehouse_id, movement_type, quantity, note)
    VALUES
        (p_product_id, p_warehouse_id, 'stock_out', p_quantity,
         CONCAT('Order placed — order id ', p_order_id));

    -- Record payment
    INSERT INTO payments
        (order_id, method, status, gateway_reference)
    VALUES
        (p_order_id, p_payment_method, 'success',
         CONCAT('TXN', FLOOR(RAND() * 1000000000)));

    -- Log coupon usage if a coupon was used
    IF v_coupon_id IS NOT NULL THEN
        INSERT INTO coupon_usage (coupon_id, customer_id, order_id)
        VALUES (v_coupon_id, p_customer_id, p_order_id);
    END IF;

    COMMIT;
    SET p_message = CONCAT('Order placed successfully — order id ', p_order_id);
END$$

DELIMITER ;


-- Test place_order — run this to verify it works

CALL place_order(1, 1, 1, 1, 2, NULL, 'upi', @order_id, @msg);
SELECT @order_id AS new_order_id, @msg AS message;


-- P3 — cancel_order procedure with 24 hour window check

DELIMITER $$

CREATE PROCEDURE cancel_order(
    IN  p_order_id INT,
    OUT p_message  VARCHAR(255)
)
BEGIN
    DECLARE v_status     VARCHAR(50);
    DECLARE v_created_at TIMESTAMP;
    DECLARE v_hours_diff INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'Cancellation failed — rolled back';
    END;

    START TRANSACTION;

    SELECT status, created_at
    INTO   v_status, v_created_at
    FROM   orders
    WHERE  id = p_order_id
    FOR UPDATE;

    SET v_hours_diff = TIMESTAMPDIFF(HOUR, v_created_at, NOW());

    IF v_hours_diff > 24 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot cancel — 24 hour window has passed';
    END IF;

    IF v_status = 'cancelled' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Order is already cancelled';
    END IF;

    IF v_status = 'delivered' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot cancel a delivered order';
    END IF;

    -- Restore inventory for all items in this order
    UPDATE inventory inv
    INNER JOIN order_items oi ON oi.product_id = inv.product_id
    SET inv.quantity_available = inv.quantity_available + oi.quantity
    WHERE oi.order_id = p_order_id;

    -- Log the stock restoration
    INSERT INTO stock_movements
        (product_id, warehouse_id, movement_type, quantity, note)
    SELECT
        oi.product_id,
        (SELECT warehouse_id FROM inventory
         WHERE product_id = oi.product_id LIMIT 1),
        'stock_in',
        oi.quantity,
        CONCAT('Order cancelled — order id ', p_order_id)
    FROM order_items oi
    WHERE oi.order_id = p_order_id;

    -- Update order status to cancelled
    UPDATE orders
    SET    status = 'cancelled'
    WHERE  id = p_order_id;

    -- Mark payment as refunded
    UPDATE payments
    SET    status = 'refunded'
    WHERE  order_id = p_order_id;

    COMMIT;
    SET p_message = CONCAT('Order ', p_order_id, ' cancelled successfully');
END$$

DELIMITER ;


-- Test cancel_order

CALL cancel_order(@order_id, @msg);
SELECT @msg AS message;


-- P4 — refund_payment procedure with amount validation

DELIMITER $$

CREATE PROCEDURE refund_payment(
    IN  p_payment_id    INT,
    IN  p_refund_amount DECIMAL(10,2),
    IN  p_return_id     INT,
    IN  p_method        VARCHAR(20),
    OUT p_message       VARCHAR(255)
)
BEGIN
    DECLARE v_original_amount DECIMAL(10,2);
    DECLARE v_pay_status      VARCHAR(50);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'Refund failed — rolled back';
    END;

    START TRANSACTION;

    SELECT o.total_amount, p.status
    INTO   v_original_amount, v_pay_status
    FROM   payments p
    INNER JOIN orders o ON o.id = p.order_id
    WHERE  p.id = p_payment_id
    FOR UPDATE;

    IF v_pay_status != 'success' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Payment must be in success status to refund';
    END IF;

    IF p_refund_amount > v_original_amount THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Refund amount cannot exceed original payment amount';
    END IF;

    INSERT INTO refunds
        (return_id, payment_id, amount, method)
    VALUES
        (p_return_id, p_payment_id, p_refund_amount, p_method);

    UPDATE payments
    SET    status = 'refunded'
    WHERE  id = p_payment_id;

    COMMIT;
    SET p_message = CONCAT('Refund of Rs ', p_refund_amount, ' processed successfully');
END$$

DELIMITER ;


-- P5 — update_inventory procedure with negative stock validation

DELIMITER $$

CREATE PROCEDURE update_inventory(
    IN  p_product_id   INT,
    IN  p_warehouse_id INT,
    IN  p_quantity     INT,
    IN  p_movement     VARCHAR(20),
    IN  p_note         VARCHAR(255),
    OUT p_message      VARCHAR(255)
)
BEGIN
    DECLARE v_current_qty INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'Inventory update failed — rolled back';
    END;

    START TRANSACTION;

    SELECT quantity_available
    INTO   v_current_qty
    FROM   inventory
    WHERE  product_id   = p_product_id
      AND  warehouse_id = p_warehouse_id
    FOR UPDATE;

    IF p_movement IN ('stock_out', 'damaged') THEN
        IF v_current_qty < p_quantity THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Cannot reduce stock below zero';
        END IF;
        UPDATE inventory
        SET    quantity_available = quantity_available - p_quantity
        WHERE  product_id   = p_product_id
          AND  warehouse_id = p_warehouse_id;
    ELSE
        UPDATE inventory
        SET    quantity_available = quantity_available + p_quantity
        WHERE  product_id   = p_product_id
          AND  warehouse_id = p_warehouse_id;
    END IF;

    INSERT INTO stock_movements
        (product_id, warehouse_id, movement_type, quantity, note)
    VALUES
        (p_product_id, p_warehouse_id, p_movement, p_quantity, p_note);

    COMMIT;
    SET p_message = 'Inventory updated successfully';
END$$

DELIMITER ;


-- Test update_inventory

CALL update_inventory(1, 1, 10, 'stock_in', 'Manual restock test', @msg);
SELECT @msg AS message;


-- P6 — apply_coupon procedure with all validations

DELIMITER $$

CREATE PROCEDURE apply_coupon(
    IN  p_coupon_code VARCHAR(50),
    IN  p_order_total DECIMAL(10,2),
    OUT p_discount    DECIMAL(10,2),
    OUT p_message     VARCHAR(255)
)
BEGIN
    DECLARE v_coupon_id  INT;
    DECLARE v_type       VARCHAR(20);
    DECLARE v_value      DECIMAL(10,2);
    DECLARE v_min_order  DECIMAL(10,2);
    DECLARE v_max_uses   INT;
    DECLARE v_used_count INT;
    DECLARE v_expires_at TIMESTAMP;

    SET p_discount = 0;

    SELECT id, type, discount_value, min_order_value,
           max_uses, used_count, expires_at
    INTO   v_coupon_id, v_type, v_value, v_min_order,
           v_max_uses, v_used_count, v_expires_at
    FROM   coupons
    WHERE  code = p_coupon_code;

    IF v_coupon_id IS NULL THEN
        SET p_message = 'Coupon does not exist';
    ELSEIF v_expires_at < NOW() THEN
        SET p_message = 'Coupon has expired';
    ELSEIF v_used_count >= v_max_uses THEN
        SET p_message = 'Coupon maximum uses reached';
    ELSEIF p_order_total < v_min_order THEN
        SET p_message = CONCAT('Minimum order value is Rs ', v_min_order);
    ELSE
        IF v_type = 'flat' THEN
            SET p_discount = v_value;
        ELSE
            SET p_discount = ROUND(p_order_total * v_value / 100, 2);
        END IF;
        SET p_message = CONCAT('Coupon applied successfully — discount Rs ', p_discount);
    END IF;
END$$

DELIMITER ;


-- Test apply_coupon

CALL apply_coupon('SAVE10', 1000.00, @discount, @msg);
SELECT @discount AS discount_amount, @msg AS message;


-- P7 — mark_order_delivered procedure with invoice generation

DELIMITER $$

CREATE PROCEDURE mark_order_delivered(
    IN  p_order_id INT,
    OUT p_message  VARCHAR(255)
)
BEGIN
    DECLARE v_status     VARCHAR(50);
    DECLARE v_payment_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'Failed to mark order as delivered';
    END;

    START TRANSACTION;

    SELECT status
    INTO   v_status
    FROM   orders
    WHERE  id = p_order_id
    FOR UPDATE;

    IF v_status != 'shipped' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Order must be in shipped status to mark as delivered';
    END IF;

    UPDATE orders
    SET    status       = 'delivered',
           delivered_at = NOW()
    WHERE  id = p_order_id;

    SELECT id
    INTO   v_payment_id
    FROM   payments
    WHERE  order_id = p_order_id
      AND  status   = 'success'
    LIMIT 1;

    IF v_payment_id IS NOT NULL THEN
        INSERT INTO invoices
            (order_id, payment_id, invoice_number, tax_amount, total_amount)
        SELECT
            p_order_id,
            v_payment_id,
            CONCAT('INV-', p_order_id, '-', UNIX_TIMESTAMP()),
            ROUND(total_amount * 0.18, 2),
            total_amount
        FROM orders
        WHERE id = p_order_id;
    END IF;

    COMMIT;
    SET p_message = CONCAT('Order ', p_order_id, ' marked as delivered and invoice generated');
END$$

DELIMITER ;


-- P8 — process_return procedure handling the full return flow in one transaction

DELIMITER $$

CREATE PROCEDURE process_return(
    IN  p_order_id      INT,
    IN  p_order_item_id INT,
    IN  p_customer_id   INT,
    IN  p_reason_code   VARCHAR(100),
    IN  p_condition     VARCHAR(20),
    IN  p_refund_method VARCHAR(20),
    OUT p_message       VARCHAR(255)
)
BEGIN
    DECLARE v_return_id   INT;
    DECLARE v_payment_id  INT;
    DECLARE v_order_total DECIMAL(10,2);
    DECLARE v_delivered_at TIMESTAMP;
    DECLARE v_days_diff   INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'Return process failed — everything rolled back';
    END;

    START TRANSACTION;

    SELECT delivered_at, total_amount
    INTO   v_delivered_at, v_order_total
    FROM   orders
    WHERE  id = p_order_id
    FOR UPDATE;

    SET v_days_diff = DATEDIFF(NOW(), v_delivered_at);

    IF v_days_diff > 7 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Return window has expired — must be within 7 days of delivery';
    END IF;

    INSERT INTO returns
        (order_id, order_item_id, customer_id,
         reason_code, item_condition, return_window_valid)
    VALUES
        (p_order_id, p_order_item_id, p_customer_id,
         p_reason_code, p_condition, TRUE);

    SET v_return_id = LAST_INSERT_ID();

    -- Restore inventory
    UPDATE inventory inv
    INNER JOIN order_items oi ON oi.product_id = inv.product_id
    SET inv.quantity_available = inv.quantity_available + oi.quantity
    WHERE oi.id = p_order_item_id;

    -- Log stock movement
    INSERT INTO stock_movements
        (product_id, warehouse_id, movement_type, quantity, note)
    SELECT
        oi.product_id,
        (SELECT warehouse_id FROM inventory
         WHERE product_id = oi.product_id LIMIT 1),
        'returned',
        oi.quantity,
        CONCAT('Return id ', v_return_id)
    FROM order_items oi
    WHERE oi.id = p_order_item_id;

    -- Get the payment id for this order
    SELECT id
    INTO   v_payment_id
    FROM   payments
    WHERE  order_id = p_order_id
      AND  status   = 'success'
    LIMIT 1;

    -- Process the refund
    INSERT INTO refunds
        (return_id, payment_id, amount, method)
    VALUES
        (v_return_id, v_payment_id, v_order_total, p_refund_method);

    UPDATE payments
    SET    status = 'refunded'
    WHERE  id = v_payment_id;

    COMMIT;
    SET p_message = CONCAT('Return ', v_return_id, ' processed and refund issued successfully');
END$$

DELIMITER ;


-- T1 — AFTER INSERT trigger on order_items to auto deduct inventory

DELIMITER $$

CREATE TRIGGER trg_deduct_inventory_on_order
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    UPDATE inventory
    SET    quantity_available = quantity_available - NEW.quantity
    WHERE  product_id = NEW.product_id
    LIMIT 1;

    INSERT INTO stock_movements
        (product_id, warehouse_id, movement_type, quantity, note)
    SELECT
        NEW.product_id,
        warehouse_id,
        'stock_out',
        NEW.quantity,
        CONCAT('Auto deducted for order item id ', NEW.id)
    FROM inventory
    WHERE product_id = NEW.product_id
    LIMIT 1;
END$$

DELIMITER ;


-- T2 — AFTER INSERT trigger on returns to auto restore inventory

DELIMITER $$

CREATE TRIGGER trg_restore_inventory_on_return
AFTER INSERT ON returns
FOR EACH ROW
BEGIN
    UPDATE inventory inv
    INNER JOIN order_items oi ON oi.product_id = inv.product_id
    SET inv.quantity_available = inv.quantity_available + oi.quantity
    WHERE oi.id = NEW.order_item_id;

    INSERT INTO stock_movements
        (product_id, warehouse_id, movement_type, quantity, note)
    SELECT
        oi.product_id,
        inv.warehouse_id,
        'returned',
        oi.quantity,
        CONCAT('Auto restored for return id ', NEW.id)
    FROM order_items oi
    INNER JOIN inventory inv ON inv.product_id = oi.product_id
    WHERE oi.id = NEW.order_item_id
    LIMIT 1;
END$$

DELIMITER ;


-- T3 — AFTER UPDATE trigger on orders when cancelled to restore inventory

DELIMITER $$

CREATE TRIGGER trg_restore_inventory_on_cancel
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN

        UPDATE inventory inv
        INNER JOIN order_items oi ON oi.product_id = inv.product_id
        SET inv.quantity_available = inv.quantity_available + oi.quantity
        WHERE oi.order_id = NEW.id;

        INSERT INTO stock_movements
            (product_id, warehouse_id, movement_type, quantity, note)
        SELECT
            oi.product_id,
            inv.warehouse_id,
            'stock_in',
            oi.quantity,
            CONCAT('Restored due to cancelled order id ', NEW.id)
        FROM order_items oi
        INNER JOIN inventory inv ON inv.product_id = oi.product_id
        WHERE oi.order_id = NEW.id;

    END IF;
END$$

DELIMITER ;


-- Add avg_rating column to products table before creating trigger T4

ALTER TABLE products
    ADD COLUMN avg_rating DECIMAL(3,2) DEFAULT 0.00;


-- T4 — AFTER INSERT trigger on ratings to recalculate product average rating

DELIMITER $$

CREATE TRIGGER trg_update_avg_rating
AFTER INSERT ON ratings
FOR EACH ROW
BEGIN
    UPDATE products
    SET    avg_rating = (
        SELECT ROUND(AVG(stars), 2)
        FROM   ratings
        WHERE  product_id = NEW.product_id
    )
    WHERE id = NEW.product_id;
END$$

DELIMITER ;


-- T5 — AFTER INSERT trigger on payments when success to auto create invoice

DELIMITER $$

CREATE TRIGGER trg_create_invoice_on_payment
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
    IF NEW.status = 'success' THEN
        INSERT INTO invoices
            (order_id, payment_id, invoice_number,
             tax_amount, total_amount)
        SELECT
            NEW.order_id,
            NEW.id,
            CONCAT('INV-', NEW.order_id, '-', NEW.id),
            ROUND(o.total_amount * 0.18, 2),
            o.total_amount
        FROM orders o
        WHERE o.id = NEW.order_id;
    END IF;
END$$

DELIMITER ;


-- Create inventory alerts table before trigger T6

CREATE TABLE IF NOT EXISTS inventory_alerts (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    product_id   INT NOT NULL,
    warehouse_id INT NOT NULL,
    current_qty  INT,
    threshold    INT,
    alerted_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- T6 — AFTER UPDATE trigger on inventory to alert when stock falls below threshold

DELIMITER $$

CREATE TRIGGER trg_low_stock_alert
AFTER UPDATE ON inventory
FOR EACH ROW
BEGIN
    IF NEW.quantity_available < NEW.reorder_threshold
    AND OLD.quantity_available >= OLD.reorder_threshold THEN
        INSERT INTO inventory_alerts
            (product_id, warehouse_id, current_qty, threshold)
        VALUES
            (NEW.product_id, NEW.warehouse_id,
             NEW.quantity_available, NEW.reorder_threshold);
    END IF;
END$$

DELIMITER ;


-- T7 — Full ROLLBACK demo — simulate payment failure and prove nothing was committed

SELECT COUNT(*) AS orders_before_rollback FROM orders;

START TRANSACTION;

    INSERT INTO orders
        (customer_id, shipping_address_id, status, total_amount)
    VALUES
        (1, 1, 'confirmed', 9999.00);

    INSERT INTO payments
        (order_id, method, status, gateway_reference)
    VALUES
        (LAST_INSERT_ID(), 'card', 'failed', 'TXN_FAILED_TEST');

ROLLBACK;

SELECT COUNT(*) AS orders_after_rollback FROM orders;

-- Both counts must be identical proving ROLLBACK worked correctly


-- T8 — process_return test to verify single transaction works end to end

-- First find a delivered order to test with
SELECT
    o.id            AS order_id,
    oi.id           AS order_item_id,
    o.customer_id
FROM orders o
INNER JOIN order_items oi ON oi.order_id = o.id
WHERE o.status = 'delivered'
LIMIT 1;

-- Then call process_return with those values
-- Replace the ids below with what the above query returns
CALL process_return(1, 1, 1, 'damaged', 'opened', 'original', @msg);
SELECT @msg AS message;