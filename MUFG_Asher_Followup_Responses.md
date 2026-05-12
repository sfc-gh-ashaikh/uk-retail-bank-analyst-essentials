# MUFG Follow-Up: Aamer's Action Items

**Prepared by:** Aamer Shaikh, Sales Engineer — Snowflake
**Date:** May 12, 2026
**Meeting Reference:** MUFG-Snowflake AI Discussion (Aamer, Ben, Aditi / Ranjan, Asher, Gaurav, Anthony)

---

## Table of Contents

1. [AI Cost Granularity & Metadata Reporting](#1-ai-cost-granularity--metadata-reporting)
2. [Semantic View Autopilot & Cortex Agents](#2-semantic-view-autopilot--cortex-agents)
3. [Promoting Agents Between Environments](#3-promoting-agents-between-environments)

---

## 1. AI Cost Granularity & Metadata Reporting

### Overview

Snowflake provides **full granularity** on every AI interaction through dedicated `ACCOUNT_USAGE` views. You can see exactly which user ran what, which model was invoked, how many tokens were consumed (input vs output vs cache), and the resulting credit cost — all without any additional configuration.

### The Views You Need

Snowflake exposes **separate usage history views** for each AI product. This is your complete inventory:

| Account Usage View | What It Tracks | Key Columns |
|---|---|---|
| `CORTEX_AGENT_USAGE_HISTORY` | Cortex Agent interactions | `AGENT_NAME`, `USER_NAME`, `REQUEST_ID`, `TOKENS`, `TOKEN_CREDITS`, `CREDITS_GRANULAR`, `TOKENS_GRANULAR` |
| `CORTEX_ANALYST_USAGE_HISTORY` | Cortex Analyst (NL-to-SQL) | `USERNAME`, `CREDITS`, `REQUEST_COUNT` |
| `CORTEX_AISQL_USAGE_HISTORY` | Cortex AI Functions (COMPLETE, TRANSLATE, etc.) | `FUNCTION_NAME`, `MODEL_NAME`, `QUERY_ID`, `TOKEN_CREDITS`, `TOKENS`, `TOKEN_CREDITS_GRANULAR`, `TOKENS_GRANULAR` |
| `CORTEX_CODE_CLI_USAGE_HISTORY` | Cortex Code (CLI) | `USER_ID`, `REQUEST_ID`, `TOKEN_CREDITS`, `TOKENS`, `CREDITS_GRANULAR` |
| `CORTEX_SEARCH_DAILY_USAGE_HISTORY` | Cortex Search Services | `SERVICE_NAME`, `CONSUMPTION_TYPE`, `MODEL_NAME`, `CREDITS`, `TOKENS` |
| `SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY` | Snowflake Intelligence | `SNOWFLAKE_INTELLIGENCE_NAME`, `AGENT_NAME`, `USER_NAME`, `TOKEN_CREDITS`, `CREDITS_GRANULAR`, `TOKENS_GRANULAR` |
| `METERING_HISTORY` | Overall service-level credit consumption | `SERVICE_TYPE`, `CREDITS_USED` |

All views live under the `SNOWFLAKE.ACCOUNT_USAGE` schema.

### Query Cookbook

Below are production-ready queries. Replace `<START_TIME>` and `<END_TIME>` with your desired window (recommended: max 1 month per query).

#### 1.1 — Overall AI Spending Breakdown (Service Level)

See how AI credits compare to warehouse compute, storage, and other services:

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

#### 1.2 — Cortex Agent Cost by Agent (Which Agent Costs Most?)

```sql
SELECT
    AGENT_DATABASE_NAME,
    AGENT_SCHEMA_NAME,
    AGENT_NAME,
    SUM(TOKEN_CREDITS) AS total_credits,
    SUM(TOKENS) AS total_tokens,
    COUNT(DISTINCT REQUEST_ID) AS request_count,
    COUNT(DISTINCT USER_NAME) AS unique_users
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
WHERE START_TIME >= '<START_TIME>'
  AND START_TIME < '<END_TIME>'
GROUP BY AGENT_DATABASE_NAME, AGENT_SCHEMA_NAME, AGENT_NAME
ORDER BY total_credits DESC;
```

#### 1.3 — Cortex Agent Cost by Model (Which LLM Is Driving Cost?)

This uses the `CREDITS_GRANULAR` and `TOKENS_GRANULAR` VARIANT columns to drill into per-model, per-token-type (input/output/cache) detail:

```sql
SELECT
    cf4.key AS model_name,
    SUM(
        COALESCE(cf4.value:input::FLOAT, 0) +
        COALESCE(cf4.value:output::FLOAT, 0) +
        COALESCE(cf4.value:cache_read_input::FLOAT, 0) +
        COALESCE(cf4.value:cache_write_input::FLOAT, 0)
    ) AS total_credits,
    SUM(
        COALESCE(tf4.value:input::FLOAT, 0) +
        COALESCE(tf4.value:output::FLOAT, 0) +
        COALESCE(tf4.value:cache_read_input::FLOAT, 0) +
        COALESCE(tf4.value:cache_write_input::FLOAT, 0)
    ) AS total_tokens,
    COUNT(DISTINCT h.REQUEST_ID) AS request_count
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY h,
     LATERAL FLATTEN(input => h.CREDITS_GRANULAR) cf1,
     LATERAL FLATTEN(input => cf1.value) cf2,
     LATERAL FLATTEN(input => cf2.value) cf3,
     LATERAL FLATTEN(input => cf3.value) cf4,
     LATERAL FLATTEN(input => h.TOKENS_GRANULAR) tf1,
     LATERAL FLATTEN(input => tf1.value) tf2,
     LATERAL FLATTEN(input => tf2.value) tf3,
     LATERAL FLATTEN(input => tf3.value) tf4
WHERE cf3.key != 'start_time'
  AND tf3.key != 'start_time'
  AND cf2.key = tf2.key
  AND cf3.key = tf3.key
  AND cf4.key = tf4.key
  AND h.START_TIME >= '<START_TIME>'
  AND h.START_TIME < '<END_TIME>'
GROUP BY cf4.key
ORDER BY total_credits DESC;
```

#### 1.4 — Agent Cost by Underlying Service Type (Analyst vs Search vs Orchestration)

Understand how much of each agent's cost comes from Cortex Analyst calls, Cortex Search calls, vs the LLM orchestration itself:

```sql
SELECT
    cf3.key AS service_type,
    SUM(
        COALESCE(cf4.value:input::FLOAT, 0) +
        COALESCE(cf4.value:output::FLOAT, 0) +
        COALESCE(cf4.value:cache_read_input::FLOAT, 0) +
        COALESCE(cf4.value:cache_write_input::FLOAT, 0)
    ) AS total_credits,
    SUM(
        COALESCE(tf4.value:input::FLOAT, 0) +
        COALESCE(tf4.value:output::FLOAT, 0) +
        COALESCE(tf4.value:cache_read_input::FLOAT, 0) +
        COALESCE(tf4.value:cache_write_input::FLOAT, 0)
    ) AS total_tokens,
    COUNT(DISTINCT h.REQUEST_ID) AS request_count
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY h,
     LATERAL FLATTEN(input => h.CREDITS_GRANULAR) cf1,
     LATERAL FLATTEN(input => cf1.value) cf2,
     LATERAL FLATTEN(input => cf2.value) cf3,
     LATERAL FLATTEN(input => cf3.value) cf4,
     LATERAL FLATTEN(input => h.TOKENS_GRANULAR) tf1,
     LATERAL FLATTEN(input => tf1.value) tf2,
     LATERAL FLATTEN(input => tf2.value) tf3,
     LATERAL FLATTEN(input => tf3.value) tf4
WHERE cf3.key != 'start_time'
  AND tf3.key != 'start_time'
  AND cf2.key = tf2.key
  AND cf3.key = tf3.key
  AND h.START_TIME >= '<START_TIME>'
  AND h.START_TIME < '<END_TIME>'
GROUP BY cf3.key
ORDER BY total_credits DESC;
```

#### 1.5 — Cortex AI Functions Cost by Model (COMPLETE, TRANSLATE, etc.)

```sql
SELECT
    MODEL_NAME,
    FUNCTION_NAME,
    ROUND(SUM(TOKEN_CREDITS_GRANULAR:input::FLOAT), 4) AS input_credits,
    ROUND(SUM(TOKEN_CREDITS_GRANULAR:output::FLOAT), 4) AS output_credits,
    ROUND(SUM(TOKEN_CREDITS), 4) AS total_credits,
    SUM(TOKENS_GRANULAR:input::FLOAT) AS input_tokens,
    SUM(TOKENS_GRANULAR:output::FLOAT) AS output_tokens,
    COUNT(DISTINCT QUERY_ID) AS total_queries
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY
WHERE USAGE_TIME >= '<START_TIME>'
  AND USAGE_TIME < '<END_TIME>'
GROUP BY MODEL_NAME, FUNCTION_NAME
ORDER BY total_credits DESC;
```

#### 1.6 — Cortex Analyst Cost per User

```sql
SELECT
    USERNAME,
    ROUND(SUM(CREDITS), 4) AS total_credits,
    SUM(REQUEST_COUNT) AS request_count,
    ROUND(SUM(CREDITS) / NULLIF(SUM(REQUEST_COUNT), 0), 6) AS avg_credits_per_request
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY
WHERE START_TIME >= '<START_TIME>'
  AND START_TIME < '<END_TIME>'
GROUP BY USERNAME
ORDER BY total_credits DESC;
```

#### 1.7 — Cortex Search Cost by Service & Consumption Type

```sql
SELECT
    SERVICE_NAME,
    CONSUMPTION_TYPE,
    ROUND(SUM(CREDITS), 4) AS total_credits,
    SUM(TOKENS) AS total_tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_DAILY_USAGE_HISTORY
WHERE USAGE_DATE >= '<START_TIME>'
  AND USAGE_DATE < '<END_TIME>'
GROUP BY SERVICE_NAME, CONSUMPTION_TYPE
ORDER BY SERVICE_NAME, total_credits DESC;
```

### Understanding the GRANULAR Columns

The `CREDITS_GRANULAR` and `TOKENS_GRANULAR` columns in agent/code/intelligence views are **nested VARIANT** structures that break down usage by:

- **Service type** (e.g., `cortex_analyst`, `cortex_search`, `orchestration`)
- **Model name** (e.g., `claude-sonnet-4-5`, `openai-gpt-4.1`)
- **Token direction** (`input`, `output`, `cache_read_input`, `cache_write_input`)

This is the deepest level of granularity available — you can see exactly how many input tokens went to which model within which service call for each individual request.

### Key Takeaway for MUFG

With these views, MUFG can build a comprehensive AI cost dashboard that answers:
- Which agents are most expensive?
- Which LLM models drive the most cost?
- What's the split between orchestration, Analyst, and Search within an agent?
- Who are the heaviest AI users?
- How is AI spend trending over time?

---

## 2. Semantic View Autopilot & Cortex Agents

### What Is Semantic View Autopilot?

Semantic View Autopilot is a **generally available** Snowflake feature (released February 2026) that uses AI to automatically create, optimize, and maintain semantic views. Instead of manually authoring complex semantic view DDL, Autopilot:

1. **Analyzes your tables** — examines column names, data types, sample values, and existing metadata
2. **Generates a complete semantic view** — including tables, relationships, facts, dimensions, metrics, synonyms, and column descriptions
3. **Learns from real user activity** — iteratively improves the semantic model based on how users actually query data
4. **Maintains accuracy over time** — detects schema drift and suggests updates when underlying tables change

### How Semantic Views Fit Into the Agent Architecture

The relationship between semantic views and Cortex Agents is critical for structured data use cases like MUFG's DTCC trading data:

```
┌────────────────────────────────────────────────────┐
│                  End User Question                   │
│   "What is our total exposure to Acme Corp?"        │
└──────────────────────┬─────────────────────────────┘
                       │
┌──────────────────────▼─────────────────────────────┐
│              CORTEX AGENT (Orchestrator)             │
│  - Plans the task                                   │
│  - Selects the right tool (Analyst/Search/Custom)   │
│  - Reflects on results                              │
│  - Generates final response                         │
└──────────────────────┬─────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
┌───────▼──────┐ ┌─────▼──────┐ ┌────▼──────┐
│ CORTEX       │ │ CORTEX     │ │ CUSTOM    │
│ ANALYST      │ │ SEARCH     │ │ TOOLS     │
│ (Structured) │ │(Unstructured)│ │ (UDFs/SPs)│
└───────┬──────┘ └────────────┘ └───────────┘
        │
┌───────▼────────────────────────────────────────────┐
│              SEMANTIC VIEW                          │
│  The "contract" between business language & data    │
│  - Tables with primary keys                         │
│  - Relationships (joins)                            │
│  - Facts (row-level calculations)                   │
│  - Dimensions (grouping attributes)                 │
│  - Metrics (KPIs)                                   │
│  - Synonyms (business terminology mapping)          │
│  - Verified Queries (known-good SQL patterns)       │
└───────┬────────────────────────────────────────────┘
        │
┌───────▼────────────────────────────────────────────┐
│          PHYSICAL TABLES (e.g., DTCC data)          │
│   trades, positions, security_ref, counterparties   │
└────────────────────────────────────────────────────┘
```

### The Autopilot Workflow

#### Step 1: Point Autopilot at Your Tables

Autopilot can be invoked through the Snowsight UI:
- Navigate to **AI & ML > Semantic Views**
- Select **Create with Autopilot**
- Choose the tables you want to model (e.g., your trades, positions, security reference tables)

#### Step 2: Autopilot Generates the Semantic View

Autopilot produces a complete `CREATE SEMANTIC VIEW` statement including:

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
    trade_to_security AS
      trades (security_id) REFERENCES securities,
    position_to_security AS
      positions (security_id) REFERENCES securities
)
FACTS (
    trades.net_amount AS trade_amount * (1 - fee_rate)
      COMMENT = 'Net trade amount after fees'
)
DIMENSIONS (
    trades.trade_date AS trade_date
      COMMENT = 'Date the trade was executed',
    trades.counterparty AS counterparty_name
      WITH SYNONYMS = ('client', 'party')
      COMMENT = 'Name of the trading counterparty'
)
METRICS (
    trades.total_volume AS SUM(trade_amount)
      COMMENT = 'Total trading volume',
    trades.avg_trade_size AS AVG(trade_amount)
      COMMENT = 'Average trade size'
)
COMMENT = 'Semantic view for DTCC trade analytics';
```

#### Step 3: Attach the Semantic View to Your Agent

When configuring a Cortex Agent (via Snowsight, REST API, or SQL), you add the semantic view as a **Cortex Analyst tool**:

- **Snowsight:** Agent config > Tools > Add Cortex Analyst > Select your semantic view
- **SQL:** `CREATE AGENT ... SPECIFICATION = '{ "tools": [{ "type": "cortex_analyst_text_to_sql", "semantic_view": "MY_DB.MY_SCHEMA.DTCC_ANALYTICS" }] }'`

The agent will then route structured data questions to Cortex Analyst, which uses the semantic view to generate accurate SQL.

#### Step 4: Autopilot Continuously Optimizes

As users interact with the agent, Autopilot:
- Identifies questions that produce poor results
- Suggests new synonyms, metrics, or verified queries
- Detects when underlying table schemas change
- Recommends semantic view updates to maintain accuracy

### Best Practices for MUFG's DTCC Use Case

| Practice | Why It Matters |
|---|---|
| **Rich column descriptions** | Autopilot uses descriptions to understand column semantics. "cusip" alone is ambiguous — "CUSIP: 9-character alphanumeric security identifier assigned by DTCC" is precise. |
| **Synonyms everywhere** | Your traders say "position" but the column is `holding_qty`. Add synonyms aggressively: `WITH SYNONYMS = ('position', 'holding', 'inventory')` |
| **Verified queries** | Add known-good SQL patterns for common questions. This anchors the Analyst to proven query shapes. |
| **Explicit relationships** | Define every join path. If trades link to securities via `cusip`, declare it. The agent cannot infer joins that aren't declared. |
| **Start simple, iterate** | Begin with 3-5 tables and the most common questions. Validate accuracy. Expand incrementally. |

### Documentation References

- Semantic Views Overview: https://docs.snowflake.com/user-guide/views-semantic/overview
- CREATE SEMANTIC VIEW: https://docs.snowflake.com/sql-reference/sql/create-semantic-view
- Cortex Analyst with Semantic Views: https://docs.snowflake.com/user-guide/snowflake-cortex/cortex-analyst
- Semantic View Autopilot Announcement: https://www.snowflake.com/en/blog/semantic-view-autopilot/

---

## 3. Promoting Agents Between Environments

### The Challenge

MUFG asked about promoting Cortex Agents from dev to QA to prod. The concern was that agent specifications reference environment-specific fully-qualified names (database, schema, warehouse) — requiring a "find and replace" in the YAML when moving between environments.

### The Answer: Yes, There Are Better Approaches

There are three progressively more sophisticated methods, depending on MUFG's CI/CD maturity.

### Method 1: SQL-Based Promotion with CREATE/ALTER AGENT

Cortex Agents are **schema-level objects** that can be managed with SQL DDL. The recommended approach:

```sql
-- In DEV: Create the agent
CREATE AGENT IF NOT EXISTS DEV_DB.AGENTS.TRADE_ASSISTANT
  SPECIFICATION = '{ ... }';

-- In PROD: Create/update with environment-specific references
ALTER AGENT PROD_DB.AGENTS.TRADE_ASSISTANT
  MODIFY SET SPECIFICATION = '{ ... }';
```

**Critical distinction:**
- `CREATE OR REPLACE AGENT` **deletes** observability logs, threads, and Snowflake Intelligence bindings
- `ALTER AGENT ... MODIFY SET SPECIFICATION` **preserves** history while updating the spec

**Best practice:** Always check if the agent exists first, then use ALTER to update:

```sql
-- Check existence
SHOW AGENTS LIKE 'TRADE_ASSISTANT' IN SCHEMA PROD_DB.AGENTS;

-- If exists: ALTER (preserves history)
ALTER AGENT PROD_DB.AGENTS.TRADE_ASSISTANT
  MODIFY SET SPECIFICATION = '<new_spec>';

-- If new: CREATE
CREATE AGENT IF NOT EXISTS PROD_DB.AGENTS.TRADE_ASSISTANT
  SPECIFICATION = '<spec>';
```

### Method 2: Jinja2-Templated Specs with Environment Configs

This is the recommended approach for any team doing CI/CD. Maintain **one agent spec template** with environment variables:

#### Environment Config Files

```yaml
# environments/dev.env.yml
environment: dev
snowflake:
  role: MUFG_DEPLOY_ROLE_DEV
  warehouse: MUFG_WH_DEV
deployment:
  database: MUFG_DEV
  schema: AGENTS
agent:
  name_suffix: _DEV
```

```yaml
# environments/prod.env.yml
environment: prod
snowflake:
  role: MUFG_DEPLOY_ROLE_PROD
  warehouse: MUFG_WH_PROD
deployment:
  database: MUFG_PROD
  schema: AGENTS
agent:
  name_suffix: _PROD
```

#### Agent Spec Template (Single Source of Truth)

```yaml
# agents/specs/trade_assistant.yml
tools:
  - name: DTCCAnalytics
    type: cortex_analyst_text_to_sql
    semantic_view: "{{ env.database }}.{{ env.schema }}.SEM_DTCC_ANALYTICS"
    warehouse: "{{ env.warehouse }}"
  - name: TradeSearch
    type: cortex_search
    service: "{{ env.database }}.{{ env.schema }}.TRADE_SEARCH_SVC"
orchestration:
  model: auto
  planning_instructions: |
    Use DTCCAnalytics for questions about trades, positions, and volumes.
    Use TradeSearch for questions about trade documentation and contracts.
  response_instructions: |
    Always cite the data source. Format numbers with appropriate precision.
```

#### Deployment Script (Python)

```python
import jinja2
import yaml
import snowflake.connector

def deploy_agent(env_name: str, spec_template_path: str):
    # Load environment config
    with open(f"environments/{env_name}.env.yml") as f:
        env_config = yaml.safe_load(f)

    # Render the spec template
    with open(spec_template_path) as f:
        template = jinja2.Template(f.read())
    rendered_spec = template.render(env=env_config['deployment'])

    # Deploy to Snowflake
    agent_fqn = (
        f"{env_config['deployment']['database']}."
        f"{env_config['deployment']['schema']}."
        f"TRADE_ASSISTANT{env_config['agent']['name_suffix']}"
    )

    conn = snowflake.connector.connect(
        connection_name=env_name
    )
    cur = conn.cursor()

    # Check if agent exists
    cur.execute(f"SHOW AGENTS LIKE 'TRADE_ASSISTANT%' IN SCHEMA "
                f"{env_config['deployment']['database']}."
                f"{env_config['deployment']['schema']}")

    if cur.fetchone():
        # ALTER preserves history
        cur.execute(f"ALTER AGENT {agent_fqn} "
                    f"MODIFY SET SPECIFICATION = '{rendered_spec}'")
    else:
        # CREATE for new agents
        cur.execute(f"CREATE AGENT IF NOT EXISTS {agent_fqn} "
                    f"SPECIFICATION = '{rendered_spec}'")
```

This eliminates all "find and replace" — the same template deploys to any environment.

### Method 3: Full CI/CD Pipeline with Evaluation Gates

For production-grade deployments, add automated evaluation and rollback:

```
Feature Branch → PR Validation → DEV (auto-deploy) → QA (auto-deploy) → PROD (manual + eval gate)
```

**Pipeline stages:**

| Stage | Trigger | Eval Threshold | On Failure |
|---|---|---|---|
| PR Validate | Pull request | Advisory only | Comment on PR |
| DEV Deploy | Merge to `dev` | 0.60 (advisory) | Warning, no block |
| QA Deploy | Merge to `main` | 0.70 (hard gate) | Block promotion |
| PROD Deploy | Manual approval | 0.80 (hard gate) | Auto-rollback to snapshot |

**Key components:**

1. **Pre-deploy snapshot:** Before every deployment, capture the current agent state (`DESCRIBE AGENT` → JSON) and semantic views for rollback
2. **Schema drift detection:** Verify that semantic view columns still match the underlying tables
3. **Evaluation with dynamic ground truth:** Use validation queries that run at eval time against current data, not hardcoded expected answers
4. **Auto-rollback:** If prod evaluation fails, automatically restore the previous snapshot

### What's Coming: Native Agent Versioning

Snowflake is developing **native agent versioning** (`CREATE AGENT VERSION`), semantic versioning, and consumer pinning. When this lands:

- Rollback becomes version-based instead of snapshot-based
- Canary deployments become possible (route % of traffic to new version)
- Promotion carries a version tag through dev → QA → prod with full auditability

### Recommendation for MUFG

Given that MUFG already has CI/CD pipelines and tagged data:

1. **Immediate:** Start with Method 1 (SQL-based CREATE/ALTER) for manual promotion
2. **Next sprint:** Adopt Method 2 (Jinja2 templates + environment configs) to eliminate find-and-replace
3. **When ready:** Layer in Method 3 (evaluation gates) as agent usage grows in production

### Reference Implementation

A complete open-source CI/CD framework for Cortex Agents is available:
- GitHub: https://github.com/Jeremy-Demlow/AgentMangement
- Article: https://medium.com/@jeremy.demlow_35029/ci-cd-for-snowflake-cortex-agents-a-practical-framework-94f2e590e1ae

---

## Summary of Follow-Up Items

| # | Action Item | Status | Response |
|---|---|---|---|
| 1 | Send queries on full AI cost granularity (metadata, model, cost) | Addressed | Section 1: Complete query cookbook with 7 production-ready queries across all AI services |
| 2 | Send documentation on semantic view autopilot with agents | Addressed | Section 2: End-to-end explanation of Autopilot → Semantic View → Agent pipeline |
| 3 | Check if there's a better way to promote agents between environments | Addressed | Section 3: Three methods from simple SQL to full CI/CD with eval gates |

---

## Next Steps

- **Asher:** Create the DTCC data agent using semantic view autopilot, referencing Section 2 for best practices
- **Asher + Aamer + Aditi:** Follow-up meeting in two weeks to review agent creation and iterate
- **Aditi + Anthony:** Separate 15-20 min session on the vulnerability testing agent demo
- **Aditi:** Send invite for May 11th 4 PM follow-up (note: may need to reschedule as date has passed)

---

*Prepared with Snowflake Cortex Code. For questions, contact Aamer Shaikh.*
