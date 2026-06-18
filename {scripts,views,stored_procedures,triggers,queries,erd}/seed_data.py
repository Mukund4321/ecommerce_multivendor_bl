import random
from faker import Faker
import mysql.connector
from datetime import datetime, timedelta

fake = Faker('en_IN')

conn = mysql.connector.connect(
    host='localhost',
    user='root',
    password='Ecommercemysql12$',
    database='ecommerce'
)
cursor = conn.cursor()
print("Connected to MySQL successfully")

NUM_USERS         = 100000
NUM_SELLERS       = 100000
NUM_PRODUCTS      = 100000
NUM_ORDERS        = 10000000
NUM_CARTS         = 100000
NUM_REVIEWS       = 100000
NUM_RETURNS       = 100000
NUM_COUPON_USAGE  = 100000
NUM_BRANDS        = 100000
NUM_CATEGORIES    = 100000
NUM_WAREHOUSES    = 100000
NUM_COUPONS       = 100000
BATCH_SIZE        = 5000

def random_date(start_months_ago=6):
    start = datetime.now() - timedelta(days=start_months_ago * 30)
    return fake.date_time_between(start_date=start, end_date='now')

def safe_email(index):
    return f"user_{index}_{random.randint(1000,9999)}@example.com"

def safe_seller_email(index):
    return f"seller_{index}_{random.randint(1000,9999)}@shop.com"


# ── 1. USERS ──────────────────────────────────────────────
print("\n[1/14] Inserting users...")
seller_user_ids = []
batch = []
for i in range(NUM_SELLERS):
    batch.append((safe_seller_email(i+1), fake.sha256(), 'seller'))
    if len(batch) == BATCH_SIZE:
        cursor.executemany("""
            INSERT INTO users (email, password_hash, role)
            VALUES (%s, %s, %s)
        """, batch)
        conn.commit()
        batch = []
        if (i+1) % 20000 == 0:
            print(f"  Sellers inserted: {i+1:,}")
if batch:
    cursor.executemany("""
        INSERT INTO users (email, password_hash, role)
        VALUES (%s, %s, %s)
    """, batch)
    conn.commit()

cursor.execute("SELECT id FROM users WHERE role = 'seller'")
seller_user_ids = [row[0] for row in cursor.fetchall()]
print(f"  Sellers done: {len(seller_user_ids):,}")

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
        if (i+1) % 20000 == 0:
            print(f"  Customers inserted: {i+1:,}")
if batch:
    cursor.executemany("""
        INSERT INTO users (email, password_hash, role)
        VALUES (%s, %s, %s)
    """, batch)
    conn.commit()

cursor.execute("SELECT id FROM users WHERE role = 'customer'")
customer_ids = [row[0] for row in cursor.fetchall()]
print(f"  Done — {len(customer_ids):,} customers + {len(seller_user_ids):,} sellers")


# ── 2. ADDRESSES ──────────────────────────────────────────
print("\n[2/14] Inserting addresses...")
cities = ['Mumbai','Delhi','Chennai','Bangalore','Hyderabad','Pune',
          'Kolkata','Ahmedabad','Jaipur','Surat','Lucknow','Kanpur',
          'Nagpur','Visakhapatnam','Bhopal','Patna','Vadodara','Ghaziabad',
          'Coimbatore','Kochi','Indore','Agra','Varanasi','Chandigarh']
states = ['Maharashtra','Delhi','Tamil Nadu','Karnataka','Telangana',
          'Maharashtra','West Bengal','Gujarat','Rajasthan','Gujarat',
          'Uttar Pradesh','Uttar Pradesh','Maharashtra','Andhra Pradesh',
          'Madhya Pradesh','Bihar','Gujarat','Uttar Pradesh',
          'Tamil Nadu','Kerala','Madhya Pradesh','Uttar Pradesh',
          'Uttar Pradesh','Punjab']

