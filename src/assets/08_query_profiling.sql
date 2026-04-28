-- =============================================================================
-- NorthBridge Bank HOL: Step 8 - Query Profiling & Performance Monitoring
--
-- Snowflake provides multiple tools to understand query performance:
--
--   1. Query Profile   — visual execution plan (in Snowsight)
--   2. Query History   — historical execution stats
--   3. EXPLAIN         — estimated execution plan without running the query
--   4. QUERY_HISTORY table function — programmatic access to query stats
--
-- As an analyst, knowing how to read these tools helps you:
--   - Identify why a query is slow
--   - Spot data spilling to disk
--   - Understand partition pruning effectiveness
--   - Write faster SQL
-- =============================================================================

USE DATABASE NORTHBRIDGE_BANK_HOL;
USE WAREHOUSE NORTHBRIDGE_WH;
USE ROLE SYSADMIN;

-- =============================================================================
-- PART A: EXPLAIN — SEE THE PLAN WITHOUT RUNNING THE QUERY
--
-- EXPLAIN shows the estimated execution plan. Use it to check whether
-- Snowflake will prune partitions before running an expensive query.
-- =============================================================================

EXPLAIN
SELECT
    a.account_type,
    COUNT(*)           AS txn_count,
    SUM(t.amount_gbp)  AS total_gbp
FROM RAW.TRANSACTIONS t
JOIN RAW.ACCOUNTS     a ON t.account_id = a.account_id
WHERE t.status = 'CLEARED'
  AND t.transaction_date >= '2026-04-01'
GROUP BY a.account_type;

-- =============================================================================
-- PART B: RUN QUERIES AND INSPECT QUERY PROFILE
--
-- After running each query, click the Query ID link in the results pane
-- (or go to Monitoring > Query History) to open the Query Profile.
--
-- Key things to look for in Query Profile:
--   - Partitions scanned vs total (pruning effectiveness)
--   - Bytes spilled to local/remote storage (indicates insufficient memory)
--   - Percentage scanned from cache (warehouse cache hit rate)
--   - Join explosion (unexpected row count growth after a JOIN)
-- =============================================================================

-- B1: Well-filtered query — should show good partition pruning
SELECT
    merchant_category,
    COUNT(*)               AS txn_count,
    ROUND(SUM(amount_gbp), 2) AS total_gbp
FROM RAW.TRANSACTIONS
WHERE status = 'CLEARED'
  AND transaction_date >= '2026-04-01'
  AND transaction_date <  '2026-04-28'
GROUP BY merchant_category
ORDER BY total_gbp DESC;

-- B2: Poorly-filtered query — scans more partitions
SELECT
    merchant_category,
    COUNT(*)               AS txn_count,
    ROUND(SUM(amount_gbp), 2) AS total_gbp
FROM RAW.TRANSACTIONS
WHERE status = 'CLEARED'
GROUP BY merchant_category
ORDER BY total_gbp DESC;

-- Compare the two queries in Query History:
--   - Which scanned more bytes?
--   - Which scanned more partitions?
--   - What was the difference in execution time?

-- =============================================================================
-- PART C: QUERY HISTORY — PROGRAMMATIC ACCESS TO EXECUTION STATS
--
-- The INFORMATION_SCHEMA.QUERY_HISTORY table function lets you analyse
-- your own query performance programmatically.
-- =============================================================================

-- Your 10 most recent queries with execution stats
SELECT
    query_id,
    query_text,
    warehouse_name,
    warehouse_size,
    execution_status,
    total_elapsed_time / 1000               AS elapsed_seconds,
    bytes_scanned / (1024*1024)             AS mb_scanned,
    rows_produced,
    partitions_scanned,
    partitions_total,
    ROUND(partitions_scanned / NULLIF(partitions_total, 0) * 100, 1) AS pct_partitions_scanned,
    bytes_spilled_to_local_storage / (1024*1024)  AS mb_spilled_local,
    bytes_spilled_to_remote_storage / (1024*1024) AS mb_spilled_remote,
    percentage_scanned_from_cache
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    END_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP()),
    RESULT_LIMIT         => 10
))
WHERE warehouse_name = 'NORTHBRIDGE_WH'
ORDER BY start_time DESC;

