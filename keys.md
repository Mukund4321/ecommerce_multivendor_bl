## Super key
## candidate key
## alternate key
## composite keys 
## foreign key

   ## keys that have more than one attribute its calleed as the composite key then whats the diffrence bewteen super key and composite key
   
   ## refrentional itegrity for foregin key

   Here is every concept explained in pure theory — no code, just clear explanations.

---

**TRIGGERS**

A trigger is a database object that automatically executes a predefined set of actions when a specific event occurs on a table. You never call a trigger manually — it fires on its own in response to an event.

A trigger has three parts. The event which is what causes it to fire such as INSERT, UPDATE, or DELETE. The timing which is either BEFORE the event or AFTER the event. And the action which is the logic that runs when it fires.

BEFORE triggers fire before the actual data change happens. They are useful for validating or modifying data before it is saved. For example a BEFORE INSERT trigger on orders could check if the customer exists before allowing the order to be created.

AFTER triggers fire after the data change is committed. They are useful for cascading effects. For example an AFTER INSERT trigger on order items automatically deducts inventory because the order item has already been safely saved.

FOR EACH ROW means the trigger fires once for every row affected by the operation. If you insert 10 order items at once the trigger fires 10 times — once per row.

The NEW keyword refers to the new values being inserted or updated. In an INSERT trigger NEW.column gives you the value of that column in the new row. In an UPDATE trigger NEW gives the new value and OLD gives the value before the update. In a DELETE trigger only OLD is available because the row is being removed.

Triggers enforce business rules automatically at the database level. This means even if someone inserts data directly into the database without going through the application the trigger still fires and the rules are still enforced.

The main triggers in your project are — inventory deduction when an order item is inserted, inventory restoration when a return is created, inventory restoration when an order is cancelled, average rating recalculation when a rating is inserted, invoice generation when a successful payment is inserted, and low stock alert when inventory falls below threshold.

---

**VIEWS**

A view is a virtual table based on a saved SELECT query. It does not store any data itself. Every time you query a view MySQL runs the underlying SELECT query and returns the result as if it were a real table.

A view is created using CREATE VIEW followed by a SELECT statement. Once created you can query it exactly like a table using SELECT from viewname. You can also filter a view using WHERE, sort it using ORDER BY, and join it with other tables just like a regular table.

Views serve three main purposes. First they simplify complexity. A query that joins five tables with complex calculations can be saved as a view. Instead of writing that complex query every time you just write SELECT from the view name. Second they provide security. You can give a user access to a view without giving them access to the underlying tables. The analyst can see revenue data through a view without being able to see sensitive customer data in the actual tables. Third they ensure consistency. Everyone querying the same view always gets data calculated the same way using the same logic.

A simple view always reflects the current state of the underlying tables. If new orders are inserted into the orders table and you query the monthly revenue view it will include those new orders automatically because the view reruns its query every time.

The five views in your project are the seller dashboard view which shows each seller's total revenue, order count, average rating, and best selling product. The monthly revenue view which shows revenue broken down by seller and month. The low stock view which shows all products whose inventory has fallen below the reorder threshold. The customer order history view which shows every order per customer along with payment status and return status. And the abandoned cart view which shows carts that have been inactive for more than 24 hours along with their total value representing potential lost revenue.

---

**INDEXES**

An index is a separate data structure that MySQL maintains alongside a table to make data retrieval faster. Without an index MySQL performs a full table scan meaning it reads every single row from top to bottom to find the rows that match your query condition. With an index MySQL can jump directly to the matching rows without reading every row.

Think of an index like the index at the back of a textbook. Without it you would read every page to find mentions of a topic. With the index you go directly to the right page numbers. The textbook content has not changed — the index is just a separate navigation aid.

A B-Tree index is the default and most common type in MySQL. It organises values in a balanced tree structure where each node contains a sorted range of values and pointers to child nodes. A search in a B-Tree takes logarithmic time. On a table with one crore rows a full scan checks one crore rows. A B-Tree index finds the same result in about 23 steps because each step halves the remaining search space.

