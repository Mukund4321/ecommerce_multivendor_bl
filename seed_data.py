import random
from faker import Faker
import mysql.connector
from datetime import datetime, timedelta

fake = Faker('en_IN')

conn = mysql.connector.connect(
    host='localhost',
    user='root',
    password='Password123',
    database='ecommerce'
)
cursor = conn.cursor()
print("Connected to MySQL successfully")

NUM_USERS      = 10000
NUM_SELLERS    = 5
NUM_ORDERS     = 10000000
BATCH_SIZE     = 5000

def random_date(start_months_ago=6):
    start = datetime.now() - timedelta(days=start_months_ago * 30)
    return fake.date_time_between(start_date=start, end_date='now')

def safe_email(index):
    return f"user_{index}_{random.randint(1000,9999)}@example.com"

def safe_seller_email(index):
    return f"seller_{index}_{random.randint(1000,9999)}@shop.com"


print("\n[1/13] Inserting users...")
seller_user_ids = []
for i in range(NUM_SELLERS):
    cursor.execute("""
        INSERT INTO users (email, password_hash, role)
        VALUES (%s, %s, 'seller')
    """, (safe_seller_email(i+1), fake.sha256()))
    seller_user_ids.append(cursor.lastrowid)
conn.commit()

customer_ids = []
batch = []
for i in range(NUM_USERS):
    batch.append((safe_email(i+1), fake.sha256(), 'customer'))
    if len(batch) == BATCH_SIZE:
        cursor.executemany("""
            INSERT INTO users (email, password_hash, role)
            VALUES (%s, %s, %s)
        """, batch)
        conn.commit()
        batch = []
        print(f"  Users inserted: {i+1}")
if batch:
    cursor.executemany("""
        INSERT INTO users (email, password_hash, role)
        VALUES (%s, %s, %s)
    """, batch)
    conn.commit()

cursor.execute("SELECT id FROM users WHERE role = 'customer'")
customer_ids = [row[0] for row in cursor.fetchall()]
print(f"  Done — {len(customer_ids)} customers + {len(seller_user_ids)} sellers")



print("\n[2/13] Inserting addresses...")
cities    = ['Mumbai','Delhi','Chennai','Bangalore','Hyderabad','Pune','Kolkata','Ahmedabad']
states    = ['Maharashtra','Delhi','Tamil Nadu','Karnataka','Telangana','Maharashtra','West Bengal','Gujarat']
batch = []
for uid in customer_ids:
    idx = random.randint(0, len(cities)-1)
    batch.append((
        uid,
        f"{random.randint(1,999)}, {fake.last_name()} Street",
        f"Near {fake.last_name()} Colony",
        cities[idx],
        states[idx],
        str(random.randint(100000, 999999)),
        random.choice(['billing','shipping'])
    ))
    if len(batch) == BATCH_SIZE:
        cursor.executemany("""
            INSERT INTO addresses
            (user_id, address_line1, address_line2,
             city, state, pincode, type)
            VALUES (%s,%s,%s,%s,%s,%s,%s)
        """, batch)
        conn.commit()
        batch = []
if batch:
    cursor.executemany("""
        INSERT INTO addresses
        (user_id, address_line1, address_line2,
         city, state, pincode, type)
        VALUES (%s,%s,%s,%s,%s,%s,%s)
    """, batch)
    conn.commit()

cursor.execute("SELECT id FROM addresses")
all_address_ids = [row[0] for row in cursor.fetchall()]
print(f"  Done — {len(all_address_ids)} addresses")


print("\n[3/13] Inserting customer profiles...")
batch = []
for uid in customer_ids:
    batch.append((uid, random.randint(0, 5000)))
    if len(batch) == BATCH_SIZE:
        cursor.executemany("""
            INSERT INTO customer_profiles (user_id, loyalty_points)
            VALUES (%s, %s)
        """, batch)
        conn.commit()
        batch = []
if batch:
    cursor.executemany("""
        INSERT INTO customer_profiles (user_id, loyalty_points)
        VALUES (%s, %s)
    """, batch)
    conn.commit()
