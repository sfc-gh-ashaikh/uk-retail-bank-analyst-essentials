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
CREATE OR REPLACE VIEW STAGING.V_CUSTOMER_SUMMARY AS
WITH account_agg AS (
    SELECT
        customer_id,
        COUNT(DISTINCT account_id) AS num_accounts,
        ROUND(SUM(balance_gbp), 2) AS total_balance_gbp,
        MIN(opened_date) AS earliest_account,
        MAX(opened_date) AS latest_account
    FROM RAW.ACCOUNTS
    WHERE status = 'ACTIVE'
    GROUP BY customer_id
),
loan_agg AS (
    SELECT
        customer_id,
        COUNT(DISTINCT loan_id) AS num_loans,
        ROUND(SUM(outstanding_balance_gbp), 2) AS total_loan_exposure_gbp
    FROM RAW.LOANS
    GROUP BY customer_id
)
SELECT
    c.customer_id,
    TRIM(c.first_name) || ' ' || TRIM(c.last_name) AS customer_name,
    c.city,
    UPPER(TRIM(c.postcode))                         AS postcode,
    c.segment,
    c.region,
    c.risk_rating,
    c.kyc_status,
    DATEDIFF('year', c.date_of_birth, CURRENT_DATE()) AS age_years,
    DATEDIFF('day', c.customer_since, CURRENT_DATE()) AS tenure_days,
    COALESCE(a.num_accounts, 0)                     AS num_accounts,
    COALESCE(a.total_balance_gbp, 0)                AS total_balance_gbp,
    COALESCE(l.num_loans, 0)                        AS num_loans,
    COALESCE(l.total_loan_exposure_gbp, 0)          AS total_loan_exposure_gbp,
    a.earliest_account,
    a.latest_account
FROM RAW.CUSTOMERS   c
LEFT JOIN account_agg a ON c.customer_id = a.customer_id
LEFT JOIN loan_agg    l ON c.customer_id = l.customer_id
WHERE c.is_active = TRUE;

SELECT segment, COUNT(*) AS customers, ROUND(AVG(total_balance_gbp), 2) AS avg_balance
FROM STAGING.V_CUSTOMER_SUMMARY
GROUP BY segment
ORDER BY avg_balance DESC;

-- B2: Monthly transaction trends — useful for reporting
CREATE OR REPLACE VIEW STAGING.V_MONTHLY_TXN_TRENDS AS
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
FROM STAGING.V_MONTHLY_TXN_TRENDS
GROUP BY txn_month, debit_credit
ORDER BY txn_month DESC, debit_credit;

-- =============================================================================
-- PART C: TABLES vs VIEWS — WHEN TO USE EACH
-- =============================================================================

-- Views are always fresh — they re-read source data on every query
-- Tables are snapshots — fast to read, but stale until reloaded

-- Create a materialised summary table from our view
CREATE OR REPLACE TABLE STAGING.CUSTOMER_SUMMARY_SNAPSHOT AS
SELECT *, CURRENT_TIMESTAMP() AS snapshot_at
FROM STAGING.V_CUSTOMER_SUMMARY;

-- Compare: table reads are instant, view reads re-execute the JOIN + GROUP BY
-- Run each of these and compare the execution times in Query History:

-- View (re-executes)
SELECT COUNT(*) FROM STAGING.V_CUSTOMER_SUMMARY;

-- Table (reads stored data)
SELECT COUNT(*) FROM STAGING.CUSTOMER_SUMMARY_SNAPSHOT;

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

CREATE TABLE IF NOT EXISTS RAW.TRANSACTIONS_DEV
    CLONE RAW.TRANSACTIONS;

-- Both tables have the same row count
SELECT
    'RAW.TRANSACTIONS'     AS table_name, COUNT(*) AS row_count FROM RAW.TRANSACTIONS UNION ALL
SELECT
    'RAW.TRANSACTIONS_DEV' AS table_name, COUNT(*) AS row_count FROM RAW.TRANSACTIONS_DEV;

-- Safe to modify the clone — does not affect the original
DELETE FROM RAW.TRANSACTIONS_DEV WHERE status = 'REJECTED';

-- Verify: original is unchanged, clone has fewer rows
SELECT
    'ORIGINAL'  AS source, COUNT(*) AS row_count FROM RAW.TRANSACTIONS UNION ALL
SELECT
    'DEV'       AS source, COUNT(*) AS row_count FROM RAW.TRANSACTIONS_DEV;

-- Clean up the dev clone when done
DROP TABLE IF EXISTS RAW.TRANSACTIONS_DEV;