all_user_ids = seller_user_ids + customer_ids
batch = []
addr_total = 0
for uid in all_user_ids:
    idx = random.randint(0, len(cities)-1)
    batch.append((
        uid,
        f"{random.randint(1,999)}, {fake.last_name()} Street",
        f"Near {fake.last_name()} Colony",
        cities[idx], states[idx],
        str(random.randint(100000, 999999)),
        random.choice(['billing','shipping'])
    ))
    if len(batch) >= BATCH_SIZE:
        cursor.executemany("""
            INSERT INTO addresses
            (user_id, address_line1, address_line2, city, state, pincode, type)
            VALUES (%s,%s,%s,%s,%s,%s,%s)
        """, batch)
        conn.commit()
        addr_total += len(batch)
        batch = []
        if addr_total % 50000 == 0:
            print(f"  Addresses: {addr_total:,}")
if batch:
    cursor.executemany("""
        INSERT INTO addresses
        (user_id, address_line1, address_line2, city, state, pincode, type)
        VALUES (%s,%s,%s,%s,%s,%s,%s)
    """, batch)
    conn.commit()
    addr_total += len(batch)

cursor.execute("SELECT id FROM addresses")
all_address_ids = [row[0] for row in cursor.fetchall()]
print(f"  Done — {addr_total:,} addresses")


# ── 3. CUSTOMER PROFILES ──────────────────────────────────
print("\n[3/14] Inserting customer profiles...")
batch = []
cp_total = 0
for uid in customer_ids:
    batch.append((uid, random.randint(0, 5000)))
    if len(batch) == BATCH_SIZE:
        cursor.executemany("""
            INSERT INTO customer_profiles (user_id, loyalty_points)
            VALUES (%s, %s)
        """, batch)
        conn.commit()
        cp_total += len(batch)
        batch = []
if batch:
    cursor.executemany("""
        INSERT INTO customer_profiles (user_id, loyalty_points)
        VALUES (%s, %s)
    """, batch)
    conn.commit()
    cp_total += len(batch)
print(f"  Done — {cp_total:,} customer profiles")


# ── 4. SELLER PROFILES ────────────────────────────────────
print("\n[4/14] Inserting seller profiles...")
business_types = [
    'Electronics Store','Fashion Hub','Sports World','Home Essentials',
    'Book Palace','Tech Zone','Style Point','Fitness Pro','Kitchen King',
    'Gadget Galaxy','Trend Mart','Sport Arena','Home Decor Plus','Read More',
    'Digital World','Fashion Street','Sports Hub','Kitchen Plus','Gadget Zone',
    'Lifestyle Store','Mega Mart','Super Store','Value Shop','Prime Store'
]
sp_batch = []
sp_total = 0
for i, uid in enumerate(seller_user_ids):
    bname = f"{fake.last_name()} {random.choice(business_types)} {i+1}"
    sp_batch.append((
        uid, bname,
        f"GST{random.randint(10,99)}{fake.bothify(text='??####?####')}",
        round(random.uniform(2.0, 15.0), 2),
        True
    ))
    if len(sp_batch) == BATCH_SIZE:
        cursor.executemany("""
            INSERT INTO seller_profiles
            (user_id, business_name, gst_number, commission_rate, is_verified)
            VALUES (%s,%s,%s,%s,%s)
        """, sp_batch)
        conn.commit()
        sp_total += len(sp_batch)
        sp_batch = []
        if sp_total % 20000 == 0:
            print(f"  Seller profiles: {sp_total:,}")
if sp_batch:
    cursor.executemany("""
        INSERT INTO seller_profiles
        (user_id, business_name, gst_number, commission_rate, is_verified)
        VALUES (%s,%s,%s,%s,%s)
    """, sp_batch)
    conn.commit()
    sp_total += len(sp_batch)
print(f"  Done — {sp_total:,} seller profiles")


# ── 5. BRANDS ─────────────────────────────────────────────
print("\n[5/14] Inserting brands...")
brand_ids = []
brand_names_list = []
br_batch = []
br_total = 0

base_brands = [
    'Samsung','Nike','Apple','boAt','Puma','Sony','LG','Adidas',
    'OnePlus','Realme','Xiaomi','HP','Dell','Lenovo','Asus','JBL',
    'Bose','Wildcraft','Woodland','VIP'
]
for name in base_brands:
    br_batch.append((name, True))
    brand_names_list.append(name)

