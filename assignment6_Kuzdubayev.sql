\set ON_ERROR_STOP on
\set ON_ERROR_ROLLBACK off
\set AUTOCOMMIT on
\pset pager off
SET search_path TO public, pg_catalog;

DO $guard$
DECLARE
    object_name TEXT;
BEGIN
    FOREACH object_name IN ARRAY ARRAY[
        'v_order_totals', 'v_uk_customers', 'mv_category_sales', 'orders_big',
        'idx_orders_big_customer', 'idx_orders_big_country_date',
        'idx_orders_big_heavy', 'idx_orders_big_city_lower'
    ] LOOP
        IF to_regclass('public.' || object_name) IS NOT NULL THEN
            RAISE EXCEPTION 'Reserved lab object already exists: %', object_name;
        END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM customers WHERE customer_id IN ('AITU1', 'AITU2'))
       OR EXISTS (SELECT 1 FROM orders WHERE order_id = 11078)
       OR EXISTS (SELECT 1 FROM products WHERE product_id = 999)
       OR EXISTS (SELECT 1 FROM order_details WHERE order_id = 10248 AND product_id = 1)
    THEN
        RAISE EXCEPTION 'Lab identifiers already occupied; use a clean local copy';
    END IF;
    IF (SELECT COUNT(*) FROM products WHERE product_id IN (1, 11, 42)) <> 3
       OR NOT EXISTS (SELECT 1 FROM orders WHERE order_id = 10248)
       OR NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = 'ALFKI')
       OR NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = 'AROUT' AND country = 'UK')
       OR NOT EXISTS (SELECT 1 FROM employees WHERE employee_id = 1)
       OR NOT EXISTS (SELECT 1 FROM shippers WHERE shipper_id = 1)
    THEN
        RAISE EXCEPTION 'Required Northwind rows are missing';
    END IF;
    IF EXISTS (SELECT 1 FROM products WHERE units_in_stock < 0)
       OR EXISTS (SELECT 1 FROM products WHERE product_id = 11 AND (units_in_stock < 5 OR units_in_stock IS NULL))
       OR EXISTS (SELECT 1 FROM products WHERE product_id = 42 AND (units_in_stock < 1 OR units_in_stock > 100 OR units_in_stock IS NULL))
       OR EXISTS (SELECT 1 FROM products WHERE product_id = 1 AND (units_in_stock < 10 OR units_in_stock IS NULL))
    THEN
        RAISE EXCEPTION 'Stock cannot support the prescribed experiments';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM products p JOIN categories c USING (category_id)
        WHERE p.product_id = 1 AND c.category_name = 'Beverages'
    ) THEN
        RAISE EXCEPTION 'Product 1 must belong to Beverages for Task 9';
    END IF;
    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'products'::regclass AND conname = 'chk_units_in_stock'
    ) THEN
        RAISE EXCEPTION 'chk_units_in_stock already exists; do not overwrite it';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'order_details'::regclass
          AND confrelid = 'products'::regclass AND contype = 'f'
          AND NOT condeferrable
    ) THEN
        RAISE EXCEPTION 'Task 12 requires an immediate product foreign key';
    END IF;
END
$guard$;

CREATE TEMP TABLE a6_one_stock ON COMMIT PRESERVE ROWS AS
SELECT product_id, units_in_stock
FROM products
WHERE product_id IN (11, 42);

CREATE TEMP TABLE a6_one_phone ON COMMIT PRESERVE ROWS AS
SELECT customer_id, phone
FROM customers
WHERE customer_id = 'AROUT';

-- Task 1
SELECT 'Customer' AS contact_type, company_name AS organization,
       contact_name AS person, city
FROM customers
WHERE country = 'UK'
UNION ALL
SELECT 'Supplier', company_name, contact_name, city
FROM suppliers
WHERE country = 'UK'
UNION ALL
SELECT 'Employee', 'Northwind Traders', first_name || ' ' || last_name, city
FROM employees
WHERE country = 'UK'
ORDER BY contact_type, city, person;

-- Task 2

SELECT country FROM customers
INTERSECT
SELECT country FROM suppliers
ORDER BY country;

SELECT country FROM customers
EXCEPT
SELECT country FROM suppliers
ORDER BY country;

SELECT city FROM customers
UNION
SELECT city FROM suppliers;

SELECT city FROM customers
UNION ALL
SELECT city FROM suppliers;

