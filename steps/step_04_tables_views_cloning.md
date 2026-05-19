# Step 4: Tables, Views, Cloning and File-Based Ingest
**Duration: 25 minutes**

> **Tuesday Afternoon** -- Two things land in your inbox. First, the PRA has published updated **LCR run-off rates** and Sarah asks you to load the CSV into Snowflake. Second, the Risk team has a quarterly review next week and needs two new views: a **customer summary** (balances and loan exposure per customer) and a **monthly transaction trends** view. Sarah adds: *"This is your first deliverable -- make sure the views work before you move on. And clone the transactions table so you have a sandbox to experiment in without touching production data."*

In this step you will load reference data from a CSV file, create analytical views, and explore zero-copy cloning.

## Loading Reference Data from CSV

Not all data arrives via pipelines. Reference data -- like regulatory rate tables published by the PRA -- arrives as files.

Sarah's email: *"The PRA published revised LCR run-off rates this morning. The data engineers are busy, so I need you to load this yourself. The file is lcr_runoff_rates.csv -- 25 rows of prescribed stress rates. Use a stage and COPY INTO so the process is repeatable when rates change next year."*

[Download lcr_runoff_rates.csv](assets/lcr_runoff_rates.csv) to your local machine.

Open your `03_FILE_LOAD` worksheet and run the following section by section:

```sql
-- =============================================================================
-- NorthBridge Bank HOL: Step 4 - Loading Reference Data from a CSV File
--
-- This script demonstrates the SQL path for loading the PRA LCR run-off
-- rate reference file into Snowflake using:
--   1. An internal named stage
--   2. A CSV file format
--   3. COPY INTO
--
-- The Snowsight Load Data wizard (UI path) is described in the guide.
-- Use this SQL path to understand the underlying mechanics.
-- =============================================================================

USE DATABASE NORTHBRIDGE_BANK_HOL;
USE SCHEMA RAW;
USE WAREHOUSE NORTHBRIDGE_WH;
USE ROLE SYSADMIN;

-- =============================================================================
-- STEP 4A: Create the target table for LCR run-off rates
-- =============================================================================
CREATE TABLE IF NOT EXISTS RAW.LCR_RUNOFF_RATES (
    rate_id                 NUMBER AUTOINCREMENT PRIMARY KEY,
    liability_category      VARCHAR(60)     NOT NULL,
    sub_category            VARCHAR(60)     NOT NULL,
    run_off_rate_pct        NUMBER(6,2)     NOT NULL,
    inflow_rate_pct         NUMBER(6,2),
    effective_date          DATE            NOT NULL,
    regulatory_basis        VARCHAR(100)    NOT NULL,
    notes                   VARCHAR(500),
    loaded_at               TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    loaded_by               VARCHAR(100)    DEFAULT CURRENT_USER()
);

-- =============================================================================
-- STEP 4B: Create an internal named stage
--
-- A stage is Snowflake's staging area — a landing zone where files are held
-- before being loaded into tables. An internal stage stores files within
-- your Snowflake account (no external cloud storage required).
-- =============================================================================
CREATE STAGE IF NOT EXISTS RAW.NORTHBRIDGE_REF_STAGE
    COMMENT = 'Internal stage for NorthBridge Bank reference data files';

-- =============================================================================
-- STEP 4C: Create a CSV file format
--
-- A file format tells Snowflake how to parse the uploaded file:
--   - What delimiter separates columns (comma)
--   - Whether there is a header row to skip
--   - How NULLs are represented in the file
--   - How to handle quoted strings
-- =============================================================================
CREATE FILE FORMAT IF NOT EXISTS RAW.CSV_HEADER_FORMAT
    TYPE                = 'CSV'
    FIELD_DELIMITER     = ','
    RECORD_DELIMITER    = '\n'
    SKIP_HEADER         = 1
    NULL_IF             = ('NULL', 'null', '')
    EMPTY_FIELD_AS_NULL = TRUE
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE          = TRUE
    COMMENT             = 'Standard CSV format with header row — used for reference data files';

-- =============================================================================
-- STEP 4D: Upload the file via Snowsight (UI Path)
--
-- In Snowsight:
--   1. Click on the stage: NORTHBRIDGE_BANK_HOL > RAW > Stages > NORTHBRIDGE_REF_STAGE
--   2. Click the "+ Files" button in the top right
--   3. Select lcr_runoff_rates.csv from your assets folder
--   4. Click "Upload"
--
-- Alternatively, if using SnowSQL CLI:
--   PUT file:///path/to/lcr_runoff_rates.csv @RAW.NORTHBRIDGE_REF_STAGE;
--
-- You can verify the file is staged with:
-- =============================================================================
LIST @RAW.NORTHBRIDGE_REF_STAGE;

-- =============================================================================
-- STEP 4E: COPY INTO — load staged file into the table
--
-- COPY INTO reads the file(s) from the stage and loads them into the table
-- using the file format definition. ON_ERROR = 'ABORT_STATEMENT' means the
-- entire load is rolled back if any row fails to parse.
-- =============================================================================
COPY INTO RAW.LCR_RUNOFF_RATES (
    liability_category,
    sub_category,
    run_off_rate_pct,
    inflow_rate_pct,
    effective_date,
    regulatory_basis,
    notes
)
FROM @RAW.NORTHBRIDGE_REF_STAGE/lcr_runoff_rates.csv
FILE_FORMAT = (FORMAT_NAME = 'RAW.CSV_HEADER_FORMAT')
ON_ERROR    = 'ABORT_STATEMENT';

-- =============================================================================
-- STEP 4F: Verify the loaded data
-- =============================================================================
SELECT
    liability_category,
    sub_category,
    run_off_rate_pct,
    effective_date,
    regulatory_basis
FROM RAW.LCR_RUNOFF_RATES
ORDER BY liability_category, sub_category;

-- How many rows loaded?
SELECT COUNT(*) AS rows_loaded FROM RAW.LCR_RUNOFF_RATES;

-- Check load history for this table
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME   => 'LCR_RUNOFF_RATES',
    START_TIME   => DATEADD(HOUR, -1, CURRENT_TIMESTAMP())
));

-- =============================================================================
-- STEP 4G: Reload scenario — truncate and reload when PRA updates rates
--
-- The PRA may issue updated run-off rates quarterly. The correct pattern
-- is to truncate the reference table and reload from the new file version:
-- =============================================================================

-- TRUNCATE TABLE RAW.LCR_RUNOFF_RATES;
-- Then re-upload the new version of lcr_runoff_rates.csv to the stage
-- Then run the COPY INTO statement above again
```

