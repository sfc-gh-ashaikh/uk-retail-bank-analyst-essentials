-- =============================================================================
-- NorthBridge Bank HOL: Step 5 - SQL Best Practices & Anti-Patterns
--
-- This script teaches SQL patterns that every analyst should know,
-- using NorthBridge Bank's real dataset. Each section shows an
-- anti-pattern (the wrong way) and the best practice (the right way).
--
-- Topics:
--   1. SELECT * vs explicit columns
--   2. Correlated subqueries vs JOINs
--   3. UNION vs UNION ALL
--   4. Filtering early (predicate pushdown)
--   5. Avoiding functions on filter columns (SARGability)
--   6. CTEs for readability and reuse
--   7. Window functions vs self-joins
--   8. QUALIFY for deduplication
--
-- Snowflake functions used in this script:
--   ROUND(expr, scale)        — rounds a number to the specified decimal places
--   DATEADD(part, n, date)    — adds/subtracts intervals from a date
--   CURRENT_DATE()            — returns today's date (session timezone)
--   DATE_TRUNC(part, date)    — truncates a date/timestamp to the specified part
--   COUNT(*) / COUNT(col)     — counts rows; COUNT(col) excludes NULLs
--   SUM() / AVG()             — aggregate functions for totals and averages
--   ROW_NUMBER() OVER (...)   — assigns sequential numbers within a partition
--   LAG(col) OVER (...)       — accesses the previous row's value in a window
--   COALESCE(a, b)            — returns the first non-NULL value
-- =============================================================================

USE DATABASE NORTHBRIDGE_BANK_HOL;
USE WAREHOUSE NORTHBRIDGE_WH;
USE ROLE SYSADMIN;

-- =============================================================================
-- PATTERN 1: SELECT * vs EXPLICIT COLUMNS
--
-- Anti-pattern: SELECT * reads every column — wastes I/O on columnar storage
-- Best practice: Name only the columns you need
--
-- Why it matters in Snowflake: Snowflake stores data in columnar format.
-- When you SELECT *, it must read ALL columns from disk. Naming only the
-- columns you need means Snowflake skips irrelevant column files entirely.
-- =============================================================================

-- ANTI-PATTERN: reads all 16 columns when you only need 4
-- OUTPUT: all columns from cleared transactions (wasteful)
SELECT *
FROM RAW.TRANSACTIONS
WHERE status = 'CLEARED'
LIMIT 100;

-- BEST PRACTICE: reads only the 4 columns needed — less I/O, faster
-- OUTPUT: transaction_id, account_id, date, and amount for cleared transactions
SELECT transaction_id, account_id, transaction_date, amount_gbp
FROM RAW.TRANSACTIONS
WHERE status = 'CLEARED'
LIMIT 100;

-- =============================================================================
-- PATTERN 2: CORRELATED SUBQUERIES vs JOINs
--
-- Anti-pattern: correlated subquery runs once PER ROW in the outer query
-- Best practice: use a JOIN with pre-aggregation
--
-- Why it matters: with 10,000 customers, the correlated subquery executes
-- 10,000 separate scans of the ACCOUNTS table. The JOIN processes both
-- tables in a single pass.
-- =============================================================================

-- ANTI-PATTERN: correlated subquery — executes the inner query for every customer
-- OUTPUT: top 20 customers ranked by total active account balance
-- The || operator concatenates strings (first_name + space + last_name)
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    (SELECT SUM(a.balance_gbp)
     FROM RAW.ACCOUNTS a
     WHERE a.customer_id = c.customer_id
       AND a.status = 'ACTIVE') AS total_balance_gbp
FROM RAW.CUSTOMERS c
WHERE c.is_active = TRUE
ORDER BY total_balance_gbp DESC NULLS LAST
LIMIT 20;

-- BEST PRACTICE: JOIN with aggregation — single pass over both tables
-- OUTPUT: same result — top 20 customers by balance — but much faster
-- ROUND(value, 2) rounds to 2 decimal places for clean GBP display
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    ROUND(SUM(a.balance_gbp), 2)       AS total_balance_gbp
FROM RAW.CUSTOMERS c
JOIN RAW.ACCOUNTS  a ON c.customer_id = a.customer_id
WHERE c.is_active = TRUE
  AND a.status = 'ACTIVE'
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_balance_gbp DESC
LIMIT 20;