SELECT
    (SELECT COUNT(*) FROM (
        SELECT city FROM customers UNION SELECT city FROM suppliers
    ) AS unique_cities) AS rows_2c,
    (SELECT COUNT(*) FROM (
        SELECT city FROM customers UNION ALL SELECT city FROM suppliers
    ) AS all_cities) AS rows_2d;

-- Task 3
SELECT c.customer_id, c.company_name, c.country, c.phone
FROM customers AS c
WHERE c.customer_id IN (
    SELECT customer_id
    FROM orders
    WHERE order_date >= DATE '1997-01-01'
      AND order_date < DATE '1998-01-01'
    EXCEPT
    SELECT customer_id
    FROM orders
    WHERE order_date >= DATE '1998-01-01'
      AND order_date < DATE '1999-01-01'
)
ORDER BY c.company_name;

-- Task 4
SELECT EXTRACT(YEAR FROM order_date) AS order_year,
       EXTRACT(QUARTER FROM order_date) AS order_quarter,
       COUNT(*) AS orders_cnt,
       ROUND(SUM(freight)::NUMERIC, 2) AS total_freight
FROM orders
GROUP BY ROLLUP (EXTRACT(YEAR FROM order_date), EXTRACT(QUARTER FROM order_date))
ORDER BY order_year NULLS LAST, order_quarter NULLS LAST;
SELECT COUNT(*) AS report_rows
FROM (
    SELECT 1
    FROM orders
    GROUP BY ROLLUP (EXTRACT(YEAR FROM order_date), EXTRACT(QUARTER FROM order_date))
) AS report;

-- Task 5
SELECT CASE WHEN GROUPING(c.category_name) = 1 THEN 'All categories'
            ELSE c.category_name END AS category,
       CASE WHEN GROUPING(EXTRACT(YEAR FROM o.order_date)) = 1 THEN 'All years'
            ELSE EXTRACT(YEAR FROM o.order_date)::TEXT END AS order_year,
       ROUND(SUM(od.unit_price::NUMERIC * od.quantity * (1 - od.discount::NUMERIC)), 2) AS revenue
FROM order_details AS od
JOIN orders AS o ON o.order_id = od.order_id
JOIN products AS p ON p.product_id = od.product_id
JOIN categories AS c ON c.category_id = p.category_id
GROUP BY CUBE (c.category_name, EXTRACT(YEAR FROM o.order_date))
ORDER BY GROUPING(c.category_name), c.category_name NULLS LAST,
         GROUPING(EXTRACT(YEAR FROM o.order_date)), EXTRACT(YEAR FROM o.order_date) NULLS LAST;

-- Task 6
SELECT c.category_name, s.country AS supplier_country,
       COUNT(*) AS products_cnt, ROUND(AVG(p.unit_price)::NUMERIC, 2) AS avg_price
FROM products AS p
LEFT JOIN categories AS c ON c.category_id = p.category_id
LEFT JOIN suppliers AS s ON s.supplier_id = p.supplier_id
GROUP BY GROUPING SETS ((c.category_name), (s.country), ())
ORDER BY GROUPING(c.category_name), c.category_name NULLS LAST,
         GROUPING(s.country), s.country NULLS LAST;

-- Task 7

CREATE VIEW v_order_totals AS
SELECT o.order_id, o.customer_id, o.employee_id, o.order_date,
       ROUND(COALESCE(d.line_total, 0), 2) AS order_total
FROM orders AS o
LEFT JOIN (
    SELECT order_id,
           SUM(unit_price::NUMERIC * quantity * (1 - discount::NUMERIC)) AS line_total
    FROM order_details
    GROUP BY order_id
) AS d ON d.order_id = o.order_id;

SELECT c.company_name, COUNT(*) AS orders_1997,
       SUM(v.order_total) AS revenue_1997
FROM v_order_totals AS v
JOIN customers AS c ON c.customer_id = v.customer_id
WHERE v.order_date >= DATE '1997-01-01'
  AND v.order_date < DATE '1998-01-01'
GROUP BY c.customer_id, c.company_name
ORDER BY revenue_1997 DESC, c.customer_id
LIMIT 5;

-- Task 8

CREATE VIEW v_uk_customers AS
SELECT customer_id, company_name, contact_name, city, country, phone
FROM customers
WHERE country = 'UK'
WITH CHECK OPTION;

UPDATE v_uk_customers SET phone = '(171) 555-0000' WHERE customer_id = 'AROUT';
SELECT customer_id, phone FROM customers WHERE customer_id = 'AROUT';