Indexes speed up SELECT queries with WHERE conditions, JOIN conditions, and ORDER BY clauses. However indexes slow down INSERT, UPDATE, and DELETE operations slightly because MySQL has to update the index every time data changes. This is the fundamental tradeoff of indexing — faster reads at the cost of slightly slower writes.

A composite index covers multiple columns together. The index on orders with customer_id and created_at means queries that filter by customer and sort by date use only the index without touching the actual table data. The order of columns in a composite index matters. MySQL can use the index for queries that filter on the first column, or the first and second column together, but not the second column alone.

A covering index is one where the index contains all the columns the query needs. When MySQL can answer a query entirely from the index without reading the actual table rows it is called an index only scan. This is the fastest possible type of query execution because it avoids touching the main table entirely.

The EXPLAIN command shows you the query execution plan. It tells you which index MySQL plans to use, how many rows it estimates it will scan, and what type of scan it will perform. A full table scan shows as ALL in the type column which is the slowest. An index scan shows as ref or range which is fast. A covering index scan shows as index which is very fast.

EXPLAIN ANALYZE actually executes the query and shows real timing numbers alongside the estimated plan. Comparing EXPLAIN output before and after adding indexes proves that the index improved performance by reducing the number of rows examined and switching from a full table scan to an index scan.

Partitioning is a related performance technique. It splits one large table into smaller physical sections called partitions based on a column value. When you query with a condition on the partition column MySQL skips entire partitions that cannot contain matching rows. This is called partition pruning. In your project orders are partitioned by year so a query for 2025 orders only scans the 2025 partition instead of all one crore rows.

---

**STORED PROCEDURES**

A stored procedure is a named, saved block of SQL code that can accept input parameters, execute complex logic, and return output parameters. You call a procedure by name using the CALL statement and pass values to it.

Stored procedures exist at the database level. They are compiled and stored in the database server. This means they run faster than sending raw SQL from an application because MySQL does not need to parse and compile them every time they run.

Procedures support programming constructs that regular SQL does not. They support variables to store temporary values during execution. They support IF ELSE logic to make decisions. They support loops to repeat operations. They support error handling to respond to failures gracefully.

The DECLARE statement creates a local variable inside a procedure. Variables exist only for the duration of the procedure call and are destroyed when the procedure ends. Input parameters use the IN keyword — values passed in from the caller. Output parameters use the OUT keyword — values the procedure sets and returns to the caller.

The most important feature of stored procedures in your project is transaction management. A transaction groups multiple SQL statements into one atomic unit. START TRANSACTION begins the transaction. COMMIT makes all changes permanent. ROLLBACK undoes all changes back to the state before the transaction started.

The DECLARE EXIT HANDLER FOR SQLEXCEPTION is the error handling mechanism. If any SQL statement inside the procedure raises an error the handler catches it, executes ROLLBACK to undo everything, and sets an error message in the output parameter. This guarantees that the database never ends up in a half-completed state. Either everything succeeds and commits or everything fails and rolls back.

SELECT FOR UPDATE is a locking mechanism used inside transactions. When a procedure reads an inventory row with SELECT FOR UPDATE MySQL places an exclusive lock on that row. No other transaction can read or modify that row until the current transaction commits or rolls back. This prevents the race condition where two customers simultaneously buy the last item in stock and both see available inventory before either deducts it.

The eight procedures in your project are place_order which handles the complete checkout flow in one transaction, cancel_order which reverses everything within a 24 hour window, refund_payment which validates and processes refunds, update_inventory which adjusts stock levels safely, apply_coupon which validates all coupon rules before applying a discount, mark_order_delivered which updates status and generates an invoice, process_return which handles the full return and refund flow in one transaction, and the rollback demonstration which proves that failed transactions leave no trace in the database.

---

**FUNCTIONS**

There are two categories of functions in MySQL — built-in functions that MySQL provides and custom functions that you create yourself.

