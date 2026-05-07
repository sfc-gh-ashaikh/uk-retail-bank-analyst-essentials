author: NorthBridge Bank HOL Team
id: uk-retail-bank-analyst-essentials
summary: A hands-on lab for data analysts exploring Snowflake. Covers Snowsight navigation, workspaces, databases/schemas/roles, tables/views/cloning, SQL best practices, warehouse scaling, caching, query profiling, and Cortex Code.
categories: snowflake-site:taxonomy/solution-center/data-analytics
environments: web
status: Published
feedback link: https://github.com/Snowflake-Labs/sfguides/issues
language: en

# NorthBridge Bank: Data Analyst Essentials on Snowflake
<!-- ------------------------ -->
## Overview
Duration: 5

Welcome to the **NorthBridge Bank Data Analyst Essentials Hands-On Lab**.

You have just joined the analytics team at **NorthBridge Bank**, a mid-size UK retail bank regulated by the Financial Conduct Authority (FCA) and the Prudential Regulation Authority (PRA). NorthBridge recently migrated its data platform from a legacy on-premises system to Snowflake. The data engineering team has already built the ingest pipelines and loaded the bank's core data -- products, customers, accounts, loans and transactions -- into a Snowflake database. Now it is the analytics team's turn to put that data to work.

Your manager, **Sarah Chen** (Head of Analytics), has planned your first week as a structured onboarding programme. Each day brings a new challenge -- from getting oriented in the platform, through building your first analytical deliverables, to diagnosing performance issues and using AI to accelerate your output. By Friday, you will be a confident, self-sufficient analyst on the team.

This lab follows that week. Each step represents a task Sarah or a business stakeholder assigns to you, with a clear reason and a concrete outcome.

### What You Will Learn

- How to navigate the Snowsight UI and find data quickly
- How to use worksheets and folders as a structured development workspace
- How databases, schemas and roles control what you can see and do
- How tables, views and zero-copy cloning support analytical workflows
- Eight SQL best practices (and the anti-patterns to avoid)
- How warehouse scaling provides elastic compute on demand
- How Snowflake's three cache layers affect query performance
- How to read query profiles and identify performance bottlenecks
- How to use Cortex Code to accelerate SQL development

### What You Will Need

- A Snowflake account with **SYSADMIN** role access
- A web browser (Chrome or Firefox recommended)
- The lab assets folder downloaded from this repository

### What You Will Build

Over the course of your first week, you will build:

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

### Prerequisites

- Basic familiarity with SQL (SELECT, JOIN, GROUP BY)
- No prior Snowflake experience required

> **Note**: All data used in this lab is entirely synthetic. No real customer data is used at any point.

<!-- ------------------------ -->
## Step 1: Getting Familiar with the Snowsight UI
Duration: 15

> **Monday Morning** -- Sarah sends you your Snowflake credentials and a message: *"Welcome to the team! We do everything in Snowsight -- queries, monitoring, data exploration. Spend the first hour getting oriented. Click around, find the Query History, browse the Data panel. Don't write any SQL yet -- just learn where things are."*

### The Snowsight Interface

Snowsight is Snowflake's browser-based interface. Everything you need to explore data, write queries, and monitor performance lives here. Let's get oriented before writing any code.

Log in to your Snowflake account. You will land on the Snowsight home page.

### Left Navigation Panel

The left sidebar is your primary navigation. Each icon takes you to a different area:

| Icon / Label | What It Does |
|---|---|
| **Home** | Activity summary and recent objects |
| **Data** | Browse databases, schemas and tables. Load data, view column profiles |
| **Worksheets** | SQL and Python development environment |
| **Notebooks** | Interactive notebook-style development |
| **Monitoring** | Query History, Task History, Copy History, Activity |
| **Admin** | Warehouses, resource monitors, users, roles |

### Top Bar -- Context Controls

The top bar of every worksheet shows your current execution context:

- **Role** -- controls what objects you can see and what operations you can perform
- **Warehouse** -- the compute cluster that executes your queries
- **Database / Schema** -- the default namespace for unqualified object references

> **Key Point**: Changing your role changes what is visible in the object browser on the left. An analyst role may not see the same databases as an engineering role. This is Snowflake's role-based access control (RBAC) in action.

### Query History

Click **Monitoring > Query History** in the left nav. This shows every SQL statement executed in your account, with:

- Execution status (Succeeded / Failed / Queued)
- Duration and bytes scanned
- The warehouse used
- The full SQL text (click any row)

As an analyst, Query History is your best friend for understanding your own query performance. You can filter by user, warehouse or status to find slow queries, failed attempts, or patterns in your work over time. Sarah mentions that the compliance team occasionally asks for evidence of who ran what query and when -- Query History is where that audit trail lives.

### Data Explorer

Click **Data** in the left nav. Expand your account's databases to browse schemas, tables and views. Click any table to see:

- Column names and data types
- A **Data Preview** tab showing sample rows
- A **Column** tab showing min/max/null statistics

This is the fastest way to discover what data is available and understand its shape before writing a single query. Sarah's advice: *"Always check the Data panel before writing a query. Half the time, the column you need has a different name than you expect."*

### Your First Query

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

<!-- ------------------------ -->
## Step 2: Using Workspaces for Code Development
Duration: 15

> **Monday Afternoon** -- Sarah stops by your desk: *"Before you start writing SQL, set up your workspace properly. We organise everything by project folder so anyone on the team can pick up where you left off. Create a folder for this onboarding and one worksheet per exercise. Trust me -- it saves hours later."*

Worksheets are Snowflake's primary code development environment. Used well, they provide a structured workspace for exploring data and building analytical queries.

### Creating and Naming a Worksheet

1. Click **Worksheets** in the left nav
2. Click **+** (top right) to create a new worksheet
3. Click the worksheet name (defaults to the current date/time) and rename it to:
   ```
   01_SETUP
   ```

Good worksheet names describe what the code does -- not who wrote it or when.

### Organising Worksheets into Folders

As a project grows, a flat list of worksheets becomes hard to navigate. Folders keep related worksheets together.

1. In the Worksheets panel, click the **+** folder icon or right-click in the left panel
2. Create a new folder called **NorthBridge Analyst HOL**
3. Drag your worksheet into that folder