brand_types = ['Electronics','Fashion','Sports','Home','Books','Beauty',
               'Automotive','Toys','Health','Grocery','Lifestyle','Tech',
               'Apparel','Footwear','Accessories','Gadgets','Appliances']
for i in range(NUM_BRANDS - len(base_brands)):
    name = f"{fake.last_name()} {random.choice(brand_types)} {i+1}"
    br_batch.append((random.choice([True, False]),))
    brand_names_list.append(name)
    br_batch[-1] = (name, random.choice([True, False]))

    if len(br_batch) >= BATCH_SIZE:
        cursor.executemany("""
            INSERT INTO brands (name, is_verified) VALUES (%s,%s)
        """, br_batch)
        conn.commit()
        br_total += len(br_batch)
        br_batch = []
        if br_total % 20000 == 0:
            print(f"  Brands: {br_total:,}")

if br_batch:
    cursor.executemany("""
        INSERT INTO brands (name, is_verified) VALUES (%s,%s)
    """, br_batch)
    conn.commit()
    br_total += len(br_batch)

cursor.execute("SELECT id, name FROM brands")
rows = cursor.fetchall()
brand_ids       = [r[0] for r in rows]
brand_names_list = [r[1] for r in rows]
print(f"  Done — {br_total:,} brands")


# ── 6. CATEGORIES ─────────────────────────────────────────
print("\n[6/14] Inserting categories...")
root_names = ['Electronics','Fashion','Sports','Home and Kitchen','Books',
              'Beauty','Automotive','Toys','Grocery','Health']
root_ids = []
for name in root_names:
    cursor.execute("""
        INSERT INTO categories (parent_id, name, slug)
        VALUES (NULL, %s, %s)
    """, (name, name.lower().replace(' ','-')))
    root_ids.append(cursor.lastrowid)
conn.commit()

cat_batch = []
cat_total = len(root_ids)
category_ids = list(root_ids)

sub_types = [
    'Mobiles','Laptops','Headphones','Tablets','Cameras','Smart Watches',
    'Men Clothing','Women Clothing','Footwear','Accessories','Ethnic Wear',
    'Cricket','Football','Running','Fitness','Yoga','Badminton',
    'Kitchen Appliances','Furniture','Decor','Bedding','Cleaning',
    'Fiction','Non-Fiction','Academic','Comics','Biographies',
    'Skincare','Haircare','Fragrances','Makeup',
    'Car Accessories','Bike Accessories','Tools',
    'Action Figures','Board Games','Educational',
    'Staples','Snacks','Beverages',
    'Supplements','Medical Devices','Vitamins'
]

for i in range(NUM_CATEGORIES - len(root_ids)):
    parent = random.choice(root_ids)
    name   = f"{random.choice(sub_types)} {i+1}"
    slug   = f"cat-{i+1}-{name.lower().replace(' ','-')}"
    cat_batch.append((parent, name, slug))

    if len(cat_batch) >= BATCH_SIZE:
        cursor.executemany("""
            INSERT INTO categories (parent_id, name, slug)
            VALUES (%s,%s,%s)
        """, cat_batch)
        conn.commit()
        cat_total += len(cat_batch)
        cat_batch = []
        if cat_total % 20000 == 0:
            print(f"  Categories: {cat_total:,}")

if cat_batch:
    cursor.executemany("""
        INSERT INTO categories (parent_id, name, slug)
        VALUES (%s,%s,%s)
    """, cat_batch)
    conn.commit()
    cat_total += len(cat_batch)

cursor.execute("SELECT id FROM categories")
category_ids = [r[0] for r in cursor.fetchall()]
print(f"  Done — {cat_total:,} categories")


# ── 7. WAREHOUSES ─────────────────────────────────────────
print("\n[7/14] Inserting warehouses...")
wh_cities = ['Mumbai','Delhi','Chennai','Bangalore','Hyderabad','Pune',
             'Kolkata','Ahmedabad','Jaipur','Surat','Lucknow','Nagpur',
             'Bhopal','Patna','Chandigarh','Kochi','Coimbatore','Vadodara',
             'Indore','Agra','Varanasi','Guwahati','Raipur','Bhubaneswar']
