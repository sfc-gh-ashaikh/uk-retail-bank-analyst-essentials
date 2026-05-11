# Step 8: Query Profiling and Performance Monitoring
**Duration: 20 minutes**

> **Thursday Afternoon** -- Sarah pulls you into a quick call: *"The monthly board report queries are running slower than expected. Before we throw a bigger warehouse at the problem, I need you to profile the queries and tell me what is actually happening -- are we scanning too many partitions? Is anything spilling to disk? Use the Query Profile and QUERY_HISTORY to diagnose it. If you can find the bottleneck, we fix the SQL instead of spending more on compute."*

Knowing how to write efficient SQL is one skill. Knowing how to diagnose a slow query is another. This step teaches you to use Snowflake's built-in profiling and monitoring tools.

Open your `08_QUERY_PROFILING` worksheet and run the following section by section:

```sql
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
  AND t.transaction_date >= DATEADD('day', -30, CURRENT_DATE())
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
  AND transaction_date >= DATEADD('day', -14, CURRENT_DATE())
  AND transaction_date <  CURRENT_DATE()
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
    compilation_time,
    execution_time,
    queued_overload_time,
    credits_used_cloud_services
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
    credits_used_cloud_services
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
  AND transaction_date >= DATEADD('day', -14, CURRENT_DATE())
  AND transaction_date <  CURRENT_DATE();

-- Check both queries in Query History — compare:
--   partitions_scanned vs partitions_total
-- The narrow date query should scan significantly fewer partitions.

ALTER SESSION SET USE_CACHED_RESULT = TRUE;

-- =============================================================================
-- PART F: IDENTIFY SLOW AND RESOURCE-HEAVY QUERIES
--
-- Use INFORMATION_SCHEMA.QUERY_HISTORY to find queries with high compilation
-- time, long execution, or queued time — all indicators of performance issues.
-- These results appear immediately (no latency like ACCOUNT_USAGE).
--
-- Note: Spill metrics (bytes_spilled_to_local/remote_storage) are only
-- available in SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY (up to 45-min latency).
-- =============================================================================

-- Find recent queries with the highest execution-to-compilation ratio
SELECT
    query_id,
    LEFT(query_text, 80)                         AS query_preview,
    warehouse_size,
    total_elapsed_time / 1000                    AS elapsed_seconds,
    compilation_time / 1000                      AS compile_seconds,
    execution_time / 1000                        AS exec_seconds,
    queued_overload_time / 1000                  AS queued_seconds,
    rows_produced,
    bytes_scanned / (1024*1024)                  AS mb_scanned
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    END_TIME_RANGE_START => DATEADD('hour', -2, CURRENT_TIMESTAMP()),
    RESULT_LIMIT         => 50
))
WHERE warehouse_name = 'NORTHBRIDGE_WH'
  AND execution_status = 'SUCCESS'
  AND total_elapsed_time > 0
ORDER BY total_elapsed_time DESC
LIMIT 10;

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
```

## Reading the Query Profile in Snowsight

After running a query:
1. Click the **Query ID** link in the results pane, or go to **Monitoring > Query History** and find the query
2. Click the **Profile** tab

The Query Profile shows a visual operator tree. Key things to look for:

**Partition Pruning**: Look at the `TableScan` node. It shows `Partitions total` and `Partitions scanned`. If scanned is much less than total, your filter is enabling partition pruning -- the single biggest performance lever in Snowflake.

**Percentage Scanned from Cache**: Shows how much data came from the warehouse cache vs remote storage.

**Spilling**: If you see `Bytes spilled to local storage` or `Bytes spilled to remote storage`, the warehouse ran out of memory. This is a sign you need a larger warehouse for this query.

## Performance Checklist

When a query is slow, work through this checklist:

| Check | How | Action |
|---|---|---|
| Missing filters? | Review WHERE clause | Add date ranges, status filters |
| Function on filter column? | Look for `YEAR()`, `UPPER()` on WHERE columns | Rewrite as SARGable range predicate |
| Partition pruning? | Query Profile > TableScan > partitions scanned vs total | Add or improve filter predicates |
| Spilling? | Query Profile > operator nodes > bytes spilled | Scale up warehouse or reduce data volume |
| Result cache available? | Check if same query ran recently | Re-run identical SQL to benefit from cache |
| Warehouse too small? | Compare elapsed time across sizes | Scale up for the workload |
