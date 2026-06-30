-- ============================================================================
-- 05 · Resolution-time distribution (histogram buckets, 2024)
-- ----------------------------------------------------------------------------
-- Business question: what does the spread of resolution times actually look
--   like -- and how much of it is near-instant?
--
-- This is the evidence for "lead with the median": a huge mass of sub-1h closes
--   (~25%) sits alongside a long multi-week/-month tail, which is exactly why a
--   single mean is misleading. The sub-1h bucket also motivates the
--   speed-vs-effectiveness split (many of those fast closes fix nothing).
--
-- Buckets are prefixed with a sort key ('0:', '1:', ...) so ORDER BY orders
--   them chronologically rather than alphabetically.
-- pct_of_closed uses a window aggregate, SUM(COUNT(*)) OVER (), to divide each
--   bucket by the grand total in one pass.
-- ============================================================================

WITH bucketed AS (
    SELECT CASE
        WHEN resolution_time_hours < 1     THEN '0: <1h'
        WHEN resolution_time_hours < 4     THEN '1: 1-4h'
        WHEN resolution_time_hours < 12    THEN '2: 4-12h'
        WHEN resolution_time_hours < 24    THEN '3: 12-24h'
        WHEN resolution_time_hours < 72    THEN '4: 1-3d'
        WHEN resolution_time_hours < 168   THEN '5: 3-7d'
        WHEN resolution_time_hours < 720   THEN '6: 7-30d'
        WHEN resolution_time_hours < 2160  THEN '7: 30-90d'
        ELSE                                    '8: >90d'
    END AS bucket
    FROM tickets
    WHERE resolution_time_hours IS NOT NULL
)

SELECT
    bucket,
    COUNT(*)                                              AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)    AS pct_of_closed
FROM bucketed
GROUP BY bucket
ORDER BY bucket;
