-- ============================================================
-- Marketing Analytics: SQL Queries
-- Dataset: campaigns(campaign_id, channel, budget, impressions,
--          clicks, conversions, revenue, start_date)
-- ============================================================


-- ============================================================
-- 1. ROI by Marketing Channel
-- ============================================================
WITH channel_totals AS (
    SELECT
        channel,
        COUNT(campaign_id)                              AS num_campaigns,
        SUM(budget)                                     AS total_budget,
        SUM(revenue)                                    AS total_revenue,
        SUM(revenue - budget)                           AS total_profit
    FROM campaigns
    GROUP BY channel
)
SELECT
    channel,
    num_campaigns,
    ROUND(total_budget, 2)                              AS total_budget,
    ROUND(total_revenue, 2)                             AS total_revenue,
    ROUND(total_profit, 2)                              AS total_profit,
    ROUND((total_profit / NULLIF(total_budget, 0)) * 100, 2)  AS roi_pct,
    RANK() OVER (ORDER BY (total_profit / NULLIF(total_budget, 0)) DESC) AS roi_rank
FROM channel_totals
ORDER BY roi_pct DESC;


-- ============================================================
-- 2. Conversion Rates at Each Funnel Stage
-- ============================================================
WITH funnel AS (
    SELECT
        channel,
        SUM(impressions)                                AS total_impressions,
        SUM(clicks)                                     AS total_clicks,
        SUM(conversions)                                AS total_conversions,
        SUM(revenue)                                    AS total_revenue
    FROM campaigns
    GROUP BY channel
)
SELECT
    channel,
    total_impressions,
    total_clicks,
    total_conversions,
    -- Stage 1: Impression -> Click (CTR)
    ROUND(total_clicks::NUMERIC / NULLIF(total_impressions, 0) * 100, 2)      AS ctr_pct,
    -- Stage 2: Click -> Conversion (CVR)
    ROUND(total_conversions::NUMERIC / NULLIF(total_clicks, 0) * 100, 2)      AS cvr_pct,
    -- Stage 3: Overall Funnel Rate
    ROUND(total_conversions::NUMERIC / NULLIF(total_impressions, 0) * 100, 4) AS overall_conversion_rate_pct
FROM funnel
ORDER BY cvr_pct DESC;


-- ============================================================
-- 3. Cost Per Acquisition (CAC) by Channel
-- ============================================================
WITH cac_calc AS (
    SELECT
        channel,
        SUM(budget)                                     AS total_spend,
        SUM(conversions)                                AS total_conversions,
        SUM(revenue)                                    AS total_revenue
    FROM campaigns
    GROUP BY channel
)
SELECT
    channel,
    ROUND(total_spend, 2)                               AS total_spend,
    total_conversions,
    ROUND(total_spend / NULLIF(total_conversions, 0), 2) AS cac,
    ROUND(total_revenue / NULLIF(total_conversions, 0), 2) AS avg_revenue_per_conversion,
    ROUND(
        (total_revenue / NULLIF(total_conversions, 0)) /
        NULLIF(total_spend / NULLIF(total_conversions, 0), 0), 2
    )                                                   AS ltv_to_cac_ratio,
    RANK() OVER (ORDER BY total_spend / NULLIF(total_conversions, 0) ASC) AS cac_rank
FROM cac_calc
ORDER BY cac ASC;


