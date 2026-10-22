-- Task 1
SELECT
    c.category_name AS category_name,
    p.product_name AS product_name,
    p.unit_price AS unit_price,
    ROW_NUMBER() OVER (
        PARTITION BY p.category_id
        ORDER BY p.unit_price DESC, p.product_name
    ) AS price_position
FROM products AS p
JOIN categories AS c
    ON c.category_id = p.category_id
ORDER BY category_name, price_position;

-- Task 2
SELECT
    ranked.product_name AS product_name,
    ranked.unit_price AS unit_price,
    ranked.price_rank AS price_rank,
    ranked.price_dense_rank AS price_dense_rank
FROM (
    SELECT
        p.product_name,
        p.unit_price,
        RANK() OVER (ORDER BY p.unit_price DESC) AS price_rank,
        DENSE_RANK() OVER (ORDER BY p.unit_price DESC) AS price_dense_rank
    FROM products AS p
) AS ranked
WHERE ranked.price_dense_rank <= 15
ORDER BY price_rank, product_name;

-- Task 3
SELECT
    ranked.category_name AS category_name,
    ranked.product_name AS product_name,
    ranked.units_sold AS units_sold,
    ranked.position AS position
FROM (
    SELECT
        c.category_name,
        p.product_name,
        SUM(od.quantity) AS units_sold,
        ROW_NUMBER() OVER (
            PARTITION BY p.category_id
            ORDER BY SUM(od.quantity) DESC, p.product_name
        ) AS position
    FROM products AS p
    JOIN categories AS c
        ON c.category_id = p.category_id
    JOIN order_details AS od
        ON od.product_id = p.product_id
    GROUP BY
        p.category_id,
        c.category_name,
        p.product_id,
        p.product_name
) AS ranked
WHERE ranked.position <= 3
ORDER BY category_name, position;

-- Task 4
SELECT
    p.product_name AS product_name,
    c.category_name AS category_name,
    p.unit_price AS unit_price,
    COUNT(*) OVER (
        PARTITION BY p.category_id
    ) AS products_in_category,
    ROUND(
        AVG(p.unit_price) OVER (
            PARTITION BY p.category_id
        )::numeric,
        2
    ) AS category_avg,
    ROUND(
        (
            p.unit_price
            - AVG(p.unit_price) OVER (
                PARTITION BY p.category_id
            )
        )::numeric,
        2
    ) AS diff_from_avg
FROM products AS p
JOIN categories AS c
    ON c.category_id = p.category_id
ORDER BY category_name, diff_from_avg DESC;

-- Task 5
SELECT
    TO_CHAR(DATE_TRUNC('month', o.order_date), 'YYYY-MM') AS month,
    ROUND(
        SUM(od.unit_price * od.quantity * (1 - od.discount))::numeric,
        2
    ) AS revenue,
    ROUND(
        SUM(
            SUM(od.unit_price * od.quantity * (1 - od.discount))
        ) OVER (
            ORDER BY DATE_TRUNC('month', o.order_date)
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )::numeric,
        2
    ) AS running_total
FROM orders AS o
JOIN order_details AS od
    ON od.order_id = o.order_id
WHERE o.order_date >= DATE '1997-01-01'
  AND o.order_date < DATE '1998-01-01'
GROUP BY DATE_TRUNC('month', o.order_date)
ORDER BY month;

-- Task 6
SELECT
    e.first_name || ' ' || e.last_name AS employee,
    ROUND(
        SUM(od.unit_price * od.quantity * (1 - od.discount))::numeric,
        2
    ) AS revenue_1997,
    ROUND(
        (
            100 * SUM(od.unit_price * od.quantity * (1 - od.discount))
            / SUM(
                SUM(od.unit_price * od.quantity * (1 - od.discount))
            ) OVER ()
        )::numeric,
        1
    ) AS share_pct,
    RANK() OVER (
        ORDER BY SUM(
            od.unit_price * od.quantity * (1 - od.discount)
        ) DESC
    ) AS revenue_rank