The key concepts:

**Stage** -- a landing zone inside your Snowflake account where files are held before loading.

**File Format** -- tells Snowflake how to parse the file (delimiter, header, null handling).

**COPY INTO** -- loads the staged file into the target table.

> **Note**: To upload the file to the stage via Snowsight: click the stage object in Data browser > Upload button. Via SnowSQL CLI: `PUT file:///path/to/lcr_runoff_rates.csv @RAW.NORTHBRIDGE_REF_STAGE;`

You should see 25 rows loaded.

## Creating Analytical Views

Open your `04_TABLES_VIEWS` worksheet and run the following:

```sql
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
--
-- Snowflake functions introduced in this script:
--   INFORMATION_SCHEMA.TABLES     — metadata view showing all tables, row counts, sizes
--   TRIM(string)                  — removes leading/trailing whitespace
--   UPPER(string)                 — converts to uppercase (useful for postcode normalisation)
--   DATEDIFF(part, start, end)    — calculates the difference between two dates in the given unit
--   COALESCE(a, b, ...)           — returns the first non-NULL argument
--   DATE_TRUNC(part, date)        — truncates a date to the specified granularity (month, year, etc.)
--   COUNT(DISTINCT col)           — counts unique values (not just rows)
--   ROUND(number, decimals)       — rounds to specified decimal places
--   CURRENT_DATE()                — today's date in the session timezone
--   CURRENT_TIMESTAMP()           — current date + time
-- =============================================================================

USE DATABASE NORTHBRIDGE_BANK_HOL;
USE WAREHOUSE NORTHBRIDGE_WH;
USE ROLE SYSADMIN;

-- =============================================================================
-- PART A: UNDERSTANDING TABLES
-- Tables store data physically. Let's explore what we have.
--
-- INFORMATION_SCHEMA.TABLES is a Snowflake metadata view that shows every
-- table in the current database — including row counts and byte sizes —
-- without needing to scan any actual data.
-- =============================================================================

-- OUTPUT: list of all tables in the RAW schema with their row counts and storage size
SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, ROW_COUNT, BYTES
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'RAW'
ORDER BY ROW_COUNT DESC;

-- Preview sample data to understand the shape of each table
SELECT * FROM RAW.CUSTOMERS LIMIT 10;

SELECT * FROM RAW.TRANSACTIONS LIMIT 10;

-- =============================================================================
-- PART B: CREATING ANALYTICAL VIEWS
--
-- Views store a query definition — not data. Every time you query a view,
-- it re-executes the underlying SQL against the latest data.
--
-- As an analyst, views let you encapsulate complex logic once and reuse it.
-- The Risk team can query V_CUSTOMER_SUMMARY without knowing the JOIN logic.
-- =============================================================================

-- B1: Customer summary view — one row per customer with balance and loan exposure
-- This view is used by the Risk team for segmentation analysis and quarterly reviews.
--
-- Key Snowflake functions used:
--   TRIM() — removes whitespace from names (defensive against dirty source data)
--   UPPER(TRIM(postcode)) — normalises postcodes to uppercase for consistent reporting
--   DATEDIFF('year', dob, CURRENT_DATE()) — calculates customer age in years
--   DATEDIFF('day', customer_since, CURRENT_DATE()) — calculates tenure in days
--   COALESCE(value, 0) — replaces NULL with 0 for customers with no accounts/loans
--   COUNT(DISTINCT id) — counts unique accounts/loans (not duplicate join rows)
--   ROUND(SUM(...), 2) — rounds GBP amounts to 2 decimal places
--
-- Architecture note: we pre-aggregate accounts and loans in separate CTEs
-- before joining to customers. This avoids a many-to-many fan-out that would
-- inflate SUM values if a customer has both multiple accounts AND multiple loans.
CREATE OR REPLACE VIEW STAGING.V_CUSTOMER_SUMMARY AS
WITH account_agg AS (
    -- Step 1: aggregate each customer's active accounts into a single row
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
    -- Step 2: aggregate each customer's loans into a single row
    SELECT
        customer_id,
        COUNT(DISTINCT loan_id) AS num_loans,
        ROUND(SUM(outstanding_balance_gbp), 2) AS total_loan_exposure_gbp
    FROM RAW.LOANS
    GROUP BY customer_id
)
-- Step 3: join pre-aggregated results to the customer dimension
-- LEFT JOIN ensures customers with no accounts or no loans still appear
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

-- OUTPUT: average balance per segment — shows which segments hold the most deposits
SELECT segment, COUNT(*) AS customers, ROUND(AVG(total_balance_gbp), 2) AS avg_balance
FROM STAGING.V_CUSTOMER_SUMMARY
GROUP BY segment
ORDER BY avg_balance DESC;

-- B2: Monthly transaction trends — useful for reporting and anomaly detection
-- Aggregates cleared transactions by month, direction (debit/credit), and category.
--
-- Key Snowflake function:
--   DATE_TRUNC('month', date) — truncates a date to the first of its month,
--   enabling GROUP BY month without losing the DATE data type.
--   This is more efficient than EXTRACT(YEAR, ...) + EXTRACT(MONTH, ...)
--   because the result stays as a DATE and can be used in time-series charts.
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

-- OUTPUT: monthly debit vs credit totals — useful for spotting seasonal patterns
SELECT txn_month, debit_credit, SUM(total_amount_gbp) AS total_gbp
FROM STAGING.V_MONTHLY_TXN_TRENDS
GROUP BY txn_month, debit_credit
ORDER BY txn_month DESC, debit_credit;

-- =============================================================================
-- PART C: TABLES vs VIEWS — WHEN TO USE EACH
--
-- Views are always fresh — they re-read source data on every query
-- Tables are snapshots — fast to read, but stale until reloaded
--
-- CURRENT_TIMESTAMP() — records the exact moment the snapshot was taken,
-- so analysts know how fresh the data is.
-- =============================================================================

-- Create a materialised summary table from our view
-- This is useful when you need fast, repeatable reads for a dashboard
CREATE OR REPLACE TABLE STAGING.CUSTOMER_SUMMARY_SNAPSHOT AS
SELECT *, CURRENT_TIMESTAMP() AS snapshot_at
FROM STAGING.V_CUSTOMER_SUMMARY;

-- Compare: table reads are instant, view reads re-execute the JOIN + GROUP BY
-- Run each of these and compare the execution times in Query History:

-- View (re-executes the full query every time)
SELECT COUNT(*) FROM STAGING.V_CUSTOMER_SUMMARY;

-- Table (reads pre-computed stored data — much faster)
SELECT COUNT(*) FROM STAGING.CUSTOMER_SUMMARY_SNAPSHOT;

-- =============================================================================
-- PART D: ZERO-COPY CLONING
--
-- CLONE is a Snowflake-specific command that creates an instant, independent
-- copy of a table, schema or database with NO additional storage cost
-- (until the clone diverges from the original).
--
-- Under the hood, both the original and clone point to the same micro-partitions.
-- Storage is only consumed when you modify the clone (copy-on-write).
--
-- For analysts, this is powerful:
--   - Experiment with data transformations without touching production
--   - Create a sandbox for ad-hoc analysis
--   - Share a point-in-time snapshot with colleagues
-- =============================================================================

-- Create an instant clone — completes in seconds regardless of table size
CREATE TABLE IF NOT EXISTS RAW.TRANSACTIONS_DEV
    CLONE RAW.TRANSACTIONS;

-- Both tables have the same row count
SELECT
    'RAW.TRANSACTIONS'     AS table_name, COUNT(*) AS row_count FROM RAW.TRANSACTIONS UNION ALL
SELECT
    'RAW.TRANSACTIONS_DEV' AS table_name, COUNT(*) AS row_count FROM RAW.TRANSACTIONS_DEV;

-- Safe to modify the clone — does not affect the original
-- Only the modified partitions consume additional storage
DELETE FROM RAW.TRANSACTIONS_DEV WHERE status = 'REJECTED';

-- Verify: original is unchanged, clone has fewer rows
SELECT
    'ORIGINAL'  AS source, COUNT(*) AS row_count FROM RAW.TRANSACTIONS UNION ALL
SELECT
    'DEV'       AS source, COUNT(*) AS row_count FROM RAW.TRANSACTIONS_DEV;

-- Clean up the dev clone when done
DROP TABLE IF EXISTS RAW.TRANSACTIONS_DEV;
```