wh_batch = []
wh_total = 0
warehouse_ids = []

for i in range(NUM_WAREHOUSES):
    city = wh_cities[i % len(wh_cities)]
    wh_batch.append((
        f"{city} Warehouse {i+1}",
        f"{city}, India",
        random.randint(5000, 100000)
    ))
    if len(wh_batch) >= BATCH_SIZE:
        cursor.executemany("""
            INSERT INTO warehouses (name, location, capacity)
            VALUES (%s,%s,%s)
        """, wh_batch)
        conn.commit()
        wh_total += len(wh_batch)
        wh_batch = []
        if wh_total % 20000 == 0:
            print(f"  Warehouses: {wh_total:,}")
if wh_batch:
    cursor.executemany("""
        INSERT INTO warehouses (name, location, capacity)
        VALUES (%s,%s,%s)
    """, wh_batch)
    conn.commit()
    wh_total += len(wh_batch)

cursor.execute("SELECT id FROM warehouses")
warehouse_ids = [r[0] for r in cursor.fetchall()]
print(f"  Done — {wh_total:,} warehouses")


# ── 8. PRODUCTS ───────────────────────────────────────────
print(f"\n[8/14] Inserting {NUM_PRODUCTS:,} products...")
flagship_names = [
    'Samsung Galaxy S24','iPhone 15 Pro','Nike Air Max',
    'boAt Airdopes 141','Sony WH-1000XM5','Dell XPS 15',
    'HP Pavilion Laptop','Puma Running Shoes','Adidas Ultraboost',
    'OnePlus 12','Realme GT 5','Xiaomi 14 Ultra','JBL Flip 6',
    'Bose QuietComfort 45','Lenovo IdeaPad','Asus ROG Phone',
    'Samsung 4K TV','LG OLED TV','Nike Dri-FIT T-Shirt',
    'Adidas Track Pants','Woodland Boots','VIP Trolley Bag',
    'Wildcraft Backpack','SG Cricket Bat','Nike Strike Football',
    'Premium Yoga Mat','Dumbbells Set 10kg','Philips Air Fryer',
    'Instant Pot 7-in-1','Morphy Richards Coffee Maker',
    'Ergonomic Office Chair','Wooden Study Table',
    'Python Programming Book','Atomic Habits','The Alchemist',
    'Harry Potter Complete Set','Samsung Galaxy Tab S9',
    'iPad Air 5','Kindle Paperwhite','GoPro Hero 12',
    'Canon EOS 200D','Nikon Z30','Fitbit Charge 6',
    'Apple Watch Series 9','Mi Band 8','Noise ColorFit Pro 4',
    'Skullcandy Crusher','Sennheiser HD 450BT',
    'Logitech MX Master 3','Keychron K2 Keyboard'
]
product_types = [
    'Wireless Mouse','Bluetooth Speaker','Smart Watch','Phone Case',
    'Laptop Sleeve','Wireless Earbuds','Power Bank','USB-C Cable',
    'Cotton T-Shirt','Denim Jeans','Running Shorts','Zipper Hoodie',
    'Sports Shoes','Leather Sandals','Travel Backpack','Leather Wallet',
    'Yoga Mat','Adjustable Dumbbell','Resistance Band','Steel Water Bottle',
    'Non-Stick Pan','Mixer Grinder','LED Table Lamp','Wall Clock',
    'Bed Sheet Set','Cushion Cover','Ruled Notebook','Desk Organizer',
    'Wireless Keyboard','HD Webcam','Gaming Headset','Monitor Stand',
    'Face Wash','Shampoo','Perfume','Lip Balm','Car Mount','Bike Lock',
    'Tool Kit','Action Figure','Board Game','Puzzle Set','Remote Car',
    'Rice 5kg','Instant Noodles','Green Tea','Milk Powder',
    'Protein Powder','Blood Pressure Monitor','Face Mask','Vitamin C Tablets'
]