-- =============================================================================
-- PATTERN 3: UNION vs UNION ALL
--
-- Anti-pattern: UNION removes duplicates (expensive sort + dedup)
-- Best practice: UNION ALL when you know there are no duplicates
--
-- Why it matters: UNION must sort the entire result set to find duplicates.
-- When the two sets are already mutually exclusive (DEBIT vs CREDIT),
-- this sort is pure waste.
-- =============================================================================

-- ANTI-PATTERN: UNION forces a dedup step — unnecessary when sources are distinct
-- OUTPUT: count of debit transactions and count of credit transactions
SELECT 'DEBIT'  AS direction, COUNT(*) AS txn_count FROM RAW.TRANSACTIONS WHERE debit_credit = 'DEBIT'
UNION
SELECT 'CREDIT' AS direction, COUNT(*) AS txn_count FROM RAW.TRANSACTIONS WHERE debit_credit = 'CREDIT';

-- BEST PRACTICE: UNION ALL skips the dedup — the two groups are inherently exclusive
-- OUTPUT: identical result, but without the unnecessary sort operation
SELECT 'DEBIT'  AS direction, COUNT(*) AS txn_count FROM RAW.TRANSACTIONS WHERE debit_credit = 'DEBIT'
UNION ALL
SELECT 'CREDIT' AS direction, COUNT(*) AS txn_count FROM RAW.TRANSACTIONS WHERE debit_credit = 'CREDIT';

-- =============================================================================
-- PATTERN 4: FILTER EARLY — PREDICATE PUSHDOWN
--
-- Anti-pattern: join everything, then filter at the end
-- Best practice: filter in subqueries or CTEs before joining
--
-- Why it matters: Snowflake's optimizer can often push filters down, but
-- explicitly filtering in CTEs guarantees it. On 5M transactions, reducing
-- to only the last 30 days before joining cuts the dataset dramatically.
--
-- DATEADD('day', -30, CURRENT_DATE()) — Snowflake function that subtracts
-- 30 days from today. Returns a DATE value for the comparison.
-- =============================================================================

-- ANTI-PATTERN: joins ALL transactions to ALL accounts, then filters
-- OUTPUT: transaction count and total GBP by account type for last 30 days
SELECT
    a.account_type,
    COUNT(*)               AS txn_count,
    SUM(t.amount_gbp)     AS total_gbp
FROM RAW.TRANSACTIONS t
JOIN RAW.ACCOUNTS     a ON t.account_id = a.account_id
WHERE t.status = 'CLEARED'
  AND t.transaction_date >= DATEADD('day', -30, CURRENT_DATE())
  AND a.status = 'ACTIVE'
GROUP BY a.account_type;

-- BEST PRACTICE: filter each table in a CTE first, then join the smaller sets
-- OUTPUT: same result — but Snowflake processes far fewer rows in the join
-- CTE = Common Table Expression (WITH clause) — a named temporary result set
WITH recent_txns AS (
    SELECT account_id, amount_gbp
    FROM RAW.TRANSACTIONS
    WHERE status = 'CLEARED'
      AND transaction_date >= DATEADD('day', -30, CURRENT_DATE())
),
active_accounts AS (
    SELECT account_id, account_type
    FROM RAW.ACCOUNTS
    WHERE status = 'ACTIVE'
)
SELECT
    a.account_type,
    COUNT(*)               AS txn_count,
    SUM(t.amount_gbp)     AS total_gbp
FROM recent_txns      t
JOIN active_accounts  a ON t.account_id = a.account_id
GROUP BY a.account_type;

-- =============================================================================
-- PATTERN 5: SARGable FILTERS — DON'T WRAP COLUMNS IN FUNCTIONS
--
-- Anti-pattern: wrapping a column in a function prevents partition pruning
-- Best practice: apply the function to the literal/parameter instead
--
-- Why it matters in Snowflake: Snowflake stores min/max metadata per
-- micro-partition. A range predicate on the raw column (e.g. >= and <)
-- lets Snowflake skip entire partitions that fall outside the range.
-- Wrapping the column in DATE_TRUNC() hides this from the optimizer.
--
-- DATE_TRUNC('month', date) — truncates to the first day of that month
-- DATEADD('month', -1, date) — subtracts one month from the given date
-- =============================================================================

