-- ============================================================
-- E-commerce Sales Analytics: Production SQL Queries
-- Database: PostgreSQL
-- Author: Analytics Team
-- Description: CTE-based queries mirroring the notebook analysis
-- ============================================================


-- ------------------------------------------------------------
-- 1. MONTHLY REVENUE TRENDS WITH MoM GROWTH
-- ------------------------------------------------------------
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE          AS month,
        COUNT(DISTINCT order_id)                        AS total_orders,
        COUNT(DISTINCT customer_id)                     AS unique_customers,
        ROUND(SUM(order_value)::NUMERIC, 2)             AS revenue,
        ROUND(AVG(order_value)::NUMERIC, 2)             AS avg_order_value
    FROM orders
    WHERE order_status != 'cancelled'
    GROUP BY 1
),
revenue_with_lag AS (
    SELECT
        month,
        total_orders,
        unique_customers,
        revenue,
        avg_order_value,
        LAG(revenue) OVER (ORDER BY month)              AS prev_month_revenue
    FROM monthly_revenue
)
SELECT
    month,
    total_orders,
    unique_customers,
    revenue,
    avg_order_value,
    prev_month_revenue,
    ROUND(
        100.0 * (revenue - prev_month_revenue) / NULLIF(prev_month_revenue, 0),
        2
    )                                                   AS mom_growth_pct
FROM revenue_with_lag
ORDER BY month;


-- ------------------------------------------------------------
-- 2. TOP CUSTOMERS BY LIFETIME VALUE (LTV)
-- ------------------------------------------------------------
WITH customer_orders AS (
    SELECT
        o.customer_id,
        c.customer_name,
        c.acquisition_channel,
        c.registration_date,
        COUNT(DISTINCT o.order_id)                      AS total_orders,
        ROUND(SUM(o.order_value)::NUMERIC, 2)           AS total_revenue,
        MIN(o.order_date)                               AS first_order_date,
        MAX(o.order_date)                               AS last_order_date,
        ROUND(AVG(o.order_value)::NUMERIC, 2)           AS avg_order_value,
        MAX(o.order_date) - MIN(o.order_date)           AS customer_lifespan_days
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status != 'cancelled'
    GROUP BY o.customer_id, c.customer_name, c.acquisition_channel, c.registration_date
),
ltv_ranked AS (
    SELECT
        *,
        ROUND(
            total_revenue * (365.0 / NULLIF(customer_lifespan_days, 0)),
            2
        )                                               AS annualized_ltv,
        NTILE(10) OVER (ORDER BY total_revenue DESC)    AS ltv_decile,
        RANK() OVER (ORDER BY total_revenue DESC)       AS ltv_rank
    FROM customer_orders
)
SELECT
    ltv_rank,
    customer_id,
    customer_name,
    acquisition_channel,
    total_orders,
    total_revenue,
    avg_order_value,
    annualized_ltv,
    customer_lifespan_days,
    ltv_decile
FROM ltv_ranked
ORDER BY ltv_rank
LIMIT 100;


-- ------------------------------------------------------------
-- 3. RFM SCORES CALCULATION
-- ------------------------------------------------------------
WITH snapshot_date AS (
    SELECT MAX(order_date) + INTERVAL '1 day' AS ref_date
    FROM orders
    WHERE order_status != 'cancelled'
),
rfm_base AS (
    SELECT
        o.customer_id,
        EXTRACT(DAY FROM (s.ref_date - MAX(o.order_date)))::INT  AS recency_days,
        COUNT(DISTINCT o.order_id)                                AS frequency,
        ROUND(SUM(o.order_value)::NUMERIC, 2)                    AS monetary
    FROM orders o
    CROSS JOIN snapshot_date s
    WHERE o.order_status != 'cancelled'
    GROUP BY o.customer_id, s.ref_date
),
rfm_percentiles AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        -- R score: lower recency = better (score 5)
        CASE
            WHEN recency_days <= PERCENTILE_CONT(0.20) WITHIN GROUP (ORDER BY recency_days) OVER () THEN 5
            WHEN recency_days <= PERCENTILE_CONT(0.40) WITHIN GROUP (ORDER BY recency_days) OVER () THEN 4
            WHEN recency_days <= PERCENTILE_CONT(0.60) WITHIN GROUP (ORDER BY recency_days) OVER () THEN 3
            WHEN recency_days <= PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY recency_days) OVER () THEN 2
            ELSE 1
        END                                                       AS r_score,
        -- F score: higher frequency = better
        NTILE(5) OVER (ORDER BY frequency ASC)                   AS f_score,
        -- M score: higher monetary = better
        NTILE(5) OVER (ORDER BY monetary ASC)                    AS m_score
    FROM rfm_base
),
rfm_segments AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        (r_score + f_score + m_score)                             AS rfm_total,
        CONCAT(r_score::TEXT, f_score::TEXT, m_score::TEXT)       AS rfm_cell,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4   THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3                     THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2                     THEN 'Recent Customers'
            WHEN r_score >= 3 AND f_score <= 3 AND m_score >= 3    THEN 'Potential Loyalists'
            WHEN r_score <= 2 AND f_score >= 4                     THEN 'At Risk'
            WHEN r_score <= 2 AND f_score >= 2 AND m_score >= 2    THEN 'Cant Lose Them'
            WHEN r_score <= 2 AND f_score <= 2                     THEN 'Lost'
            ELSE 'Hibernating'
        END                                                        AS segment
    FROM rfm_percentiles
)
SELECT
    segment,
    COUNT(customer_id)                                            AS customer_count,
    ROUND(AVG(recency_days), 1)                                   AS avg_recency_days,
    ROUND(AVG(frequency), 2)                                      AS avg_frequency,
    ROUND(AVG(monetary), 2)                                       AS avg_monetary,
    ROUND(SUM(monetary), 2)                                       AS total_revenue,
    ROUND(100.0 * COUNT(customer_id) / SUM(COUNT(customer_id)) OVER (), 2) AS pct_customers,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2)  AS pct_revenue