product_ids = []
product_to_seller = {}
pc_batch  = []
img_batch = []

for i, pname in enumerate(flagship_names):
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
    product_to_seller[pid] = seller
    pc_batch.append((pid, random.choice(category_ids)))
    for j in range(random.randint(1,3)):
        img_batch.append((pid, f"https://images.ecommerce.com/products/{pid}/img{j+1}.jpg", j))

cursor.executemany("INSERT INTO product_categories (product_id, category_id) VALUES (%s,%s)", pc_batch)
cursor.executemany("INSERT INTO product_images (product_id, image_url, sort_order) VALUES (%s,%s,%s)", img_batch)
conn.commit()
pc_batch  = []
img_batch = []

for i in range(NUM_PRODUCTS - len(flagship_names)):
    ptype     = random.choice(product_types)
    bidx      = random.randint(0, len(brand_ids)-1)
    brand     = brand_ids[bidx]
    bname     = brand_names_list[bidx]
    model_num = random.randint(100, 9999)
    pname     = f"{bname} {ptype} {model_num}"
    slug      = f"gen-{i}-{ptype.lower().replace(' ','-')}-{model_num}"
    price     = round(random.uniform(199, 99999), 2)
    seller    = random.choice(seller_user_ids)

    cursor.execute("""
        INSERT INTO products
        (seller_id, brand_id, sku, slug, name, base_price, status)
        VALUES (%s,%s,%s,%s,%s,%s,'active')
    """, (seller, brand, f'SKU-{2000+i}', slug, pname, price))
    pid = cursor.lastrowid
    product_ids.append(pid)
    product_to_seller[pid] = seller
    pc_batch.append((pid, random.choice(category_ids)))
    for j in range(random.randint(1,2)):
        img_batch.append((pid, f"https://images.ecommerce.com/products/{pid}/img{j+1}.jpg", j))

    if len(pc_batch) >= BATCH_SIZE:
        cursor.executemany("INSERT INTO product_categories (product_id, category_id) VALUES (%s,%s)", pc_batch)
        cursor.executemany("INSERT INTO product_images (product_id, image_url, sort_order) VALUES (%s,%s,%s)", img_batch)
        conn.commit()
        pc_batch  = []
        img_batch = []
        if (i+1) % 20000 == 0:
            print(f"  Products: {i+1+len(flagship_names):,}")

if pc_batch:
    cursor.executemany("INSERT INTO product_categories (product_id, category_id) VALUES (%s,%s)", pc_batch)
    cursor.executemany("INSERT INTO product_images (product_id, image_url, sort_order) VALUES (%s,%s,%s)", img_batch)
    conn.commit()
print(f"  Done — {len(product_ids):,} products")


# ── 9. INVENTORY ──────────────────────────────────────────
print(f"\n[9/14] Inserting inventory...")
inv_batch = []
mov_batch = []
inv_total = 0
for pid in product_ids:
    wh_sample = random.sample(warehouse_ids, min(3, len(warehouse_ids)))
    for wid in wh_sample:
        qty = random.randint(100, 5000)
        inv_batch.append((pid, wid, qty, random.randint(10,50)))
        mov_batch.append((pid, wid, 'stock_in', qty, 'Initial stock'))

    if len(inv_batch) >= BATCH_SIZE:
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
        inv_total += len(inv_batch)
        inv_batch = []
        mov_batch = []
        if inv_total % 100000 == 0:
            print(f"  Inventory rows: {inv_total:,}")

if inv_batch:
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
    inv_total += len(inv_batch)
print(f"  Done — {inv_total:,} inventory rows + stock movements")