For this lab, you will create one worksheet per step:

| Worksheet Name | Step |
|---|---|
| `01_SETUP` | Step 3 |
| `02_DATA_GENERATION` | Step 3 |
| `03_FILE_LOAD` | Step 4 |
| `04_TABLES_VIEWS` | Step 4 |
| `05_SQL_PATTERNS` | Step 5 |
| `06_WAREHOUSE_SCALING` | Step 6 |
| `07_CACHING` | Step 7 |
| `08_QUERY_PROFILING` | Step 8 |
| `09_CORTEX_CODE` | Step 9 |

### Running Code Efficiently

| Action | Mac | Windows |
|---|---|---|
| Run selected statement | `Cmd + Enter` | `Ctrl + Enter` |
| Run all statements | `Cmd + Shift + Enter` | `Ctrl + Shift + Enter` |
| Comment/uncomment selection | `Cmd + /` | `Ctrl + /` |
| Format SQL | `Cmd + Shift + F` | `Ctrl + Shift + F` |
| Open keyboard shortcut reference | `?` icon top right | `?` icon top right |

> **Tip**: Highlight a single statement and press `Cmd/Ctrl + Enter` to run only that statement. This is the most important habit to develop -- it prevents accidentally running an entire file when you only want to test one query.

### The Worksheet Context Bar

At the top of every worksheet is a context bar showing:

```
Role: SYSADMIN  |  Warehouse: NORTHBRIDGE_WH  |  Database: NORTHBRIDGE_BANK_HOL  |  Schema: RAW
```

> **Note**: This context will be available after completing Step 3 (setup). For now, just know where to find it.

Setting this context means you can write `SELECT * FROM CUSTOMERS` instead of the fully qualified `SELECT * FROM NORTHBRIDGE_BANK_HOL.RAW.CUSTOMERS`. For this lab, always verify your context before running a script.

### Results Panel

After running a query, the results panel appears at the bottom of the worksheet. You can:

- **Download** results as CSV (cloud icon)
- **Switch to Chart view** to quickly visualise query output
- **Copy** individual cells or entire rows

Create all nine worksheets inside the **NorthBridge Analyst HOL** folder before proceeding to Step 3.

<!-- ------------------------ -->
## Step 3: Understanding Databases, Schemas and Roles
Duration: 25

> **Tuesday Morning** -- Sarah sends you a Slack message: *"The data engineering team finished the migration last night. The database is called NORTHBRIDGE_BANK_HOL. Before you touch anything, make sure you understand the schema layout -- RAW, STAGING and REPORTING each serve a different purpose. Also, switch roles a few times to see how RBAC works. In a regulated bank, knowing what you can and cannot see matters."*

In this step you will create the NorthBridge Bank environment and load the synthetic dataset.

### Snowflake Object Hierarchy

Every object in Snowflake exists within a hierarchy:

```
Organisation
    +-- Account (your Snowflake account)
            +-- Database  (e.g. NORTHBRIDGE_BANK_HOL)
                    +-- Schema  (e.g. RAW, STAGING, REPORTING)
                            +-- Tables, Views, Stages...
```

When you write SQL without fully qualifying names, Snowflake uses your current **database** and **schema** context to resolve the reference.

### Why Three Schemas?

NorthBridge Bank uses a three-layer architecture -- a standard pattern in regulated data environments:

| Schema | Purpose | Who Writes | Who Reads |
|---|---|---|---|
| **RAW** | Immutable ingest zone. Data lands here exactly as received from source systems. | Ingest pipelines | Engineers, Analysts |
| **STAGING** | Cleansed, standardised, enriched data. PII is masked, data types are enforced. | Data engineers | Analysts, Analytics engineers |
| **REPORTING** | Business-facing views and daily snapshots. | Analytics engineers | Analysts, Risk & Compliance |

As an analyst, you will primarily read from STAGING and REPORTING. Understanding this architecture helps you know where to find clean data (STAGING/REPORTING) versus raw source data (RAW). Sarah notes: *"If you ever need to check something against the source, RAW is your ground truth. But never build a report off RAW -- that is what STAGING is for."*

### Run 01_SETUP

Open your `01_SETUP` worksheet. Copy and run the contents of `assets/01_setup.sql`.

This creates:
- The `NORTHBRIDGE_BANK_HOL` database
- Three schemas: `RAW`, `STAGING`, `REPORTING`
- The `NORTHBRIDGE_WH` warehouse (X-Small, auto-suspend after 60 seconds)

After running, verify in the left **Data** panel that the database and schemas are visible.

### Role-Based Access in Practice

Click the role selector in the top bar. Toggle between `SYSADMIN` and `PUBLIC`.

> **Observe**: As `PUBLIC`, the database browser may show fewer objects or none at all. This is RBAC -- different roles see different objects. In a real bank, the ingest team would use a dedicated `INGEST_ROLE`, analysts would use an `ANALYST_ROLE`, and the compliance team would have read-only access to `REPORTING`.

Run the following to see your granted roles:

```sql
SHOW GRANTS TO USER CURRENT_USER();
```

Switch back to `SYSADMIN` before continuing.

### Load the Synthetic Dataset

Open your `02_DATA_GENERATION` worksheet and run `assets/02_data_generation.sql`.

> **Note**: The transactions table generates approximately 500,000 rows. This step takes approximately 60 seconds.

Once complete, verify the row counts:

```sql
SELECT 'PRODUCTS'     AS table_name, COUNT(*) AS row_count FROM RAW.PRODUCTS     UNION ALL
SELECT 'CUSTOMERS'    AS table_name, COUNT(*) AS row_count FROM RAW.CUSTOMERS    UNION ALL
SELECT 'ACCOUNTS'     AS table_name, COUNT(*) AS row_count FROM RAW.ACCOUNTS     UNION ALL
SELECT 'LOANS'        AS table_name, COUNT(*) AS row_count FROM RAW.LOANS        UNION ALL
SELECT 'TRANSACTIONS' AS table_name, COUNT(*) AS row_count FROM RAW.TRANSACTIONS;
```

You should see approximately:

| Table | Expected Rows |
|---|---|
| PRODUCTS | 20 |
| CUSTOMERS | 10,000 |
| ACCOUNTS | 15,000 |
| LOANS | 3,000 |
| TRANSACTIONS | 500,000 |

