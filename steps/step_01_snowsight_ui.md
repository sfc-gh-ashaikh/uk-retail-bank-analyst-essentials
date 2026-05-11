# Step 1: Getting Familiar with the Snowsight UI
**Duration: 15 minutes**

> **Monday Morning** -- Sarah sends you your Snowflake credentials and a message: *"Welcome to the team! We do everything in Snowsight -- queries, monitoring, data exploration. Spend the first hour getting oriented. Click around, learn where things are. Don't write any SQL yet -- just get comfortable with the interface."*

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

Take a moment to click through each section. You will not see the NorthBridge Bank data yet -- we will create that in Step 3. For now, the goal is to know where each panel lives so you can find it quickly later.

## Top Bar -- Context Controls

Open a worksheet (click **Worksheets > +**). The top bar shows your current execution context:

- **Role** -- controls what objects you can see and what operations you can perform
- **Warehouse** -- the compute cluster that executes your queries
- **Database / Schema** -- the default namespace for unqualified object references

> **Key Point**: Changing your role changes what is visible in the object browser on the left. An analyst role may not see the same databases as an engineering role. This is Snowflake's role-based access control (RBAC) in action. You will see this first-hand in Step 3.

## Key Areas to Locate

Before moving on, make sure you can find each of these -- you will use them throughout the lab:

**Worksheets** -- where you will write and run all your SQL. Click **+** to create a new one. You can rename worksheets and organise them into folders (covered in Step 2).

**Monitoring > Query History** -- shows every SQL statement executed in your account. You will use this heavily in Steps 6, 7 and 8 to compare execution times, check cache behaviour, and identify slow queries. For now, just note where it is.

**Data panel** -- browse databases, schemas, tables and views. Once we create the NorthBridge Bank database in Step 3, this is where you will explore the data, check column names, and preview sample rows. Sarah's advice: *"Always check the Data panel before writing a query. Half the time, the column you need has a different name than you expect."*

**Admin > Warehouses** -- where you can see warehouse sizes and status. You will use this in Step 6 when scaling compute up and down.

## Your First Query

Run the following in your new worksheet to confirm your connection context:

```sql
SELECT
    CURRENT_USER()      AS my_user,
    CURRENT_ROLE()      AS my_role,
    CURRENT_WAREHOUSE() AS my_warehouse,
    CURRENT_DATABASE()  AS my_database,
    CURRENT_TIMESTAMP() AS current_time;
```

Click the **Run** button or press **Cmd + Enter** (Mac) / **Ctrl + Enter** (Windows).

You should see your user and role returned. If the warehouse shows `null`, select any available warehouse from the dropdown in the top bar -- we will create the dedicated lab warehouse `NORTHBRIDGE_WH` in Step 3.