Built-in functions are categorised by what they operate on.

String functions operate on text values. UPPER converts text to uppercase. LOWER converts to lowercase. LENGTH returns the number of characters. CONCAT joins multiple strings together. SUBSTRING extracts part of a string starting at a given position. REPLACE substitutes one substring with another. TRIM removes leading and trailing spaces. These are useful for formatting output, searching text, and cleaning data.

Date and time functions work with temporal values. NOW returns the current date and time. CURDATE returns only the current date. DATE extracts the date portion from a timestamp. DATE_FORMAT formats a date into a custom string pattern such as showing April 2026 instead of 2026-04-01. DATEDIFF calculates the number of days between two dates. DATE_ADD and DATE_SUB add or subtract time intervals from a date. YEAR, MONTH, and DAY extract individual components from a date. TIMESTAMPDIFF calculates the difference between two timestamps in a specified unit such as hours, days, or months.

Numeric functions perform mathematical operations. ROUND rounds a decimal to a specified number of places. CEIL rounds up to the nearest integer. FLOOR rounds down to the nearest integer. ABS returns the absolute value removing any negative sign. MOD returns the remainder after division. RAND generates a random decimal between zero and one.

Aggregate functions collapse multiple rows into a single value. COUNT counts the number of rows. SUM adds all values in a column. AVG calculates the mean. MIN returns the smallest value. MAX returns the largest value. These are always used with GROUP BY when you want results broken down by category.

NULL handling functions deal with missing values. IFNULL returns a replacement value if the expression is NULL. NULLIF returns NULL if two values are equal, otherwise returns the first value. COALESCE returns the first non-null value from a list of expressions. These prevent NULL values from breaking calculations or causing unexpected results.

CAST and CONVERT change a value from one data type to another. CAST as UNSIGNED converts a decimal to an integer. CAST as DATE extracts the date from a timestamp. CAST as CHAR converts a number to text. This is important when comparing values of different types or when you need to format output in a specific way.

A custom function is one you create yourself using CREATE FUNCTION. Unlike a stored procedure a function must return exactly one value and cannot use transactions or modify data. Functions are meant for calculations and transformations. For example a calculate_tax function takes an amount and returns 18 percent of it as the tax value. A get_discount function takes an amount and a percentage and returns the discount value. Custom functions can be used directly inside SELECT statements just like built-in functions which makes queries much more readable.

---

**WINDOW FUNCTIONS**

Window functions perform calculations across a set of rows related to the current row without collapsing them into a single result like aggregate functions do. The key concept is that every row in the result is preserved — you get the original row data plus the calculated window value added as a new column.

Every window function uses the OVER clause. Inside OVER you can specify PARTITION BY to divide rows into groups and ORDER BY to define the order within each group. The window function then performs its calculation within each partition independently.

PARTITION BY divides all rows into separate groups called partitions. The window function resets and recalculates for each partition. For example partitioning by seller_id means the ranking resets for each seller — each seller's products are ranked among themselves not against all products globally.

ORDER BY inside OVER determines the order in which rows are processed within each partition. For ranking functions it determines who gets rank 1. For LAG and LEAD it determines which row is considered previous or next.

RANK assigns a rank number based on ORDER BY. When two rows have the same value they get the same rank and the next rank is skipped. So if two products tie for rank 1 the next product gets rank 3 not rank 2.

DENSE_RANK works exactly like RANK but does not skip numbers after a tie. If two products tie for rank 1 the next product gets rank 2.

ROW_NUMBER assigns a unique sequential number to every row regardless of ties. Even if two rows have identical values they still get different row numbers. This is useful for deduplication — you can number duplicate rows and keep only row number 1.

LAG accesses the value from a previous row within the partition. LAG with no offset gets the immediately previous row. This is how you calculate month over month change — you get this month's revenue and the previous month's revenue in the same row then subtract them.

LEAD accesses the value from a following row within the partition. This is how you find the next order date for a customer — you get the current order date and the next order date in the same row then calculate the days between them.