FROM rfm_segments
GROUP BY segment
ORDER BY total_revenue DESC;


-- ------------------------------------------------------------
-- 4. COHORT RETENTION MATRIX
-- ------------------------------------------------------------
WITH cohort_base AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(order_date))::DATE      AS cohort_month
    FROM orders
    WHERE order_status != 'cancelled'
    GROUP BY customer_id
),
customer_activity AS (
    SELECT
        o.customer_id,
        cb.cohort_month,
        DATE_TRUNC('month', o.order_date)::DATE         AS activity_month,
        EXTRACT(
            MONTH FROM AGE(
                DATE_TRUNC('month', o.order_date),
                cb.cohort_month
            )
        )::INT                                          AS period_number
    FROM orders o
    JOIN cohort_base cb ON o.customer_id = cb.customer_id
    WHERE o.order_status != 'cancelled'
),
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id)                     AS cohort_size
    FROM cohort_base
    GROUP BY cohort_month
),
retention_counts AS (
    SELECT
        ca.cohort_month,
        ca.period_number,
        COUNT(DISTINCT ca.customer_id)                  AS retained_customers
    FROM customer_activity ca
    GROUP BY ca.cohort_month, ca.period_number
)
SELECT
    rc.cohort_month,
    cs.cohort_size,
    rc.period_number,
    rc.retained_customers,
    ROUND(
        100.0 * rc.retained_customers / cs.cohort_size,
        2
    )                                                   AS retention_rate_pct
FROM retention_counts rc
JOIN cohort_sizes cs ON rc.cohort_month = cs.cohort_month
WHERE rc.period_number <= 6
ORDER BY rc.cohort_month, rc.period_number;


-- ------------------------------------------------------------
-- 5. PRODUCT CATEGORY PERFORMANCE
-- ------------------------------------------------------------
WITH category_metrics AS (
    SELECT
        p.category,
        COUNT(DISTINCT oi.order_id)                         AS total_orders,
        COUNT(DISTINCT o.customer_id)                       AS unique_buyers,
        SUM(oi.quantity)                                    AS units_sold,
        ROUND(SUM(oi.quantity * oi.unit_price)::NUMERIC, 2) AS gross_revenue,
        ROUND(AVG(oi.unit_price)::NUMERIC, 2)               AS avg_unit_price,
        ROUND(AVG(oi.quantity * oi.unit_price)::NUMERIC, 2) AS avg_item_revenue
    FROM order_items oi
    JOIN orders o   ON oi.order_id   = o.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE o.order_status != 'cancelled'
    GROUP BY p.category
),
category_ranked AS (
    SELECT
        *,
        RANK() OVER (ORDER BY gross_revenue DESC)           AS revenue_rank,
        ROUND(
            100.0 * gross_revenue / SUM(gross_revenue) OVER (),
            2
        )                                                   AS revenue_contribution_pct,
        SUM(gross_revenue) OVER (ORDER BY gross_revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                                   AS cumulative_revenue
    FROM category_metrics
)
SELECT
    revenue_rank,
    category,
    total_orders,
    unique_buyers,
    units_sold,
    gross_revenue,
    avg_unit_price,
    revenue_contribution_pct,
    ROUND(
        100.0 * cumulative_revenue / SUM(gross_revenue) OVER (),
        2
    )                                                       AS cumulative_pct
FROM category_ranked
ORDER BY revenue_rank;
