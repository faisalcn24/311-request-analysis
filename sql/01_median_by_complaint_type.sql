-- ============================================================================
-- 01 · PRIMARY: slowest complaint types by MEDIAN resolution time (2024)
-- ----------------------------------------------------------------------------
-- Business question: which complaint types take longest to resolve?
--
-- Why median (not mean): resolution time is extreme-right-skewed (citywide
--   mean ~298 h vs median ~8 h). Median is the headline; mean rides alongside
--   as a caveated secondary so the skew is visible, not hidden.
-- Why a substantive-rate column: speed != effectiveness. A fast median next to
--   a low substantive % = "closed quickly without fixing anything". Pairing
--   them is the whole point (see 02 for the effectiveness deep-dive).
-- Cap label: categories whose median sits on the 290-day cleaning cap (e.g.
--   New Tree Request -- seasonal Parks planting) are reported as a long-cycle
--   band, not a fake-precise number.
-- Noise control: HAVING n_closed >= 500 drops tiny categories that would
--   otherwise produce unstable, noisy medians.
--
-- SQLite has no MEDIAN(): we compute it with a ROW_NUMBER()/COUNT() window
-- (pick the middle 1-2 ranked rows per group, then average them), then JOIN
-- that to the per-type aggregates.
-- ============================================================================

WITH closed AS (
    SELECT complaint_type, resolution_time_hours, resolution_category
    FROM tickets
    WHERE resolution_time_hours IS NOT NULL          -- closed tickets only
),

-- Per-type volume, mean (secondary), and substantive (Action/Enforcement) rate.
agg AS (
    SELECT
        complaint_type,
        COUNT(*)                                   AS n_closed,
        ROUND(AVG(resolution_time_hours), 1)       AS mean_hours,
        ROUND(100.0 * SUM(CASE WHEN resolution_category = 'Action/Enforcement'
                               THEN 1 ELSE 0 END) / COUNT(*), 1) AS substantive_pct
    FROM closed
    GROUP BY complaint_type
),

-- Rank rows within each type to locate the median position.
ranked AS (
    SELECT
        complaint_type,
        resolution_time_hours,
        ROW_NUMBER() OVER (PARTITION BY complaint_type
                           ORDER BY resolution_time_hours) AS rn,
        COUNT(*)     OVER (PARTITION BY complaint_type)     AS n
    FROM closed
),

-- Middle row (odd n) or average of the two middle rows (even n).
med AS (
    SELECT complaint_type, AVG(resolution_time_hours) AS median_hours
    FROM ranked
    WHERE rn IN ((n + 1) / 2, (n + 2) / 2)
    GROUP BY complaint_type
)

SELECT
    a.complaint_type,
    a.n_closed,
    CASE WHEN m.median_hours >= 6960
         THEN '>290 days (long-cycle)'
         ELSE printf('%.1f h', m.median_hours)
    END                              AS median_label,
    ROUND(m.median_hours, 1)         AS median_hours,
    a.mean_hours,
    a.substantive_pct
FROM agg a
JOIN med m USING (complaint_type)
WHERE a.n_closed >= 500              -- drop noisy small categories
ORDER BY m.median_hours DESC
LIMIT 20;
