# Step 9: Accelerating Development with Cortex Code
**Duration: 15 minutes**

> **Friday Morning** -- A new compliance request arrives from the **Head of Risk, Priya Patel**: *"We need four ad-hoc queries by end of day -- top customers by balance, an explanation of the CTE-based query James wrote, a rewrite of a legacy correlated subquery, and a spending anomaly detection query for the fraud team. Normally this would take a full day, but try using Cortex Code to accelerate delivery."* Sarah adds: *"This is a good test of when AI helps and when you still need to validate manually. Use Cortex Code, but check every result."*

Cortex Code is Snowflake's AI assistant built directly into the Snowsight SQL editor. It helps you generate, explain, and optimise SQL -- without ever leaving your worksheet.

Open your `09_CORTEX_CODE` worksheet.

> **Data Residency**: Cortex Code runs entirely within your Snowflake account. Your SQL and schema metadata never leave your Snowflake environment.

## Accessing Cortex Code

Click the **Cortex Code** icon (sparkle) in the top-right corner of the worksheet editor. A chat panel opens alongside your worksheet.

Alternatively, type a natural language comment directly in the worksheet -- Cortex Code will suggest completions.

## Exercise 1: Generate a Customer Analysis Query

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

## Exercise 2: Explain a Complex Query

Copy the CTE-based best-practice query from Step 5 (Pattern 6) into your worksheet.

In the Cortex Code chat panel, type:

```
Explain what this query does, step by step, including what each CTE is responsible for
```

Read the explanation. Does it match your understanding from Step 5?

## Exercise 3: Rewrite a Correlated Subquery

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

## Exercise 4: Detect Spending Pattern Changes

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

## When to Trust vs Validate

| Cortex Code is reliable for | Validate carefully when |
|---|---|
| Standard SQL patterns (GROUP BY, JOIN, aggregation) | Complex window function logic |
| Explaining well-structured queries | Business-specific calculations with exact formula requirements |
| Scaffolding repetitive boilerplate (CASE statements, pivots) | Any query that feeds a regulatory submission |
| Suggesting performance improvements | Schema-specific column names (may hallucinate) |

> **Best Practice**: Always validate AI-generated SQL against expected results. Cortex Code is a productivity accelerator, not a replacement for understanding your data and your SQL.