### Explore the Data

Click on **Data > NORTHBRIDGE_BANK_HOL > RAW > CUSTOMERS** in the left panel. Click the **Data Preview** tab to see sample rows.

Notice the UK-specific data:
- `NI_NUMBER` -- UK National Insurance number format (`XX 00 00 00 X`)
- `POSTCODE` -- UK postcode format (e.g. `EC1A 1BB`)
- `SORT_CODE` -- UK bank sort code format (`20-XX-XX`) in the ACCOUNTS table
- All monetary amounts are in GBP

<!-- ------------------------ -->
## Step 4: Tables, Views, Cloning and File-Based Ingest
Duration: 25

> **Tuesday Afternoon** -- Two things land in your inbox. First, the PRA has published updated **LCR run-off rates** and Sarah asks you to load the CSV into Snowflake. Second, the Risk team has a quarterly review next week and needs two new views: a **customer summary** (balances and loan exposure per customer) and a **monthly transaction trends** view. Sarah adds: *"This is your first deliverable -- make sure the views work before you move on. And clone the transactions table so you have a sandbox to experiment in without touching production data."*

In this step you will load reference data from a CSV file, create analytical views, and explore zero-copy cloning.

### Loading Reference Data from CSV

Not all data arrives via pipelines. Reference data -- like regulatory rate tables published by the PRA -- arrives as files.

Sarah's email: *"The PRA published revised LCR run-off rates this morning. The data engineers are busy, so I need you to load this yourself. The file is lcr_runoff_rates.csv -- 25 rows of prescribed stress rates. Use a stage and COPY INTO so the process is repeatable when rates change next year."*

Download `assets/lcr_runoff_rates.csv` from this repository to your local machine.

Open your `03_FILE_LOAD` worksheet and run `assets/03_file_load.sql` section by section.

The key concepts:

**Stage** -- a landing zone inside your Snowflake account where files are held before loading:
```sql
CREATE STAGE IF NOT EXISTS RAW.NORTHBRIDGE_REF_STAGE;
```

**File Format** -- tells Snowflake how to parse the file:
```sql
CREATE FILE FORMAT IF NOT EXISTS RAW.CSV_HEADER_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    NULL_IF = ('NULL', 'null', '')
    EMPTY_FIELD_AS_NULL = TRUE;
```

**COPY INTO** -- loads the staged file into the target table:
```sql
COPY INTO RAW.LCR_RUNOFF_RATES (...)
FROM @RAW.NORTHBRIDGE_REF_STAGE/lcr_runoff_rates.csv
FILE_FORMAT = (FORMAT_NAME = 'RAW.CSV_HEADER_FORMAT')
ON_ERROR = 'ABORT_STATEMENT';
```

> **Note**: To upload the file to the stage via SQL (SnowSQL CLI): `PUT file:///path/to/lcr_runoff_rates.csv @RAW.NORTHBRIDGE_REF_STAGE;`
> For this lab, use the Snowsight stage UI to upload the file (click the stage object in Data browser > Upload button).

Verify the load:

```sql
SELECT COUNT(*) AS rows_loaded FROM RAW.LCR_RUNOFF_RATES;
```

You should see 25 rows.

### Creating Analytical Views

Open your `04_TABLES_VIEWS` worksheet and run `assets/04_tables_views_cloning.sql`.

The Risk team's quarterly review needs two things: a per-customer balance and loan exposure summary, and a monthly transaction trends breakdown. You will build these as views so they always reflect the latest data.

Views are virtual tables -- they store the query definition but not the data. Every time you query a view, it reads the latest data from the underlying tables.

**V_CUSTOMER_SUMMARY** -- a single-row-per-customer view that aggregates account balances and loan exposure:

```sql
CREATE OR REPLACE VIEW STAGING.V_CUSTOMER_SUMMARY AS
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name  AS customer_name,
    c.segment,
    c.region,
    COUNT(DISTINCT a.account_id)         AS num_accounts,
    ROUND(SUM(a.balance_gbp), 2)         AS total_balance_gbp,
    COUNT(DISTINCT l.loan_id)            AS num_loans,
    ROUND(COALESCE(SUM(l.outstanding_balance_gbp), 0), 2) AS total_loan_exposure_gbp
FROM RAW.CUSTOMERS       c
LEFT JOIN RAW.ACCOUNTS   a ON c.customer_id = a.customer_id
LEFT JOIN RAW.LOANS      l ON c.customer_id = l.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.segment, c.region;
```

**V_MONTHLY_TXN_TRENDS** -- aggregates transaction volumes and amounts by month for trend analysis:

```sql
CREATE OR REPLACE VIEW STAGING.V_MONTHLY_TXN_TRENDS AS
SELECT
    DATE_TRUNC('MONTH', t.transaction_date)  AS txn_month,
    t.debit_credit,
    t.merchant_category,
    COUNT(*)                                  AS txn_count,
    ROUND(SUM(t.amount_gbp), 2)              AS total_amount_gbp,
    ROUND(AVG(t.amount_gbp), 2)              AS avg_amount_gbp
FROM RAW.TRANSACTIONS t
WHERE t.status = 'CLEARED'
GROUP BY txn_month, t.debit_credit, t.merchant_category;
```

Test both views:

```sql
SELECT * FROM STAGING.V_CUSTOMER_SUMMARY ORDER BY total_balance_gbp DESC LIMIT 10;
SELECT * FROM STAGING.V_MONTHLY_TXN_TRENDS ORDER BY txn_month DESC, total_amount_gbp DESC LIMIT 20;
```

### Zero-Copy Cloning

Sarah's standing rule: *"Never experiment on production tables. Clone them first."* Cloning creates an instant, independent copy of a table that uses no additional storage until the clone diverges from the original:

```sql
CREATE TABLE IF NOT EXISTS RAW.TRANSACTIONS_DEV
    CLONE RAW.TRANSACTIONS;
```

This completes instantly regardless of table size. Verify:

```sql
SELECT
    'RAW.TRANSACTIONS'     AS table_name, COUNT(*) AS row_count FROM RAW.TRANSACTIONS UNION ALL
SELECT
    'RAW.TRANSACTIONS_DEV' AS table_name, COUNT(*) AS row_count FROM RAW.TRANSACTIONS_DEV;
```

