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

BATCH_SIZE       = 5000
NUM_REVIEWS      = 0
NUM_RETURNS      = 100000
NUM_CARTS        = 100000
NUM_COUPON_USAGE = 100000

def random_date(start_months_ago=6):
    start = datetime.now() - timedelta(days=start_months_ago * 30)
    return fake.date_time_between(start_date=start, end_date='now')


# ── fetch existing ids needed ──────────────────────────────
print("\nFetching existing ids from database...")

cursor.execute("SELECT id FROM users WHERE role = 'customer'")
customer_ids = [r[0] for r in cursor.fetchall()]
print(f"  Customers: {len(customer_ids):,}")

cursor.execute("SELECT id FROM products")
product_ids = [r[0] for r in cursor.fetchall()]
print(f"  Products: {len(product_ids):,}")

cursor.execute("SELECT id FROM coupons")
coupon_ids = [r[0] for r in cursor.fetchall()]
print(f"  Coupons: {len(coupon_ids):,}")


# ── REVIEWS AND RATINGS ────────────────────────────────────
print(f"\n[1/4] Inserting {NUM_REVIEWS:,} reviews and ratings...")
rev_batch = []
rat_batch = []
rev_total = 0

for _ in range(NUM_REVIEWS):
    pid = random.choice(product_ids)
    cid = random.choice(customer_ids)
    rev_batch.append((
        pid, cid,
        f"Review {random.randint(1,9999)}",
        f"Good product. {fake.sentence()}",
        True,
        random.randint(0, 500)
    ))
    rat_batch.append((pid, cid, random.randint(1,5), 'approved'))

    if len(rev_batch) == BATCH_SIZE:
        cursor.executemany("""
            INSERT INTO reviews
            (product_id, customer_id, title, body, is_verified_purchase, helpful_votes)
            VALUES (%s,%s,%s,%s,%s,%s)
        """, rev_batch)
        cursor.executemany("""
            INSERT INTO ratings
            (product_id, customer_id, stars, moderation_status)
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
        INSERT INTO ratings
        (product_id, customer_id, stars, moderation_status)
        VALUES (%s,%s,%s,%s)
    """, rat_batch)
    conn.commit()
    rev_total += len(rev_batch)

print(f"  Done — {rev_total:,} reviews and ratings each")


# ── CARTS AND CART ITEMS ───────────────────────────────────
print(f"\n[2/4] Inserting {NUM_CARTS:,} carts and cart items...")
cart_batch = []
cart_total = 0

for i in range(NUM_CARTS):
    cart_batch.append((random.choice(customer_ids), random_date(2)))
    if len(cart_batch) == BATCH_SIZE:
        cursor.executemany("""
            INSERT INTO cart (user_id, created_at) VALUES (%s,%s)
        """, cart_batch)
        conn.commit()
        cart_total += len(cart_batch)
        cart_batch = []
        if cart_total % 20000 == 0:
            print(f"  Carts: {cart_total:,}")

if cart_batch:
    cursor.executemany("""
        INSERT INTO cart (user_id, created_at) VALUES (%s,%s)
    """, cart_batch)
    conn.commit()
    cart_total += len(cart_batch)

cursor.execute("SELECT id FROM cart ORDER BY id ASC")
cart_ids = [r[0] for r in cursor.fetchall()]
print(f"  Carts inserted: {cart_total:,}")

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


# ── RETURNS AND REFUNDS ────────────────────────────────────
print(f"\n[3/4] Inserting {NUM_RETURNS:,} returns and refunds...")

# pull a small pre-existing set of order_items and matching payment ids
# using order_items_small to avoid timeout on 25 million row table
print("  Fetching eligible order items from order_items_small...")
cursor.execute("""
    SELECT oi.id, oi.order_id, p.id AS payment_id
    FROM order_items_small oi
    INNER JOIN payments p ON p.order_id = oi.order_id
    WHERE p.status = 'success'
    LIMIT %s
""", (NUM_RETURNS,))
return_source_rows = cursor.fetchall()
print(f"  Eligible rows found: {len(return_source_rows):,}")

# if order_items_small doesn't have enough rows fall back to order_items
if len(return_source_rows) < NUM_RETURNS:
    print("  Not enough in order_items_small — fetching from order_items...")
    cursor.execute("""
        SELECT oi.id, oi.order_id, p.id AS payment_id
        FROM order_items oi
        INNER JOIN payments p ON p.order_id = oi.order_id
        WHERE p.status = 'success'
        LIMIT %s
    """, (NUM_RETURNS,))
    return_source_rows = cursor.fetchall()
    print(f"  Eligible rows found: {len(return_source_rows):,}")

ret_total = 0
ref_total = 0

for start in range(0, len(return_source_rows), BATCH_SIZE):
    chunk         = return_source_rows[start:start+BATCH_SIZE]
    ret_batch     = []
    pay_ids_chunk = []

    for oi_id, ord_id, pay_id in chunk:
        ret_batch.append((
            ord_id, oi_id,
            random.choice(customer_ids),
            random.choice(['damaged','wrong_item','not_needed','quality_issue']),
            random.choice(['unopened','opened','damaged']),
            True
        ))
        pay_ids_chunk.append(pay_id)

    cursor.executemany("""
        INSERT INTO returns
        (order_id, order_item_id, customer_id,
         reason_code, item_condition, return_window_valid)
        VALUES (%s,%s,%s,%s,%s,%s)
    """, ret_batch)
    conn.commit()
    ret_total += len(ret_batch)

    cursor.execute("""
        SELECT id FROM returns ORDER BY id DESC LIMIT %s
    """, (len(ret_batch),))
    new_return_ids = [r[0] for r in cursor.fetchall()]
    new_return_ids.reverse()

    ref_batch = []
    for ret_id, pay_id in zip(new_return_ids, pay_ids_chunk):
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
    ref_total += len(ref_batch)

    if ret_total % 20000 == 0:
        print(f"  Returns/refunds: {ret_total:,}")

print(f"  Done — {ret_total:,} returns | {ref_total:,} refunds")


# ── COUPON USAGE ───────────────────────────────────────────
print(f"\n[4/4] Inserting {NUM_COUPON_USAGE:,} coupon usage records...")
cursor.execute("""
    SELECT id FROM orders
    WHERE status = 'delivered'
    LIMIT %s
""", (NUM_COUPON_USAGE,))
delivered_order_ids = [r[0] for r in cursor.fetchall()]
print(f"  Delivered orders found: {len(delivered_order_ids):,}")

cup_batch = []
cup_total = 0
for oid in delivered_order_ids:
    cup_batch.append((
        random.choice(coupon_ids),
        random.choice(customer_ids),
        oid
    ))
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

print(f"  Done — {cup_total:,} coupon usage records")


cursor.close()
conn.close()
print("\n" + "="*55)
print("REMAINING TABLES SEEDED SUCCESSFULLY")
print("="*55)
print(f"  Reviews       : {rev_total:,}")
print(f"  Ratings       : {rev_total:,}")
print(f"  Carts         : {cart_total:,}")
print(f"  Cart items    : {ci_total:,}")
print(f"  Returns       : {ret_total:,}")
print(f"  Refunds       : {ref_total:,}")
print(f"  Coupon usage  : {cup_total:,}")
print("="*55)