-- ANTI-PATTERN: DATE_TRUNC on the column defeats micro-partition pruning
-- OUTPUT: count of transactions from last month (scans ALL partitions)
SELECT COUNT(*)
FROM RAW.TRANSACTIONS
WHERE DATE_TRUNC('month', transaction_date) = DATE_TRUNC('month', DATEADD('month', -1, CURRENT_DATE()));

-- BEST PRACTICE: range predicate on the raw column — Snowflake prunes partitions
-- OUTPUT: same count, but only scans partitions overlapping the date range
SELECT COUNT(*)
FROM RAW.TRANSACTIONS
WHERE transaction_date >= DATE_TRUNC('month', DATEADD('month', -1, CURRENT_DATE()))
  AND transaction_date <  DATE_TRUNC('month', CURRENT_DATE());

-- =============================================================================
-- PATTERN 6: CTEs FOR READABILITY AND REUSE
--
-- Anti-pattern: deeply nested subqueries that are hard to read and debug
-- Best practice: CTEs (WITH clause) that read like a step-by-step recipe
--
-- Why it matters: in regulated banking, queries must be auditable. CTEs
-- let reviewers (and your future self) understand each logical step.
-- Each CTE can be tested independently by running just that part.
-- =============================================================================

-- ANTI-PATTERN: nested subqueries — hard to read, hard to debug
-- OUTPUT: average total balance per customer segment (MASS_MARKET, AFFLUENT, etc.)
SELECT segment, avg_balance FROM (
    SELECT c.segment, AVG(totals.total_balance) AS avg_balance FROM (
        SELECT customer_id, SUM(balance_gbp) AS total_balance
        FROM RAW.ACCOUNTS WHERE status = 'ACTIVE' GROUP BY customer_id
    ) totals
    JOIN RAW.CUSTOMERS c ON totals.customer_id = c.customer_id
    GROUP BY c.segment
) final
ORDER BY avg_balance DESC;

-- BEST PRACTICE: CTEs — each step is named and self-documenting
-- OUTPUT: same result — avg balance and customer count per segment
-- Step 1 (account_totals): sum each customer's active account balances
-- Step 2 (segment_averages): join to customers, group by segment, compute averages
WITH account_totals AS (
    SELECT customer_id, SUM(balance_gbp) AS total_balance
    FROM RAW.ACCOUNTS
    WHERE status = 'ACTIVE'
    GROUP BY customer_id
),
segment_averages AS (
    SELECT
        c.segment,
        ROUND(AVG(a.total_balance), 2) AS avg_balance,
        COUNT(*)                        AS customer_count
    FROM account_totals a
    JOIN RAW.CUSTOMERS  c ON a.customer_id = c.customer_id
    GROUP BY c.segment
)
SELECT segment, avg_balance, customer_count
FROM segment_averages
ORDER BY avg_balance DESC;

-- =============================================================================
-- PATTERN 7: WINDOW FUNCTIONS vs SELF-JOINS
--
-- Anti-pattern: self-join to rank or compare rows within a group
-- Best practice: window functions — single pass, no self-join
--
-- Key Snowflake window functions:
--   ROW_NUMBER() OVER (PARTITION BY x ORDER BY y)
--     — assigns 1, 2, 3... within each partition (no ties)
--   RANK() OVER (...) — like ROW_NUMBER but ties get the same rank
--   LAG(col, n) OVER (...) — returns the value from n rows back
--   LEAD(col, n) OVER (...) — returns the value from n rows ahead
--   SUM(col) OVER (ORDER BY x ROWS UNBOUNDED PRECEDING) — running total
-- =============================================================================

-- ANTI-PATTERN: self-join to find the highest-balance account per customer
-- OUTPUT: top 20 customers with their single highest-balance account
-- Problem: if two accounts have the exact same balance, this returns duplicates
SELECT
    a.customer_id,
    a.account_id,
    a.account_type,
    a.balance_gbp
FROM RAW.ACCOUNTS a
JOIN (
    SELECT customer_id, MAX(balance_gbp) AS max_balance
    FROM RAW.ACCOUNTS
    WHERE status = 'ACTIVE'
    GROUP BY customer_id
) m ON a.customer_id = m.customer_id AND a.balance_gbp = m.max_balance
WHERE a.status = 'ACTIVE'
ORDER BY a.balance_gbp DESC
LIMIT 20;