print(f"  Done — {len(customer_ids)} customer profiles")


print("\n[4/13] Inserting seller profiles...")
seller_names = [
    'Samsung Official Store',
    'Nike India',
    'Apple Reseller',
    'boAt Lifestyle',
    'Puma Sports'
]
for i, uid in enumerate(seller_user_ids):
    cursor.execute("""
        INSERT INTO seller_profiles
        (user_id, business_name, gst_number, commission_rate, is_verified)
        VALUES (%s,%s,%s,%s,%s)
    """, (
        uid,
        seller_names[i],
        f"GST{random.randint(10,99)}{fake.bothify(text='??####?####')}",
        round(random.uniform(2.0, 15.0), 2),
        True
    ))
conn.commit()
print(f"  Done — {NUM_SELLERS} seller profiles")


print("\n[5/13] Inserting brands...")
brand_names = [
    'Samsung','Nike','Apple','boAt','Puma','Sony',
    'LG','Adidas','OnePlus','Realme','Xiaomi','HP',
    'Dell','Lenovo','Asus','JBL','Bose','Wildcraft',
    'Woodland','VIP'
]
brand_ids = []
for name in brand_names:
    cursor.execute("""
        INSERT INTO brands (name, is_verified) VALUES (%s, %s)
    """, (name, True))
    brand_ids.append(cursor.lastrowid)
conn.commit()
print(f"  Done — {len(brand_ids)} brands")

print("\n[6/13] Inserting categories...")
root_categories = ['Electronics','Fashion','Sports','Home and Kitchen','Books']
root_ids = []
for name in root_categories:
    cursor.execute("""
        INSERT INTO categories (parent_id, name, slug)
        VALUES (NULL, %s, %s)
    """, (name, name.lower().replace(' ','-')))
    root_ids.append(cursor.lastrowid)

sub_map = {
    root_ids[0]: ['Mobiles','Laptops','Headphones','Tablets','Cameras'],
    root_ids[1]: ['Men Clothing','Women Clothing','Footwear','Accessories'],
    root_ids[2]: ['Cricket','Football','Running','Fitness','Yoga'],
    root_ids[3]: ['Kitchen Appliances','Furniture','Decor','Bedding'],
    root_ids[4]: ['Fiction','Non-Fiction','Academic','Comics']
}
category_ids = list(root_ids)
for parent_id, subs in sub_map.items():
    for sub in subs:
        cursor.execute("""
            INSERT INTO categories (parent_id, name, slug)
            VALUES (%s, %s, %s)
        """, (parent_id, sub, sub.lower().replace(' ','-')))
        category_ids.append(cursor.lastrowid)
conn.commit()
print(f"  Done — {len(category_ids)} categories")


print("\n[7/13] Inserting warehouses...")
warehouse_data = [
    ('Mumbai Warehouse',  'Mumbai, Maharashtra',  50000),
    ('Delhi Warehouse',   'Delhi, NCR',            45000),
    ('Chennai Warehouse', 'Chennai, Tamil Nadu',   40000)
]
warehouse_ids = []
for name, loc, cap in warehouse_data:
    cursor.execute("""
        INSERT INTO warehouses (name, location, capacity)
        VALUES (%s,%s,%s)
    """, (name, loc, cap))
    warehouse_ids.append(cursor.lastrowid)
conn.commit()
print(f"  Done — {len(warehouse_ids)} warehouses")


