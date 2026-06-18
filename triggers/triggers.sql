USE ecommerce;

-- T1 — AFTER INSERT on order_items to auto deduct inventory

DELIMITER $$

CREATE TRIGGER trg_deduct_inventory_on_order
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    UPDATE inventory
    SET    quantity_available = quantity_available - NEW.quantity
    WHERE  product_id = NEW.product_id
    LIMIT 1;

    INSERT INTO stock_movements (product_id, warehouse_id, movement_type, quantity, note)
    SELECT NEW.product_id, warehouse_id, 'stock_out', NEW.quantity,
           CONCAT('Auto deducted for order item id ', NEW.id)
    FROM inventory WHERE product_id = NEW.product_id LIMIT 1;
END$$

DELIMITER ;


-- T2 — AFTER INSERT on returns to auto restore inventory

DELIMITER $$

CREATE TRIGGER trg_restore_inventory_on_return
AFTER INSERT ON returns
FOR EACH ROW
BEGIN
    UPDATE inventory inv
    INNER JOIN order_items oi ON oi.product_id = inv.product_id
    SET inv.quantity_available = inv.quantity_available + oi.quantity
    WHERE oi.id = NEW.order_item_id;

    INSERT INTO stock_movements (product_id, warehouse_id, movement_type, quantity, note)
    SELECT oi.product_id, inv.warehouse_id, 'returned', oi.quantity,
           CONCAT('Auto restored for return id ', NEW.id)
    FROM order_items oi
    INNER JOIN inventory inv ON inv.product_id = oi.product_id
    WHERE oi.id = NEW.order_item_id LIMIT 1;
END$$

DELIMITER ;


-- T3 — AFTER UPDATE on orders when cancelled to restore inventory

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

        INSERT INTO stock_movements (product_id, warehouse_id, movement_type, quantity, note)
        SELECT oi.product_id, inv.warehouse_id, 'stock_in', oi.quantity,
               CONCAT('Restored for cancelled order id ', NEW.id)
        FROM order_items oi
        INNER JOIN inventory inv ON inv.product_id = oi.product_id
        WHERE oi.order_id = NEW.id;
    END IF;
END$$

DELIMITER ;


-- T4 — AFTER INSERT on ratings to recalculate product average rating

DELIMITER $$

CREATE TRIGGER trg_update_avg_rating
AFTER INSERT ON ratings
FOR EACH ROW
BEGIN
    UPDATE products
    SET    avg_rating = (
        SELECT ROUND(AVG(stars), 2) FROM ratings WHERE product_id = NEW.product_id
    )
    WHERE id = NEW.product_id;
END$$

DELIMITER ;


-- T5 — AFTER INSERT on payments when success to auto create invoice

DELIMITER $$

CREATE TRIGGER trg_create_invoice_on_payment
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
    IF NEW.status = 'success' THEN
        INSERT INTO invoices (order_id, payment_id, invoice_number, tax_amount, total_amount)
        SELECT NEW.order_id, NEW.id,
               CONCAT('INV-', NEW.order_id, '-', NEW.id),
               ROUND(o.total_amount * 0.18, 2),
               o.total_amount
        FROM orders o WHERE o.id = NEW.order_id;
    END IF;
END$$

DELIMITER ;


-- T6 — AFTER UPDATE on inventory to alert when stock falls below threshold

DELIMITER $$

CREATE TRIGGER trg_low_stock_alert
AFTER UPDATE ON inventory
FOR EACH ROW
BEGIN
    IF NEW.quantity_available < NEW.reorder_threshold
    AND OLD.quantity_available >= OLD.reorder_threshold THEN
        INSERT INTO inventory_alerts (product_id, warehouse_id, current_qty, threshold)
        VALUES (NEW.product_id, NEW.warehouse_id, NEW.quantity_available, NEW.reorder_threshold);
    END IF;
END$$

DELIMITER ;
