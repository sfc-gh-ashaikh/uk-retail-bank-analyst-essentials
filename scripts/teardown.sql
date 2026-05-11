-- =============================================================================
-- NorthBridge Bank HOL: Teardown
-- Removes all lab objects from your Snowflake account
-- =============================================================================

USE ROLE SYSADMIN;

DROP DATABASE  IF EXISTS NORTHBRIDGE_BANK_HOL;
DROP WAREHOUSE IF EXISTS NORTHBRIDGE_WH;