# ── 10. COUPONS ───────────────────────────────────────────
print(f"\n[10/14] Inserting {NUM_COUPONS:,} coupons...")
coup_batch = []
coup_total = 0
for i in range(NUM_COUPONS):
    code  = f"COUP{i+1:06d}{random.randint(10,99)}"
    ctype = random.choice(['flat','percentage'])
    val   = round(random.uniform(10,500),2) if ctype=='percentage' else round(random.uniform(50,2000),2)
    coup_batch.append((
        code, ctype, val,
        random.randint(50, 5000),
        round(random.uniform(100, 2000), 2),
        datetime.now() + timedelta(days=random.randint(30,365))
    ))
    if len(coup_batch) == BATCH_SIZE:
        cursor.executemany("""
            INSERT INTO coupons
            (code, type, discount_value, max_uses, min_order_value, expires_at)
            VALUES (%s,%s,%s,%s,%s,%s)
        """, coup_batch)
        conn.commit()
        coup_total += len(coup_batch)
        coup_batch = []
        if coup_total % 20000 == 0:
            print(f"  Coupons: {coup_total:,}")
if coup_batch:
    cursor.executemany("""
        INSERT INTO coupons
        (code, type, discount_value, max_uses, min_order_value, expires_at)
        VALUES (%s,%s,%s,%s,%s,%s)
    """, coup_batch)
    conn.commit()
    coup_total += len(coup_batch)

cursor.execute("SELECT id FROM coupons")
coupon_ids = [r[0] for r in cursor.fetchall()]
print(f"  Done — {coup_total:,} coupons")


# ── 11. ORDERS ────────────────────────────────────────────
print(f"\n[11/14] Inserting {NUM_ORDERS:,} orders...")
statuses = ['pending','confirmed','shipped','delivered','cancelled']
weights  = [5, 10, 15, 65, 5]
batch    = []
total_orders = 0

for i in range(NUM_ORDERS):
    cid     = random.choice(customer_ids)
    addr    = random.choice(all_address_ids)
    status  = random.choices(statuses, weights=weights)[0]
    total   = round(random.uniform(299, 149999), 2)
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
        if total_orders % 200000 == 0:
            print(f"  Orders: {total_orders:,}")

if batch:
    cursor.executemany("""
        INSERT INTO orders
        (customer_id, shipping_address_id, status,
         total_amount, created_at, delivered_at)
        VALUES (%s,%s,%s,%s,%s,%s)
    """, batch)
    conn.commit()
    total_orders += len(batch)
print(f"  Done — {total_orders:,} orders")