Views are virtual tables -- they store the query definition but not the data. Every time you query a view, it reads the latest data from the underlying tables.

**V_CUSTOMER_SUMMARY** -- a single-row-per-customer view that aggregates account balances and loan exposure. Pre-aggregates accounts and loans separately to avoid cross-join fan-out.

**V_MONTHLY_TXN_TRENDS** -- aggregates transaction volumes and amounts by month for trend analysis.

## Zero-Copy Cloning

Sarah's standing rule: *"Never experiment on production tables. Clone them first."*

Cloning creates an instant, independent copy of a table that uses no additional storage until the clone diverges from the original. This completes instantly regardless of table size. The clone is fully independent -- modifications to `TRANSACTIONS_DEV` do not affect `TRANSACTIONS`.

This is the recommended pattern for:
- Creating a sandbox to experiment with data safely
- Testing query logic against a copy without risk to production data
- Producing ad-hoc analysis snapshots for stakeholders

> **Analyst Tip**: If you need to manipulate data for an analysis (deleting rows, adding columns, updating values), always clone the table first and work on the clone. This protects the source data.

## Tables vs Views -- When to Use Each

| | Table | View |
|---|---|---|
| **Storage** | Stores data physically | Stores only the query definition |
| **Performance** | Fast reads (no re-computation) | Re-executes query on every access |
| **Freshness** | Snapshot at load time | Always current |
| **Use when** | You need stable, fast reads or a sandbox | Data must always reflect the latest source |