-- ============================================================
-- 4. Weekly Campaign Performance
-- ============================================================
WITH weekly AS (
    SELECT
        DATE_TRUNC('week', start_date)                  AS week_start,
        channel,
        COUNT(campaign_id)                              AS campaigns_launched,
        SUM(budget)                                     AS weekly_spend,
        SUM(impressions)                                AS weekly_impressions,
        SUM(clicks)                                     AS weekly_clicks,
        SUM(conversions)                                AS weekly_conversions,
        SUM(revenue)                                    AS weekly_revenue
    FROM campaigns
    GROUP BY DATE_TRUNC('week', start_date), channel
),
weekly_with_trends AS (
    SELECT
        week_start,
        channel,
        campaigns_launched,
        ROUND(weekly_spend, 2)                          AS weekly_spend,
        weekly_impressions,
        weekly_clicks,
        weekly_conversions,
        ROUND(weekly_revenue, 2)                        AS weekly_revenue,
        ROUND((weekly_revenue - weekly_spend) / NULLIF(weekly_spend, 0) * 100, 2) AS weekly_roi_pct,
        -- Week-over-week revenue change per channel
        LAG(weekly_revenue) OVER (PARTITION BY channel ORDER BY week_start) AS prev_week_revenue,
        ROUND(
            (weekly_revenue - LAG(weekly_revenue) OVER (PARTITION BY channel ORDER BY week_start)) /
            NULLIF(LAG(weekly_revenue) OVER (PARTITION BY channel ORDER BY week_start), 0) * 100, 2
        )                                               AS wow_revenue_growth_pct
    FROM weekly
)
SELECT *
FROM weekly_with_trends
ORDER BY week_start, channel;


-- ============================================================
-- 5. Attribution Analysis: Top Campaigns by Revenue Contribution
-- ============================================================
WITH campaign_metrics AS (
    SELECT
        campaign_id,
        channel,
        start_date,
        budget,
        impressions,
        clicks,
        conversions,
        revenue,
        revenue - budget                                AS profit,
        ROUND(clicks::NUMERIC / NULLIF(impressions, 0) * 100, 2)       AS ctr_pct,
        ROUND(conversions::NUMERIC / NULLIF(clicks, 0) * 100, 2)       AS cvr_pct,
        ROUND((revenue - budget) / NULLIF(budget, 0) * 100, 2)         AS roi_pct
    FROM campaigns
),
channel_revenue_totals AS (
    SELECT channel, SUM(revenue) AS channel_total_revenue
    FROM campaigns
    GROUP BY channel
),
grand_total AS (
    SELECT SUM(revenue) AS total_revenue FROM campaigns
)
SELECT
    cm.campaign_id,
    cm.channel,
    cm.start_date,
    ROUND(cm.budget, 2)                                 AS budget,
    ROUND(cm.revenue, 2)                                AS revenue,
    cm.roi_pct,
    cm.ctr_pct,
    cm.cvr_pct,
    -- Revenue share within channel
    ROUND(cm.revenue / NULLIF(ct.channel_total_revenue, 0) * 100, 2)   AS pct_of_channel_revenue,
    -- Revenue share overall
    ROUND(cm.revenue / NULLIF(gt.total_revenue, 0) * 100, 2)           AS pct_of_total_revenue,
    -- Percentile rank by ROI within channel
    ROUND(
        PERCENT_RANK() OVER (PARTITION BY cm.channel ORDER BY cm.roi_pct) * 100, 1
    )                                                   AS roi_percentile_in_channel
FROM campaign_metrics cm
JOIN channel_revenue_totals ct ON cm.channel = ct.channel
CROSS JOIN grand_total gt
ORDER BY cm.revenue DESC
LIMIT 50;


-- ============================================================
-- 6. Monthly Channel Budget vs Revenue Trend
-- ============================================================
WITH monthly AS (
    SELECT
        TO_CHAR(start_date, 'YYYY-MM')                 AS month,
        channel,
        ROUND(SUM(budget), 2)                          AS monthly_budget,
        ROUND(SUM(revenue), 2)                         AS monthly_revenue,
        SUM(conversions)                               AS monthly_conversions
    FROM campaigns
    GROUP BY TO_CHAR(start_date, 'YYYY-MM'), channel
)
SELECT
    month,
    channel,
    monthly_budget,
    monthly_revenue,
    monthly_conversions,
    ROUND((monthly_revenue - monthly_budget) / NULLIF(monthly_budget, 0) * 100, 2) AS monthly_roi_pct,
    -- Running total revenue per channel
    ROUND(SUM(monthly_revenue) OVER (PARTITION BY channel ORDER BY month
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2)         AS cumulative_revenue,
    -- Monthly budget as % of that channel's total annual budget
    ROUND(monthly_budget / SUM(monthly_budget) OVER (PARTITION BY channel) * 100, 2) AS pct_of_annual_budget
FROM monthly
ORDER BY month, channel;
