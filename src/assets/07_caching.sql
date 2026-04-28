-- =============================================================================
-- NorthBridge Bank HOL: Step 7 - Using Caching Effectively
--
-- Snowflake has three layers of caching that accelerate queries:
--
--   1. RESULT CACHE    — 24-hour cache of exact query results (free, no warehouse)
--   2. WAREHOUSE CACHE — local SSD cache of micro-partitions on active warehouse
--   3. METADATA CACHE  — row counts, min/max per column (instant, no warehouse)
--
-- Understanding caching lets you:
--   - Get instant answers when re-running reports
--   - Know when to disable caching for honest benchmarks
--   - Recognise when Snowflake is serving cached vs computed results
-- =============================================================================

USE DATABASE NORTHBRIDGE_BANK_HOL;
USE WAREHOUSE NORTHBRIDGE_WH;
USE ROLE SYSADMIN;

-- =============================================================================
-- PART A: METADATA CACHE — INSTANT ANSWERS WITHOUT A WAREHOUSE
--
-- Snowflake maintains metadata about every table: row count, min/max values,
-- NULL counts. Queries that can be answered from metadata alone do not need
-- a running warehouse and return instantly.
-- =============================================================================

-- These queries are answered from metadata — check Query History for 0 bytes scanned
SELECT COUNT(*) FROM RAW.TRANSACTIONS;

SELECT MIN(transaction_date), MAX(transaction_date) FROM RAW.TRANSACTIONS;

SELECT COUNT(*) FROM RAW.CUSTOMERS;

-- This query CANNOT be answered from metadata — it needs to scan data
SELECT COUNT(DISTINCT merchant_category) FROM RAW.TRANSACTIONS;

-- =============================================================================
-- PART B: RESULT CACHE — IDENTICAL QUERIES RETURN INSTANTLY
--
-- When you run the exact same query (same SQL text, same data, same role),
-- Snowflake returns the cached result without using any warehouse compute.
-- The cache lasts 24 hours or until the underlying data changes.
-- =============================================================================

-- First run: warehouse executes the query (check bytes scanned in Query History)
SELECT
    merchant_category,
    COUNT(*)               AS txn_count,
    ROUND(SUM(amount_gbp), 2) AS total_gbp
FROM RAW.TRANSACTIONS
WHERE status = 'CLEARED'
  AND debit_credit = 'DEBIT'
GROUP BY merchant_category
ORDER BY total_gbp DESC;

-- Second run: IDENTICAL query — result cache hit (0 bytes scanned, instant)
SELECT
    merchant_category,
    COUNT(*)               AS txn_count,
    ROUND(SUM(amount_gbp), 2) AS total_gbp
FROM RAW.TRANSACTIONS
WHERE status = 'CLEARED'
  AND debit_credit = 'DEBIT'
GROUP BY merchant_category
ORDER BY total_gbp DESC;

-- =============================================================================
-- PART C: WHAT BREAKS THE RESULT CACHE?
--
-- The result cache is invalidated when:
--   1. The underlying data changes (INSERT, UPDATE, DELETE)
--   2. The SQL text changes (even a single character difference)
--   3. The session setting USE_CACHED_RESULT is set to FALSE
--   4. 24 hours have elapsed since the cached result was generated
-- =============================================================================

-- Same logic, different formatting — this is a CACHE MISS (SQL text differs)
SELECT merchant_category,
       COUNT(*) AS txn_count,
       ROUND(SUM(amount_gbp),2) AS total_gbp
FROM RAW.TRANSACTIONS
WHERE status='CLEARED' AND debit_credit='DEBIT'
GROUP BY merchant_category
ORDER BY total_gbp DESC;

-- Adding a comment also changes the SQL text — this is a CACHE MISS
SELECT
    merchant_category,
    COUNT(*)               AS txn_count,
    ROUND(SUM(amount_gbp), 2) AS total_gbp
FROM RAW.TRANSACTIONS
WHERE status = 'CLEARED'
  AND debit_credit = 'DEBIT'
GROUP BY merchant_category
ORDER BY total_gbp DESC
-- added a comment
;

-- Adding LIMIT changes the query — CACHE MISS
SELECT
    merchant_category,
    COUNT(*)               AS txn_count,
    ROUND(SUM(amount_gbp), 2) AS total_gbp
FROM RAW.TRANSACTIONS
WHERE status = 'CLEARED'
  AND debit_credit = 'DEBIT'
GROUP BY merchant_category
ORDER BY total_gbp DESC
LIMIT 5;