SUM OVER with ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW calculates a running total. For each row it adds all values from the first row up to and including the current row. This gives you a cumulative total that grows with each new row.

AVG OVER with ROWS BETWEEN 6 PRECEDING AND CURRENT ROW calculates a rolling average. For each row it averages the current row and the 6 rows before it. This smooths out daily fluctuations to show the trend over a 7 day window.

NTILE divides all rows into a specified number of equal buckets. NTILE of 4 creates four quartiles. Each row is assigned a bucket number from 1 to 4 based on its position in the ordered result. This is used to classify products or customers into performance tiers.

PERCENT_RANK calculates the relative rank of a row as a percentage between 0 and 1. A seller at PERCENT_RANK of 1 is at the very top. A seller at 0.5 is exactly in the middle. Multiplying by 100 gives you a percentile score.

MIN and MAX can also be used as window functions. Unlike the aggregate versions they do not collapse rows. They add the minimum or maximum value across the partition as a new column alongside each existing row. This lets you compare each row to the group minimum or maximum in the same query.

---

**CTEs — COMMON TABLE EXPRESSIONS**

A CTE is a temporary named result set that you define at the beginning of a query using the WITH keyword. The CTE exists only for the duration of that single query. It cannot be used in other queries and it disappears after the query finishes.

The purpose of CTEs is to make complex queries readable and maintainable by breaking them into named steps. Instead of nesting subqueries inside subqueries which becomes unreadable you give each step a meaningful name and refer to it by that name. Anyone reading the query can understand each step independently before understanding how they connect.

Multiple CTEs can be chained together in a single query. Each CTE can reference CTEs defined before it. You write them one after another separated by commas all before the final main query. The first CTE calculates raw revenue. The second CTE calculates the average. The main query then compares each seller to that average.

A recursive CTE is a special type that references itself. It has two parts separated by UNION ALL. The anchor part is the starting point that runs once and produces the initial rows. The recursive part references the CTE name itself and runs repeatedly, each time taking the output of the previous iteration as its input. MySQL keeps running the recursive part until it produces no new rows.

Recursive CTEs are ideal for hierarchical data where the depth is unknown. In your project the categories table is self-referencing — a category can have a parent category which can also have a parent. The recursive CTE starts with root categories that have no parent, then adds their children, then adds those children's children, building the full path string as it goes. The result shows the complete path from root to leaf for every category in the hierarchy.

---

**JOINS**

A join combines rows from two or more tables based on a related column. Joins are fundamental to relational databases because data is intentionally spread across multiple normalised tables and joins are how you reassemble it into meaningful results.

INNER JOIN returns only rows where there is a matching row in both tables. If a product has no brand it will not appear in an INNER JOIN between products and brands. If an order has no matching payment it will not appear in an INNER JOIN between orders and payments. INNER JOIN is the strictest join — it requires both sides to have a match.

LEFT JOIN returns all rows from the left table regardless of whether there is a match in the right table. Where there is no match the right side columns show NULL. This is how you find customers who have never placed an order — all customers come from the left, and the ones with NULL on the orders side never ordered anything. The NULL acts as a filter to identify the absent relationship.

RIGHT JOIN is the mirror image of LEFT JOIN. All rows from the right table are returned regardless of whether there is a match in the left table. It is rarely used in practice because any RIGHT JOIN can be rewritten as a LEFT JOIN by swapping the table order.

FULL OUTER JOIN returns all rows from both tables. Where there is no match on either side NULL fills the missing columns. MySQL does not support FULL OUTER JOIN directly — you achieve the same result by combining a LEFT JOIN and a RIGHT JOIN using UNION.

A self join joins a table to itself. This is used for hierarchical or comparative data within the same table. In your project the categories table references itself through parent_id. A self join connects each category to its parent category which is also in the same table.

A cross join returns every possible combination of rows from both tables. If table A has 5 rows and table B has 3 rows the cross join produces 15 rows. This is rarely intentional but is useful for generating combinations or comparing every row against a single aggregate value such as comparing each seller's revenue to the overall average.