-- =============================================================================
-- PART D: FIND YOUR SLOWEST QUERIES
--
-- Useful for identifying queries that need optimisation.
-- =============================================================================

SELECT
    query_id,
    LEFT(query_text, 100)                        AS query_preview,
    warehouse_size,
    total_elapsed_time / 1000                    AS elapsed_seconds,
    bytes_scanned / (1024*1024)                  AS mb_scanned,
    rows_produced,
    compilation_time / 1000                      AS compile_seconds,
    execution_time / 1000                        AS exec_seconds,
    queued_overload_time / 1000                  AS queued_seconds,
    bytes_spilled_to_local_storage / (1024*1024) AS mb_spilled_local
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    END_TIME_RANGE_START => DATEADD('hour', -2, CURRENT_TIMESTAMP()),
    RESULT_LIMIT         => 50
))
WHERE warehouse_name = 'NORTHBRIDGE_WH'
  AND execution_status = 'SUCCESS'
  AND query_type = 'SELECT'
ORDER BY total_elapsed_time DESC
LIMIT 10;

-- =============================================================================
-- PART E: PARTITION PRUNING IN ACTION
--
-- Snowflake automatically organises data into micro-partitions.
-- When you filter on well-clustered columns, Snowflake can skip
-- irrelevant partitions entirely — dramatically reducing I/O.
-- =============================================================================

ALTER SESSION SET USE_CACHED_RESULT = FALSE;

-- Query 1: No date filter — scans ALL partitions
SELECT COUNT(*), SUM(amount_gbp)
FROM RAW.TRANSACTIONS
WHERE status = 'CLEARED';

-- Query 2: Narrow date range — should scan fewer partitions
SELECT COUNT(*), SUM(amount_gbp)
FROM RAW.TRANSACTIONS
WHERE status = 'CLEARED'
  AND transaction_date >= '2026-04-01'
  AND transaction_date <  '2026-04-15';

-- Check both queries in Query History — compare:
--   partitions_scanned vs partitions_total
-- The narrow date query should scan significantly fewer partitions.

ALTER SESSION SET USE_CACHED_RESULT = TRUE;

-- =============================================================================
-- PART F: IDENTIFY SPILLING
--
-- When a query's working set exceeds the warehouse memory, Snowflake
-- "spills" data to local SSD and then to remote storage. Spilling
-- slows queries significantly.
--
-- Remedies:
--   1. Filter earlier (reduce data volume before aggregation)
--   2. Use a larger warehouse (more memory)
--   3. Simplify the query (fewer intermediate result sets)
-- =============================================================================

-- Check for any queries in your recent history that spilled
SELECT
    query_id,
    LEFT(query_text, 80)                         AS query_preview,
    warehouse_size,
    total_elapsed_time / 1000                    AS elapsed_seconds,
    bytes_spilled_to_local_storage / (1024*1024) AS mb_spilled_local,
    bytes_spilled_to_remote_storage / (1024*1024) AS mb_spilled_remote
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    END_TIME_RANGE_START => DATEADD('hour', -2, CURRENT_TIMESTAMP()),
    RESULT_LIMIT         => 50
))
WHERE warehouse_name = 'NORTHBRIDGE_WH'
  AND (bytes_spilled_to_local_storage > 0 OR bytes_spilled_to_remote_storage > 0)
ORDER BY bytes_spilled_to_local_storage DESC;

-- =============================================================================
-- PART G: PERFORMANCE CHECKLIST FOR ANALYSTS
-- =============================================================================
--
-- Before running a heavy query, check:
--   [ ] Am I selecting only the columns I need? (no SELECT *)
--   [ ] Am I filtering as early as possible?
--   [ ] Are my date filters using range predicates? (not DATE_TRUNC on column)
--   [ ] Is my warehouse size appropriate for this workload?
--   [ ] Can I use LIMIT during development to validate logic first?
--
-- After running a slow query, check:
--   [ ] Query Profile: partitions scanned vs total
--   [ ] Query Profile: bytes spilled to local/remote
--   [ ] Query Profile: percentage scanned from cache
--   [ ] Query History: compare elapsed time vs compilation vs execution
--   [ ] Could a CTE or filter reduce the intermediate result set?
