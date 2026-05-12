**Subject:** Follow-Up from Our AI/Cortex Discussion — Cost Granularity, Semantic View Autopilot & Agent CI/CD

---

Hi Asher, Ranjan, Anthony, Gaurav,

Thanks again for the great session last week. As promised, below are the follow-ups from our discussion. I've structured this into three sections covering the items I owed you.

---

## 1. AI Cost & Metadata Granularity — Full Visibility Into Every AI Interaction

Great question on wanting full transparency into what's running, which model is being used, and what it costs. The good news: Snowflake provides this out of the box through dedicated ACCOUNT_USAGE views — no additional setup required.

### Available Views

All views sit under `SNOWFLAKE.ACCOUNT_USAGE`:

| View | What It Tracks | Key Detail |
|---|---|---|
| `CORTEX_AGENT_USAGE_HISTORY` | Agent interactions | Per-request breakdown by agent name, user, model, token direction (input/output/cache), and service type (Analyst vs Search vs orchestration) |
| `CORTEX_ANALYST_USAGE_HISTORY` | Cortex Analyst (NL-to-SQL) | Credits and request counts per user |
| `CORTEX_AISQL_USAGE_HISTORY` | AI Functions (COMPLETE, TRANSLATE, etc.) | Per-function, per-model, per-query detail with input/output token splits |
| `CORTEX_CODE_CLI_USAGE_HISTORY` | Cortex Code (CLI) | Per-user, per-model credits |
| `CORTEX_SEARCH_DAILY_USAGE_HISTORY` | Cortex Search Services | Serving vs embedding cost per search service |
| `SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY` | Snowflake Intelligence | Per-SI-instance, per-agent, per-model breakdown |
| `METERING_HISTORY` | Overall service-level credits | High-level: AI vs compute vs storage vs serverless |

### The Key Insight: GRANULAR Columns

The agent, code, and intelligence views include `CREDITS_GRANULAR` and `TOKENS_GRANULAR` VARIANT columns that nest three levels deep:

**Service Type** (cortex_analyst / cortex_search / orchestration) → **Model Name** (claude-sonnet-4-5, openai-gpt-4.1, etc.) → **Token Direction** (input / output / cache_read_input / cache_write_input)

This means you can answer questions like: *"How many input tokens did our Trade Assistant agent send to Claude Sonnet 4.5 via Cortex Analyst last Tuesday?"*

### Ready-to-Use Queries

Here are the most useful queries for your team. Replace `<START_TIME>` and `<END_TIME>` with your window (max 1 month recommended).

**Which agents cost the most?**
```sql
SELECT
    AGENT_NAME,
    SUM(TOKEN_CREDITS) AS total_credits,
    SUM(TOKENS) AS total_tokens,
    COUNT(DISTINCT REQUEST_ID) AS request_count,
    COUNT(DISTINCT USER_NAME) AS unique_users
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
WHERE START_TIME >= '<START_TIME>' AND START_TIME < '<END_TIME>'
GROUP BY AGENT_NAME
ORDER BY total_credits DESC;
```

**Which LLM models are driving cost?**
```sql
SELECT
    cf4.key AS model_name,
    SUM(
        COALESCE(cf4.value:input::FLOAT, 0) +
        COALESCE(cf4.value:output::FLOAT, 0) +
        COALESCE(cf4.value:cache_read_input::FLOAT, 0) +
        COALESCE(cf4.value:cache_write_input::FLOAT, 0)
    ) AS total_credits,
    COUNT(DISTINCT h.REQUEST_ID) AS request_count
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY h,
     LATERAL FLATTEN(input => h.CREDITS_GRANULAR) cf1,
     LATERAL FLATTEN(input => cf1.value) cf2,
     LATERAL FLATTEN(input => cf2.value) cf3,
     LATERAL FLATTEN(input => cf3.value) cf4
WHERE cf3.key != 'start_time'
  AND h.START_TIME >= '<START_TIME>' AND h.START_TIME < '<END_TIME>'
GROUP BY cf4.key
ORDER BY total_credits DESC;
```

**What's the cost split between Analyst, Search, and orchestration within an agent?**
```sql
SELECT
    cf3.key AS service_type,
    ROUND(SUM(
        COALESCE(cf4.value:input::FLOAT, 0) +
        COALESCE(cf4.value:output::FLOAT, 0) +
        COALESCE(cf4.value:cache_read_input::FLOAT, 0) +
        COALESCE(cf4.value:cache_write_input::FLOAT, 0)
    ), 4) AS total_credits,
    COUNT(DISTINCT h.REQUEST_ID) AS request_count
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY h,
     LATERAL FLATTEN(input => h.CREDITS_GRANULAR) cf1,
     LATERAL FLATTEN(input => cf1.value) cf2,
     LATERAL FLATTEN(input => cf2.value) cf3,
     LATERAL FLATTEN(input => cf3.value) cf4
WHERE cf3.key != 'start_time'
  AND h.START_TIME >= '<START_TIME>' AND h.START_TIME < '<END_TIME>'
GROUP BY cf3.key
ORDER BY total_credits DESC;
```