FROM employees AS e
JOIN orders AS o
    ON o.employee_id = e.employee_id
JOIN order_details AS od
    ON od.order_id = o.order_id
WHERE o.order_date >= DATE '1997-01-01'
  AND o.order_date < DATE '1998-01-01'
GROUP BY e.employee_id, e.first_name, e.last_name
ORDER BY revenue_rank;

-- Task 7
SELECT
    TO_CHAR(DATE_TRUNC('month', o.order_date), 'YYYY-MM') AS month,
    COUNT(*) AS orders_cnt,
    LAG(COUNT(*)) OVER (
        ORDER BY DATE_TRUNC('month', o.order_date)
    ) AS prev_orders,
    COUNT(*) - LAG(COUNT(*)) OVER (
        ORDER BY DATE_TRUNC('month', o.order_date)
    ) AS change
FROM orders AS o
WHERE o.order_date >= DATE '1997-01-01'
  AND o.order_date < DATE '1998-01-01'
GROUP BY DATE_TRUNC('month', o.order_date)
ORDER BY month;

-- Task 8
SELECT
    c.company_name AS company_name,
    o.order_id AS order_id,
    o.order_date AS order_date,
    ROW_NUMBER() OVER (
        PARTITION BY o.customer_id
        ORDER BY o.order_date, o.order_id
    ) AS order_number,
    o.order_date - LAG(o.order_date) OVER (
        PARTITION BY o.customer_id
        ORDER BY o.order_date, o.order_id
    ) AS days_since_prev
FROM customers AS c
JOIN orders AS o
    ON o.customer_id = c.customer_id
WHERE c.country = 'Mexico'
ORDER BY company_name, order_number;

-- Task 9

SELECT
    TO_CHAR(monthly.month_start, 'YYYY-MM') AS month,
    ROUND(monthly.revenue::numeric, 2) AS revenue,
    ROUND(
        AVG(monthly.revenue) OVER (
            ORDER BY monthly.month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        )::numeric,
        2
    ) AS moving_avg_3m
FROM (
    SELECT
        DATE_TRUNC('month', o.order_date)::date AS month_start,
        SUM(
            od.unit_price * od.quantity * (1 - od.discount)
        ) AS revenue
    FROM orders AS o
    JOIN order_details AS od
        ON od.order_id = o.order_id
    GROUP BY DATE_TRUNC('month', o.order_date)::date
) AS monthly
ORDER BY month;

-- Task 10
SELECT
    ranked.company_name AS company_name,
    ranked.country AS country,
    ROUND(ranked.revenue::numeric, 2) AS revenue,
    ranked.revenue_quartile AS revenue_quartile,
    ranked.best_in_country AS best_in_country,
    ROUND(ranked.pct_of_country::numeric, 1) AS pct_of_country
FROM (
    SELECT
        c.company_name,
        c.country,
        SUM(
            od.unit_price * od.quantity * (1 - od.discount)
        ) AS revenue,
        NTILE(4) OVER (
            ORDER BY SUM(
                od.unit_price * od.quantity * (1 - od.discount)
            ) DESC
        ) AS revenue_quartile,
        FIRST_VALUE(c.company_name) OVER (
            PARTITION BY c.country
            ORDER BY
                SUM(
                    od.unit_price * od.quantity * (1 - od.discount)
                ) DESC,
                c.company_name
        ) AS best_in_country,
        100 * SUM(
            od.unit_price * od.quantity * (1 - od.discount)
        ) / SUM(
            SUM(od.unit_price * od.quantity * (1 - od.discount))
        ) OVER (
            PARTITION BY c.country
        ) AS pct_of_country
    FROM customers AS c
    JOIN orders AS o
        ON o.customer_id = c.customer_id
    JOIN order_details AS od
        ON od.order_id = o.order_id
    GROUP BY c.customer_id, c.company_name, c.country
) AS ranked
WHERE ranked.revenue_quartile = 1
ORDER BY revenue DESC;
