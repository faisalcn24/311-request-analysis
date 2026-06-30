-- ============================================================================
-- 04 · Backlog: % of tickets still open by complaint type (2024)
-- ----------------------------------------------------------------------------
-- Business question: which complaint types accumulate unresolved tickets?
--
-- "Open" is defined by a NULL close date, NOT status = 'Open'. The raw data is
--   messier than the status field implies -- 27,573 tickets are marked
--   'Closed' yet have no close timestamp. Keying on the null close date is the
--   honest definition of unresolved (see analysis_decisions.md sec 3.2).
--
-- A high open % flags a genuine backlog (work still queued), distinct from a
--   slow median (work that finishes, but slowly). Both matter for reallocation.
-- Noise control: HAVING n_total >= 500.
-- ============================================================================

SELECT
    complaint_type,
    COUNT(*)                                                    AS n_total,
    SUM(CASE WHEN resolution_time_hours IS NULL THEN 1 ELSE 0 END) AS n_open,
    ROUND(100.0 * SUM(CASE WHEN resolution_time_hours IS NULL THEN 1 ELSE 0 END)
                / COUNT(*), 2)                                  AS open_pct
FROM tickets
GROUP BY complaint_type
HAVING n_total >= 500
ORDER BY open_pct DESC
LIMIT 20;
