# Step 5: SQL Best Practices and Anti-Patterns
**Duration: 25 minutes**

> **Wednesday Morning** -- Sarah forwards you a set of queries from the legacy reporting system that were migrated as-is. A senior analyst, **James Okafor**, reviewed them during a code review and flagged eight anti-patterns. He sends you a message: *"These all produce correct results, but they are slow, hard to read, or both. Your task: rewrite each one following Snowflake best practices. Run both versions and compare execution times -- that is the evidence we need to justify the cleanup to the team."*

Writing correct SQL is one thing. Writing efficient SQL is another. In this step you will work through eight common patterns, each demonstrated with an anti-pattern and the corresponding best practice.

Open your `05_SQL_PATTERNS` worksheet and run the following section by section:

```sql
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
-- =============================================================================

USE DATABASE NORTHBRIDGE_BANK_HOL;
USE WAREHOUSE NORTHBRIDGE_WH;
USE ROLE SYSADMIN;

-- =============================================================================
-- PATTERN 1: SELECT * vs EXPLICIT COLUMNS
--
-- Anti-pattern: SELECT * reads every column — wastes I/O on columnar storage
-- Best practice: Name only the columns you need
-- =============================================================================

-- ANTI-PATTERN: reads all 16 columns when you only need 4
SELECT *
FROM RAW.TRANSACTIONS
WHERE status = 'CLEARED'
LIMIT 100;

-- BEST PRACTICE: reads only the 4 columns needed — less I/O, faster
SELECT transaction_id, account_id, transaction_date, amount_gbp
FROM RAW.TRANSACTIONS
WHERE status = 'CLEARED'
LIMIT 100;

-- =============================================================================
-- PATTERN 2: CORRELATED SUBQUERIES vs JOINs
--
-- Anti-pattern: correlated subquery runs once PER ROW in the outer query
-- Best practice: use a JOIN with pre-aggregation
-- =============================================================================

-- ANTI-PATTERN: correlated subquery — executes the inner query for every customer
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
-- =============================================================================

-- ANTI-PATTERN: UNION forces a dedup step — unnecessary when sources are distinct
SELECT 'DEBIT'  AS direction, COUNT(*) AS txn_count FROM RAW.TRANSACTIONS WHERE debit_credit = 'DEBIT'
UNION
SELECT 'CREDIT' AS direction, COUNT(*) AS txn_count FROM RAW.TRANSACTIONS WHERE debit_credit = 'CREDIT';

-- BEST PRACTICE: UNION ALL skips the dedup — the two groups are inherently exclusive
SELECT 'DEBIT'  AS direction, COUNT(*) AS txn_count FROM RAW.TRANSACTIONS WHERE debit_credit = 'DEBIT'
UNION ALL
SELECT 'CREDIT' AS direction, COUNT(*) AS txn_count FROM RAW.TRANSACTIONS WHERE debit_credit = 'CREDIT';

-- =============================================================================
-- PATTERN 4: FILTER EARLY — PREDICATE PUSHDOWN
--
-- Anti-pattern: join everything, then filter at the end
-- Best practice: filter in subqueries or CTEs before joining
-- =============================================================================

-- ANTI-PATTERN: joins ALL transactions to ALL accounts, then filters
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
-- =============================================================================

-- ANTI-PATTERN: DATE_TRUNC on the column defeats micro-partition pruning
SELECT COUNT(*)
FROM RAW.TRANSACTIONS
WHERE DATE_TRUNC('month', transaction_date) = DATE_TRUNC('month', DATEADD('month', -1, CURRENT_DATE()));

-- BEST PRACTICE: range predicate on the raw column — Snowflake prunes partitions
SELECT COUNT(*)
FROM RAW.TRANSACTIONS
WHERE transaction_date >= DATE_TRUNC('month', DATEADD('month', -1, CURRENT_DATE()))
  AND transaction_date <  DATE_TRUNC('month', CURRENT_DATE());

-- =============================================================================
-- PATTERN 6: CTEs FOR READABILITY AND REUSE
--
-- Anti-pattern: deeply nested subqueries that are hard to read and debug
-- Best practice: CTEs (WITH clause) that read like a step-by-step recipe
-- =============================================================================

-- ANTI-PATTERN: nested subqueries — hard to read, hard to debug
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
-- =============================================================================

-- ANTI-PATTERN: self-join to find the highest-balance account per customer
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

-- BEST PRACTICE: Running total of daily transaction volume
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
-- =============================================================================

-- ANTI-PATTERN: nested subquery to deduplicate
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
SELECT
    customer_id,
    account_id,
    balance_gbp
FROM RAW.ACCOUNTS
WHERE status = 'ACTIVE'
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY balance_gbp DESC) = 1
ORDER BY balance_gbp DESC
LIMIT 10;
```

### Pattern 1: SELECT * vs Explicit Columns

`SELECT *` reads every column, including those you do not need. On wide tables this wastes I/O and memory. It also breaks downstream code if columns are added or renamed. Always name the columns you need.

### Pattern 2: Correlated Subqueries vs JOINs

A correlated subquery executes once per row in the outer query. A JOIN with GROUP BY allows the optimiser to process both tables in a single pass. On 10,000 customers, the difference is significant.

### Pattern 3: UNION vs UNION ALL

`UNION` sorts and deduplicates the result set. `UNION ALL` does not. If you know duplicates are acceptable (or impossible), use `UNION ALL` to avoid the unnecessary sort.

### Pattern 4: Filter Early (Predicate Pushdown)

Apply filters as early as possible -- ideally in the WHERE clause of the innermost query. This reduces the number of rows flowing through joins and aggregations.

### Pattern 5: SARGable Filters

A **SARGable** (Search ARGument able) filter allows the engine to use partition pruning. Wrapping a column in a function (`YEAR()`, `MONTH()`, `UPPER()`) prevents the optimiser from pruning partitions efficiently. Use range predicates on raw column values instead.

### Pattern 6: CTEs for Readability

CTEs (Common Table Expressions) break complex logic into named, readable steps. Each CTE is a self-contained unit that can be tested independently. This is especially important in banking where queries must be auditable and explainable.

### Pattern 7: Window Functions vs Self-Joins

Window functions (`LAG`, `LEAD`, `ROW_NUMBER`, `RANK`, `SUM() OVER`) let you reference other rows in the result set without self-joining. They are more readable, more efficient, and less error-prone than the self-join equivalent.

### Pattern 8: QUALIFY for Deduplication

`QUALIFY` is Snowflake's clause for filtering on window function results -- analogous to `HAVING` for aggregations. It eliminates the need for a subquery wrapper, making deduplication queries shorter and clearer.

> **Summary**: Run both the anti-pattern and best-practice versions of each query. Compare execution times in the Query History panel. The differences become more pronounced as data volumes grow.
