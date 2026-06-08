-- ============================================================
-- Fintech Analytics: Credit Card Spending Behavior Queries
-- Database: PostgreSQL
-- Description: Analytical queries for credit card holder
--              behavior analysis and risk assessment
-- ============================================================

-- ------------------------------------------------------------
-- 1. Average Transaction Amount by Customer Segment
--    Segments: Low / Mid / High income
-- ------------------------------------------------------------
WITH customer_segments AS (
    SELECT
        c.customer_id,
        c.income,
        c.credit_limit,
        CASE
            WHEN c.income < 40000  THEN 'Low Income'
            WHEN c.income < 80000  THEN 'Mid Income'
            ELSE                        'High Income'
        END AS income_segment,
        CASE
            WHEN c.age < 30 THEN '18-29'
            WHEN c.age < 45 THEN '30-44'
            WHEN c.age < 60 THEN '45-59'
            ELSE                  '60+'
        END AS age_group
    FROM customers c
),
transaction_stats AS (
    SELECT
        t.customer_id,
        AVG(t.amount)   AS avg_transaction_amount,
        SUM(t.amount)   AS total_spending,
        COUNT(*)        AS transaction_count
    FROM transactions t
    GROUP BY t.customer_id
)
SELECT
    cs.income_segment,
    cs.age_group,
    COUNT(cs.customer_id)                      AS customer_count,
    ROUND(AVG(ts.avg_transaction_amount), 2)   AS avg_txn_amount,
    ROUND(AVG(ts.total_spending), 2)           AS avg_total_spending,
    ROUND(AVG(ts.transaction_count), 1)        AS avg_txn_count
FROM customer_segments cs
JOIN transaction_stats ts ON cs.customer_id = ts.customer_id
GROUP BY cs.income_segment, cs.age_group
ORDER BY
    CASE cs.income_segment
        WHEN 'Low Income'  THEN 1
        WHEN 'Mid Income'  THEN 2
        WHEN 'High Income' THEN 3
    END,
    cs.age_group;


-- ------------------------------------------------------------
-- 2. Monthly Spending Trends (12-month rolling)
--    With month-over-month growth rate
-- ------------------------------------------------------------
WITH monthly_totals AS (
    SELECT
        DATE_TRUNC('month', t.transaction_date) AS txn_month,
        COUNT(DISTINCT t.customer_id)           AS active_customers,
        COUNT(*)                                AS total_transactions,
        ROUND(SUM(t.amount), 2)                 AS total_spending,
        ROUND(AVG(t.amount), 2)                 AS avg_transaction
    FROM transactions t
    WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY DATE_TRUNC('month', t.transaction_date)
),
monthly_with_growth AS (
    SELECT
        txn_month,
        active_customers,
        total_transactions,
        total_spending,
        avg_transaction,
        LAG(total_spending) OVER (ORDER BY txn_month) AS prev_month_spending,
        ROUND(
            100.0 * (total_spending - LAG(total_spending) OVER (ORDER BY txn_month))
            / NULLIF(LAG(total_spending) OVER (ORDER BY txn_month), 0),
            2
        ) AS mom_growth_pct
    FROM monthly_totals
)
SELECT
    TO_CHAR(txn_month, 'YYYY-MM')   AS month,
    active_customers,
    total_transactions,
    total_spending,
    avg_transaction,
    COALESCE(mom_growth_pct, 0)     AS mom_growth_pct
FROM monthly_with_growth
ORDER BY txn_month;


-- ------------------------------------------------------------
-- 3. Credit Utilization Rate per Customer
--    Utilization = total_spending / credit_limit
-- ------------------------------------------------------------
WITH customer_spending AS (
    SELECT
        t.customer_id,
        SUM(t.amount) AS total_spending_12m
    FROM transactions t
    WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY t.customer_id
),
utilization AS (
    SELECT
        c.customer_id,
        c.credit_limit,
        cs.total_spending_12m,
        ROUND(cs.total_spending_12m / NULLIF(c.credit_limit, 0), 4) AS utilization_rate,
        CASE
            WHEN cs.total_spending_12m / NULLIF(c.credit_limit, 0) < 0.30 THEN 'Low (< 30%)'
            WHEN cs.total_spending_12m / NULLIF(c.credit_limit, 0) < 0.60 THEN 'Moderate (30-60%)'
            WHEN cs.total_spending_12m / NULLIF(c.credit_limit, 0) < 0.80 THEN 'High (60-80%)'
            ELSE                                                               'Critical (> 80%)'
        END AS utilization_band
    FROM customers c
    JOIN customer_spending cs ON c.customer_id = cs.customer_id
)
SELECT
    customer_id,
    credit_limit,
    total_spending_12m,
    utilization_rate,
    utilization_band
