# Step 10: Clean Up
**Duration: 5 minutes**

Congratulations -- you have completed your first week at NorthBridge Bank.

## What You Delivered

- **For Sarah**: A structured analytical workspace following team conventions, with nine worksheets in a project folder
- **For the Risk team**: Two analytical views (`V_CUSTOMER_SUMMARY`, `V_MONTHLY_TXN_TRENDS`) ready for the quarterly review
- **For James**: Eight legacy queries rewritten following Snowflake best practices, with execution time evidence
- **For the CFO**: An urgent board-ready analysis delivered on time by scaling warehouse compute
- **For Tom**: A documented explanation of Snowflake's three cache layers
- **For Sarah (again)**: Query profile diagnostics identifying performance bottlenecks in the monthly board report queries
- **For Priya**: Four compliance queries delivered in a fraction of the usual time using Cortex Code
- **For yourself**: A cloned sandbox table for safe data exploration, and a production-ready workflow you will use every day

## What You Learned

- **Snowsight UI**: Query History for tracking your own performance, Data Explorer for discovering tables
- **Workspaces**: Organising worksheets into folders, running selections, keyboard shortcuts
- **Databases, Schemas and Roles**: Three-layer architecture, RBAC context switching
- **Tables and Views**: Creating analytical views, when to materialise vs keep virtual
- **Zero-Copy Cloning**: Instant sandbox creation for safe exploration
- **File-Based Ingest**: Internal stages, file formats, COPY INTO
- **SQL Best Practices**: SELECT explicit columns, use JOINs over correlated subqueries, UNION ALL, filter early, SARGable predicates, CTEs, window functions, QUALIFY
- **Warehouse Scaling**: Instant resize with ALTER WAREHOUSE, right-sizing compute to workload
- **Caching**: Three cache layers (metadata, result, warehouse), when caching helps and when it does not
- **Query Profiling**: EXPLAIN plans, Query Profile in Snowsight, partition pruning, spilling identification, QUERY_HISTORY analysis
- **Cortex Code**: Generate, explain, refactor and extend SQL using AI assistance

## Teardown

To remove all lab objects from your Snowflake account:

```sql
-- =============================================================================
-- NorthBridge Bank HOL: Teardown
-- Removes all lab objects from your Snowflake account
-- =============================================================================

USE ROLE SYSADMIN;

DROP DATABASE  IF EXISTS NORTHBRIDGE_BANK_HOL;
DROP WAREHOUSE IF EXISTS NORTHBRIDGE_WH;
```

## Related Resources

- [Snowflake SQL Reference](https://docs.snowflake.com/en/sql-reference)
- [Query Profile Documentation](https://docs.snowflake.com/en/user-guide/ui-query-profile)
- [Understanding Warehouse Sizing](https://docs.snowflake.com/en/user-guide/warehouses-overview)
- [Result Caching](https://docs.snowflake.com/en/user-guide/querying-persisted-results)
- [Understanding Stages](https://docs.snowflake.com/en/user-guide/data-load-local-file-system-stage-ui)
- [Cloning Considerations](https://docs.snowflake.com/en/user-guide/object-clone)
- [Cortex Code Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-code)
