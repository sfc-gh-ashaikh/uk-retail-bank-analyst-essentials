# Step 1: Getting Familiar with the Snowsight UI
**Duration: 15 minutes**

> **Monday Morning** -- Sarah sends you your Snowflake credentials and a message: *"Welcome to the team! We do everything in Snowsight -- queries, monitoring, data exploration. Spend the first hour getting oriented. Click around, find the Query History, browse the Data panel. Don't write any SQL yet -- just learn where things are."*

Snowsight is Snowflake's browser-based interface. Everything you need to explore data, write queries, and monitor performance lives here. Let's get oriented before writing any code.

Log in to your Snowflake account. You will land on the Snowsight home page.

## Left Navigation Panel

The left sidebar is your primary navigation. Each icon takes you to a different area:

| Icon / Label | What It Does |
|---|---|
| **Home** | Activity summary and recent objects |
| **Data** | Browse databases, schemas and tables. Load data, view column profiles |
| **Worksheets** | SQL and Python development environment |
| **Notebooks** | Interactive notebook-style development |
| **Monitoring** | Query History, Task History, Copy History, Activity |
| **Admin** | Warehouses, resource monitors, users, roles |

## Top Bar -- Context Controls

The top bar of every worksheet shows your current execution context:

- **Role** -- controls what objects you can see and what operations you can perform
- **Warehouse** -- the compute cluster that executes your queries
- **Database / Schema** -- the default namespace for unqualified object references

> **Key Point**: Changing your role changes what is visible in the object browser on the left. An analyst role may not see the same databases as an engineering role. This is Snowflake's role-based access control (RBAC) in action.

## Query History

Click **Monitoring > Query History** in the left nav. This shows every SQL statement executed in your account, with:

- Execution status (Succeeded / Failed / Queued)
- Duration and bytes scanned
- The warehouse used
- The full SQL text (click any row)

As an analyst, Query History is your best friend for understanding your own query performance. You can filter by user, warehouse or status to find slow queries, failed attempts, or patterns in your work over time. Sarah mentions that the compliance team occasionally asks for evidence of who ran what query and when -- Query History is where that audit trail lives.

## Data Explorer

Click **Data** in the left nav. Expand your account's databases to browse schemas, tables and views. Click any table to see:

- Column names and data types
- A **Data Preview** tab showing sample rows
- A **Column** tab showing min/max/null statistics

This is the fastest way to discover what data is available and understand its shape before writing a single query. Sarah's advice: *"Always check the Data panel before writing a query. Half the time, the column you need has a different name than you expect."*

## Your First Query

Click **Worksheets** in the left nav, then click **+** to open a new worksheet.

Run the following to confirm your connection context:

```sql
SELECT
    CURRENT_USER()      AS my_user,
    CURRENT_ROLE()      AS my_role,
    CURRENT_WAREHOUSE() AS my_warehouse,
    CURRENT_DATABASE()  AS my_database,
    CURRENT_TIMESTAMP() AS current_time;
```

Click the **Run** button or press **Cmd + Enter** (Mac) / **Ctrl + Enter** (Windows).

You should see your user, role and warehouse returned. If the warehouse shows `null`, select any available warehouse from the dropdown in the top bar (we will create the lab warehouse `NORTHBRIDGE_WH` in Step 3).
