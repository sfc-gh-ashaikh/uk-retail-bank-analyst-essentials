# Santander UK Snow Camp: Data Analyst Essentials

Welcome to the **NorthBridge Bank Data Analyst Essentials Hands-On Lab**.

You have just joined the analytics team at **NorthBridge Bank**, a mid-size UK retail bank regulated by the Financial Conduct Authority (FCA) and the Prudential Regulation Authority (PRA). NorthBridge recently migrated its data platform from a legacy on-premises system to Snowflake. The data engineering team has already built the ingest pipelines and loaded the bank's core data -- products, customers, accounts, loans and transactions -- into a Snowflake database. Now it is the analytics team's turn to put that data to work.

Your manager, **Sarah Chen** (Head of Analytics), has planned your first week as a structured onboarding programme. Each day brings a new challenge -- from getting oriented in the platform, through building your first analytical deliverables, to diagnosing performance issues and using AI to accelerate your output. By Friday, you will be a confident, self-sufficient analyst on the team.

---

## What You Will Learn

| Topic | What You Will Learn |
|---|---|
| Snowsight UI | Navigate the interface, Query History, Data Explorer |
| Workspaces | Organise worksheets and folders for structured analysis |
| Databases, Schemas & Roles | Object hierarchy, RBAC, context switching |
| Tables, Views & Cloning | When to use each, creating analytical views, sandbox cloning |
| SQL Best Practices | 8 patterns and anti-patterns every analyst should know |
| Warehouse Scaling | Instant resize for heavy workloads, cost-aware sizing |
| Caching | Three cache layers -- metadata, result, warehouse |
| Query Profiling | Query Profile, EXPLAIN, partition pruning, spilling |
| Cortex Code | AI-assisted SQL generation, explanation and refactoring |

---

## What You Will Need

- A Snowflake account with **SYSADMIN** role access
- A web browser (Chrome or Firefox recommended)
- Basic SQL familiarity (SELECT, JOIN, GROUP BY) -- no prior Snowflake experience required

---

## What You Will Build

- A structured analytical workspace mirroring team conventions
- Two analytical views for the quarterly Risk review (`V_CUSTOMER_SUMMARY`, `V_MONTHLY_TXN_TRENDS`)
- A sandbox clone for safe data exploration
- A library of eight SQL best-practice rewrites replacing legacy anti-patterns
- Benchmarks proving when to scale warehouse compute
- Evidence of how Snowflake's three cache layers affect your query costs
- Query profiles identifying performance bottlenecks
- AI-assisted queries for an urgent compliance request

All built against NorthBridge Bank's core dataset:

```
PRODUCTS (20 rows)        CUSTOMERS (10,000 rows)
ACCOUNTS (15,000 rows)    LOANS (3,000 rows)
TRANSACTIONS (500,000 rows)
LCR_RUNOFF_RATES (25 rows -- loaded from CSV)
```

---

## Running the Lab

**Duration**: ~3 hours (half-day)

Follow the step guides in `steps/` in order (01 to 10). Each file contains instructions and the full SQL -- copy and paste directly into a Snowsight worksheet and run section by section.

| Step | Topic | Scenario | Duration |
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
| 10 | Clean Up | Remove all lab objects from your account | 5 min |

---

## Resources

[Snowflake SQL Reference](https://docs.snowflake.com/en/sql-reference) | [Query Profile](https://docs.snowflake.com/en/user-guide/ui-query-profile) | [Warehouse Sizing](https://docs.snowflake.com/en/user-guide/warehouses-overview) | [Caching](https://docs.snowflake.com/en/user-guide/querying-persisted-results) | [Stages](https://docs.snowflake.com/en/user-guide/data-load-local-file-system-stage-ui) | [Cloning](https://docs.snowflake.com/en/user-guide/object-clone) | [Cortex Code](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-code)
