# Step 2: Using Workspaces for Code Development
**Duration: 15 minutes**

> **Monday Afternoon** -- Sarah stops by your desk: *"Before you start writing SQL, set up your workspace properly. We organise everything by project folder so anyone on the team can pick up where you left off. Create a folder for this onboarding and one worksheet per exercise. Trust me -- it saves hours later."*

Worksheets are Snowflake's primary code development environment. Used well, they provide a structured workspace for exploring data and building analytical queries.

## Creating and Naming a Worksheet

1. Click **Worksheets** in the left nav
2. Click **+** (top right) to create a new worksheet
3. Click the worksheet name (defaults to the current date/time) and rename it to:
   ```
   01_SETUP
   ```

Good worksheet names describe what the code does -- not who wrote it or when.

## Organising Worksheets into Folders

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

## Running Code Efficiently

| Action | Mac | Windows |
|---|---|---|
| Run selected statement | `Cmd + Enter` | `Ctrl + Enter` |
| Run all statements | `Cmd + Shift + Enter` | `Ctrl + Shift + Enter` |
| Comment/uncomment selection | `Cmd + /` | `Ctrl + /` |
| Format SQL | `Cmd + Shift + F` | `Ctrl + Shift + F` |
| Open keyboard shortcut reference | `?` icon top right | `?` icon top right |

> **Tip**: Highlight a single statement and press `Cmd/Ctrl + Enter` to run only that statement. This is the most important habit to develop -- it prevents accidentally running an entire file when you only want to test one query.

## The Worksheet Context Bar

At the top of every worksheet is a context bar showing:

```
Role: SYSADMIN  |  Warehouse: NORTHBRIDGE_WH  |  Database: NORTHBRIDGE_BANK_HOL  |  Schema: RAW
```

> **Note**: This context will be available after completing Step 3 (setup). For now, just know where to find it.

Setting this context means you can write `SELECT * FROM CUSTOMERS` instead of the fully qualified `SELECT * FROM NORTHBRIDGE_BANK_HOL.RAW.CUSTOMERS`. For this lab, always verify your context before running a script.

## Results Panel

After running a query, the results panel appears at the bottom of the worksheet. You can:

- **Download** results as CSV (cloud icon)
- **Switch to Chart view** to quickly visualise query output
- **Copy** individual cells or entire rows

Create all nine worksheets inside the **NorthBridge Analyst HOL** folder before proceeding to Step 3.