# ── 12. ORDER ITEMS, PAYMENTS, TRANSACTIONS, INVOICES ─────
print("\n[12/14] Order items, payments, transactions, invoices...")
CHUNK = 200000
offset = 0
total_items    = 0
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
        for _ in range(random.randint(1,4)):
            pid    = random.choice(product_ids)
            seller = product_to_seller[pid]
            oi_batch.append((oid, pid, seller, random.randint(1,5),
                             round(random.uniform(299, 49999), 2)))

        pstatus = 'success' if ostatus in ('confirmed','shipped','delivered') else (
                  'failed'  if ostatus == 'cancelled' else 'pending')
        pay_batch.append((oid, random.choice(methods), pstatus,
                          f"TXN{random.randint(100000000,999999999)}"))

    cursor.executemany("""
        INSERT INTO order_items
        (order_id, product_id, seller_id, quantity, unit_price)
        VALUES (%s,%s,%s,%s,%s)
    """, oi_batch)
    total_items += len(oi_batch)

    cursor.executemany("""
        INSERT INTO payments (order_id, method, status, gateway_reference)
        VALUES (%s,%s,%s,%s)
    """, pay_batch)
    total_payments += len(pay_batch)
    conn.commit()

    cursor.execute("""
        SELECT id, order_id, status FROM payments
        ORDER BY id DESC LIMIT %s
    """, (len(pay_batch),))
    pay_rows = cursor.fetchall()

    for pay_id, pay_order_id, pay_status in pay_rows:
        ptx_batch.append((pay_id, 1, pay_status, f"RC{random.randint(100,999)}"))
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
            (order_id, payment_id, invoice_number, tax_amount, total_amount)
            VALUES (%s,%s,%s,%s,%s)
        """, inv_batch)

    conn.commit()
    offset += CHUNK
    print(f"  Chunk done — items: {total_items:,} | payments: {total_payments:,}")

print(f"  Done — {total_items:,} order items | {total_payments:,} payments")


# ── 13. CARTS AND CART ITEMS ──────────────────────────────
print(f"\n[13/14] Inserting {NUM_CARTS:,} carts...")
cart_batch = []
cart_total = 0
for i in range(NUM_CARTS):
    cart_batch.append((random.choice(customer_ids), random_date(2)))
    if len(cart_batch) == BATCH_SIZE:
        cursor.executemany("INSERT INTO cart (user_id, created_at) VALUES (%s,%s)", cart_batch)
        conn.commit()
        cart_total += len(cart_batch)
        cart_batch = []
if cart_batch:
    cursor.executemany("INSERT INTO cart (user_id, created_at) VALUES (%s,%s)", cart_batch)
    conn.commit()
    cart_total += len(cart_batch)

cursor.execute("SELECT id FROM cart ORDER BY id ASC")
cart_ids = [r[0] for r in cursor.fetchall()]

ci_batch = []
ci_total = 0
for cart_id in cart_ids:
    for pid in random.sample(product_ids, min(3, len(product_ids))):
        ci_batch.append((cart_id, pid, random.randint(1,3), random_date(2)))
    if len(ci_batch) >= BATCH_SIZE:
        cursor.executemany("""
            INSERT INTO cart_items (cart_id, product_id, quantity, added_at)
            VALUES (%s,%s,%s,%s)
        """, ci_batch)
        conn.commit()
        ci_total += len(ci_batch)
        ci_batch = []
        if ci_total % 50000 == 0:
            print(f"  Cart items: {ci_total:,}")
if ci_batch:
    cursor.executemany("""
        INSERT INTO cart_items (cart_id, product_id, quantity, added_at)
        VALUES (%s,%s,%s,%s)
    """, ci_batch)
    conn.commit()
    ci_total += len(ci_batch)
print(f"  Done — {cart_total:,} carts | {ci_total:,} cart items")


# ── 14. REVIEWS, RATINGS, RETURNS, REFUNDS, COUPON USAGE ──
print(f"\n[14/14] Reviews, ratings, returns, refunds, coupon usage...")

rev_batch = []
rat_batch = []
rev_total = 0
for _ in range(NUM_REVIEWS):
    pid = random.choice(product_ids)
    cid = random.choice(customer_ids)
    rev_batch.append((pid, cid,
        f"Review {random.randint(1,9999)}",
        f"Good product. {fake.sentence()}",
        True, random.randint(0,500)))
    rat_batch.append((pid, cid, random.randint(1,5), 'approved'))

    if len(rev_batch) == BATCH_SIZE:
        cursor.executemany("""
            INSERT INTO reviews
            (product_id, customer_id, title, body, is_verified_purchase, helpful_votes)
            VALUES (%s,%s,%s,%s,%s,%s)
        """, rev_batch)
        cursor.executemany("""
            INSERT INTO ratings (product_id, customer_id, stars, moderation_status)
            VALUES (%s,%s,%s,%s)
        """, rat_batch)
        conn.commit()
        rev_total += len(rev_batch)
        rev_batch = []
        rat_batch = []
        if rev_total % 20000 == 0:
            print(f"  Reviews/ratings: {rev_total:,}")
if rev_batch:
    cursor.executemany("""
        INSERT INTO reviews
        (product_id, customer_id, title, body, is_verified_purchase, helpful_votes)
        VALUES (%s,%s,%s,%s,%s,%s)
    """, rev_batch)
    cursor.executemany("""
        INSERT INTO ratings (product_id, customer_id, stars, moderation_status)
        VALUES (%s,%s,%s,%s)
    """, rat_batch)
    conn.commit()
    rev_total += len(rev_batch)
print(f"  Reviews and ratings: {rev_total:,} each")

cursor.execute("""
    SELECT oi.id, oi.order_id, p.id
    FROM order_items oi
    JOIN payments p ON p.order_id = oi.order_id
    WHERE p.status = 'success'
    LIMIT %s