print("\n[8/13] Inserting products...")
product_names = [
    'Samsung Galaxy S24','iPhone 15 Pro','Nike Air Max',
    'boAt Airdopes 141','Sony WH-1000XM5','Dell XPS 15',
    'HP Pavilion Laptop','Puma Running Shoes','Adidas Ultraboost',
    'OnePlus 12','Realme GT 5','Xiaomi 14 Ultra',
    'JBL Flip 6','Bose QuietComfort 45','Lenovo IdeaPad',
    'Asus ROG Phone','Samsung 4K TV','LG OLED TV',
    'Nike Dri-FIT T-Shirt','Adidas Track Pants',
    'Woodland Boots','VIP Trolley Bag','Wildcraft Backpack',
    'SG Cricket Bat','Nike Strike Football',
    'Premium Yoga Mat','Dumbbells Set 10kg',
    'Philips Air Fryer','Instant Pot 7-in-1','Morphy Richards Coffee Maker',
    'Ergonomic Office Chair','Wooden Study Table',
    'Python Programming Book','Atomic Habits',
    'The Alchemist','Harry Potter Complete Set',
    'Samsung Galaxy Tab S9','iPad Air 5','Kindle Paperwhite',
    'GoPro Hero 12','Canon EOS 200D','Nikon Z30',
    'Fitbit Charge 6','Apple Watch Series 9',
    'Mi Band 8','Noise ColorFit Pro 4',
    'Skullcandy Crusher','Sennheiser HD 450BT',
    'Logitech MX Master 3','Keychron K2 Keyboard'
]
product_ids = []
image_batch = []
for i, pname in enumerate(product_names):
    seller = random.choice(seller_user_ids)
    brand  = random.choice(brand_ids)
    price  = round(random.uniform(299, 149999), 2)
    slug   = pname.lower().replace(' ','-').replace("'","")
    cursor.execute("""
        INSERT INTO products
        (seller_id, brand_id, sku, slug, name, base_price, status)
        VALUES (%s,%s,%s,%s,%s,%s,'active')
    """, (seller, brand, f'SKU-{1000+i}', slug, pname, price))
    pid = cursor.lastrowid
    product_ids.append(pid)

    cursor.execute("""
        INSERT INTO product_categories (product_id, category_id)
        VALUES (%s,%s)
    """, (pid, random.choice(category_ids)))

    for img_order in range(random.randint(1,3)):
        image_batch.append((
            pid,
            f"https://images.ecommerce.com/products/{pid}/img{img_order+1}.jpg",
            img_order
        ))

cursor.executemany("""
    INSERT INTO product_images (product_id, image_url, sort_order)
    VALUES (%s,%s,%s)
""", image_batch)
conn.commit()
print(f"  Done — {len(product_ids)} products + images")


print("\n[9/13] Inserting inventory...")
inv_batch = []
mov_batch = []
for pid in product_ids:
    for wid in warehouse_ids:
        qty = random.randint(100, 5000)
        inv_batch.append((pid, wid, qty, random.randint(10,50)))
        mov_batch.append((pid, wid, 'stock_in', qty, 'Initial stock'))

cursor.executemany("""
    INSERT INTO inventory
    (product_id, warehouse_id, quantity_available, reorder_threshold)
    VALUES (%s,%s,%s,%s)
""", inv_batch)
cursor.executemany("""
    INSERT INTO stock_movements
    (product_id, warehouse_id, movement_type, quantity, note)
    VALUES (%s,%s,%s,%s,%s)
""", mov_batch)
conn.commit()
print(f"  Done — {len(inv_batch)} inventory rows")


print("\n[10/13] Inserting coupons...")
coupon_data = [
    ('SAVE10',    'percentage', 10,  100, 500),
    ('FLAT200',   'flat',       200, 500, 1000),
    ('NEWUSER50', 'percentage', 50,  200, 299),
    ('FESTIVE20', 'percentage', 20,  300, 999),
    ('WELCOME100','flat',       100, 1000,699)
]
coupon_ids = []
for code, ctype, val, max_uses, min_order in coupon_data:
    cursor.execute("""
        INSERT INTO coupons
        (code, type, discount_value, max_uses, min_order_value, expires_at)
        VALUES (%s,%s,%s,%s,%s,%s)
    """, (code, ctype, val, max_uses, min_order,
          datetime.now() + timedelta(days=180)))
    coupon_ids.append(cursor.lastrowid)
conn.commit()
print(f"  Done — {len(coupon_ids)} coupons")


print(f"\n[11/13] Inserting {NUM_ORDERS:,} orders — grab a coffee, this will take a while...")
statuses = ['pending','confirmed','shipped','delivered','cancelled']
weights  = [5, 10, 15, 65, 5]
batch = []
total_orders = 0