-- BEST PRACTICE: ROW_NUMBER to find the highest-balance account per customer
-- OUTPUT: exactly one row per customer — their highest-balance active account
-- ROW_NUMBER() guarantees one winner per partition even with tied values
SELECT customer_id, account_id, account_type, balance_gbp
FROM (
    SELECT
        customer_id,
        account_id,
        account_type,
        balance_gbp,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY balance_gbp DESC) AS rn
    FROM RAW.ACCOUNTS
    WHERE status = 'ACTIVE'
)
WHERE rn = 1
ORDER BY balance_gbp DESC
LIMIT 20;

-- ANTI-PATTERN: self-join to compute running total
-- OUTPUT: daily transaction totals with a cumulative running total over 30 days
-- Problem: the triangular join (d2.date <= d1.date) scans O(n²) row combinations
SELECT
    d1.transaction_date,
    d1.debit_credit,
    d1.daily_total,
    SUM(d2.daily_total) AS running_total
FROM (
    SELECT transaction_date, debit_credit, SUM(amount_gbp) AS daily_total
    FROM RAW.TRANSACTIONS
    WHERE status = 'CLEARED'
      AND transaction_date >= DATEADD('day', -30, CURRENT_DATE())
    GROUP BY transaction_date, debit_credit
) d1
JOIN (
    SELECT transaction_date, debit_credit, SUM(amount_gbp) AS daily_total
    FROM RAW.TRANSACTIONS
    WHERE status = 'CLEARED'
      AND transaction_date >= DATEADD('day', -30, CURRENT_DATE())
    GROUP BY transaction_date, debit_credit
) d2 ON d1.debit_credit = d2.debit_credit AND d2.transaction_date <= d1.transaction_date
GROUP BY d1.transaction_date, d1.debit_credit, d1.daily_total
ORDER BY d1.transaction_date, d1.debit_credit;

-- BEST PRACTICE: Running total using SUM() OVER() window function
-- OUTPUT: same result — daily totals with cumulative running total
-- SUM(SUM(x)) OVER (...) — the inner SUM is the GROUP BY aggregate,
-- the outer SUM with OVER computes the running total across the window
-- ROWS UNBOUNDED PRECEDING means "from the first row up to the current row"
SELECT
    transaction_date,
    debit_credit,
    SUM(amount_gbp)                                                     AS daily_total,
    SUM(SUM(amount_gbp)) OVER (PARTITION BY debit_credit
                                ORDER BY transaction_date
                                ROWS UNBOUNDED PRECEDING)               AS running_total
FROM RAW.TRANSACTIONS
WHERE status = 'CLEARED'
  AND transaction_date >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY transaction_date, debit_credit
ORDER BY transaction_date, debit_credit;

-- =============================================================================
-- PATTERN 8: QUALIFY FOR DEDUPLICATION
--
-- QUALIFY is Snowflake's filter clause for window functions.
-- It replaces the nested subquery pattern for deduplication.
--
-- QUALIFY works like WHERE (filters rows) but runs AFTER window functions
-- are computed. It is unique to Snowflake (not standard SQL) and eliminates
-- the need for wrapping your query in a subquery just to filter on ROW_NUMBER.
-- =============================================================================

-- ANTI-PATTERN: nested subquery to deduplicate
-- OUTPUT: one row per customer — their highest-balance active account
-- Requires wrapping the entire query in a subquery just to filter rn = 1
SELECT * FROM (
    SELECT
        customer_id,
        account_id,
        balance_gbp,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY balance_gbp DESC) AS rn
    FROM RAW.ACCOUNTS
    WHERE status = 'ACTIVE'
)
WHERE rn = 1
LIMIT 10;

-- BEST PRACTICE: QUALIFY — cleaner, no nesting required
-- OUTPUT: same result — one row per customer, highest balance
-- QUALIFY filters on window function results directly, no subquery needed
SELECT
    customer_id,
    account_id,
    balance_gbp
FROM RAW.ACCOUNTS
WHERE status = 'ACTIVE'
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY balance_gbp DESC) = 1
ORDER BY balance_gbp DESC
LIMIT 10;