**AI Functions cost by model & function (COMPLETE, TRANSLATE, etc.)**
```sql
SELECT
    MODEL_NAME,
    FUNCTION_NAME,
    ROUND(SUM(TOKEN_CREDITS), 4) AS total_credits,
    SUM(TOKENS) AS total_tokens,
    COUNT(DISTINCT QUERY_ID) AS total_queries
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY
WHERE USAGE_TIME >= '<START_TIME>' AND USAGE_TIME < '<END_TIME>'
GROUP BY MODEL_NAME, FUNCTION_NAME
ORDER BY total_credits DESC;
```

**Overall spending by service type (AI vs compute vs storage)**
```sql
SELECT
    service_type,
    ROUND(SUM(credits_used), 2) AS total_credits,
    ROUND(SUM(credits_used) / SUM(SUM(credits_used)) OVER () * 100, 1) AS pct_of_total
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY
WHERE start_time >= DATEADD(DAY, -30, CURRENT_DATE())
  AND start_time < CURRENT_DATE()
GROUP BY service_type
ORDER BY total_credits DESC;
```

With these views, you can build a comprehensive AI cost dashboard. Happy to help you set one up in Streamlit if that would be useful.

---

## 2. Semantic View Autopilot — How It Fits Into the Agent Puzzle

This was one of the key questions from our call — how does Semantic View Autopilot accelerate the path from raw data to a working agent?

### The Short Version

Semantic View Autopilot uses AI to **automatically generate the semantic view** that sits between your physical tables and Cortex Analyst. Instead of manually writing the semantic view DDL (tables, relationships, facts, dimensions, metrics, synonyms), Autopilot analyses your tables and produces a production-ready semantic view in minutes rather than days.

### How It Works End-to-End

```
Your Tables (DTCC trades, positions, security ref)
        ↓
   SEMANTIC VIEW AUTOPILOT
   (Analyses columns, types, sample data, metadata)
        ↓
   SEMANTIC VIEW (auto-generated)
   - Tables with primary keys
   - Relationships (join paths)
   - Facts (row-level calculations)
   - Dimensions (grouping/filtering attributes)
   - Metrics (KPIs like total volume, avg trade size)
   - Synonyms (maps business terms → column names)
        ↓
   CORTEX AGENT
   (Attaches semantic view as a Cortex Analyst tool)
        ↓
   End User asks: "What's our total DTCC volume this month?"
   Agent routes to Analyst → Analyst uses semantic view → SQL generated → Answer returned
```

### Getting Started — Autopilot Workflow

1. **Navigate** to Snowsight → AI & ML → Semantic Views → Create with Autopilot
2. **Select your tables** — e.g., your DTCC trades, positions, and security reference tables
3. **Autopilot generates** a complete `CREATE SEMANTIC VIEW` statement
4. **Review and refine** — add synonyms for your business terminology, adjust metrics
5. **Attach to your agent** — in the agent config, add the semantic view as a Cortex Analyst tool

### Example: What Autopilot Generates

For DTCC-style data, the output would look something like:

```sql
CREATE OR REPLACE SEMANTIC VIEW MY_DB.MY_SCHEMA.DTCC_ANALYTICS
TABLES (
    trades AS MY_DB.MY_SCHEMA.DTCC_TRADES
      PRIMARY KEY (trade_id)
      WITH SYNONYMS ('transactions', 'deals')
      COMMENT = 'DTCC trade records',
    positions AS MY_DB.MY_SCHEMA.POSITIONS
      PRIMARY KEY (position_id)
      COMMENT = 'Current position data',
    securities AS MY_DB.MY_SCHEMA.SECURITY_REF
      PRIMARY KEY (cusip)
      WITH SYNONYMS ('instruments', 'assets')
      COMMENT = 'Security reference data'
)
RELATIONSHIPS (
    trade_to_security AS trades (security_id) REFERENCES securities,
    position_to_security AS positions (security_id) REFERENCES securities
)
DIMENSIONS (
    trades.trade_date AS trade_date COMMENT = 'Date the trade was executed',
    trades.counterparty AS counterparty_name
      WITH SYNONYMS = ('client', 'party') COMMENT = 'Trading counterparty'
)
METRICS (
    trades.total_volume AS SUM(trade_amount) COMMENT = 'Total trading volume',
    trades.avg_trade_size AS AVG(trade_amount) COMMENT = 'Average trade size'
)
COMMENT = 'Semantic view for DTCC trade analytics';
```

### Continuous Optimisation

Autopilot doesn't stop after initial generation. As users interact with the agent, it:
- Identifies questions producing poor results and suggests new synonyms or metrics
- Detects when underlying table schemas change and recommends updates
- Learns from real query patterns to improve accuracy over time

### Best Practices for Your DTCC Use Case

| Practice | Why |
|---|---|
| **Rich column descriptions** | "cusip" alone is ambiguous — "CUSIP: 9-character alphanumeric security identifier assigned by DTCC" is precise and helps Analyst generate correct SQL |
| **Synonyms aggressively** | Traders say "position" but the column is `holding_qty`. Map all business terms. |
| **Verified queries** | Add known-good SQL patterns for your most common questions. This anchors the Analyst. |
| **Explicit relationships** | Declare every join path. The agent cannot infer joins not declared in the semantic view. |
| **Start with 3-5 tables** | Validate accuracy on core tables before expanding. |

