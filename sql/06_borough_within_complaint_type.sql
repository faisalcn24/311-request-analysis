-- ============================================================================
-- 06 · SECONDARY (caveated): borough median WITHIN complaint type (2024)
-- ----------------------------------------------------------------------------
-- Business question: is any borough genuinely slower -- or is "slow borough"
--   just a complaint-mix artifact?
--
-- CAVEAT (this is the point of the query): borough ranked on its own is
--   misleading. The overall ranking REVERSES once you control for complaint
--   type. Bronx has the slowest overall median yet is the FASTEST borough for
--   Heat/Hot Water -- it only looks slow because of WHAT gets reported there,
--   not how fast the city responds. So we show borough-WITHIN-type next to the
--   borough's overall median, side by side, so the composition effect is
--   visible instead of hidden.
--
-- The JOIN stitches each (type, borough) median to that borough's overall
--   median. 'Unspecified' borough is excluded (it's a data-quality bucket with
--   a ~100h median, not a real place).
-- Median via the ROW_NUMBER()/COUNT() window trick, computed at two grains.
-- ============================================================================

WITH closed AS (
    SELECT borough, complaint_type, resolution_time_hours
    FROM tickets
    WHERE resolution_time_hours IS NOT NULL
      AND borough <> 'Unspecified'
),

top_types AS (
    SELECT complaint_type
    FROM closed
    GROUP BY complaint_type
    ORDER BY COUNT(*) DESC
    LIMIT 6
),

-- (a) each borough's OVERALL median across all complaint types (the
--     misleading headline number).
ranked_b AS (
    SELECT borough, resolution_time_hours,
           ROW_NUMBER() OVER (PARTITION BY borough
                              ORDER BY resolution_time_hours) AS rn,
           COUNT(*)     OVER (PARTITION BY borough)           AS n
    FROM closed
),
borough_overall AS (
    SELECT borough, AVG(resolution_time_hours) AS overall_median
    FROM ranked_b
    WHERE rn IN ((n + 1) / 2, (n + 2) / 2)
    GROUP BY borough
),

-- (b) median per borough WITHIN each top complaint type.
ranked_bt AS (
    SELECT borough, complaint_type, resolution_time_hours,
           ROW_NUMBER() OVER (PARTITION BY complaint_type, borough
                              ORDER BY resolution_time_hours) AS rn,
           COUNT(*)     OVER (PARTITION BY complaint_type, borough) AS n
    FROM closed
    WHERE complaint_type IN (SELECT complaint_type FROM top_types)
),
within_type AS (
    SELECT complaint_type, borough,
           AVG(resolution_time_hours) AS median_within_type
    FROM ranked_bt
    WHERE rn IN ((n + 1) / 2, (n + 2) / 2)
    GROUP BY complaint_type, borough
)

SELECT
    w.complaint_type,
    w.borough,
    ROUND(w.median_within_type, 1) AS median_within_type,
    ROUND(b.overall_median, 1)     AS borough_overall_median
FROM within_type w
JOIN borough_overall b USING (borough)
ORDER BY w.complaint_type, w.median_within_type;