INSERT INTO v_uk_customers (customer_id, company_name, city, country)
VALUES ('AITU1', 'AITU Test Ltd', 'London', 'UK');
\set ON_ERROR_STOP off

INSERT INTO v_uk_customers (customer_id, company_name, city, country)
VALUES ('AITU2', 'AITU Paris', 'Paris', 'France');
\set ON_ERROR_STOP on

\set ON_ERROR_STOP off

UPDATE v_uk_customers SET country = 'Kazakhstan' WHERE customer_id = 'AITU1';
\set ON_ERROR_STOP on
SELECT customer_id, country FROM customers WHERE customer_id IN ('AITU1', 'AITU2');

-- Task 9

CREATE MATERIALIZED VIEW mv_category_sales AS
SELECT c.category_name, COUNT(DISTINCT od.order_id) AS orders_cnt,
       SUM(od.quantity) AS units_sold,
       ROUND(SUM(od.unit_price::NUMERIC * od.quantity * (1 - od.discount::NUMERIC)), 2) AS revenue
FROM categories AS c
JOIN products AS p ON p.category_id = c.category_id
JOIN order_details AS od ON od.product_id = p.product_id
GROUP BY c.category_name;
SELECT * FROM mv_category_sales ORDER BY revenue DESC, category_name;

BEGIN;
INSERT INTO order_details (order_id, product_id, unit_price, quantity, discount)
VALUES (10248, 1, 18, 100, 0);
SELECT 'before refresh' AS observation, units_sold
FROM mv_category_sales WHERE category_name = 'Beverages';
REFRESH MATERIALIZED VIEW mv_category_sales;
SELECT 'after refresh' AS observation, units_sold
FROM mv_category_sales WHERE category_name = 'Beverages';
ROLLBACK;
SELECT 'after rollback' AS observation, units_sold
FROM mv_category_sales WHERE category_name = 'Beverages';

CREATE TABLE orders_big AS
SELECT g.n * 100000 + o.order_id AS order_id,
    o.customer_id, o.employee_id,
    o.order_date + (g.n % 365) AS order_date,
    o.ship_country, o.ship_city, o.freight
FROM orders o
CROSS JOIN generate_series(1, 1000) AS g(n);
ANALYZE orders_big;

-- Task 10

EXPLAIN ANALYZE SELECT * FROM orders_big WHERE customer_id = 'ALFKI';

CREATE INDEX idx_orders_big_customer ON orders_big (customer_id);
EXPLAIN ANALYZE SELECT * FROM orders_big WHERE customer_id = 'ALFKI';

EXPLAIN ANALYZE SELECT * FROM orders_big WHERE customer_id >= 'B';
SELECT COUNT(*) AS all_rows,
       COUNT(*) FILTER (WHERE customer_id >= 'B') AS matching_rows,
       ROUND(100.0 * COUNT(*) FILTER (WHERE customer_id >= 'B') / NULLIF(COUNT(*), 0), 2) AS percent_returned
FROM orders_big;

-- Task 11

EXPLAIN ANALYZE
SELECT * FROM orders_big
WHERE ship_country = 'Germany'
  AND order_date BETWEEN DATE '1997-01-01' AND DATE '1997-01-31';
CREATE INDEX idx_orders_big_country_date ON orders_big (ship_country, order_date);
EXPLAIN ANALYZE
SELECT * FROM orders_big
WHERE ship_country = 'Germany'
  AND order_date BETWEEN DATE '1997-01-01' AND DATE '1997-01-31';
EXPLAIN ANALYZE
SELECT * FROM orders_big
WHERE order_date BETWEEN DATE '1997-01-01' AND DATE '1997-01-31';

EXPLAIN ANALYZE SELECT * FROM orders_big WHERE freight > 500;
CREATE INDEX idx_orders_big_heavy ON orders_big (freight) WHERE freight > 500;
EXPLAIN ANALYZE SELECT * FROM orders_big WHERE freight > 500;

EXPLAIN ANALYZE SELECT * FROM orders_big WHERE LOWER(ship_city) = 'london';
CREATE INDEX idx_orders_big_city_lower ON orders_big (LOWER(ship_city));
ANALYZE orders_big;
EXPLAIN ANALYZE SELECT * FROM orders_big WHERE LOWER(ship_city) = 'london';

