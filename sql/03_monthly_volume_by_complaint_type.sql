-- ============================================================================
-- 03 · Seasonality: monthly volume by complaint type (2024)
-- ----------------------------------------------------------------------------
-- Business question: when does demand spike, and for what?
--
-- Key framing: seasonality lives PER complaint type, not in aggregate.
--   Citywide monthly volume looks flat because Heat (winter peak) and Noise
--   (summer peak) cancel out. So we never trend aggregate volume -- we trend
--   by type.
--
-- seasonality_index = a type's volume in a month as a % of that type's AVERAGE
--   month (window: AVG(n) OVER PARTITION BY type). 100 = an average month;
--   285 = nearly 3x the type's norm. This makes types of very different sizes
--   directly comparable on one chart (the shape, not the height).
--
-- Scope: the 8 highest-volume complaint types (subquery), so the chart shows
--   real signal, not a long tail of sparse, noisy series.
-- ============================================================================

WITH top_types AS (
    SELECT complaint_type
    FROM tickets
    GROUP BY complaint_type
    ORDER BY COUNT(*) DESC
    LIMIT 8
),

monthly AS (
    SELECT
        complaint_type,
        CAST(strftime('%m', created_date) AS INTEGER) AS month,
        COUNT(*) AS n
    FROM tickets
    WHERE complaint_type IN (SELECT complaint_type FROM top_types)
    GROUP BY complaint_type, month
)

SELECT
    complaint_type,
    month,
    n,
    ROUND(100.0 * n / AVG(n) OVER (PARTITION BY complaint_type), 0)
        AS seasonality_index           -- 100 = that type's average month
FROM monthly
ORDER BY complaint_type, month;
