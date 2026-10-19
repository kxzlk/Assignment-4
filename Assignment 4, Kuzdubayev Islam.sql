-- Task 1
SELECT
    e.first_name || ' ' || UPPER(e.last_name) AS full_name,
    e.title AS title,
    LOWER(LEFT(e.first_name, 1) || e.last_name) AS login,
    LENGTH(e.first_name) + LENGTH(e.last_name) AS name_length,
    EXTRACT(YEAR FROM e.hire_date) AS hire_year
FROM employees AS e
ORDER BY e.hire_date;

-- Task 2
SELECT
    o.order_id AS order_id,
    TO_CHAR(o.order_date, 'DD.MM.YYYY') AS order_day,
    o.required_date AS required_date,
    o.shipped_date AS shipped_date,
    o.shipped_date - o.required_date AS days_late
FROM orders AS o
WHERE o.shipped_date > o.required_date
ORDER BY days_late DESC, o.order_id;

-- Task 3
SELECT
    c.category_name AS category_name,
    COUNT(p.product_id) AS products_cnt,
    ROUND(AVG(p.unit_price)::numeric, 2) AS avg_price,
    MIN(p.unit_price) AS min_price,
    MAX(p.unit_price) AS max_price,
    SUM(p.units_in_stock) AS total_stock
FROM categories AS c
JOIN products AS p
    ON p.category_id = c.category_id
GROUP BY c.category_id, c.category_name
HAVING AVG(p.unit_price) > 25
ORDER BY avg_price DESC;

-- Task 4
SELECT
    c.country AS country,
    COUNT(DISTINCT c.customer_id) AS customers_cnt,
    COUNT(o.order_id) AS orders_cnt,
    ROUND(SUM(o.freight)::numeric, 2) AS total_freight
FROM customers AS c
JOIN orders AS o
    ON o.customer_id = c.customer_id
GROUP BY c.country
HAVING COUNT(o.order_id) >= 30
ORDER BY orders_cnt DESC;

-- Task 5
SELECT
    p.product_name AS product_name,
    p.unit_price AS unit_price,
    ROUND(
        (SELECT AVG(p_avg.unit_price) FROM products AS p_avg)::numeric,
        2
    ) AS avg_price
FROM products AS p
WHERE p.unit_price > (
    SELECT AVG(p_avg.unit_price)
    FROM products AS p_avg
)
ORDER BY p.unit_price DESC;

-- Task 6
SELECT
    c.customer_id AS customer_id,
    c.company_name AS company_name,
    c.country AS country
FROM customers AS c
WHERE c.customer_id IN (
    SELECT o.customer_id
    FROM orders AS o
    WHERE o.order_id IN (
        SELECT od.order_id
        FROM order_details AS od
        WHERE od.product_id = (
            SELECT p.product_id
            FROM products AS p
            WHERE p.product_name = 'Chai'
        )
    )
)
ORDER BY c.company_name;

-- Task 7
SELECT
    c.customer_id AS customer_id,
    c.company_name AS company_name,
    c.city AS city,
    c.country AS country
FROM customers AS c
WHERE NOT EXISTS (
    SELECT 1
    FROM orders AS o
    WHERE o.customer_id = c.customer_id
      AND o.order_date >= DATE '1998-01-01'
      AND o.order_date < DATE '1999-01-01'
)
ORDER BY c.country, c.company_name;

-- Task 8
SELECT
    p.product_name AS product_name,
    c.category_name AS category_name,
    p.unit_price AS unit_price,
    ROUND(
        (
            SELECT AVG(p_avg.unit_price)
            FROM products AS p_avg
            WHERE p_avg.category_id = p.category_id
        )::numeric,
        2
    ) AS category_avg
FROM products AS p
JOIN categories AS c
    ON c.category_id = p.category_id
WHERE p.unit_price > (
    SELECT AVG(p_avg.unit_price)
    FROM products AS p_avg
    WHERE p_avg.category_id = p.category_id
)
ORDER BY c.category_name, p.unit_price DESC;

-- Task 9
SELECT
    c.company_name AS company_name,
    COUNT(o.order_id) AS orders_cnt,
    ROUND(AVG(ot.order_total)::numeric, 2) AS avg_order_value,
    ROUND(MAX(ot.order_total)::numeric, 2) AS max_order_value
FROM customers AS c
JOIN orders AS o
    ON o.customer_id = c.customer_id
JOIN (
    SELECT
        od.order_id,
        SUM(od.unit_price * od.quantity * (1 - od.discount)) AS order_total
    FROM order_details AS od
    GROUP BY od.order_id
) AS ot
    ON ot.order_id = o.order_id
GROUP BY c.customer_id, c.company_name
HAVING COUNT(o.order_id) >= 15
ORDER BY avg_order_value DESC;

-- Task 10
SELECT
    e.first_name || ' ' || e.last_name AS employee,
    COUNT(o.order_id) AS orders_1997
FROM employees AS e
JOIN orders AS o
    ON o.employee_id = e.employee_id
WHERE EXTRACT(YEAR FROM o.order_date) = 1997
GROUP BY e.employee_id, e.first_name, e.last_name
HAVING COUNT(o.order_id) > (
    SELECT AVG(ec.orders_cnt)
    FROM (
        SELECT COUNT(o_avg.order_id) AS orders_cnt
        FROM orders AS o_avg
        WHERE EXTRACT(YEAR FROM o_avg.order_date) = 1997
        GROUP BY o_avg.employee_id
    ) AS ec
)
ORDER BY orders_1997 DESC;
