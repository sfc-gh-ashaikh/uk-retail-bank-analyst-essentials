-- =============================================================================
-- NorthBridge Bank HOL: Step 4 - Tables, Views, Cloning & File-Based Ingest
--
-- This script introduces core Snowflake object types from an analyst's
-- perspective:
--   - Tables vs Views — when to use each
--   - Creating analytical views over raw data
--   - Zero-Copy Cloning for safe exploration
--
-- As a data analyst you will typically READ from tables built by the
-- engineering team, but understanding how they work makes you a better
-- consumer of data and a better collaborator.
-- =============================================================================

USE DATABASE NORTHBRIDGE_BANK_HOL;
USE WAREHOUSE NORTHBRIDGE_WH;
USE ROLE SYSADMIN;

-- =============================================================================
-- PART A: UNDERSTANDING TABLES
-- Tables store data physically. Let's explore what we have.
-- =============================================================================

SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, ROW_COUNT, BYTES
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'RAW'
ORDER BY ROW_COUNT DESC;

SELECT * FROM RAW.CUSTOMERS LIMIT 10;

SELECT * FROM RAW.TRANSACTIONS LIMIT 10;

-- =============================================================================
-- PART B: CREATING ANALYTICAL VIEWS
--
-- Views store a query definition — not data. Every time you query a view,
-- it re-executes the underlying SQL against the latest data.
--
-- As an analyst, views let you encapsulate complex logic once and reuse it.
-- =============================================================================

-- B1: Customer summary view — useful for segmentation analysis
CREATE OR REPLACE VIEW RAW.V_CUSTOMER_SUMMARY AS
SELECT
    c.customer_id,
    TRIM(c.first_name) || ' ' || TRIM(c.last_name) AS full_name,
    c.city,
    UPPER(TRIM(c.postcode))                         AS postcode,
    c.segment,
    c.risk_rating,
    c.kyc_status,
    DATEDIFF('year', c.date_of_birth, CURRENT_DATE()) AS age_years,
    DATEDIFF('day', c.customer_since, CURRENT_DATE()) AS tenure_days,
    COUNT(DISTINCT a.account_id)                    AS account_count,
    ROUND(SUM(a.balance_gbp), 2)                    AS total_balance_gbp,
    MIN(a.opened_date)                              AS earliest_account,
    MAX(a.opened_date)                              AS latest_account
FROM RAW.CUSTOMERS   c
LEFT JOIN RAW.ACCOUNTS a ON c.customer_id = a.customer_id
    AND a.status = 'ACTIVE'
WHERE c.is_active = TRUE
GROUP BY c.customer_id, c.first_name, c.last_name, c.city, c.postcode,
         c.segment, c.risk_rating, c.kyc_status, c.date_of_birth, c.customer_since;

SELECT segment, COUNT(*) AS customers, ROUND(AVG(total_balance_gbp), 2) AS avg_balance
FROM RAW.V_CUSTOMER_SUMMARY
GROUP BY segment
ORDER BY avg_balance DESC;

-- B2: Monthly transaction trends — useful for reporting
CREATE OR REPLACE VIEW RAW.V_MONTHLY_TXN_TRENDS AS
SELECT
    DATE_TRUNC('month', t.transaction_date)         AS txn_month,
    t.debit_credit,
    t.merchant_category,
    COUNT(*)                                        AS txn_count,
    ROUND(SUM(t.amount_gbp), 2)                    AS total_amount_gbp,
    ROUND(AVG(t.amount_gbp), 2)                    AS avg_amount_gbp
FROM RAW.TRANSACTIONS t
WHERE t.status = 'CLEARED'
GROUP BY txn_month, t.debit_credit, t.merchant_category;

SELECT txn_month, debit_credit, SUM(total_amount_gbp) AS total_gbp
FROM RAW.V_MONTHLY_TXN_TRENDS
GROUP BY txn_month, debit_credit
ORDER BY txn_month DESC, debit_credit;

-- =============================================================================
-- PART C: TABLES vs VIEWS — WHEN TO USE EACH
-- =============================================================================

-- Views are always fresh — they re-read source data on every query
-- Tables are snapshots — fast to read, but stale until reloaded

-- Create a materialised summary table from our view
CREATE OR REPLACE TABLE RAW.CUSTOMER_SUMMARY_SNAPSHOT AS
SELECT *, CURRENT_TIMESTAMP() AS snapshot_at
FROM RAW.V_CUSTOMER_SUMMARY;

-- Compare: table reads are instant, view reads re-execute the JOIN + GROUP BY
-- Run each of these and compare the execution times in Query History:

-- View (re-executes)
SELECT COUNT(*) FROM RAW.V_CUSTOMER_SUMMARY;

-- Table (reads stored data)
SELECT COUNT(*) FROM RAW.CUSTOMER_SUMMARY_SNAPSHOT;

-- =============================================================================
-- PART D: ZERO-COPY CLONING
--
-- Cloning creates an instant, independent copy of a table, schema or database
-- with NO additional storage cost (until the clone diverges from the original).
--
-- For analysts, this is powerful:
--   - Experiment with data transformations without touching production
--   - Create a sandbox for ad-hoc analysis
--   - Share a point-in-time snapshot with colleagues
-- =============================================================================

CREATE TABLE IF NOT EXISTS RAW.TRANSACTIONS_SANDBOX
    CLONE RAW.TRANSACTIONS;

-- Both tables have the same row count
SELECT
    'RAW.TRANSACTIONS'         AS table_name, COUNT(*) AS row_count FROM RAW.TRANSACTIONS UNION ALL
SELECT
    'RAW.TRANSACTIONS_SANDBOX' AS table_name, COUNT(*) AS row_count FROM RAW.TRANSACTIONS_SANDBOX;

-- Safe to modify the clone — does not affect the original
DELETE FROM RAW.TRANSACTIONS_SANDBOX WHERE status = 'REJECTED';

-- Verify: original is unchanged, clone has fewer rows
SELECT
    'ORIGINAL'  AS source, COUNT(*) AS row_count FROM RAW.TRANSACTIONS UNION ALL
SELECT
    'SANDBOX'   AS source, COUNT(*) AS row_count FROM RAW.TRANSACTIONS_SANDBOX;

-- Clean up the sandbox when done
DROP TABLE IF EXISTS RAW.TRANSACTIONS_SANDBOX;
