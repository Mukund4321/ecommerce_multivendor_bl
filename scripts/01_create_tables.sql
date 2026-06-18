USE ecommerce;

CREATE TABLE users (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    email         VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role          ENUM('customer','seller','admin') NOT NULL,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE addresses (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    user_id       INT NOT NULL,
    address_line1 VARCHAR(255) NOT NULL,
    address_line2 VARCHAR(255),
    city          VARCHAR(100),
    state         VARCHAR(100),
    pincode       VARCHAR(20),
    type          ENUM('billing','shipping'),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE customer_profiles (
    id                   INT AUTO_INCREMENT PRIMARY KEY,
    user_id              INT NOT NULL,
    loyalty_points       INT DEFAULT 0,
    date_of_birth        DATE,
    preferred_address_id INT,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE seller_profiles (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT NOT NULL,
    business_name   VARCHAR(150) NOT NULL,
    gst_number      VARCHAR(50),
    commission_rate DECIMAL(5,2),
    is_verified     BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE brands (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE
);

CREATE TABLE categories (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    parent_id INT DEFAULT NULL,
    name      VARCHAR(100) NOT NULL,
    slug      VARCHAR(100) UNIQUE,
    FOREIGN KEY (parent_id) REFERENCES categories(id)
);

CREATE TABLE products (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    seller_id  INT NOT NULL,
    brand_id   INT,
    sku        VARCHAR(100) UNIQUE NOT NULL,
    slug       VARCHAR(150) UNIQUE,
    name       VARCHAR(255) NOT NULL,
    base_price DECIMAL(10,2) NOT NULL,
    status     ENUM('active','inactive','draft') DEFAULT 'draft',
    avg_rating DECIMAL(3,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (seller_id) REFERENCES users(id),
    FOREIGN KEY (brand_id)  REFERENCES brands(id)
);

CREATE TABLE product_categories (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    product_id  INT NOT NULL,
    category_id INT NOT NULL,
    FOREIGN KEY (product_id)  REFERENCES products(id),
    FOREIGN KEY (category_id) REFERENCES categories(id)
);

CREATE TABLE product_images (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    image_url  VARCHAR(500) NOT NULL,
    sort_order INT DEFAULT 0,
    FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE TABLE warehouses (
    id       INT AUTO_INCREMENT PRIMARY KEY,
    name     VARCHAR(150) NOT NULL,
    location VARCHAR(255),
    capacity INT
);

CREATE TABLE inventory (
    id                 INT AUTO_INCREMENT PRIMARY KEY,
    product_id         INT NOT NULL,
    warehouse_id       INT NOT NULL,
    quantity_available INT DEFAULT 0,
    reorder_threshold  INT DEFAULT 10,
    FOREIGN KEY (product_id)   REFERENCES products(id),
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
);

CREATE TABLE stock_movements (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    product_id    INT NOT NULL,
    warehouse_id  INT NOT NULL,
    movement_type ENUM('stock_in','stock_out','damaged','returned') NOT NULL,
    quantity      INT NOT NULL,
    moved_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    note          VARCHAR(255),
    FOREIGN KEY (product_id)   REFERENCES products(id),
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
);

CREATE TABLE cart (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE cart_items (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    cart_id    INT NOT NULL,
    product_id INT NOT NULL,
    quantity   INT DEFAULT 1,
    added_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (cart_id)    REFERENCES cart(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE TABLE orders (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    customer_id         INT NOT NULL,
    shipping_address_id INT,
    status              ENUM('pending','confirmed','shipped','delivered','cancelled') DEFAULT 'pending',
    total_amount        DECIMAL(10,2),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    delivered_at        TIMESTAMP NULL,
    FOREIGN KEY (customer_id)         REFERENCES users(id),
    FOREIGN KEY (shipping_address_id) REFERENCES addresses(id)
);

CREATE TABLE order_items (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    order_id   INT NOT NULL,
    product_id INT NOT NULL,
    seller_id  INT NOT NULL,
    quantity   INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id)   REFERENCES orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (seller_id)  REFERENCES users(id)
);

CREATE TABLE payments (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    order_id          INT NOT NULL,
    method            ENUM('card','upi','netbanking','wallet','cod'),
    status            ENUM('pending','success','failed','refunded') DEFAULT 'pending',
    gateway_reference VARCHAR(255),
    paid_at           TIMESTAMP NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id)
);

CREATE TABLE payment_transactions (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    payment_id     INT NOT NULL,
    attempt_number INT DEFAULT 1,
    status         ENUM('pending','success','failed'),
    response_code  VARCHAR(50),
    attempted_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (payment_id) REFERENCES payments(id)
);

CREATE TABLE invoices (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    order_id       INT NOT NULL,
    payment_id     INT NOT NULL,
    invoice_number VARCHAR(100) UNIQUE,
    tax_amount     DECIMAL(10,2),
    total_amount   DECIMAL(10,2),
    generated_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id)   REFERENCES orders(id),
    FOREIGN KEY (payment_id) REFERENCES payments(id)
);

CREATE TABLE coupons (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    code            VARCHAR(50) UNIQUE NOT NULL,
    type            ENUM('flat','percentage'),
    discount_value  DECIMAL(10,2),
    max_uses        INT,
    used_count      INT DEFAULT 0,
    min_order_value DECIMAL(10,2),
    expires_at      TIMESTAMP NULL
);

CREATE TABLE coupon_usage (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    coupon_id   INT NOT NULL,
    customer_id INT NOT NULL,
    order_id    INT NOT NULL,
    used_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (coupon_id)   REFERENCES coupons(id),
    FOREIGN KEY (customer_id) REFERENCES users(id),
    FOREIGN KEY (order_id)    REFERENCES orders(id)
);

CREATE TABLE reviews (
    id                   INT AUTO_INCREMENT PRIMARY KEY,
    product_id           INT NOT NULL,
    customer_id          INT NOT NULL,
    title                VARCHAR(150),
    body                 TEXT,
    is_verified_purchase BOOLEAN DEFAULT FALSE,
    helpful_votes        INT DEFAULT 0,
    created_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id)  REFERENCES products(id),
    FOREIGN KEY (customer_id) REFERENCES users(id)
);

CREATE TABLE ratings (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    product_id        INT NOT NULL,
    customer_id       INT NOT NULL,
    stars             INT CHECK (stars BETWEEN 1 AND 5),
    moderation_status ENUM('pending','approved','rejected') DEFAULT 'pending',
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id)  REFERENCES products(id),
    FOREIGN KEY (customer_id) REFERENCES users(id)
);

CREATE TABLE returns (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    order_id            INT NOT NULL,
    order_item_id       INT NOT NULL,
    customer_id         INT NOT NULL,
    reason_code         VARCHAR(100),
    item_condition      ENUM('unopened','opened','damaged'),
    return_window_valid BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id)      REFERENCES orders(id),
    FOREIGN KEY (order_item_id) REFERENCES order_items(id),
    FOREIGN KEY (customer_id)   REFERENCES users(id)
);

CREATE TABLE refunds (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    return_id    INT NOT NULL,
    payment_id   INT NOT NULL,
    amount       DECIMAL(10,2),
    method       ENUM('original','wallet','bank'),
    processed_at TIMESTAMP NULL,
    FOREIGN KEY (return_id)  REFERENCES returns(id),
    FOREIGN KEY (payment_id) REFERENCES payments(id)
);

CREATE TABLE inventory_alerts (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    product_id   INT NOT NULL,
    warehouse_id INT NOT NULL,
    current_qty  INT,
    threshold    INT,
    alerted_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SHOW TABLES;
