# NorthBridge Bank: Data Analyst Essentials on Snowflake

A hands-on lab for data analysts at UK retail banks. You play a newly hired analyst at NorthBridge Bank, working through your first week on the analytics team. Each step is driven by a real request from a colleague or business stakeholder -- from loading PRA reference data, to profiling slow queries for the monthly board report, to delivering urgent compliance queries using Cortex Code.

---

## The Story

NorthBridge Bank recently migrated its data platform from a legacy on-premises system to Snowflake. The data engineering team has loaded the core dataset. Now it is the analytics team's turn. Your manager, **Sarah Chen** (Head of Analytics), has planned your first week as structured onboarding: each day brings a new challenge from a different stakeholder. By Friday, you deliver real analytical value to the Risk team, the CFO's office, and the Head of Compliance.

---

## What Participants Will Learn

A practical toolkit for data analysts working on Snowflake:

| Topic | What You Will Learn |
|---|---|
| Snowsight UI | Navigate the interface, Query History, Data Explorer |
| Workspaces | Organise worksheets and folders for structured analysis |
| Databases, Schemas & Roles | Object hierarchy, RBAC, context switching |
| Tables, Views & Cloning | When to use each, creating analytical views, sandbox cloning |
| SQL Best Practices | 8 patterns and anti-patterns every analyst should know |
| Warehouse Scaling | Instant resize for heavy workloads, cost-aware sizing |
| Caching | Three cache layers — metadata, result, warehouse |
| Query Profiling | Query Profile, EXPLAIN, partition pruning, spilling |
| Cortex Code | AI-assisted SQL generation, explanation and refactoring |

---

## Lab Structure

**Duration**: ~3 hours (half-day)
**Audience**: Data analysts, business intelligence developers
**Snowflake Features**: Snowsight UI, worksheets, databases/schemas/roles, tables, views, zero-copy cloning, internal stages, COPY INTO, warehouse scaling, caching, Query Profile, EXPLAIN, QUERY_HISTORY, Cortex Code

| Step | Topic | Stakeholder / Context | Duration |
|---|---|---|---|
| 1 | Getting Familiar with the Snowsight UI | Sarah: "Explore the platform -- we work entirely in Snowsight" | 15 min |
| 2 | Using Workspaces for Code Development | Sarah: "Set up your workspace before the data lands" | 15 min |
| 3 | Understanding Databases, Schemas and Roles | Sarah: "Learn the schema layout and how RBAC works" | 25 min |
| 4 | Tables, Views, Cloning & File-Based Ingest | Risk team quarterly review + PRA run-off rates CSV | 25 min |
| 5 | SQL Best Practices & Anti-Patterns | James (senior analyst): legacy query code review rewrite | 25 min |
| 6 | Warehouse Scaling | CFO's office: urgent board-call analysis running too slowly | 15 min |
| 7 | Using Caching Effectively | Tom (colleague): "Why does the second run return instantly?" | 20 min |
| 8 | Query Profiling & Performance Monitoring | Sarah: "Profile the slow board report queries" | 20 min |
| 9 | Accelerating Development with Cortex Code | Priya (Head of Risk): four urgent compliance queries by EOD | 15 min |

---

## Requirements Coverage

| Requirement | Step |
|---|---|
| Navigating the Snowsight UI | Step 1 |
| Using worksheets and folders as a development workspace | Step 2 |
| Creating and selecting databases, schemas and roles | Step 3 |
| Core data fundamentals: tables, views, cloning, file-based ingest | Step 4 |
| SQL best practice patterns and anti-patterns | Step 5 |
| Warehouse scaling | Step 6 |
| Using caching effectively | Step 7 |
| Query profiling and performance monitoring | Step 8 |
| Using Cortex Code to accelerate SQL development | Step 9 |

---

## Repository Structure

```
uk-retail-bank-analyst-essentials/
├── README.md                                              ← This file
└── src/
    ├── uk-retail-bank-analyst-essentials.md                ← Main guide (sfguides format)
    └── assets/
        ├── 01_setup.sql                                    ← Database, schemas, warehouse
        ├── 02_data_generation.sql                          ← Synthetic dataset (~530k rows)
        ├── lcr_runoff_rates.csv                            ← PRA reference data (25 rows)
        ├── 03_file_load.sql                                ← Stage, file format, COPY INTO
        ├── 04_tables_views_cloning.sql                     ← Tables, views, analytical views, cloning
        ├── 05_sql_patterns.sql                             ← SQL best practices & anti-patterns
        ├── 06_warehouse_scaling.sql                        ← Warehouse scaling exercises
        ├── 07_caching.sql                                  ← Result cache, warehouse cache, metadata cache
        └── 08_query_profiling.sql                          ← Query Profile, EXPLAIN, QUERY_HISTORY
```

---

## Synthetic Dataset

All data is generated entirely within Snowflake using `GENERATOR()` and `RANDOM()`. No external files are needed for the core dataset. The data is entirely fictional.

| Table | Rows | Key UK Fields |
|---|---|---|
| `RAW.PRODUCTS` | 20 | Product types, LCR categories |
| `RAW.CUSTOMERS` | 10,000 | NI numbers, UK postcodes, KYC status |
| `RAW.ACCOUNTS` | 15,000 | Sort codes, account numbers, GBP balances |
| `RAW.LOANS` | 3,000 | Mortgages, personal loans, auto finance |
| `RAW.TRANSACTIONS` | 500,000 | 6 months of card, BACS, CHAPS, standing order data |

The CSV file `lcr_runoff_rates.csv` contains 25 rows of PRA/Basel III prescribed run-off rates, used to demonstrate file-based ingest.

---

## Prerequisites

- A Snowflake account with `SYSADMIN` role access
- A web browser (Chrome or Firefox recommended)
- This repository downloaded locally

No prior Snowflake experience is required. Basic SQL familiarity (SELECT, JOIN, GROUP BY) is assumed.

---

## Running the Lab

### Option A — Follow the Guide

Open the main guide file and follow each step in sequence:

```
src/uk-retail-bank-analyst-essentials.md
```

The guide references each SQL asset file at the appropriate step.

### Option B — Run SQL Assets Directly

Each SQL file in the `assets/` folder can be run independently in Snowsight. Run them in order (01 → 08).

---

## Clean Up

To remove all lab objects from your Snowflake account after completing the lab:

```sql
USE ROLE SYSADMIN;
DROP DATABASE  IF EXISTS NORTHBRIDGE_BANK_HOL;
DROP WAREHOUSE IF EXISTS NORTHBRIDGE_WH;
```

---

## Related Resources

- [Snowflake Documentation](https://docs.snowflake.com)
- [Snowflake SQL Reference](https://docs.snowflake.com/en/sql-reference)
- [Query Profile Documentation](https://docs.snowflake.com/en/user-guide/ui-query-profile)
- [Understanding Caching](https://docs.snowflake.com/en/user-guide/querying-persisted-results)
- [Warehouse Sizing Guide](https://docs.snowflake.com/en/user-guide/warehouses-overview)
- [Cortex Code Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-code)