### Docs
- Semantic Views: https://docs.snowflake.com/user-guide/views-semantic/overview
- Cortex Analyst: https://docs.snowflake.com/user-guide/snowflake-cortex/cortex-analyst
- Autopilot blog: https://www.snowflake.com/en/blog/semantic-view-autopilot/

---

## 3. Promoting Agents Between Environments — Better Than Find & Replace

Ranjan — this was your question about whether there's a cleaner way to promote agents from dev → QA → prod without manually doing find-and-replace on fully-qualified names in the YAML. The answer is yes, and there are a few approaches depending on your CI/CD maturity.

### Method 1: ALTER AGENT (Quick Wins)

Cortex Agents are schema-level objects managed with SQL DDL. The key insight:

- **`CREATE OR REPLACE AGENT`** — deletes observability logs, threads, and SI bindings. Avoid in prod.
- **`ALTER AGENT ... MODIFY SET SPECIFICATION`** — updates the spec while **preserving history**. Use this.

```sql
-- Check if agent exists
SHOW AGENTS LIKE 'TRADE_ASSISTANT' IN SCHEMA PROD_DB.AGENTS;

-- If exists: ALTER (preserves history)
ALTER AGENT PROD_DB.AGENTS.TRADE_ASSISTANT
  MODIFY SET SPECIFICATION = '<new_spec_json>';

-- If new: CREATE
CREATE AGENT IF NOT EXISTS PROD_DB.AGENTS.TRADE_ASSISTANT
  SPECIFICATION = '<spec_json>';
```

### Method 2: Jinja2 Templates + Environment Configs (Recommended)

Maintain **one agent spec template** with environment placeholders. No copy-paste, no divergence.

**Environment configs:**
```yaml
# environments/dev.env.yml           # environments/prod.env.yml
environment: dev                      environment: prod
snowflake:                            snowflake:
  warehouse: MUFG_WH_DEV               warehouse: MUFG_WH_PROD
deployment:                           deployment:
  database: MUFG_DEV                    database: MUFG_PROD
  schema: AGENTS                        schema: AGENTS
```

**Single agent spec (source of truth):**
```yaml
# agents/specs/trade_assistant.yml
tools:
  - name: DTCCAnalytics
    type: cortex_analyst_text_to_sql
    semantic_view: "{{ env.database }}.{{ env.schema }}.SEM_DTCC_ANALYTICS"
    warehouse: "{{ env.warehouse }}"
orchestration:
  model: auto
  planning_instructions: |
    Use DTCCAnalytics for trades, positions, and volumes.
```

At deploy time, a simple Python script renders the template with the right environment config and runs `ALTER AGENT`. Same spec, different environment. No find-and-replace.

### Method 3: Full CI/CD with Evaluation Gates (Enterprise-Grade)

For when you're ready to productionise:

| Stage | Trigger | Eval Threshold | On Failure |
|---|---|---|---|
| PR Validate | Pull request | Advisory only | Comment on PR |
| DEV | Merge to dev | 0.60 (advisory) | Warning |
| QA | Merge to main | 0.70 (hard gate) | Block promotion |
| PROD | Manual approval | 0.80 (hard gate) | Auto-rollback |

Key additions: pre-deploy snapshots for rollback, schema drift detection (verify semantic view columns match tables), and evaluation with dynamic ground truth (validation SQL runs at eval time, not hardcoded answers).

**Open-source reference implementation:** https://github.com/Jeremy-Demlow/AgentMangement

### What's Coming

Snowflake is developing **native agent versioning** (`CREATE AGENT VERSION`). When this lands, rollback becomes version-based, canary deployments become possible, and promotion carries a version tag through environments with full auditability.

### Our Recommendation

Given your existing CI/CD pipelines:
1. **Now:** Use ALTER AGENT for manual promotion (Method 1)
2. **Next sprint:** Adopt Jinja2 templates to eliminate find-and-replace (Method 2)
3. **As usage grows:** Layer in evaluation gates and auto-rollback (Method 3)

---

## Summary

| Follow-Up | Status |
|---|---|
| AI cost granularity queries (metadata, model, cost) | Addressed — Section 1 with 5 production-ready queries |
| Semantic View Autopilot + Agents documentation | Addressed — Section 2 with architecture, workflow, and best practices |
| Better way to promote agents between environments | Addressed — Section 3 with three methods from quick to enterprise-grade |

## Next Steps

- **Asher:** Start building the DTCC data agent — use Autopilot to generate your semantic view (Section 2)
- **Asher + Aamer + Aditi:** Two-week follow-up to review agent and iterate
- **Aditi + Anthony:** Separate 15-20 min on the vulnerability testing agent demo
- Let me know if you'd like a working session on any of these topics

Looking forward to seeing the DTCC agent come together. Please don't hesitate to reach out with questions in the meantime.

Best,
Aamer