Both tables show the same row count. The clone is fully independent -- modifications to `TRANSACTIONS_DEV` do not affect `TRANSACTIONS`. This is the recommended pattern for:

- Creating a sandbox to experiment with data safely
- Testing query logic against a copy without risk to production data
- Producing ad-hoc analysis snapshots for stakeholders

> **Analyst Tip**: If you need to manipulate data for an analysis (deleting rows, adding columns, updating values), always clone the table first and work on the clone. This protects the source data.

### Tables vs Views -- When to Use Each

| | Table | View |
|---|---|---|
| **Storage** | Stores data physically | Stores only the query definition |
| **Performance** | Fast reads (no re-computation) | Re-executes query on every access |
| **Freshness** | Snapshot at load time | Always current |
| **Use when** | You need stable, fast reads or a sandbox | Data must always reflect the latest source |

<!-- ------------------------ -->
## Step 5: SQL Best Practices and Anti-Patterns
Duration: 25

> **Wednesday Morning** -- Sarah forwards you a set of queries from the legacy reporting system that were migrated as-is. A senior analyst, **James Okafor**, reviewed them during a code review and flagged eight anti-patterns. He sends you a message: *"These all produce correct results, but they are slow, hard to read, or both. Your task: rewrite each one following Snowflake best practices. Run both versions and compare execution times -- that is the evidence we need to justify the cleanup to the team."*

Writing correct SQL is one thing. Writing efficient SQL is another. In this step you will work through eight common patterns, each demonstrated with an anti-pattern and the corresponding best practice.

Open your `05_SQL_PATTERNS` worksheet and run `assets/05_sql_patterns.sql` section by section.

### Pattern 1: SELECT * vs Explicit Columns

**Anti-pattern:**
```sql
SELECT * FROM RAW.TRANSACTIONS;
```

**Best practice:**
```sql
SELECT
    transaction_id,
    account_id,
    transaction_date,
    amount_gbp,
    debit_credit
FROM RAW.TRANSACTIONS;
```

`SELECT *` reads every column, including those you do not need. On wide tables this wastes I/O and memory. It also breaks downstream code if columns are added or renamed. Always name the columns you need.

### Pattern 2: Correlated Subqueries vs JOINs

**Anti-pattern:**
```sql
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    (SELECT COUNT(*)
     FROM RAW.ACCOUNTS a
     WHERE a.customer_id = c.customer_id) AS account_count
FROM RAW.CUSTOMERS c;
```

**Best practice:**
```sql
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(a.account_id) AS account_count
FROM RAW.CUSTOMERS c
LEFT JOIN RAW.ACCOUNTS a ON c.customer_id = a.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name;
```

A correlated subquery executes once per row in the outer query. A JOIN with GROUP BY allows the optimiser to process both tables in a single pass. On 10,000 customers, the difference is significant.

### Pattern 3: UNION vs UNION ALL

**Anti-pattern:**
```sql
SELECT customer_id FROM RAW.ACCOUNTS WHERE status = 'ACTIVE'
UNION
SELECT customer_id FROM RAW.LOANS WHERE status = 'PERFORMING';
```

**Best practice:**
```sql
SELECT customer_id FROM RAW.ACCOUNTS WHERE status = 'ACTIVE'
UNION ALL
SELECT customer_id FROM RAW.LOANS WHERE status = 'PERFORMING';
```

`UNION` sorts and deduplicates the result set. `UNION ALL` does not. If you know duplicates are acceptable (or impossible), use `UNION ALL` to avoid the unnecessary sort. If you do need distinct values, wrap with an explicit `SELECT DISTINCT`.

### Pattern 4: Filter Early (Predicate Pushdown)

**Anti-pattern:**
```sql
SELECT *
FROM (
    SELECT t.*, a.account_type
    FROM RAW.TRANSACTIONS t
    JOIN RAW.ACCOUNTS a ON t.account_id = a.account_id
) sub
WHERE sub.transaction_date >= DATEADD('month', -3, CURRENT_DATE());
```

**Best practice:**
```sql
SELECT t.transaction_id, t.amount_gbp, a.account_type
FROM RAW.TRANSACTIONS t
JOIN RAW.ACCOUNTS a ON t.account_id = a.account_id
WHERE t.transaction_date >= DATEADD('month', -3, CURRENT_DATE());
```

Apply filters as early as possible -- ideally in the WHERE clause of the innermost query. This reduces the number of rows flowing through joins and aggregations. Snowflake's optimiser can push predicates down in many cases, but writing the filter in the right place ensures it always happens.

### Pattern 5: SARGable Filters

**Anti-pattern:**
```sql
SELECT *
FROM RAW.TRANSACTIONS
WHERE YEAR(transaction_date) = YEAR(CURRENT_DATE())
  AND MONTH(transaction_date) = MONTH(CURRENT_DATE()) - 1;
```

**Best practice:**
```sql
SELECT *
FROM RAW.TRANSACTIONS
WHERE transaction_date >= DATE_TRUNC('month', DATEADD('month', -1, CURRENT_DATE()))
  AND transaction_date <  DATE_TRUNC('month', CURRENT_DATE());
```

A **SARGable** (Search ARGument able) filter allows the engine to use partition pruning. Wrapping a column in a function (`YEAR()`, `MONTH()`, `UPPER()`) prevents the optimiser from pruning partitions efficiently. Use range predicates on raw column values instead.

### Pattern 6: CTEs for Readability

**Anti-pattern:**
```sql
SELECT
    a.account_type,
    SUM(t.amount_gbp) AS total_debits
FROM RAW.TRANSACTIONS t
JOIN RAW.ACCOUNTS a ON t.account_id = a.account_id
WHERE t.debit_credit = 'DEBIT'
  AND t.status = 'CLEARED'
  AND t.transaction_date >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY a.account_type
HAVING SUM(t.amount_gbp) > (
    SELECT AVG(monthly_total)
    FROM (
        SELECT DATE_TRUNC('MONTH', transaction_date) AS m, SUM(amount_gbp) AS monthly_total
        FROM RAW.TRANSACTIONS
        WHERE debit_credit = 'DEBIT' AND status = 'CLEARED'
        GROUP BY m
    )
);
```

