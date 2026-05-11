# Step 7: Using Caching Effectively
**Duration: 20 minutes**

> **Thursday Morning** -- Your colleague **Tom Hargreaves** messages you: *"I ran the same query twice and the second time it came back instantly -- zero seconds. But when I changed one word in the WHERE clause, it took 3 seconds again. Is Snowflake caching results? How does that work?"* You investigate and discover Snowflake's three cache layers. Sarah encourages you to document what you find: *"Every analyst on the team should understand when they are getting cached results versus fresh scans. It affects both speed and cost."*

Snowflake uses three layers of caching to avoid redundant work. Understanding these layers helps you write queries that benefit from caching -- and recognise when cached results might give you stale data.

## The Three Cache Layers

| Cache Layer | What It Stores | Lifetime | Invalidated When |
|---|---|---|---|
| **Metadata Cache** | Row counts, min/max values, NULL counts | Always available | Underlying data changes |
| **Result Cache** | Full query result sets | 24 hours | Underlying data changes, or `USE_CACHED_RESULT = FALSE` |
| **Warehouse Cache** | Raw data micro-partitions in SSD/memory | While warehouse is active | Warehouse suspends, or data changes |

Open your `07_CACHING` worksheet and run the following section by section:

```sql
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

-- Fix: use a literal date instead of CURRENT_DATE() so the result is cacheable.
-- Type today's date as a string literal (e.g. '2026-05-07') — do NOT use CURRENT_DATE()
-- The example below uses a session variable so the script works on any day:
SET report_dt = CURRENT_DATE()::VARCHAR;

SELECT
    $report_dt::DATE       AS report_date,
    merchant_category,
    COUNT(*)               AS txn_count,
    ROUND(SUM(amount_gbp), 2) AS total_gbp
FROM RAW.TRANSACTIONS
WHERE status = 'CLEARED'
  AND debit_credit = 'DEBIT'
GROUP BY merchant_category
ORDER BY total_gbp DESC;

-- Run the same query again — CACHE HIT (same SQL text, deterministic expression)
SELECT
    $report_dt::DATE       AS report_date,
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
```

## Exercises Walkthrough

**Exercise 1: Metadata Cache** -- `COUNT(*)` returns instantly. Snowflake does not scan any data; the row count is stored in the table's metadata.

**Exercise 2: Result Cache** -- Run the same query twice. The second run returns instantly -- Snowflake recognised the identical SQL text and served the result from cache. No credits consumed.

**Exercise 3: Cache Miss** -- Changing even one character in the SQL text (filter value, formatting, adding a comment) causes a cache miss.

**Exercise 4: Non-Deterministic Functions** -- Queries containing `CURRENT_DATE()`, `CURRENT_TIMESTAMP()`, `RANDOM()` etc. are never cached.

**Exercise 5: Warehouse Cache** -- With result cache disabled, the second run is faster because the warehouse cached micro-partitions in local SSD/memory. Suspending the warehouse clears this cache.

## Caching Summary

| Scenario | Cache Used | Credits Consumed |
|---|---|---|
| `COUNT(*)` with no filter | Metadata | None |
| Exact same query, data unchanged | Result | None |
| Same query, non-deterministic function | None | Yes |
| Same query, result cache disabled | Warehouse (if warm) | Yes (reduced) |
| Same query, warehouse suspended/resumed | None | Yes (full scan) |

> **Analyst Tip**: If you are running the same analytical query repeatedly during an exploration session, caching saves you time and credits. But if you need fresh results (e.g. after an upstream data load), either wait for the cache to invalidate or disable it explicitly with `ALTER SESSION SET USE_CACHED_RESULT = FALSE`.
