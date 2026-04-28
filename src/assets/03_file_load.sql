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
