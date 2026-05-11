# Step 6: Warehouse Scaling
**Duration: 15 minutes**

> **Wednesday Afternoon** -- The CFO's office emails Sarah with an urgent request: *"We need the transaction category breakdown for the last 30 days before the 4pm board call. The query is running too slowly on the default warehouse."* Sarah forwards the request to you: *"Scale up the warehouse, run the query, then scale back down. I want you to see how Snowflake's elastic compute works -- and understand that you only pay for the time the bigger warehouse is running."*

Snowflake separates storage from compute. You can resize a warehouse with a single command, and the change takes effect immediately. This step demonstrates how an analyst can scale compute to match the workload.

Open your `06_WAREHOUSE_SCALING` worksheet and run the following section by section:

```sql
-- =============================================================================
-- NorthBridge Bank HOL: Step 6 - Warehouse Scaling
--
-- Snowflake separates storage from compute. You can resize a warehouse
-- instantly without affecting your data, SQL or other users.
--
-- This script demonstrates:
--   1. Running a query on X-SMALL (baseline)
--   2. Scaling to MEDIUM with ALTER WAREHOUSE
--   3. Re-running with cache cleared (honest comparison)
--   4. Scaling back down — you only pay for what you use
--
-- As an analyst, understanding warehouse sizing helps you:
--   - Run heavy ad-hoc queries faster when deadlines are tight
--   - Avoid wasting credits on oversized warehouses for light work
--   - Have informed conversations with your platform team
-- =============================================================================

USE DATABASE NORTHBRIDGE_BANK_HOL;
USE WAREHOUSE NORTHBRIDGE_WH;
USE ROLE SYSADMIN;

-- =============================================================================
-- PART A: CONFIRM STARTING SIZE
-- =============================================================================

SHOW WAREHOUSES LIKE 'NORTHBRIDGE_WH';

-- =============================================================================
-- PART B: DISABLE RESULT CACHE
--
-- Snowflake caches query results for 24 hours. To get an honest benchmark
-- of warehouse performance, we disable this temporarily.
-- =============================================================================

ALTER SESSION SET USE_CACHED_RESULT = FALSE;

-- =============================================================================
-- PART C: BASELINE — RUN ON X-SMALL
--
-- This query joins 500k transactions to accounts and aggregates by multiple
-- dimensions. Note the execution time in Query History.
-- =============================================================================

SELECT
    a.account_type,
    p.product_name,
    t.debit_credit,
    t.merchant_category,
    DATE_TRUNC('month', t.transaction_date) AS txn_month,
    COUNT(*)                                AS txn_count,
    ROUND(SUM(t.amount_gbp), 2)            AS total_amount_gbp,
    ROUND(AVG(t.amount_gbp), 2)            AS avg_amount_gbp,
    ROUND(MIN(t.amount_gbp), 2)            AS min_amount_gbp,
    ROUND(MAX(t.amount_gbp), 2)            AS max_amount_gbp
FROM RAW.TRANSACTIONS t
JOIN RAW.ACCOUNTS     a ON t.account_id = a.account_id
JOIN RAW.PRODUCTS     p ON a.product_id = p.product_id
WHERE t.status = 'CLEARED'
  AND a.status = 'ACTIVE'
GROUP BY a.account_type, p.product_name, t.debit_credit,
         t.merchant_category, txn_month
ORDER BY total_amount_gbp DESC;

-- =============================================================================
-- PART D: SCALE UP TO MEDIUM
--
-- MEDIUM = 4x the compute of X-SMALL
-- The change takes effect immediately — no downtime, no data movement.
-- =============================================================================

ALTER WAREHOUSE NORTHBRIDGE_WH SET WAREHOUSE_SIZE = 'MEDIUM';

-- Suspend and resume to clear the warehouse data cache
-- (ensures we are comparing raw compute power, not cached micro-partitions)
ALTER WAREHOUSE NORTHBRIDGE_WH SUSPEND;
ALTER WAREHOUSE NORTHBRIDGE_WH RESUME;

-- =============================================================================
-- PART E: RE-RUN ON MEDIUM
--
-- Run the exact same query. Compare the execution time with Part C.
-- =============================================================================

SELECT
    a.account_type,
    p.product_name,
    t.debit_credit,
    t.merchant_category,
    DATE_TRUNC('month', t.transaction_date) AS txn_month,
    COUNT(*)                                AS txn_count,
    ROUND(SUM(t.amount_gbp), 2)            AS total_amount_gbp,
    ROUND(AVG(t.amount_gbp), 2)            AS avg_amount_gbp,
    ROUND(MIN(t.amount_gbp), 2)            AS min_amount_gbp,
    ROUND(MAX(t.amount_gbp), 2)            AS max_amount_gbp
FROM RAW.TRANSACTIONS t
JOIN RAW.ACCOUNTS     a ON t.account_id = a.account_id
JOIN RAW.PRODUCTS     p ON a.product_id = p.product_id
WHERE t.status = 'CLEARED'
  AND a.status = 'ACTIVE'
GROUP BY a.account_type, p.product_name, t.debit_credit,
         t.merchant_category, txn_month
ORDER BY total_amount_gbp DESC;

-- =============================================================================
-- PART F: SCALE BACK DOWN
--
-- Always scale back after your heavy workload completes.
-- Credits are billed per second — don't leave a large warehouse running idle.
-- =============================================================================

ALTER WAREHOUSE NORTHBRIDGE_WH SET WAREHOUSE_SIZE = 'X-SMALL';

-- Re-enable result cache
ALTER SESSION SET USE_CACHED_RESULT = TRUE;

-- =============================================================================
-- PART G: WAREHOUSE SIZING REFERENCE
-- =============================================================================

-- Quick reference: each size doubles the compute (and cost) of the previous
--
-- | Size    | Credits/Hour | Relative Speed |
-- |---------|-------------|----------------|
-- | X-SMALL | 1           | 1x (baseline)  |
-- | SMALL   | 2           | ~2x            |
-- | MEDIUM  | 4           | ~4x            |
-- | LARGE   | 8           | ~8x            |
-- | X-LARGE | 16          | ~16x           |
--
-- Rule of thumb for analysts:
--   - X-SMALL: day-to-day exploration, small queries
--   - SMALL/MEDIUM: ad-hoc analysis on large tables, dashboard refreshes
--   - LARGE+: one-off heavy aggregations, data exports
--   - Always scale back down when the heavy work is done
```

## Warehouse Sizing Reference

| Warehouse Size | Credits/Hour | Use When |
|---|---|---|
| X-SMALL | 1 | Day-to-day queries, lightweight exploration |
| SMALL | 2 | Moderate analytical workloads |
| MEDIUM | 4 | Complex joins, large aggregations, report generation |
| LARGE | 8 | Heavy analytical workloads, large data exports |

## When Would an Analyst Do This?

You just experienced it: the CFO needed results before a 4pm board call. Scaling up took one command, the query ran in a fraction of the time, and you scaled back immediately. Other scenarios:

- A monthly board report query that normally takes 5 minutes on X-SMALL needs to run before a meeting in 2 minutes -- scale up to MEDIUM, run the query, scale back.
- A data exploration session against a full year of transactions is sluggish -- scale up for the session, scale back when done.
- The key principle: scale compute to your workload, not your peak. You only pay for what you use.

> **Key Takeaway**: Snowflake's elastic compute means you never need to choose between performance and cost permanently. Scale up when you need speed, scale down when you are done.