-- =============================================================================
-- PART D: NON-DETERMINISTIC FUNCTIONS DEFEAT THE RESULT CACHE
--
-- Queries containing CURRENT_DATE(), CURRENT_TIMESTAMP(), RANDOM(), UUID etc.
-- are never cached because the result would be different on each execution.
-- =============================================================================

-- This will NEVER be served from the result cache
SELECT
    CURRENT_DATE()         AS report_date,
    merchant_category,
    COUNT(*)               AS txn_count,
    ROUND(SUM(amount_gbp), 2) AS total_gbp
FROM RAW.TRANSACTIONS
WHERE status = 'CLEARED'
  AND debit_credit = 'DEBIT'
GROUP BY merchant_category
ORDER BY total_gbp DESC;

-- Fix: use a literal date instead of CURRENT_DATE() if the value won't change
SELECT
    '2026-04-28'::DATE     AS report_date,
    merchant_category,
    COUNT(*)               AS txn_count,
    ROUND(SUM(amount_gbp), 2) AS total_gbp
FROM RAW.TRANSACTIONS
WHERE status = 'CLEARED'
  AND debit_credit = 'DEBIT'
GROUP BY merchant_category
ORDER BY total_gbp DESC;

-- Run the literal-date version again — CACHE HIT (identical SQL, deterministic)
SELECT
    '2026-04-28'::DATE     AS report_date,
    merchant_category,
    COUNT(*)               AS txn_count,
    ROUND(SUM(amount_gbp), 2) AS total_gbp
FROM RAW.TRANSACTIONS
WHERE status = 'CLEARED'
  AND debit_credit = 'DEBIT'
GROUP BY merchant_category
ORDER BY total_gbp DESC;

-- =============================================================================
-- PART E: WAREHOUSE CACHE (LOCAL DISK CACHE)
--
-- When a warehouse reads data from Snowflake's cloud storage, it caches
-- the micro-partitions on local SSD. Subsequent queries that read the same
-- partitions benefit from faster I/O.
--
-- The warehouse cache is:
--   - Tied to the running warehouse (lost on suspend)
--   - Shared across all queries on that warehouse
--   - Invisible in the UI but visible in Query Profile (Remote vs Local I/O)
-- =============================================================================

-- Disable result cache to isolate warehouse cache effects
ALTER SESSION SET USE_CACHED_RESULT = FALSE;

-- First run: reads from remote storage (cold warehouse)
SELECT
    account_type,
    COUNT(*)               AS txn_count,
    SUM(amount_gbp)        AS total_gbp
FROM RAW.TRANSACTIONS t
JOIN RAW.ACCOUNTS     a ON t.account_id = a.account_id
WHERE t.status = 'CLEARED'
GROUP BY account_type;

-- Second run: same data, warehouse cache is warm — check Query Profile
-- Look for "Percentage scanned from cache" in the TableScan operator
SELECT
    account_type,
    COUNT(*)               AS txn_count,
    SUM(amount_gbp)        AS total_gbp
FROM RAW.TRANSACTIONS t
JOIN RAW.ACCOUNTS     a ON t.account_id = a.account_id
WHERE t.status = 'CLEARED'
GROUP BY account_type;

-- Suspend + resume clears the warehouse cache
ALTER WAREHOUSE NORTHBRIDGE_WH SUSPEND;
ALTER WAREHOUSE NORTHBRIDGE_WH RESUME;

-- Third run: warehouse cache is cold again — should be slower than second run
SELECT
    account_type,
    COUNT(*)               AS txn_count,
    SUM(amount_gbp)        AS total_gbp
FROM RAW.TRANSACTIONS t
JOIN RAW.ACCOUNTS     a ON t.account_id = a.account_id
WHERE t.status = 'CLEARED'
GROUP BY account_type;

-- Re-enable result cache
ALTER SESSION SET USE_CACHED_RESULT = TRUE;

-- =============================================================================
-- PART F: CACHING SUMMARY
-- =============================================================================
--
-- | Cache Layer      | Cost       | Persists?              | Best For                  |
-- |-----------------|------------|------------------------|---------------------------|
-- | Metadata Cache   | Free       | Always                 | COUNT(*), MIN/MAX         |
-- | Result Cache     | Free       | 24 hrs (if data static)| Repeated identical queries|
-- | Warehouse Cache  | WH running | Until suspend          | Re-scanning same data     |
--
-- Tips for analysts:
--   1. Run the same query twice — the second run is free (result cache)
--   2. Don't use CURRENT_DATE() in reports if the date won't change mid-session
--   3. If benchmarking, disable result cache: ALTER SESSION SET USE_CACHED_RESULT = FALSE
--   4. Keep your warehouse running between related queries to benefit from warm cache
--   5. Use COUNT(*) and MIN/MAX for quick checks — they're answered from metadata