for i in range(NUM_ORDERS):
    cid    = random.choice(customer_ids)
    addr   = random.choice(all_address_ids)
    status = random.choices(statuses, weights=weights)[0]
    total  = round(random.uniform(299, 149999), 2)
    created = random_date(6)
    delivered = (
        created + timedelta(days=random.randint(1,7))
        if status == 'delivered' else None
    )
    batch.append((cid, addr, status, total, created, delivered))

    if len(batch) == BATCH_SIZE:
        cursor.executemany("""
            INSERT INTO orders
            (customer_id, shipping_address_id, status,
             total_amount, created_at, delivered_at)
            VALUES (%s,%s,%s,%s,%s,%s)
        """, batch)
        conn.commit()
        total_orders += len(batch)
        batch = []
        if total_orders % 100000 == 0:
            print(f"  Orders inserted: {total_orders:,}")

if batch:
    cursor.executemany("""
        INSERT INTO orders
        (customer_id, shipping_address_id, status,
         total_amount, created_at, delivered_at)
        VALUES (%s,%s,%s,%s,%s,%s)
    """, batch)
    conn.commit()
    total_orders += len(batch)

print(f"  Done — {total_orders:,} orders inserted")


print("\n[12/13] Inserting order items, payments, transactions, invoices...")

# fetch orders in chunks
CHUNK = 200000
offset = 0
total_items = 0
total_payments = 0
methods = ['card','upi','netbanking','wallet','cod']

while True:
    cursor.execute("""
        SELECT id, status, total_amount, created_at
        FROM orders LIMIT %s OFFSET %s
    """, (CHUNK, offset))
    rows = cursor.fetchall()
    if not rows:
        break

    oi_batch  = []
    pay_batch = []
    ptx_batch = []
    inv_batch = []

    for oid, ostatus, ototal, ocreated in rows:
        # order items
        num_items = random.randint(1, 4)
        for _ in range(num_items):
            pid    = random.choice(product_ids)
            seller = seller_user_ids[product_ids.index(pid) % NUM_SELLERS]
            oi_batch.append((
                oid, pid, seller,
                random.randint(1,5),
                round(random.uniform(299, 49999), 2)
            ))

        # payment
        pstatus = 'success' if ostatus in ('confirmed','shipped','delivered') else (
                  'failed'  if ostatus == 'cancelled' else 'pending')
        method  = random.choice(methods)
        pay_batch.append((
            oid, method, pstatus,
            f"TXN{random.randint(100000000,999999999)}"
        ))

    # insert order items
    cursor.executemany("""
        INSERT INTO order_items
        (order_id, product_id, seller_id, quantity, unit_price)
        VALUES (%s,%s,%s,%s,%s)
    """, oi_batch)
    total_items += len(oi_batch)

    # insert payments
    cursor.executemany("""
        INSERT INTO payments
        (order_id, method, status, gateway_reference)
        VALUES (%s,%s,%s,%s)
    """, pay_batch)
    total_payments += len(pay_batch)
    conn.commit()

    # get payment ids just inserted for this chunk
    cursor.execute("""
        SELECT id, order_id, status FROM payments
        ORDER BY id DESC LIMIT %s
    """, (len(pay_batch),))
    pay_rows = cursor.fetchall()

    for pay_id, pay_order_id, pay_status in pay_rows:
        ptx_batch.append((
            pay_id, 1, pay_status,
            f"RC{random.randint(100,999)}"
        ))
        if pay_status == 'success':
            inv_batch.append((
                pay_order_id, pay_id,
                f"INV-{pay_order_id}-{pay_id}",
                round(random.uniform(10, 500), 2),
                round(random.uniform(299, 149999), 2)
            ))

    if ptx_batch:
        cursor.executemany("""
            INSERT INTO payment_transactions
            (payment_id, attempt_number, status, response_code)
            VALUES (%s,%s,%s,%s)
        """, ptx_batch)

    if inv_batch:
        cursor.executemany("""
            INSERT INTO invoices
            (order_id, payment_id, invoice_number,
             tax_amount, total_amount)
            VALUES (%s,%s,%s,%s,%s)
        """, inv_batch)

    conn.commit()
    offset += CHUNK
    print(f"  Processed chunk — order items: {total_items:,} | payments: {total_payments:,}")

