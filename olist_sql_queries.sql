
-- ============================================================
-- Ecommerce Sales & Customer Analytics Project
-- Dataset  : Olist Ecommerce Dataset
-- Database : PostgreSQL
-- Visualization Tool : Tableau
--
-- Project Objective:
-- Analyze ecommerce sales performance, customer behavior,
-- product category performance, and business growth trends
-- using SQL analytics techniques.
-- ============================================================


-- ============================================================
-- SECTION 1 : TABLE CREATION
-- Creates core ecommerce tables used for analytics
-- ============================================================

CREATE TABLE customers (
    customer_id TEXT PRIMARY KEY,
    customer_unique_id TEXT,
    customer_zip_code_prefix INT,
    customer_city TEXT,
    customer_state TEXT
);

CREATE TABLE orders (
    order_id TEXT,
    customer_id TEXT,
    order_status TEXT,
    order_purchase_timestamp TEXT,
    order_approved_at TEXT,
    order_delivered_carrier_date TEXT,
    order_delivered_customer_date TEXT,
    order_estimated_delivery_date TEXT
);

CREATE TABLE order_items (
    order_id TEXT,
    order_item_id INT,
    product_id TEXT,
    seller_id TEXT,
    shipping_limit_date TIMESTAMP,
    price NUMERIC,
    freight_value NUMERIC
);

CREATE TABLE products (
    product_id TEXT PRIMARY KEY,
    product_category_name TEXT,
    product_name_lenght INT,
    product_description_lenght INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);

-- ============================================================
-- SECTION 2 : DATA VALIDATION
-- Check total rows loaded into each table
-- ============================================================

SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM order_items;
SELECT COUNT(*) FROM products;

-- ============================================================
-- SECTION 3 : MONTHLY REVENUE & MoM GROWTH ANALYSIS
-- Calculates monthly revenue and month-over-month growth
-- using window functions (LAG)
-- ============================================================

WITH monthly_revenue AS (

    SELECT
        DATE_TRUNC(
            'month',
            CAST(o.order_purchase_timestamp AS TIMESTAMP)
        ) AS month,

        ROUND(SUM(oi.price)::numeric, 2) AS revenue

    FROM orders o

    JOIN order_items oi
        ON o.order_id = oi.order_id

    GROUP BY month
)

SELECT
    month,

    revenue,

    LAG(revenue)
    OVER(ORDER BY month)
    AS previous_month_revenue,

    CASE

        WHEN LAG(revenue)
        OVER(ORDER BY month) < 1000

        THEN NULL

        ELSE ROUND(
            (
                (
                    revenue -

                    LAG(revenue)
                    OVER(ORDER BY month)
                )

                /

                LAG(revenue)
                OVER(ORDER BY month)

            ) * 100,
            2
        )

    END AS mom_growth_percent

FROM monthly_revenue;

-- ============================================================
-- SECTION 4 : TOP CUSTOMERS BY SPENDING
-- Identifies highest spending customers and cities
-- ============================================================

SELECT

    c.customer_id,

    c.customer_city,

    ROUND(SUM(oi.price)::numeric, 2)
        AS total_spent

FROM customers c

JOIN orders o
    ON c.customer_id = o.customer_id

JOIN order_items oi
    ON o.order_id = oi.order_id

GROUP BY
    c.customer_id,
    c.customer_city

ORDER BY total_spent DESC

LIMIT 10;

-- ============================================================
-- SECTION 5 : TOP PRODUCT CATEGORIES
-- Finds highest revenue generating product categories
-- ============================================================

SELECT

    COALESCE(
        p.product_category_name,
        'Unknown'
    ) AS category_name,

    ROUND(SUM(oi.price)::numeric, 2)
        AS category_revenue

FROM products p

JOIN order_items oi
    ON p.product_id = oi.product_id

JOIN orders o
    ON oi.order_id = o.order_id

GROUP BY
    COALESCE(
        p.product_category_name,
        'Unknown'
    )

ORDER BY
    category_revenue DESC

LIMIT 10;

-- ============================================================
-- SECTION 4 : TOP CUSTOMERS BY SPENDING
-- Identifies highest spending customers and cities
-- ============================================================

SELECT

    c.customer_id,

    COUNT(o.order_id)
        AS total_orders

FROM customers c

JOIN orders o
    ON c.customer_id = o.customer_id

GROUP BY
    c.customer_id

ORDER BY
    total_orders DESC

LIMIT 10;


SELECT

    c.customer_unique_id,

    COUNT(o.order_id)
        AS total_orders

FROM customers c

JOIN orders o
    ON c.customer_id = o.customer_id

