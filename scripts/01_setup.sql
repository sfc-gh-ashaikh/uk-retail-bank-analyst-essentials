-- =============================================================================
-- NorthBridge Bank HOL: Step 3 - Environment Setup
-- Creates the database, schemas, warehouse and audit log table
-- =============================================================================

-- Set your role to SYSADMIN to create objects
USE ROLE SYSADMIN;

-- =============================================================================
-- WAREHOUSE
-- =============================================================================
CREATE WAREHOUSE IF NOT EXISTS NORTHBRIDGE_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND   = 60
    AUTO_RESUME    = TRUE
    COMMENT        = 'NorthBridge Bank HOL warehouse';

USE WAREHOUSE NORTHBRIDGE_WH;

-- =============================================================================
-- DATABASE
-- =============================================================================
CREATE DATABASE IF NOT EXISTS NORTHBRIDGE_BANK_HOL
    COMMENT = 'NorthBridge Bank Hands-On Lab — FCA/PRA Regulatory Reporting Pipeline';

USE DATABASE NORTHBRIDGE_BANK_HOL;

-- =============================================================================
-- SCHEMAS
-- Three-layer architecture mirrors a regulated bank environment:
--   RAW      : Immutable ingest zone — data lands here exactly as received
--   STAGING  : Cleansed, standardised, enriched data ready for analytics
--   REPORTING: Business-facing regulatory reporting views and snapshots
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Immutable raw ingest layer — data as received from source systems';

CREATE SCHEMA IF NOT EXISTS STAGING
    COMMENT = 'Cleansed and standardised layer — validated, enriched data';

CREATE SCHEMA IF NOT EXISTS REPORTING
    COMMENT = 'FCA/PRA regulatory reporting layer — LCR, CAR, Large Exposures';

-- =============================================================================
-- AUDIT LOG TABLE (created in STAGING schema)
-- Used by stored procedures to record pipeline execution history
-- =============================================================================
USE SCHEMA STAGING;

CREATE TABLE IF NOT EXISTS STAGING.AUDIT_LOG (
    audit_id        NUMBER AUTOINCREMENT PRIMARY KEY,
    procedure_name  VARCHAR(100)    NOT NULL,
    step_name       VARCHAR(200)    NOT NULL,
    rows_processed  NUMBER          DEFAULT 0,
    status          VARCHAR(20)     NOT NULL,   -- SUCCESS / FAILED
    error_message   VARCHAR(2000),
    executed_at     TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    executed_by     VARCHAR(100)    DEFAULT CURRENT_USER()
);

-- =============================================================================
-- Verify setup
-- =============================================================================
SHOW SCHEMAS IN DATABASE NORTHBRIDGE_BANK_HOL;

SELECT
    'Setup complete' AS status,
    CURRENT_DATABASE()  AS database_name,
    CURRENT_WAREHOUSE() AS warehouse_name,
    CURRENT_ROLE()      AS active_role;