print(f"  Done — {total_items:,} order items | {total_payments:,} payments")


print("\n[13/13] Inserting reviews, ratings, returns, refunds, coupon usage...")

# reviews + ratings
rev_batch = []
rat_batch = []
for _ in range(50000):
    pid = random.choice(product_ids)
    cid = random.choice(customer_ids)
    rev_batch.append((
        pid, cid,
        f"Great product {random.randint(1,999)}",
        f"I really liked this product. Quality is good. Worth the price. {fake.sentence()}",
        True,
        random.randint(0,200)
    ))
    rat_batch.append((pid, cid, random.randint(1,5), 'approved'))

cursor.executemany("""
    INSERT INTO reviews
    (product_id, customer_id, title, body,
     is_verified_purchase, helpful_votes)
    VALUES (%s,%s,%s,%s,%s,%s)
""", rev_batch)
cursor.executemany("""
    INSERT INTO ratings
    (product_id, customer_id, stars, moderation_status)
    VALUES (%s,%s,%s,%s)
""", rat_batch)
conn.commit()
print(f"  Reviews and ratings: 50,000 each")

# returns + refunds
cursor.execute("SELECT id FROM order_items LIMIT 5000")
sample_oi = [r[0] for r in cursor.fetchall()]
cursor.execute("""
    SELECT oi.id, oi.order_id, p.id
    FROM order_items oi
    JOIN payments p ON p.order_id = oi.order_id
    WHERE p.status = 'success'
    LIMIT 5000
""")
return_rows = cursor.fetchall()

ret_batch = []
ref_batch = []
for oi_id, ord_id, pay_id in return_rows[:2000]:
    cid = random.choice(customer_ids)
    ret_batch.append((
        ord_id, oi_id, cid,
        random.choice(['damaged','wrong_item','not_needed','quality_issue']),
        random.choice(['unopened','opened','damaged']),
        True
    ))

cursor.executemany("""
    INSERT INTO returns
    (order_id, order_item_id, customer_id,
     reason_code, item_condition, return_window_valid)
    VALUES (%s,%s,%s,%s,%s,%s)
""", ret_batch)
conn.commit()

cursor.execute("SELECT id FROM returns LIMIT 2000")
return_ids = [r[0] for r in cursor.fetchall()]

for i, ret_id in enumerate(return_ids):
    pay_id = return_rows[i][2]
    ref_batch.append((
        ret_id, pay_id,
        round(random.uniform(100, 5000), 2),
        random.choice(['original','wallet','bank'])
    ))

cursor.executemany("""
    INSERT INTO refunds (return_id, payment_id, amount, method)
    VALUES (%s,%s,%s,%s)
""", ref_batch)
conn.commit()
print(f"  Returns: {len(ret_batch)} | Refunds: {len(ref_batch)}")

# coupon usage
cursor.execute("""
    SELECT id FROM orders
    WHERE status = 'delivered'
    LIMIT 10000
""")
delivered_order_ids = [r[0] for r in cursor.fetchall()]
cup_batch = []
for oid in delivered_order_ids[:5000]:
    cup_batch.append((
        random.choice(coupon_ids),
        random.choice(customer_ids),
        oid
    ))
cursor.executemany("""
    INSERT INTO coupon_usage (coupon_id, customer_id, order_id)
    VALUES (%s,%s,%s)
""", cup_batch)
conn.commit()
print(f"  Coupon usage: {len(cup_batch)}")

cursor.close()
conn.close()
print("\n" + "="*50)
print("ALL SEED DATA INSERTED SUCCESSFULLY")
print("="*50)
print(f"  Users        : {NUM_USERS + NUM_SELLERS:,}")
print(f"  Products     : {len(product_names)}")
print(f"  Warehouses   : 3")
print(f"  Orders       : {NUM_ORDERS:,}")
print(f"  Reviews      : 50,000")
print(f"  Returns      : 2,000")
print(f"  Refunds      : 2,000")
print(f"  Coupon Usage : 5,000")    
print("="*50)