""", (NUM_RETURNS,))
return_source_rows = cursor.fetchall()
print(f"  Eligible rows for returns: {len(return_source_rows):,}")

ret_total = 0
ref_total = 0
for start in range(0, len(return_source_rows), BATCH_SIZE):
    chunk = return_source_rows[start:start+BATCH_SIZE]
    ret_batch     = []
    pay_ids_chunk = []
    for oi_id, ord_id, pay_id in chunk:
        ret_batch.append((
            ord_id, oi_id, random.choice(customer_ids),
            random.choice(['damaged','wrong_item','not_needed','quality_issue']),
            random.choice(['unopened','opened','damaged']), True
        ))
        pay_ids_chunk.append(pay_id)

    cursor.executemany("""
        INSERT INTO returns
        (order_id, order_item_id, customer_id, reason_code, item_condition, return_window_valid)
        VALUES (%s,%s,%s,%s,%s,%s)
    """, ret_batch)
    conn.commit()
    ret_total += len(ret_batch)

    cursor.execute("SELECT id FROM returns ORDER BY id DESC LIMIT %s", (len(ret_batch),))
    new_return_ids = [r[0] for r in cursor.fetchall()]
    new_return_ids.reverse()

    ref_batch = []
    for ret_id, pay_id in zip(new_return_ids, pay_ids_chunk):
        ref_batch.append((ret_id, pay_id,
            round(random.uniform(100, 5000), 2),
            random.choice(['original','wallet','bank'])))

    cursor.executemany("""
        INSERT INTO refunds (return_id, payment_id, amount, method)
        VALUES (%s,%s,%s,%s)
    """, ref_batch)
    conn.commit()
    ref_total += len(ref_batch)
    if ret_total % 20000 == 0:
        print(f"  Returns/refunds: {ret_total:,}")
print(f"  Returns: {ret_total:,} | Refunds: {ref_total:,}")

cursor.execute("""
    SELECT id FROM orders WHERE status = 'delivered' LIMIT %s
""", (NUM_COUPON_USAGE,))
delivered_order_ids = [r[0] for r in cursor.fetchall()]

cup_batch = []
cup_total = 0
for oid in delivered_order_ids:
    cup_batch.append((random.choice(coupon_ids), random.choice(customer_ids), oid))
    if len(cup_batch) == BATCH_SIZE:
        cursor.executemany("""
            INSERT INTO coupon_usage (coupon_id, customer_id, order_id)
            VALUES (%s,%s,%s)
        """, cup_batch)
        conn.commit()
        cup_total += len(cup_batch)
        cup_batch = []
        if cup_total % 20000 == 0:
            print(f"  Coupon usage: {cup_total:,}")
if cup_batch:
    cursor.executemany("""
        INSERT INTO coupon_usage (coupon_id, customer_id, order_id)
        VALUES (%s,%s,%s)
    """, cup_batch)
    conn.commit()
    cup_total += len(cup_batch)
print(f"  Coupon usage: {cup_total:,}")


cursor.close()
conn.close()
print("\n" + "="*55)
print("ALL SEED DATA INSERTED SUCCESSFULLY")
print("="*55)
print(f"  Users              : {NUM_USERS + NUM_SELLERS:,}")
print(f"  Addresses          : {addr_total:,}")
print(f"  Customer profiles  : {cp_total:,}")
print(f"  Seller profiles    : {sp_total:,}")
print(f"  Brands             : {br_total:,}")
print(f"  Categories         : {cat_total:,}")
print(f"  Warehouses         : {wh_total:,}")
print(f"  Products           : {len(product_ids):,}")
print(f"  Inventory rows     : {inv_total:,}")
print(f"  Stock movements    : {inv_total:,}")
print(f"  Coupons            : {coup_total:,}")
print(f"  Orders             : {total_orders:,}")
print(f"  Order items        : {total_items:,}")
print(f"  Payments           : {total_payments:,}")
print(f"  Carts              : {cart_total:,}")
print(f"  Cart items         : {ci_total:,}")
print(f"  Reviews            : {rev_total:,}")
print(f"  Ratings            : {rev_total:,}")
print(f"  Returns            : {ret_total:,}")
print(f"  Refunds            : {ref_total:,}")
print(f"  Coupon usage       : {cup_total:,}")
print("="*55)