---

**TRANSACTIONS AND ACID**

A transaction is a sequence of SQL operations treated as a single indivisible unit of work. Either all operations in the transaction succeed and are permanently saved or all operations fail and are completely undone.

ACID is the set of four properties that guarantee transactions are processed reliably.

Atomicity means the transaction is all or nothing. If you are placing an order and the payment insert fails, atomicity ensures the order insert, the order items insert, and the inventory deduction are all undone. The database returns to exactly the state it was in before the transaction started. There is no partial completion.

Consistency means the database always moves from one valid state to another valid state. All constraints, foreign keys, and rules are enforced. You can never end up with an order pointing to a customer that does not exist or inventory going negative.

Isolation means concurrent transactions do not interfere with each other. Each transaction operates as if it is the only one running. The SELECT FOR UPDATE lock in your place_order procedure enforces isolation — when one customer is in the middle of buying the last item, the inventory row is locked and another customer's transaction must wait until the first one finishes before it can read the stock level.

Durability means once a transaction is committed it is permanently saved. Even if the server crashes immediately after COMMIT the data is safe because MySQL writes committed data to disk before confirming success.

---

**NORMALIZATION**

Normalization is the process of organizing a database to reduce data redundancy and improve data integrity. It involves decomposing tables so that each table contains data about only one thing and relationships between things are expressed through foreign keys.

First Normal Form requires that every column contains atomic values — no lists or arrays in a single column, and each row is uniquely identifiable.

Second Normal Form requires that every non-key column depends on the entire primary key, not just part of it. This mainly applies to composite keys.

Third Normal Form requires that every non-key column depends only on the primary key and not on other non-key columns. This eliminates transitive dependencies.

In your project you never store the seller's business name inside the orders table. You store the seller_id which points to users which points to seller_profiles. If a seller changes their business name you update it in one place and every query automatically gets the updated name. Without normalization you would store the business name in every order row and updating it would require changing millions of rows with risk of inconsistency.

---

**DDL DML DCL**

DDL stands for Data Definition Language. These commands define and modify the structure of the database itself. CREATE TABLE builds a new table. ALTER TABLE changes an existing table by adding, dropping, or modifying columns. DROP TABLE permanently deletes a table. TRUNCATE removes all rows while keeping the structure. These commands affect the schema not the data.

DML stands for Data Manipulation Language. These commands work with the data inside tables. SELECT retrieves rows. INSERT adds new rows. UPDATE modifies existing rows. DELETE removes specific rows. INSERT INTO SELECT copies data from one table into another. These commands affect the data not the structure.

DCL stands for Data Control Language. These commands manage access and permissions. GRANT gives a user permission to perform specific operations on specific database objects. REVOKE removes a previously granted permission. CREATE USER creates a new database user account. These commands affect security and access control.

---

**CONSTRAINTS**

Constraints are rules defined at the table level that MySQL enforces automatically on every INSERT and UPDATE operation.

PRIMARY KEY is the most fundamental constraint. It enforces uniqueness and non-null across the designated column. Every table must have exactly one primary key. It is the official identifier for each row.

FOREIGN KEY enforces referential integrity. It ensures that a value in one table always corresponds to an existing value in another table. MySQL will reject any INSERT or UPDATE that would create an orphaned reference — an order pointing to a customer that does not exist.

NOT NULL prevents a column from ever containing a null value. Critical fields like email and password use this constraint to ensure they always have values.

UNIQUE ensures no two rows can have the same value in a column while still allowing the column to be NULL. Unlike primary key a table can have multiple unique constraints.

DEFAULT automatically fills in a value if none is provided during INSERT. The created_at column uses DEFAULT CURRENT_TIMESTAMP so the timestamp is automatically recorded without the application needing to send it.

CHECK validates that a value meets a specific condition before it is saved. The stars column in ratings uses CHECK stars BETWEEN 1 AND 5 so it is impossible to insert a rating of 0 or 6.