SELECT indexname, pg_size_pretty(pg_relation_size(
           format('%I.%I', schemaname, indexname)::REGCLASS)) AS index_size
FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'orders_big'
ORDER BY indexname;
SELECT pg_size_pretty(pg_relation_size('public.orders_big')) AS table_heap_size,
       pg_size_pretty(pg_total_relation_size('public.orders_big')) AS table_with_indexes_size;

-- Task 12

SELECT product_id, units_in_stock FROM products WHERE product_id IN (11, 42) ORDER BY product_id;

BEGIN;
INSERT INTO orders (order_id, customer_id, employee_id, order_date, required_date,
                    ship_via, freight, ship_country)
VALUES (11078, 'ALFKI', 1, DATE '1998-05-07', DATE '1998-06-04', 1, 25.00, 'Germany');
INSERT INTO order_details (order_id, product_id, unit_price, quantity, discount)
VALUES (11078, 11, 21.00, 5, 0);
UPDATE products SET units_in_stock = units_in_stock - 5 WHERE product_id = 11;
\set ON_ERROR_STOP off

INSERT INTO order_details (order_id, product_id, unit_price, quantity, discount)
VALUES (11078, 999, 10.00, 1, 0);

UPDATE products SET units_in_stock = units_in_stock - 1 WHERE product_id = 42;
COMMIT;
\set ON_ERROR_STOP on
SELECT EXISTS (SELECT 1 FROM orders WHERE order_id = 11078) AS order_survived;
SELECT product_id, units_in_stock FROM products WHERE product_id = 11;

DO $check$
BEGIN
    IF EXISTS (SELECT 1 FROM orders WHERE order_id = 11078)
       OR EXISTS (
           SELECT 1 FROM products p JOIN a6_one_stock s USING (product_id)
           WHERE p.units_in_stock IS DISTINCT FROM s.units_in_stock
       ) THEN
        RAISE EXCEPTION 'Task 12b did not roll back as expected; stop and inspect';
    END IF;
END
$check$;

BEGIN;
INSERT INTO orders (order_id, customer_id, employee_id, order_date, required_date,
                    ship_via, freight, ship_country)
VALUES (11078, 'ALFKI', 1, DATE '1998-05-07', DATE '1998-06-04', 1, 25.00, 'Germany');
INSERT INTO order_details (order_id, product_id, unit_price, quantity, discount)
VALUES (11078, 11, 21.00, 5, 0);
UPDATE products SET units_in_stock = units_in_stock - 5 WHERE product_id = 11;
SAVEPOINT before_second_item;
\set ON_ERROR_STOP off

INSERT INTO order_details (order_id, product_id, unit_price, quantity, discount)
VALUES (11078, 999, 10.00, 1, 0);
ROLLBACK TO SAVEPOINT before_second_item;
\set ON_ERROR_STOP on
INSERT INTO order_details (order_id, product_id, unit_price, quantity, discount)
VALUES (11078, 42, 14.00, 1, 0);
UPDATE products SET units_in_stock = units_in_stock - 1 WHERE product_id = 42;
COMMIT;
SELECT * FROM order_details WHERE order_id = 11078 ORDER BY product_id;
SELECT product_id, units_in_stock FROM products WHERE product_id IN (11, 42) ORDER BY product_id;

-- Task 13

ALTER TABLE products ADD CONSTRAINT chk_units_in_stock CHECK (units_in_stock >= 0);
BEGIN;
\set ON_ERROR_STOP off

UPDATE products SET units_in_stock = units_in_stock - 100 WHERE product_id = 42;
ROLLBACK;
\set ON_ERROR_STOP on
SELECT product_id, units_in_stock FROM products WHERE product_id = 42;

BEGIN;
DELETE FROM order_details WHERE order_id = 11078;
DELETE FROM orders WHERE order_id = 11078;
UPDATE products AS p SET units_in_stock = s.units_in_stock
FROM a6_one_stock AS s WHERE s.product_id = p.product_id;
UPDATE customers AS c SET phone = s.phone
FROM a6_one_phone AS s WHERE s.customer_id = c.customer_id;
DELETE FROM customers WHERE customer_id = 'AITU1';
ALTER TABLE products DROP CONSTRAINT chk_units_in_stock;
DROP MATERIALIZED VIEW mv_category_sales;
DROP VIEW v_uk_customers, v_order_totals;
DROP TABLE orders_big;
COMMIT;
DROP TABLE a6_one_stock, a6_one_phone;