**Best practice:**
```sql
WITH monthly_averages AS (
    SELECT
        DATE_TRUNC('MONTH', transaction_date) AS txn_month,
        SUM(amount_gbp)                       AS monthly_total
    FROM RAW.TRANSACTIONS
    WHERE debit_credit = 'DEBIT' AND status = 'CLEARED'
    GROUP BY txn_month
),
avg_monthly AS (
    SELECT AVG(monthly_total) AS avg_monthly_debit FROM monthly_averages
),
recent_debits AS (
    SELECT
        a.account_type,
        SUM(t.amount_gbp) AS total_debits
    FROM RAW.TRANSACTIONS t
    JOIN RAW.ACCOUNTS a ON t.account_id = a.account_id
    WHERE t.debit_credit = 'DEBIT'
      AND t.status = 'CLEARED'
      AND t.transaction_date >= DATEADD('day', -30, CURRENT_DATE())
    GROUP BY a.account_type
)
SELECT rd.account_type, rd.total_debits
FROM recent_debits rd
CROSS JOIN avg_monthly am
WHERE rd.total_debits > am.avg_monthly_debit;
```

CTEs (Common Table Expressions) break complex logic into named, readable steps. Each CTE is a self-contained unit that can be tested independently. This is especially important in banking where queries must be auditable and explainable.

### Pattern 7: Window Functions vs Self-Joins

**Anti-pattern:**
```sql
SELECT
    t1.account_id,
    t1.transaction_date,
    t1.amount_gbp,
    t1.amount_gbp - t2.prev_amount AS change_from_previous
FROM RAW.TRANSACTIONS t1
LEFT JOIN (
    SELECT account_id, transaction_date, amount_gbp AS prev_amount,
           ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY transaction_date DESC) AS rn
    FROM RAW.TRANSACTIONS
) t2 ON t1.account_id = t2.account_id AND t2.rn = 1;
```

**Best practice:**
```sql
SELECT
    account_id,
    transaction_date,
    amount_gbp,
    amount_gbp - LAG(amount_gbp) OVER (
        PARTITION BY account_id ORDER BY transaction_date
    ) AS change_from_previous
FROM RAW.TRANSACTIONS;
```

Window functions (`LAG`, `LEAD`, `ROW_NUMBER`, `RANK`, `SUM() OVER`) let you reference other rows in the result set without self-joining. They are more readable, more efficient, and less error-prone than the self-join equivalent.

### Pattern 8: QUALIFY for Deduplication

**Anti-pattern:**
```sql
SELECT * FROM (
    SELECT
        t.*,
        ROW_NUMBER() OVER (
            PARTITION BY account_id, transaction_date
            ORDER BY transaction_id DESC
        ) AS rn
    FROM RAW.TRANSACTIONS t
)
WHERE rn = 1;
```

**Best practice:**
```sql
SELECT *
FROM RAW.TRANSACTIONS
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY account_id, transaction_date
    ORDER BY transaction_id DESC
) = 1;
```

`QUALIFY` is Snowflake's clause for filtering on window function results -- analogous to `HAVING` for aggregations. It eliminates the need for a subquery wrapper, making deduplication queries shorter and clearer.

> **Summary**: Run both the anti-pattern and best-practice versions of each query. Compare execution times in the Query History panel. The differences become more pronounced as data volumes grow.

<!-- ------------------------ -->
## Step 6: Warehouse Scaling
Duration: 15

> **Wednesday Afternoon** -- The CFO's office emails Sarah with an urgent request: *"We need the transaction category breakdown for the last 30 days before the 4pm board call. The query is running too slowly on the default warehouse."* Sarah forwards the request to you: *"Scale up the warehouse, run the query, then scale back down. I want you to see how Snowflake's elastic compute works -- and understand that you only pay for the time the bigger warehouse is running."*

Snowflake separates storage from compute. You can resize a warehouse with a single command, and the change takes effect immediately. This step demonstrates how an analyst can scale compute to match the workload.

Open your `06_WAREHOUSE_SCALING` worksheet and run `assets/06_warehouse_scaling.sql` section by section.

### Elastic Compute

A warehouse is a cluster of compute resources. Scaling up a warehouse gives you more CPU and memory. Scaling down reduces cost. You only pay for the time the warehouse is active.

### Step-by-Step Benchmark

**1. Disable caching**

To get an honest comparison, disable Snowflake's result cache:

```sql
ALTER SESSION SET USE_CACHED_RESULT = FALSE;
```

**2. Confirm warehouse size is X-SMALL**

```sql
SHOW WAREHOUSES LIKE 'NORTHBRIDGE_WH';
```

Check the `size` column. If not X-SMALL:

```sql
ALTER WAREHOUSE NORTHBRIDGE_WH SET WAREHOUSE_SIZE = 'X-SMALL';
```

**3. Run the benchmark query**

This query joins transactions to accounts and aggregates by category -- representative of an analytical workload:

```sql
SELECT
    a.account_type,
    t.debit_credit,
    t.merchant_category,
    COUNT(*)                       AS txn_count,
    ROUND(SUM(t.amount_gbp), 2)   AS total_amount_gbp,
    ROUND(AVG(t.amount_gbp), 2)   AS avg_amount_gbp
FROM RAW.TRANSACTIONS  t
JOIN RAW.ACCOUNTS      a ON t.account_id = a.account_id
WHERE t.transaction_date >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY a.account_type, t.debit_credit, t.merchant_category
ORDER BY total_amount_gbp DESC;
```

Note the execution time from the results pane or Query History.

**4. Scale up to MEDIUM**

```sql
ALTER WAREHOUSE NORTHBRIDGE_WH SET WAREHOUSE_SIZE = 'MEDIUM';
ALTER WAREHOUSE NORTHBRIDGE_WH SUSPEND;
ALTER WAREHOUSE NORTHBRIDGE_WH RESUME;
```

The suspend/resume clears the warehouse data cache so we are comparing compute power, not cached data.

**5. Re-run the same query**

Run the exact same benchmark query. Compare the execution time with your X-SMALL baseline.

> **Observe**: A MEDIUM warehouse has 4x the compute of X-SMALL. You should see a noticeable reduction in execution time -- with zero changes to your SQL.

