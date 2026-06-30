-- ============================================================================
-- 02 · Speed vs effectiveness by AGENCY (2024)
-- ----------------------------------------------------------------------------
-- Business question: which agencies close fast but fix little, and which take
--   longer but actually resolve the complaint?
--
-- This is the "speed != effectiveness" table. Agency is a clean, low-noise cut
--   (~20 rows), so the contrast reads immediately: e.g. a high-volume agency
--   with a tiny median but a low substantive % is closing tickets without a
--   fix. (Complaint-type-level effectiveness lives in 01's substantive_pct.)
--
-- substantive_pct = share of CLOSED tickets categorised Action/Enforcement
--   (an actual fix / summons / violation). We never delete the fast
--   non-resolutions -- we label them, so the gap is the insight.
-- no_fix_pct = share closed with "No issue found" or "Gone/No access": closed,
--   but nothing done.
-- Median via the same ROW_NUMBER()/COUNT() window trick as 01.
-- ============================================================================

WITH closed AS (
    SELECT agency, resolution_time_hours, resolution_category
    FROM tickets
    WHERE resolution_time_hours IS NOT NULL
),

agg AS (
    SELECT
        agency,
        COUNT(*)                             AS n_closed,
        ROUND(AVG(resolution_time_hours), 1) AS mean_hours,
        ROUND(100.0 * SUM(CASE WHEN resolution_category = 'Action/Enforcement'
                               THEN 1 ELSE 0 END) / COUNT(*), 1) AS substantive_pct,
        ROUND(100.0 * SUM(CASE WHEN resolution_category IN ('No issue found',
                                    'Gone/No access')
                               THEN 1 ELSE 0 END) / COUNT(*), 1) AS no_fix_pct
    FROM closed
    GROUP BY agency
),

ranked AS (
    SELECT
        agency,
        resolution_time_hours,
        ROW_NUMBER() OVER (PARTITION BY agency
                           ORDER BY resolution_time_hours) AS rn,
        COUNT(*)     OVER (PARTITION BY agency)            AS n
    FROM closed
),

med AS (
    SELECT agency, AVG(resolution_time_hours) AS median_hours
    FROM ranked
    WHERE rn IN ((n + 1) / 2, (n + 2) / 2)
    GROUP BY agency
)

SELECT
    a.agency,
    a.n_closed,
    ROUND(m.median_hours, 1) AS median_hours,
    a.mean_hours,
    a.substantive_pct,
    a.no_fix_pct
FROM agg a
JOIN med m USING (agency)
WHERE a.n_closed >= 1000            -- focus on agencies with real volume
ORDER BY a.n_closed DESC
LIMIT 15;