FROM utilization
ORDER BY utilization_rate DESC;


-- ------------------------------------------------------------
-- 4. Customers at Risk (near or over credit limit)
--    Flags customers for proactive outreach
-- ------------------------------------------------------------
WITH monthly_spending AS (
    SELECT
        t.customer_id,
        DATE_TRUNC('month', t.transaction_date) AS txn_month,
        SUM(t.amount)                           AS monthly_spend
    FROM transactions t
    GROUP BY t.customer_id, DATE_TRUNC('month', t.transaction_date)
),
customer_risk AS (
    SELECT
        ms.customer_id,
        c.income,
        c.credit_limit,
        c.months_on_book,
        ROUND(AVG(ms.monthly_spend), 2)                            AS avg_monthly_spend,
        ROUND(MAX(ms.monthly_spend), 2)                            AS peak_monthly_spend,
        ROUND(AVG(ms.monthly_spend) / NULLIF(c.credit_limit, 0), 4) AS avg_utilization,
        ROUND(MAX(ms.monthly_spend) / NULLIF(c.credit_limit, 0), 4) AS peak_utilization,
        COUNT(CASE WHEN ms.monthly_spend / c.credit_limit > 0.8 THEN 1 END) AS months_over_80pct
    FROM monthly_spending ms
    JOIN customers c ON ms.customer_id = c.customer_id
    GROUP BY ms.customer_id, c.income, c.credit_limit, c.months_on_book
)
SELECT
    customer_id,
    income,
    credit_limit,
    months_on_book,
    avg_monthly_spend,
    peak_monthly_spend,
    ROUND(avg_utilization * 100, 1)  AS avg_utilization_pct,
    ROUND(peak_utilization * 100, 1) AS peak_utilization_pct,
    months_over_80pct,
    CASE
        WHEN avg_utilization > 0.80                        THEN 'HIGH RISK'
        WHEN avg_utilization > 0.60 OR months_over_80pct >= 3 THEN 'MEDIUM RISK'
        ELSE                                                    'LOW RISK'
    END AS risk_flag
FROM customer_risk
WHERE avg_utilization > 0.60
   OR months_over_80pct >= 2
ORDER BY avg_utilization DESC, months_over_80pct DESC;


-- ------------------------------------------------------------
-- 5. Transaction Frequency Analysis
--    Per customer: frequency, recency, monetary value (RFM)
-- ------------------------------------------------------------
WITH rfm_base AS (
    SELECT
        t.customer_id,
        MAX(t.transaction_date)                              AS last_txn_date,
        CURRENT_DATE - MAX(t.transaction_date)::date        AS recency_days,
        COUNT(*)                                             AS frequency,
        ROUND(SUM(t.amount), 2)                              AS monetary,
        ROUND(AVG(t.amount), 2)                              AS avg_amount,
        COUNT(DISTINCT t.category)                           AS distinct_categories,
        COUNT(DISTINCT DATE_TRUNC('month', t.transaction_date)) AS active_months
    FROM transactions t
    WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY t.customer_id
),
rfm_scored AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_days ASC)  AS r_score,
        NTILE(5) OVER (ORDER BY frequency DESC)    AS f_score,
        NTILE(5) OVER (ORDER BY monetary DESC)     AS m_score
    FROM rfm_base
),
rfm_final AS (
    SELECT
        *,
        (r_score + f_score + m_score)                AS rfm_total,
        CONCAT(r_score::text, f_score::text, m_score::text) AS rfm_segment_code
    FROM rfm_scored
)
SELECT
    rf.customer_id,
    c.income,
    c.credit_limit,
    rf.recency_days,
    rf.frequency,
    rf.monetary,
    rf.avg_amount,
    rf.distinct_categories,
    rf.active_months,
    rf.r_score,
    rf.f_score,
    rf.m_score,
    rf.rfm_total,
    rf.rfm_segment_code,
    CASE
        WHEN rf.rfm_total >= 13 THEN 'Champions'
        WHEN rf.rfm_total >= 10 THEN 'Loyal Customers'
        WHEN rf.rfm_total >= 7  THEN 'Potential Loyalists'
        WHEN rf.rfm_total >= 5  THEN 'At Risk'
        ELSE                        'Lost'
    END AS rfm_label
FROM rfm_final rf
JOIN customers c ON rf.customer_id = c.customer_id
ORDER BY rf.rfm_total DESC, rf.monetary DESC;