**6. Scale back down**

```sql
ALTER WAREHOUSE NORTHBRIDGE_WH SET WAREHOUSE_SIZE = 'X-SMALL';
ALTER SESSION SET USE_CACHED_RESULT = TRUE;
```

### Warehouse Sizing Reference

| Warehouse Size | Credits/Hour | Use When |
|---|---|---|
| X-SMALL | 1 | Day-to-day queries, lightweight exploration |
| SMALL | 2 | Moderate analytical workloads |
| MEDIUM | 4 | Complex joins, large aggregations, report generation |
| LARGE | 8 | Heavy analytical workloads, large data exports |

### When Would an Analyst Do This?

You just experienced it: the CFO needed results before a 4pm board call. Scaling up took one command, the query ran in a fraction of the time, and you scaled back immediately. Other scenarios:

- A monthly board report query that normally takes 5 minutes on X-SMALL needs to run before a meeting in 2 minutes -- scale up to MEDIUM, run the query, scale back.
- A data exploration session against a full year of transactions is sluggish -- scale up for the session, scale back when done.
- The key principle: scale compute to your workload, not your peak. You only pay for what you use.

> **Key Takeaway**: Snowflake's elastic compute means you never need to choose between performance and cost permanently. Scale up when you need speed, scale down when you are done.

<!-- ------------------------ -->
## Step 7: Using Caching Effectively
Duration: 20

> **Thursday Morning** -- Your colleague **Tom Hargreaves** messages you: *"I ran the same query twice and the second time it came back instantly -- zero seconds. But when I changed one word in the WHERE clause, it took 3 seconds again. Is Snowflake caching results? How does that work?"* You investigate and discover Snowflake's three cache layers. Sarah encourages you to document what you find: *"Every analyst on the team should understand when they are getting cached results versus fresh scans. It affects both speed and cost."*

Snowflake uses three layers of caching to avoid redundant work. Understanding these layers helps you write queries that benefit from caching -- and recognise when cached results might give you stale data.

Open your `07_CACHING` worksheet and run `assets/07_caching.sql` section by section.

### The Three Cache Layers

| Cache Layer | What It Stores | Lifetime | Invalidated When |
|---|---|---|---|
| **Metadata Cache** | Row counts, min/max values, NULL counts | Always available | Underlying data changes |
| **Result Cache** | Full query result sets | 24 hours | Underlying data changes, or `USE_CACHED_RESULT = FALSE` |
| **Warehouse Cache** | Raw data micro-partitions in SSD/memory | While warehouse is active | Warehouse suspends, or data changes |

### Exercise 1: Metadata Cache

Run the following:

```sql
SELECT COUNT(*) FROM RAW.TRANSACTIONS;
```

This returns almost instantly -- even on an X-SMALL warehouse. Snowflake does not scan any data. The row count is stored in the table's metadata. Check the Query Profile: you will see **METADATA-BASED RESULT** as the source.

Other metadata-cached operations: `MIN()`, `MAX()` on columns, `COUNT(*)` without filters.

### Exercise 2: Result Cache

Run a query with a filter:

```sql
SELECT
    merchant_category,
    COUNT(*)                     AS txn_count,
    ROUND(SUM(amount_gbp), 2)   AS total_gbp
FROM RAW.TRANSACTIONS
WHERE debit_credit = 'DEBIT'
GROUP BY merchant_category
ORDER BY total_gbp DESC;
```

Note the execution time. Now run the exact same query again.

> **Observe**: The second run returns instantly. Snowflake recognised the identical SQL text, confirmed the underlying data has not changed, and served the result directly from the result cache. No warehouse compute was used -- which means no credits were consumed.

### Exercise 3: Cache Miss -- Different SQL

Now run a slightly different version:

```sql
SELECT
    merchant_category,
    COUNT(*)                     AS txn_count,
    ROUND(SUM(amount_gbp), 2)   AS total_gbp
FROM RAW.TRANSACTIONS
WHERE debit_credit = 'CREDIT'
GROUP BY merchant_category
ORDER BY total_gbp DESC;
```

This is a cache miss -- the filter changed from `'DEBIT'` to `'CREDIT'`, so the SQL text is different. Snowflake must execute the query from scratch.

### Exercise 4: Non-Deterministic Functions and Caching

```sql
SELECT
    CURRENT_TIMESTAMP() AS now,
    COUNT(*)            AS total_rows
FROM RAW.TRANSACTIONS;
```

Run this twice. Despite being the same SQL text, the result includes `CURRENT_TIMESTAMP()`, which is non-deterministic. Snowflake cannot cache results that contain non-deterministic functions because the output would differ on every execution.

> **Analyst Tip**: If you are running the same analytical query repeatedly during an exploration session, caching saves you time and credits. But if you need fresh results (e.g. after an upstream data load), either wait for the cache to invalidate or disable it explicitly with `ALTER SESSION SET USE_CACHED_RESULT = FALSE`.

### Exercise 5: Warehouse Cache

Disable the result cache to isolate the warehouse cache:

```sql
ALTER SESSION SET USE_CACHED_RESULT = FALSE;
```

Run the benchmark query:

```sql
SELECT
    a.account_type,
    t.debit_credit,
    COUNT(*)                     AS txn_count,
    ROUND(SUM(t.amount_gbp), 2) AS total_gbp
FROM RAW.TRANSACTIONS  t
JOIN RAW.ACCOUNTS      a ON t.account_id = a.account_id
WHERE t.status = 'CLEARED'
GROUP BY a.account_type, t.debit_credit
ORDER BY total_gbp DESC;
```

Run it again immediately. The second run should be faster -- not because of the result cache (which is disabled), but because the warehouse has cached the micro-partitions in local SSD/memory from the first scan.

Now suspend and resume the warehouse to clear its cache:

```sql
ALTER WAREHOUSE NORTHBRIDGE_WH SUSPEND;
ALTER WAREHOUSE NORTHBRIDGE_WH RESUME;
```

Run the query a third time. It should take about as long as the first run -- the warehouse cache was cleared by the suspend.

Re-enable the result cache:

```sql
ALTER SESSION SET USE_CACHED_RESULT = TRUE;
```

### Caching Summary