GROUP BY
    c.customer_unique_id

HAVING COUNT(o.order_id) > 1

ORDER BY
    total_orders DESC;


-- ============================================================
-- SECTION 6 : CUSTOMER RETENTION ANALYSIS
-- Measures repeat customer percentage
-- ============================================================

WITH customer_orders AS (

    SELECT

        c.customer_unique_id,

        COUNT(o.order_id) AS total_orders

    FROM customers c

    JOIN orders o
        ON c.customer_id = o.customer_id

    GROUP BY
        c.customer_unique_id
)

SELECT

    COUNT(
        CASE
            WHEN total_orders > 1
            THEN 1
        END
    ) AS repeat_customers,

    COUNT(*) AS total_customers,

    ROUND(
        (
            COUNT(
                CASE
                    WHEN total_orders > 1
                    THEN 1
                END
            ) * 100.0

            /

            COUNT(*)
        ),
        2
    ) AS retention_rate

FROM customer_orders;

-- ============================================================
-- SECTION 7 : CONSECUTIVE ORDER DATE ANALYSIS
-- Finds continuous order streaks using gaps & islands logic
-- ============================================================

WITH order_dates AS (

    SELECT DISTINCT

        DATE(
            CAST(order_purchase_timestamp AS TIMESTAMP)
        ) AS order_date

    FROM orders
),

numbered_dates AS (

    SELECT

        order_date,

        ROW_NUMBER()
        OVER(ORDER BY order_date) AS rn

    FROM order_dates
),

grouped_dates AS (

    SELECT

        order_date,

        rn,

        order_date - rn * INTERVAL '1 day'
            AS grp

    FROM numbered_dates
)

SELECT

    MIN(order_date) AS streak_start,

    MAX(order_date) AS streak_end,

    COUNT(*) AS consecutive_days

FROM grouped_dates

GROUP BY grp

ORDER BY streak_start;


-- ============================================================
-- SECTION 8 : CUSTOMER RANKING ANALYSIS
-- Demonstrates ROW_NUMBER, RANK, and DENSE_RANK
-- ============================================================

WITH customer_spending AS (

    SELECT

        c.customer_unique_id,

        ROUND(SUM(oi.price)::numeric, 2)
            AS total_spent

    FROM customers c

    JOIN orders o
        ON c.customer_id = o.customer_id

    JOIN order_items oi
        ON o.order_id = oi.order_id

    GROUP BY
        c.customer_unique_id
)

SELECT

    customer_unique_id,

    total_spent,

    ROW_NUMBER()
    OVER(ORDER BY total_spent DESC)
        AS row_num,

    RANK()
    OVER(ORDER BY total_spent DESC)
        AS rank_num,

    DENSE_RANK()
    OVER(ORDER BY total_spent DESC)
        AS dense_rank_num

FROM customer_spending

LIMIT 20;


WITH repeat_customers AS (

    SELECT

        c.customer_unique_id

    FROM customers c

    JOIN orders o
        ON c.customer_id = o.customer_id

    GROUP BY
        c.customer_unique_id

    HAVING COUNT(*) > 1
),

customer_activity AS (

    SELECT

        c.customer_unique_id,

        CAST(
            o.order_purchase_timestamp AS TIMESTAMP
        ) AS activity_time

    FROM customers c

    JOIN orders o
        ON c.customer_id = o.customer_id

    WHERE c.customer_unique_id IN (
        SELECT customer_unique_id
        FROM repeat_customers
    )
),

time_differences AS (

    SELECT

        customer_unique_id,

        activity_time,

        LAG(activity_time)
        OVER(
            PARTITION BY customer_unique_id
            ORDER BY activity_time
        ) AS previous_time

    FROM customer_activity
),

session_flags AS (

    SELECT

        customer_unique_id,

        activity_time,

        previous_time,

        CASE

            WHEN previous_time IS NULL
            THEN 1

            WHEN activity_time - previous_time
                 > INTERVAL '30 minutes'
            THEN 1

            ELSE 0

        END AS new_session

    FROM time_differences
)

SELECT

    customer_unique_id,

    activity_time,

    previous_time,

    new_session,

    SUM(new_session)
    OVER(
        PARTITION BY customer_unique_id
        ORDER BY activity_time
    ) AS session_number

FROM session_flags

ORDER BY
    customer_unique_id,
    activity_time;


SELECT

    PERCENTILE_CONT(0.5)

    WITHIN GROUP(
        ORDER BY price
    ) AS median_price

FROM order_items;


SELECT
    ROUND(AVG(price)::numeric, 2)
FROM order_items;


