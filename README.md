# Multi-Vendor E-Commerce Analytics & Inventory Management System

## Project Structure

ecommerce/
├── scripts/
│   ├── 01_create_tables.sql     — All 25 tables with constraints and foreign keys
│   ├── 02_indexes.sql           — B-Tree, composite, covering indexes + EXPLAIN reports
│   └── 03_extras.sql            — DCL, CAST, copy command, custom functions
├── views/
│   └── views.sql                — 5 views: seller dashboard, monthly revenue, low stock, order history, abandoned cart
├── stored_procedures/
│   └── procedures.sql           — 8 procedures: place_order, cancel_order, refund_payment, update_inventory, apply_coupon, mark_order_delivered, process_return, rollback demo
├── triggers/
│   └── triggers.sql             — 6 triggers: inventory deduction, restore on return, restore on cancel, avg rating, invoice generation, low stock alert
├── queries/
│   ├── task2_joins_ctes.sql     — 20 queries: joins, subqueries, CTEs, recursive CTE
│   └── task3_window_functions.sql — 20 queries: RANK, DENSE_RANK, ROW_NUMBER, LAG, LEAD, NTILE, PERCENT_RANK, running totals, rolling averages
└── erd/
    └── erd_notes.md             — All table relationships and cardinalities

## How to Run

1. Open MySQL Workbench and connect to your local MySQL instance
2. Create the database: CREATE DATABASE ecommerce; USE ecommerce;
3. Run scripts/01_create_tables.sql — creates all 25 tables
4. Run your seed_data.py to populate data
5. Run queries/task2_joins_ctes.sql — one query at a time
6. Run queries/task3_window_functions.sql — uses orders_small and order_items_small
7. Run stored_procedures/procedures.sql — one procedure block at a time using DELIMITER $$
8. Run triggers/triggers.sql — one trigger block at a time
9. Run views/views.sql — creates helper tables first then all 5 views
10. Run scripts/02_indexes.sql — indexes and EXPLAIN reports
11. Run scripts/03_extras.sql — DCL, CAST, custom functions

## Database — MySQL 8.0.46
## Tables — 25 across 8 modules
## Total queries and scripts — 68 items