| Scenario | Cache Used | Credits Consumed |
|---|---|---|
| `COUNT(*)` with no filter | Metadata | None |
| Exact same query, data unchanged | Result | None |
| Same query, non-deterministic function | None | Yes |
| Same query, result cache disabled | Warehouse (if warm) | Yes (reduced) |
| Same query, warehouse suspended/resumed | None | Yes (full scan) |

<!-- ------------------------ -->
## Step 8: Query Profiling and Performance Monitoring
Duration: 20

> **Thursday Afternoon** -- Sarah pulls you into a quick call: *"The monthly board report queries are running slower than expected. Before we throw a bigger warehouse at the problem, I need you to profile the queries and tell me what is actually happening -- are we scanning too many partitions? Is anything spilling to disk? Use the Query Profile and QUERY_HISTORY to diagnose it. If you can find the bottleneck, we fix the SQL instead of spending more on compute."*

Knowing how to write efficient SQL is one skill. Knowing how to diagnose a slow query is another. This step teaches you to use Snowflake's built-in profiling and monitoring tools.

Open your `08_QUERY_PROFILING` worksheet and run `assets/08_query_profiling.sql` section by section.

### EXPLAIN Plans

Before running a query, you can see its execution plan:

```sql
EXPLAIN
SELECT
    a.account_type,
    COUNT(*)                     AS txn_count,
    ROUND(SUM(t.amount_gbp), 2) AS total_gbp
FROM RAW.TRANSACTIONS  t
JOIN RAW.ACCOUNTS      a ON t.account_id = a.account_id
WHERE t.transaction_date >= DATEADD('month', -3, CURRENT_DATE())
GROUP BY a.account_type;
```

The EXPLAIN output shows the logical plan -- how Snowflake intends to execute the query, including join strategies, filter placement and aggregation steps. This is useful for validating that your predicates are being applied where you expect.

### Reading the Query Profile in Snowsight

Run the query above (without EXPLAIN). Then:

1. Click the **Query ID** link in the results pane, or go to **Monitoring > Query History** and find the query
2. Click the **Profile** tab

The Query Profile shows a visual operator tree. Key things to look for:

**Partition Pruning**: Look at the `TableScan` node. It shows:
- `Partitions total` -- total micro-partitions in the table
- `Partitions scanned` -- how many were actually read

If scanned is much less than total, your filter is enabling partition pruning. This is the single biggest performance lever in Snowflake.

**Percentage Scanned from Cache**: Shows how much data came from the warehouse cache vs remote storage. Higher cache hit rates mean faster queries.

**Spilling**: If you see `Bytes spilled to local storage` or `Bytes spilled to remote storage` on any operator, the warehouse ran out of memory and wrote intermediate results to disk. This is a sign you need a larger warehouse for this query.

### Partition Pruning Demonstration

Run these two queries and compare their profiles:

**No pruning (function on column):**
```sql
SELECT COUNT(*), SUM(amount_gbp)
FROM RAW.TRANSACTIONS
WHERE YEAR(transaction_date) = YEAR(CURRENT_DATE());
```

**With pruning (range predicate):**
```sql
SELECT COUNT(*), SUM(amount_gbp)
FROM RAW.TRANSACTIONS
WHERE transaction_date >= DATE_TRUNC('year', CURRENT_DATE())
  AND transaction_date <  DATEADD('year', 1, DATE_TRUNC('year', CURRENT_DATE()));
```

Check the `Partitions scanned` vs `Partitions total` in the Query Profile for each. The range predicate version should scan fewer partitions -- this is the SARGable pattern from Step 5 in action.

### Using QUERY_HISTORY for Analysis

The `INFORMATION_SCHEMA.QUERY_HISTORY` table function lets you programmatically analyse your recent queries:

```sql
SELECT
    query_id,
    query_text,
    execution_status,
    total_elapsed_time / 1000 AS elapsed_seconds,
    bytes_scanned,
    rows_produced,
    partitions_scanned,
    partitions_total
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    DATE_RANGE_START => DATEADD('hour', -2, CURRENT_TIMESTAMP()),
    RESULT_LIMIT     => 20
))
ORDER BY total_elapsed_time DESC;
```

### Finding Slow Queries

To find your slowest queries in the last 24 hours:

```sql
SELECT
    query_id,
    SUBSTR(query_text, 1, 100)         AS query_preview,
    total_elapsed_time / 1000          AS elapsed_seconds,
    bytes_scanned / (1024*1024)        AS mb_scanned,
    partitions_scanned,
    partitions_total,
    CASE
        WHEN partitions_total > 0
        THEN ROUND(partitions_scanned / partitions_total * 100, 1)
        ELSE 0
    END                                AS pct_partitions_scanned
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    DATE_RANGE_START => DATEADD('day', -1, CURRENT_TIMESTAMP()),
    RESULT_LIMIT     => 50
))
WHERE execution_status = 'SUCCESS'
  AND total_elapsed_time > 1000
ORDER BY total_elapsed_time DESC;
```

Queries scanning a high percentage of partitions or taking many seconds are your optimisation targets.

### Identifying Spilling

Spilling happens when a query's intermediate results exceed the warehouse's memory. To find queries that spilled:

```sql
SELECT
    query_id,
    SUBSTR(query_text, 1, 100)                 AS query_preview,
    total_elapsed_time / 1000                  AS elapsed_seconds,
    bytes_spilled_to_local_storage / (1024*1024)  AS mb_spilled_local,
    bytes_spilled_to_remote_storage / (1024*1024) AS mb_spilled_remote
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    DATE_RANGE_START => DATEADD('day', -1, CURRENT_TIMESTAMP()),
    RESULT_LIMIT     => 50
))
WHERE bytes_spilled_to_local_storage > 0
   OR bytes_spilled_to_remote_storage > 0
ORDER BY bytes_spilled_to_remote_storage DESC;
```

If a query regularly spills, consider:
- Adding filters to reduce the data volume
- Scaling up the warehouse for that query
- Rewriting the query to reduce intermediate result sizes

### Performance Checklist

When a query is slow, work through this checklist:

| Check | How | Action |
|---|---|---|
| Missing filters? | Review WHERE clause | Add date ranges, status filters |
| Function on filter column? | Look for `YEAR()`, `UPPER()` on WHERE columns | Rewrite as SARGable range predicate |
| Partition pruning? | Query Profile > TableScan > partitions scanned vs total | Add or improve filter predicates |
| Spilling? | Query Profile > operator nodes > bytes spilled | Scale up warehouse or reduce data volume |
| Result cache available? | Check if same query ran recently | Re-run identical SQL to benefit from cache |
| Warehouse too small? | Compare elapsed time across sizes | Scale up for the workload |

<!-- ------------------------ -->
## Step 9: Accelerating Development with Cortex Code
Duration: 15

> **Friday Morning** -- A new compliance request arrives from the **Head of Risk, Priya Patel**: *"We need four ad-hoc queries by end of day -- top customers by balance, an explanation of the CTE-based query James wrote, a rewrite of a legacy correlated subquery, and a spending anomaly detection query for the fraud team. Normally this would take a full day, but try using Cortex Code to accelerate delivery."* Sarah adds: *"This is a good test of when AI helps and when you still need to validate manually. Use Cortex Code, but check every result."*

Cortex Code is Snowflake's AI assistant built directly into the Snowsight SQL editor. It helps you generate, explain, and optimise SQL -- without ever leaving your worksheet.

Open your `09_CORTEX_CODE` worksheet.

> **Data Residency**: Cortex Code runs entirely within your Snowflake account. Your SQL and schema metadata never leave your Snowflake environment.

### Accessing Cortex Code

Click the **Cortex Code** icon (sparkle) in the top-right corner of the worksheet editor. A chat panel opens alongside your worksheet.

Alternatively, type a natural language comment directly in the worksheet -- Cortex Code will suggest completions.

### Exercise 1 -- Generate a Customer Analysis Query

Type the following comment into your worksheet and invoke Cortex Code:

```sql
-- Show me the top 10 customers by total account balance,
-- with their segment and number of accounts
```

Cortex Code will suggest a SQL query. Review it, then run it. Compare the output with your `V_CUSTOMER_SUMMARY` view:

```sql
SELECT customer_name, segment, num_accounts, total_balance_gbp
FROM STAGING.V_CUSTOMER_SUMMARY
ORDER BY total_balance_gbp DESC
LIMIT 10;
```

Do the results agree? If not, examine the differences -- this is a good exercise in validating AI-generated SQL.

### Exercise 2 -- Explain a Complex Query

Copy the CTE-based best-practice query from Step 5 (Pattern 6) into your worksheet.

In the Cortex Code chat panel, type:

```
Explain what this query does, step by step, including what each CTE is responsible for
```

Read the explanation. Does it match your understanding from Step 5?

### Exercise 3 -- Rewrite a Correlated Subquery

Paste the following query (the anti-pattern from Step 5, Pattern 2) into your worksheet:

```sql
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    (SELECT COUNT(*)
     FROM RAW.ACCOUNTS a
     WHERE a.customer_id = c.customer_id) AS account_count
FROM RAW.CUSTOMERS c;
```

Ask Cortex Code:

```
Rewrite this query to eliminate the correlated subquery using a JOIN and GROUP BY instead
```

Run both versions and compare execution times in Query History.

### Exercise 4 -- Detect Spending Pattern Changes

Type the following comment and let Cortex Code generate the SQL:

```sql
-- Write a query to find customers whose spending pattern changed significantly
-- month-over-month. Compare each customer's total debit transactions in the most
-- recent complete month to the month before, and flag anyone whose spending
-- increased or decreased by more than 50%
```

Review the generated SQL. Does it:
- Filter for debit transactions only?
- Handle the edge case where the previous month had zero transactions?
- Use window functions or CTEs effectively?

Run the query and examine the results. This kind of spending anomaly detection is exactly what Priya's fraud team needs. In a real bank, results like these would feed into a case management system for further investigation.

### When to Trust vs Validate

| Cortex Code is reliable for | Validate carefully when |
|---|---|
| Standard SQL patterns (GROUP BY, JOIN, aggregation) | Complex window function logic |
| Explaining well-structured queries | Business-specific calculations with exact formula requirements |
| Scaffolding repetitive boilerplate (CASE statements, pivots) | Any query that feeds a regulatory submission |
| Suggesting performance improvements | Schema-specific column names (may hallucinate) |

> **Best Practice**: Always validate AI-generated SQL against expected results. Cortex Code is a productivity accelerator, not a replacement for understanding your data and your SQL.

<!-- ------------------------ -->
## Conclusion and What You Learned
Duration: 5

Congratulations -- you have completed your first week at NorthBridge Bank.

### What You Delivered

- **For Sarah**: A structured analytical workspace following team conventions, with nine worksheets in a project folder
- **For the Risk team**: Two analytical views (`V_CUSTOMER_SUMMARY`, `V_MONTHLY_TXN_TRENDS`) ready for the quarterly review
- **For James**: Eight legacy queries rewritten following Snowflake best practices, with execution time evidence
- **For the CFO**: An urgent board-ready analysis delivered on time by scaling warehouse compute
- **For Tom**: A documented explanation of Snowflake's three cache layers
- **For Sarah (again)**: Query profile diagnostics identifying performance bottlenecks in the monthly board report queries
- **For Priya**: Four compliance queries delivered in a fraction of the usual time using Cortex Code
- **For yourself**: A cloned sandbox table for safe data exploration, and a production-ready workflow you will use every day

### What You Learned

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

### Clean Up (Optional)

To remove all lab objects from your account:

```sql
USE ROLE SYSADMIN;
DROP DATABASE IF EXISTS NORTHBRIDGE_BANK_HOL;
DROP WAREHOUSE IF EXISTS NORTHBRIDGE_WH;
```

### Related Resources

- [Snowflake SQL Reference](https://docs.snowflake.com/en/sql-reference)
- [Query Profile Documentation](https://docs.snowflake.com/en/user-guide/ui-query-profile)
- [Understanding Warehouse Sizing](https://docs.snowflake.com/en/user-guide/warehouses-overview)
- [Result Caching](https://docs.snowflake.com/en/user-guide/querying-persisted-results)
- [Understanding Stages](https://docs.snowflake.com/en/user-guide/data-load-local-file-system-stage-ui)
- [Cloning Considerations](https://docs.snowflake.com/en/user-guide/object-clone)
- [Cortex Code Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-code)
