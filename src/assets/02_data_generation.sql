-- =============================================================================
-- NorthBridge Bank HOL: Step 3 - Synthetic Data Generation
-- Generates realistic UK retail banking data entirely within Snowflake
-- No external files or stages required for this step
--
-- Tables generated:
--   RAW.PRODUCTS      (~20 rows)     - Bank product catalogue
--   RAW.CUSTOMERS     (~10,000 rows) - UK retail customers
--   RAW.ACCOUNTS      (~15,000 rows) - Customer accounts
--   RAW.LOANS         (~3,000 rows)  - Loan portfolio
--   RAW.TRANSACTIONS  (~500,000 rows)- 6 months of transaction history
-- =============================================================================

USE DATABASE NORTHBRIDGE_BANK_HOL;
USE SCHEMA RAW;
USE WAREHOUSE NORTHBRIDGE_WH;
USE ROLE SYSADMIN;

-- =============================================================================
-- 1. PRODUCTS TABLE
-- Product catalogue with LCR classification and Basel III risk weights
-- =============================================================================
CREATE OR REPLACE TABLE RAW.PRODUCTS (
    product_id          NUMBER          NOT NULL PRIMARY KEY,
    product_code        VARCHAR(20)     NOT NULL,
    product_name        VARCHAR(100)    NOT NULL,
    product_type        VARCHAR(50)     NOT NULL,
    lcr_category        VARCHAR(20)     NOT NULL,
    lcr_liability_cat   VARCHAR(50)     NOT NULL,
    risk_weight_pct     NUMBER(5,2)     NOT NULL,
    is_active           BOOLEAN         DEFAULT TRUE,
    created_at          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO RAW.PRODUCTS VALUES
    (1,  'CA_BASIC',    'Basic Current Account',            'CURRENT',   'NON_HQLA',   'RETAIL_DEPOSIT',            0.00,  TRUE, CURRENT_TIMESTAMP()),
    (2,  'CA_PREMIER',  'Premier Current Account',          'CURRENT',   'NON_HQLA',   'RETAIL_DEPOSIT',            0.00,  TRUE, CURRENT_TIMESTAMP()),
    (3,  'CA_BUSINESS', 'Business Current Account',         'CURRENT',   'NON_HQLA',   'SME_OPERATIONAL',           0.00,  TRUE, CURRENT_TIMESTAMP()),
    (4,  'SA_EASY',     'Easy Access Savings Account',      'SAVINGS',   'NON_HQLA',   'RETAIL_DEPOSIT',            0.00,  TRUE, CURRENT_TIMESTAMP()),
    (5,  'SA_FIXED1',   'Fixed Rate Bond 1 Year',           'SAVINGS',   'NON_HQLA',   'RETAIL_DEPOSIT',            0.00,  TRUE, CURRENT_TIMESTAMP()),
    (6,  'SA_FIXED3',   'Fixed Rate Bond 3 Year',           'SAVINGS',   'HQLA_L2A',   'RETAIL_DEPOSIT',            0.00,  TRUE, CURRENT_TIMESTAMP()),
    (7,  'ISA_CASH',    'Cash ISA',                         'ISA',       'HQLA_L2A',   'RETAIL_DEPOSIT',            0.00,  TRUE, CURRENT_TIMESTAMP()),
    (8,  'ISA_HELP',    'Help to Buy ISA',                  'ISA',       'HQLA_L2A',   'RETAIL_DEPOSIT',            0.00,  TRUE, CURRENT_TIMESTAMP()),
    (9,  'ISA_LISA',    'Lifetime ISA',                     'ISA',       'HQLA_L2A',   'RETAIL_DEPOSIT',            0.00,  TRUE, CURRENT_TIMESTAMP()),
    (10, 'CA_YOUTH',    'Youth Current Account',            'CURRENT',   'NON_HQLA',   'RETAIL_DEPOSIT',            0.00,  TRUE, CURRENT_TIMESTAMP()),
    (11, 'MTG_RESI',    'Residential Mortgage',             'MORTGAGE',  'NON_HQLA',   'SECURED_NON_HQLA',          35.00, TRUE, CURRENT_TIMESTAMP()),
    (12, 'MTG_BTL',     'Buy-to-Let Mortgage',              'MORTGAGE',  'NON_HQLA',   'SECURED_NON_HQLA',          50.00, TRUE, CURRENT_TIMESTAMP()),
    (13, 'LOAN_PERS',   'Personal Loan',                    'PERSONAL',  'NON_HQLA',   'SECURED_NON_HQLA',          75.00, TRUE, CURRENT_TIMESTAMP()),
    (14, 'LOAN_AUTO',   'Auto Finance Loan',                'AUTO',      'NON_HQLA',   'SECURED_NON_HQLA',          75.00, TRUE, CURRENT_TIMESTAMP()),
    (15, 'LOAN_CONS',   'Debt Consolidation Loan',          'PERSONAL',  'NON_HQLA',   'SECURED_NON_HQLA',          100.00,TRUE, CURRENT_TIMESTAMP()),
    (16, 'OD_ARRANGED', 'Arranged Overdraft',               'OVERDRAFT', 'NON_HQLA',   'COMMITTED_FACILITY_RETAIL', 0.00,  TRUE, CURRENT_TIMESTAMP()),
    (17, 'CC_STANDARD', 'Standard Credit Card',             'CREDIT_CARD','NON_HQLA',  'COMMITTED_FACILITY_RETAIL', 0.00,  TRUE, CURRENT_TIMESTAMP()),
    (18, 'CC_REWARDS',  'Rewards Credit Card',              'CREDIT_CARD','NON_HQLA',  'COMMITTED_FACILITY_RETAIL', 0.00,  TRUE, CURRENT_TIMESTAMP()),
    (19, 'SA_NOTICE',   'Notice Savings Account (90 day)',  'SAVINGS',   'HQLA_L1',    'RETAIL_DEPOSIT',            0.00,  TRUE, CURRENT_TIMESTAMP()),
    (20, 'BOND_CORP',   'Corporate Bond Account',           'BOND',      'HQLA_L1',    'WHOLESALE_NON_OPERATIONAL', 0.00,  TRUE, CURRENT_TIMESTAMP());

-- =============================================================================
-- 2. CUSTOMERS TABLE
-- 10,000 UK retail customers with realistic identifiers
-- =============================================================================
CREATE OR REPLACE TABLE RAW.CUSTOMERS (
    customer_id         NUMBER          NOT NULL PRIMARY KEY,
    first_name          VARCHAR(50)     NOT NULL,
    last_name           VARCHAR(50)     NOT NULL,
    date_of_birth       DATE            NOT NULL,
    email               VARCHAR(150),
    phone               VARCHAR(20),
    address_line1       VARCHAR(100),
    address_line2       VARCHAR(100),
    city                VARCHAR(50),
    postcode            VARCHAR(10)     NOT NULL,
    region              VARCHAR(30)     NOT NULL,
    ni_number           VARCHAR(13)     NOT NULL,
    kyc_status          VARCHAR(20)     NOT NULL,
    kyc_verified_date   DATE,
    risk_rating         VARCHAR(10)     NOT NULL,
    customer_since      DATE            NOT NULL,
    is_active           BOOLEAN         DEFAULT TRUE,
    segment             VARCHAR(30)     NOT NULL,
    created_at          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO RAW.CUSTOMERS
WITH
first_names AS (
    SELECT f.* FROM (VALUES
        ('Oliver'),('Jack'),('Harry'),('George'),('Noah'),('Charlie'),('Jacob'),('Alfie'),('Freddie'),('Oscar'),
        ('Amelia'),('Olivia'),('Isla'),('Emily'),('Poppy'),('Ava'),('Isabella'),('Jessica'),('Lily'),('Sophie'),
        ('Thomas'),('William'),('James'),('Joshua'),('Henry'),('Samuel'),('Lucas'),('Daniel'),('Ethan'),('Mason'),
        ('Grace'),('Evie'),('Mia'),('Ruby'),('Ella'),('Florence'),('Freya'),('Charlotte'),('Daisy'),('Alice'),
        ('Mohammed'),('Muhammad'),('Adam'),('Liam'),('Logan'),('Nathan'),('Ryan'),('Dylan'),('Tyler'),('Callum'),
        ('Fatima'),('Aisha'),('Zara'),('Sara'),('Maya'),('Priya'),('Ananya'),('Riya'),('Arya'),('Neha')
    ) AS f(v)
),
last_names AS (
    SELECT l.* FROM (VALUES
        ('Smith'),('Jones'),('Williams'),('Taylor'),('Brown'),('Davies'),('Evans'),('Wilson'),('Thomas'),('Roberts'),
        ('Johnson'),('Walker'),('Wright'),('Thompson'),('White'),('Hughes'),('Edwards'),('Green'),('Hall'),('Lewis'),
        ('Harris'),('Clarke'),('Patel'),('Jackson'),('Wood'),('Turner'),('Martin'),('Cooper'),('Hill'),('Ward'),
        ('Morris'),('Moore'),('Clark'),('Lee'),('King'),('Baker'),('Harrison'),('Morgan'),('Allen'),('James'),
        ('Khan'),('Ahmed'),('Ali'),('Shah'),('Hussain'),('Malik'),('Singh'),('Kumar'),('Sharma'),('Gupta')
    ) AS l(v)
),
cities AS (
    SELECT c.* FROM (VALUES
        ('London',          'LONDON'),
        ('Manchester',      'NORTH_WEST'),
        ('Birmingham',      'WEST_MIDLANDS'),
        ('Leeds',           'YORKSHIRE'),
        ('Liverpool',       'NORTH_WEST'),
        ('Sheffield',       'YORKSHIRE'),
        ('Bristol',         'SOUTH_WEST'),
        ('Edinburgh',       'SCOTLAND'),
        ('Glasgow',         'SCOTLAND'),
        ('Cardiff',         'WALES'),
        ('Leicester',       'EAST_MIDLANDS'),
        ('Nottingham',      'EAST_MIDLANDS'),
        ('Newcastle',       'NORTH_EAST'),
        ('Brighton',        'SOUTH_EAST'),
        ('Southampton',     'SOUTH_EAST'),
        ('Oxford',          'SOUTH_EAST'),
        ('Cambridge',       'EAST'),
        ('Reading',         'SOUTH_EAST'),
        ('Coventry',        'WEST_MIDLANDS'),
        ('Bradford',        'YORKSHIRE'),
        ('Hull',            'YORKSHIRE'),
        ('Derby',           'EAST_MIDLANDS'),
        ('Plymouth',        'SOUTH_WEST'),
        ('Stoke-on-Trent',  'WEST_MIDLANDS'),
        ('Wolverhampton',   'WEST_MIDLANDS'),
        ('Belfast',         'NORTHERN_IRELAND'),
        ('Portsmouth',      'SOUTH_EAST'),
        ('Norwich',         'EAST'),
        ('Milton Keynes',   'SOUTH_EAST'),
        ('Swindon',         'SOUTH_WEST')
    ) AS c(v, region)
),
postcode_areas AS (
    SELECT p.* FROM (VALUES
        ('EC1A'),('EC2V'),('WC2N'),('W1A'),('SW1A'),('SE1'),('N1'),('E1'),('W2'),('NW1'),
        ('M1'),('M2'),('M3'),('B1'),('B2'),('LS1'),('LS2'),('L1'),('L2'),('S1'),
        ('BS1'),('BS2'),('EH1'),('G1'),('CF1'),('LE1'),('NG1'),('NE1'),('BN1'),('SO1'),
        ('OX1'),('CB1'),('RG1'),('CV1'),('BD1'),('HU1'),('DE1'),('PL1'),('ST1'),('WV1')
    ) AS p(v)
),
gen AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SEQ4()) AS rn,
        UNIFORM(1, 60,   RANDOM()) AS fn_idx,
        UNIFORM(1, 50,   RANDOM()) AS ln_idx,
        UNIFORM(1, 30,   RANDOM()) AS city_idx,
        UNIFORM(1, 40,   RANDOM()) AS pc_idx,
        ABS(RANDOM()) % 9000 + 1000                                    AS pc_suffix,
        UNIFORM(0, 25,   RANDOM())                                     AS age_years_extra,
        DATEADD(DAY, -(UNIFORM(6570, 25550, RANDOM())), CURRENT_DATE()) AS dob,
        DATEADD(DAY, -(UNIFORM(30,   3650,  RANDOM())), CURRENT_DATE()) AS cust_since,
        UNIFORM(0, 99,   RANDOM())                                     AS kyc_rand,
        UNIFORM(0, 99,   RANDOM())                                     AS risk_rand,
        UNIFORM(0, 99,   RANDOM())                                     AS seg_rand,
        CHAR(65 + UNIFORM(0, 25, RANDOM())) AS ni_l1,
        CHAR(65 + UNIFORM(0, 25, RANDOM())) AS ni_l2,
        LPAD(UNIFORM(0, 99, RANDOM())::VARCHAR, 2, '0')  AS ni_d1,
        LPAD(UNIFORM(0, 99, RANDOM())::VARCHAR, 2, '0')  AS ni_d2,
        LPAD(UNIFORM(0, 99, RANDOM())::VARCHAR, 2, '0')  AS ni_d3,
        CHAR(65 + UNIFORM(0, 3, RANDOM()))               AS ni_l3
    FROM TABLE(GENERATOR(ROWCOUNT => 10000))
),
names_joined AS (
    SELECT
        g.rn,
        fn.v AS first_name,
        ln.v AS last_name,
        g.dob,
        g.cust_since,
        ci.v AS city,
        ci.region,
        pa.v AS pc_area,
        g.pc_suffix,
        g.kyc_rand,
        g.risk_rand,
        g.seg_rand,
        g.ni_l1 || g.ni_l2 || ' ' || g.ni_d1 || ' ' || g.ni_d2 || ' ' || g.ni_d3 || ' ' || g.ni_l3 AS ni_number
    FROM gen g
    LEFT JOIN (SELECT v, ROW_NUMBER() OVER (ORDER BY SEQ4()) AS idx FROM first_names) fn ON (g.fn_idx = fn.idx)
    LEFT JOIN (SELECT v, ROW_NUMBER() OVER (ORDER BY SEQ4()) AS idx FROM last_names)  ln ON (g.ln_idx = ln.idx)
    LEFT JOIN (SELECT v, region, ROW_NUMBER() OVER (ORDER BY SEQ4()) AS idx FROM cities) ci ON (g.city_idx = ci.idx)
    LEFT JOIN (SELECT v, ROW_NUMBER() OVER (ORDER BY SEQ4()) AS idx FROM postcode_areas) pa ON (g.pc_idx = pa.idx)
)
SELECT
    rn                                              AS customer_id,
    first_name,
    last_name,
    dob                                             AS date_of_birth,
    LOWER(first_name) || '.' || LOWER(last_name) || rn::VARCHAR || '@email.co.uk' AS email,
    '07' || LPAD((ABS(RANDOM()) % 900000000)::VARCHAR, 9, '0')      AS phone,
    UNIFORM(1, 999, RANDOM())::VARCHAR || ' ' || city || ' Road'    AS address_line1,
    NULL                                            AS address_line2,
    city,
    pc_area || ' ' || LPAD((ABS(RANDOM()) % 9 + 1)::VARCHAR, 1, '0') ||
        CHAR(65 + UNIFORM(0,25,RANDOM())) || CHAR(65 + UNIFORM(0,25,RANDOM())) AS postcode,
    COALESCE(region, 'LONDON')                      AS region,
    ni_number,
    CASE WHEN kyc_rand < 80 THEN 'VERIFIED'
         WHEN kyc_rand < 92 THEN 'PENDING'
         ELSE 'FAILED' END                          AS kyc_status,
    CASE WHEN kyc_rand < 80 THEN DATEADD(DAY, UNIFORM(1, 30, RANDOM()), cust_since) ELSE NULL END AS kyc_verified_date,
    CASE WHEN risk_rand < 60 THEN 'LOW'
         WHEN risk_rand < 85 THEN 'MEDIUM'
         WHEN risk_rand < 97 THEN 'HIGH'
         ELSE 'PEP' END                             AS risk_rating,
    cust_since                                      AS customer_since,
    TRUE                                            AS is_active,
    CASE WHEN seg_rand < 40 THEN 'MASS_MARKET'
         WHEN seg_rand < 65 THEN 'AFFLUENT'
         WHEN seg_rand < 85 THEN 'SME'
         ELSE 'PREMIER' END                         AS segment,
    CURRENT_TIMESTAMP()                             AS created_at
FROM names_joined;

-- =============================================================================
-- 3. ACCOUNTS TABLE
-- ~15,000 accounts (avg 1.5 per customer, some customers have multiple accounts)
-- =============================================================================
CREATE OR REPLACE TABLE RAW.ACCOUNTS (
    account_id              NUMBER          NOT NULL PRIMARY KEY,
    customer_id             NUMBER          NOT NULL,
    product_id              NUMBER          NOT NULL,
    account_type            VARCHAR(30)     NOT NULL,
    sort_code               VARCHAR(8)      NOT NULL,
    account_number          VARCHAR(8)      NOT NULL,
    balance_gbp             NUMBER(15,2)    NOT NULL DEFAULT 0.00,
    opened_date             DATE            NOT NULL,
    closed_date             DATE,
    status                  VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE',
    lcr_liability_category  VARCHAR(50)     NOT NULL,
    overdraft_limit_gbp     NUMBER(10,2)    DEFAULT 0.00,
    interest_rate_pct       NUMBER(6,4)     DEFAULT 0.0000,
    created_at              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO RAW.ACCOUNTS
WITH gen AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SEQ4())       AS rn,
        UNIFORM(1, 10000, RANDOM())               AS customer_id,
        UNIFORM(1, 20,    RANDOM())               AS product_id_raw,
        ABS(RANDOM()) % 900000 + 100000           AS sort_suffix,
        LPAD((ABS(RANDOM()) % 90000000 + 10000000)::VARCHAR, 8, '0') AS account_number,
        DATEADD(DAY, -(UNIFORM(30, 3650, RANDOM())), CURRENT_DATE()) AS opened_date,
        UNIFORM(0, 99, RANDOM())                  AS status_rand,
        UNIFORM(0, 99, RANDOM())                  AS bal_tier
    FROM TABLE(GENERATOR(ROWCOUNT => 15000))
),
enriched AS (
    SELECT
        g.*,
        p.product_id,
        p.product_type  AS account_type,
        p.lcr_liability_cat AS lcr_liability_category,
        p.risk_weight_pct
    FROM gen g
    JOIN RAW.PRODUCTS p ON p.product_id = g.product_id_raw
    WHERE p.product_type IN ('CURRENT','SAVINGS','ISA','BOND')
)
SELECT
    rn                  AS account_id,
    customer_id,
    product_id,
    account_type,
    '20-' || LPAD((ABS(RANDOM()) % 90 + 10)::VARCHAR, 2, '0') || '-' ||
        LPAD((ABS(RANDOM()) % 90 + 10)::VARCHAR, 2, '0')           AS sort_code,
    account_number,
    CASE
        WHEN account_type = 'CURRENT' AND bal_tier < 30  THEN ROUND(UNIFORM(100,    5000,   RANDOM())::FLOAT, 2)
        WHEN account_type = 'CURRENT' AND bal_tier < 70  THEN ROUND(UNIFORM(5000,   25000,  RANDOM())::FLOAT, 2)
        WHEN account_type = 'CURRENT'                    THEN ROUND(UNIFORM(25000,  250000, RANDOM())::FLOAT, 2)
        WHEN account_type = 'SAVINGS' AND bal_tier < 40  THEN ROUND(UNIFORM(500,    10000,  RANDOM())::FLOAT, 2)
        WHEN account_type = 'SAVINGS' AND bal_tier < 80  THEN ROUND(UNIFORM(10000,  100000, RANDOM())::FLOAT, 2)
        WHEN account_type = 'SAVINGS'                    THEN ROUND(UNIFORM(100000, 500000, RANDOM())::FLOAT, 2)
        WHEN account_type = 'ISA'                        THEN ROUND(UNIFORM(1000,   85000,  RANDOM())::FLOAT, 2)
        ELSE                                                  ROUND(UNIFORM(10000,  1000000,RANDOM())::FLOAT, 2)
    END                 AS balance_gbp,
    opened_date,
    CASE WHEN status_rand > 96 THEN DATEADD(DAY, UNIFORM(1, 365, RANDOM()), opened_date) ELSE NULL END AS closed_date,
    CASE WHEN status_rand > 96 THEN 'CLOSED'
         WHEN status_rand > 93 THEN 'DORMANT'
         ELSE 'ACTIVE' END  AS status,
    lcr_liability_category,
    CASE WHEN account_type = 'CURRENT' THEN ROUND(UNIFORM(0, 5000, RANDOM())::FLOAT, 2) ELSE 0.00 END AS overdraft_limit_gbp,
    CASE
        WHEN account_type = 'SAVINGS' THEN ROUND(UNIFORM(200, 500, RANDOM())::FLOAT / 100, 4)
        WHEN account_type = 'ISA'     THEN ROUND(UNIFORM(300, 450, RANDOM())::FLOAT / 100, 4)
        WHEN account_type = 'BOND'    THEN ROUND(UNIFORM(400, 600, RANDOM())::FLOAT / 100, 4)
        ELSE 0.0000
    END                 AS interest_rate_pct,
    CURRENT_TIMESTAMP() AS created_at
FROM enriched;

-- =============================================================================
-- 4. LOANS TABLE
-- ~3,000 loans (mortgages, personal loans, auto finance)
-- =============================================================================
CREATE OR REPLACE TABLE RAW.LOANS (
    loan_id                 NUMBER          NOT NULL PRIMARY KEY,
    customer_id             NUMBER          NOT NULL,
    product_id              NUMBER          NOT NULL,
    loan_type               VARCHAR(30)     NOT NULL,
    original_amount_gbp     NUMBER(15,2)    NOT NULL,
    outstanding_balance_gbp NUMBER(15,2)    NOT NULL,
    interest_rate_pct       NUMBER(6,4)     NOT NULL,
    term_months             NUMBER(3)       NOT NULL,
    start_date              DATE            NOT NULL,
    maturity_date           DATE            NOT NULL,
    monthly_payment_gbp     NUMBER(10,2)    NOT NULL,
    risk_weight_pct         NUMBER(5,2)     NOT NULL,
    collateral_type         VARCHAR(50),
    collateral_value_gbp    NUMBER(15,2),
    status                  VARCHAR(20)     NOT NULL DEFAULT 'PERFORMING',
    arrears_days            NUMBER(3)       DEFAULT 0,
    created_at              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO RAW.LOANS
WITH gen AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SEQ4())         AS rn,
        UNIFORM(1, 10000, RANDOM())                 AS customer_id,
        UNIFORM(0, 99,    RANDOM())                 AS type_rand,
        UNIFORM(0, 99,    RANDOM())                 AS status_rand,
        DATEADD(MONTH, -(UNIFORM(1, 120, RANDOM())), CURRENT_DATE()) AS start_date
    FROM TABLE(GENERATOR(ROWCOUNT => 3000))
),
typed AS (
    SELECT
        g.*,
        CASE
            WHEN type_rand < 45 THEN 'MORTGAGE'
            WHEN type_rand < 65 THEN 'BTL_MORTGAGE'
            WHEN type_rand < 82 THEN 'PERSONAL'
            ELSE 'AUTO'
        END AS loan_type,
        CASE
            WHEN type_rand < 45 THEN 11
            WHEN type_rand < 65 THEN 12
            WHEN type_rand < 82 THEN 13
            ELSE 14
        END AS product_id
    FROM gen g
)
SELECT
    t.rn                AS loan_id,
    t.customer_id,
    t.product_id,
    t.loan_type,
    CASE
        WHEN t.loan_type = 'MORTGAGE'     THEN ROUND(UNIFORM(100000, 600000,  RANDOM())::FLOAT, 2)
        WHEN t.loan_type = 'BTL_MORTGAGE' THEN ROUND(UNIFORM(80000,  450000,  RANDOM())::FLOAT, 2)
        WHEN t.loan_type = 'PERSONAL'     THEN ROUND(UNIFORM(2000,   50000,   RANDOM())::FLOAT, 2)
        ELSE                                   ROUND(UNIFORM(5000,   40000,   RANDOM())::FLOAT, 2)
    END                                         AS original_amount_gbp,
    ROUND(
        CASE
            WHEN t.loan_type = 'MORTGAGE'     THEN UNIFORM(50000,  550000,  RANDOM())::FLOAT
            WHEN t.loan_type = 'BTL_MORTGAGE' THEN UNIFORM(40000,  400000,  RANDOM())::FLOAT
            WHEN t.loan_type = 'PERSONAL'     THEN UNIFORM(500,    45000,   RANDOM())::FLOAT
            ELSE                                   UNIFORM(1000,   35000,   RANDOM())::FLOAT
        END, 2)                                 AS outstanding_balance_gbp,
    CASE
        WHEN t.loan_type IN ('MORTGAGE','BTL_MORTGAGE') THEN ROUND(UNIFORM(199, 499, RANDOM())::FLOAT / 100, 4)
        WHEN t.loan_type = 'PERSONAL'                   THEN ROUND(UNIFORM(499, 1999,RANDOM())::FLOAT / 100, 4)
        ELSE                                                  ROUND(UNIFORM(599, 1499,RANDOM())::FLOAT / 100, 4)
    END                                         AS interest_rate_pct,
    CASE
        WHEN t.loan_type IN ('MORTGAGE','BTL_MORTGAGE') THEN UNIFORM(120, 300, RANDOM())
        WHEN t.loan_type = 'PERSONAL'                   THEN UNIFORM(12,  84,  RANDOM())
        ELSE                                                  UNIFORM(24,  60,  RANDOM())
    END                                         AS term_months,
    t.start_date,
    DATEADD(MONTH,
        CASE
            WHEN t.loan_type IN ('MORTGAGE','BTL_MORTGAGE') THEN UNIFORM(120, 300, RANDOM())
            WHEN t.loan_type = 'PERSONAL'                   THEN UNIFORM(12,  84,  RANDOM())
            ELSE                                                  UNIFORM(24,  60,  RANDOM())
        END,
        t.start_date)                           AS maturity_date,
    CASE
        WHEN t.loan_type IN ('MORTGAGE','BTL_MORTGAGE') THEN ROUND(UNIFORM(400,   3000,  RANDOM())::FLOAT, 2)
        WHEN t.loan_type = 'PERSONAL'                   THEN ROUND(UNIFORM(100,   1200,  RANDOM())::FLOAT, 2)
        ELSE                                                  ROUND(UNIFORM(150,   800,   RANDOM())::FLOAT, 2)
    END                                         AS monthly_payment_gbp,
    CASE
        WHEN t.loan_type IN ('MORTGAGE','BTL_MORTGAGE') THEN 35.00
        WHEN t.loan_type = 'PERSONAL'                   THEN 75.00
        ELSE                                                  75.00
    END                                         AS risk_weight_pct,
    CASE
        WHEN t.loan_type IN ('MORTGAGE','BTL_MORTGAGE') THEN 'RESIDENTIAL_PROPERTY'
        WHEN t.loan_type = 'AUTO'                        THEN 'VEHICLE'
        ELSE NULL
    END                                         AS collateral_type,
    CASE
        WHEN t.loan_type IN ('MORTGAGE','BTL_MORTGAGE') THEN ROUND(UNIFORM(120000, 750000, RANDOM())::FLOAT, 2)
        WHEN t.loan_type = 'AUTO'                        THEN ROUND(UNIFORM(5000,   45000,  RANDOM())::FLOAT, 2)
        ELSE NULL
    END                                         AS collateral_value_gbp,
    CASE
        WHEN status_rand < 85 THEN 'PERFORMING'
        WHEN status_rand < 92 THEN 'WATCH_LIST'
        WHEN status_rand < 97 THEN 'NON_PERFORMING'
        ELSE 'DEFAULT'
    END                                         AS status,
    CASE
        WHEN status_rand >= 92 THEN UNIFORM(30, 180, RANDOM())
        WHEN status_rand >= 85 THEN UNIFORM(1, 29, RANDOM())
        ELSE 0
    END                                         AS arrears_days,
    CURRENT_TIMESTAMP()                         AS created_at
FROM typed t;

-- =============================================================================
-- 5. TRANSACTIONS TABLE
-- ~500,000 transactions covering 6 months of activity
-- This is the largest table - takes ~60 seconds to generate
-- =============================================================================
CREATE OR REPLACE TABLE RAW.TRANSACTIONS (
    transaction_id      VARCHAR(20)     NOT NULL PRIMARY KEY,
    account_id          NUMBER          NOT NULL,
    transaction_date    DATE            NOT NULL,
    transaction_time    TIME            NOT NULL,
    transaction_type    VARCHAR(20)     NOT NULL,
    debit_credit        VARCHAR(6)      NOT NULL,
    amount_gbp          NUMBER(12,2)    NOT NULL,
    description         VARCHAR(200),
    merchant_name       VARCHAR(100),
    merchant_category   VARCHAR(50),
    reference           VARCHAR(50),
    channel             VARCHAR(20)     NOT NULL,
    status              VARCHAR(20)     NOT NULL DEFAULT 'CLEARED',
    counterparty_sort   VARCHAR(8),
    counterparty_acct   VARCHAR(8),
    created_at          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO RAW.TRANSACTIONS
WITH
merchant_data AS (
    SELECT m.* FROM (VALUES
        ('Tesco',            'GROCERY',              'DEBIT'),
        ('Sainsburys',       'GROCERY',              'DEBIT'),
        ('ASDA',             'GROCERY',              'DEBIT'),
        ('Waitrose',         'GROCERY',              'DEBIT'),
        ('M&S Food',         'GROCERY',              'DEBIT'),
        ('Lidl',             'GROCERY',              'DEBIT'),
        ('Aldi',             'GROCERY',              'DEBIT'),
        ('Amazon',           'ONLINE_RETAIL',        'DEBIT'),
        ('ASOS',             'ONLINE_RETAIL',        'DEBIT'),
        ('eBay',             'ONLINE_RETAIL',        'DEBIT'),
        ('BP Petrol',        'FUEL',                 'DEBIT'),
        ('Shell',            'FUEL',                 'DEBIT'),
        ('TfL Oyster',       'TRANSPORT',            'DEBIT'),
        ('National Rail',    'TRANSPORT',            'DEBIT'),
        ('Uber',             'TRANSPORT',            'DEBIT'),
        ('British Gas',      'UTILITIES',            'DEBIT'),
        ('EDF Energy',       'UTILITIES',            'DEBIT'),
        ('Sky',              'UTILITIES',            'DEBIT'),
        ('BT Group',         'UTILITIES',            'DEBIT'),
        ('Vodafone',         'UTILITIES',            'DEBIT'),
        ('Netflix',          'SUBSCRIPTIONS',        'DEBIT'),
        ('Spotify',          'SUBSCRIPTIONS',        'DEBIT'),
        ('Apple',            'SUBSCRIPTIONS',        'DEBIT'),
        ('Costa Coffee',     'DINING',               'DEBIT'),
        ('Pret A Manger',    'DINING',               'DEBIT'),
        ('Nandos',           'DINING',               'DEBIT'),
        ('Greggs',           'DINING',               'DEBIT'),
        ('Lloyds Bank',      'BANK_TRANSFER',        'CREDIT'),
        ('NatWest',          'BANK_TRANSFER',        'CREDIT'),
        ('Barclays',         'BANK_TRANSFER',        'CREDIT'),
        ('HSBC',             'BANK_TRANSFER',        'CREDIT'),
        ('Employer Payroll', 'SALARY',               'CREDIT'),
        ('HMRC',             'GOVERNMENT',           'CREDIT'),
        ('DWP',              'GOVERNMENT',           'CREDIT')
    ) AS m(merchant_name, merchant_category, debit_credit)
),
gen AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SEQ4())   AS rn,
        UNIFORM(1, 15000, RANDOM())           AS account_id,
        DATEADD(DAY, -(UNIFORM(0, 180, RANDOM())), CURRENT_DATE()) AS txn_date,
        TIMEADD(SECOND, UNIFORM(0, 86399, RANDOM()), '00:00:00'::TIME) AS txn_time,
        UNIFORM(1, 34, RANDOM())              AS merchant_idx,
        UNIFORM(0, 99, RANDOM())              AS type_rand,
        UNIFORM(0, 99, RANDOM())              AS status_rand,
        UNIFORM(0, 99, RANDOM())              AS channel_rand
    FROM TABLE(GENERATOR(ROWCOUNT => 500000))
),
enriched AS (
    SELECT
        g.*,
        m.merchant_name,
        m.merchant_category,
        m.debit_credit
    FROM gen g
    LEFT JOIN (SELECT merchant_name, merchant_category, debit_credit,
                      ROW_NUMBER() OVER (ORDER BY SEQ4()) AS idx
               FROM merchant_data) m
        ON g.merchant_idx = m.idx
)
SELECT
    'TXN' || LPAD(rn::VARCHAR, 10, '0')     AS transaction_id,
    account_id,
    txn_date                                AS transaction_date,
    txn_time                                AS transaction_time,
    CASE
        WHEN type_rand < 5  THEN 'DIRECT_DEBIT'
        WHEN type_rand < 8  THEN 'STANDING_ORDER'
        WHEN type_rand < 12 THEN 'FASTER_PAYMENT'
        WHEN type_rand < 15 THEN 'CHAPS'
        WHEN type_rand < 20 THEN 'BACS'
        ELSE 'CARD'
    END                                     AS transaction_type,
    debit_credit,
    CASE
        WHEN merchant_category = 'SALARY'       THEN ROUND(UNIFORM(1500, 8000, RANDOM())::FLOAT, 2)
        WHEN merchant_category = 'GOVERNMENT'   THEN ROUND(UNIFORM(200,  2000, RANDOM())::FLOAT, 2)
        WHEN merchant_category = 'BANK_TRANSFER'THEN ROUND(UNIFORM(50,   5000, RANDOM())::FLOAT, 2)
        WHEN merchant_category = 'UTILITIES'    THEN ROUND(UNIFORM(30,   200,  RANDOM())::FLOAT, 2)
        WHEN merchant_category = 'GROCERY'      THEN ROUND(UNIFORM(10,   150,  RANDOM())::FLOAT, 2)
        WHEN merchant_category = 'FUEL'         THEN ROUND(UNIFORM(30,   120,  RANDOM())::FLOAT, 2)
        WHEN merchant_category = 'DINING'       THEN ROUND(UNIFORM(5,    60,   RANDOM())::FLOAT, 2)
        WHEN merchant_category = 'TRANSPORT'    THEN ROUND(UNIFORM(5,    200,  RANDOM())::FLOAT, 2)
        WHEN merchant_category = 'SUBSCRIPTIONS'THEN ROUND(UNIFORM(5,    50,   RANDOM())::FLOAT, 2)
        ELSE                                         ROUND(UNIFORM(10,   500,  RANDOM())::FLOAT, 2)
    END                                     AS amount_gbp,
    merchant_name || ' - ' || TO_CHAR(txn_date, 'DDMONYYYY') AS description,
    merchant_name,
    merchant_category,
    'REF' || LPAD(rn::VARCHAR, 8, '0')      AS reference,
    CASE
        WHEN channel_rand < 50 THEN 'CARD_POS'
        WHEN channel_rand < 65 THEN 'ONLINE'
        WHEN channel_rand < 75 THEN 'MOBILE_APP'
        WHEN channel_rand < 82 THEN 'ATM'
        WHEN channel_rand < 88 THEN 'BRANCH'
        ELSE 'BACS_CHAPS'
    END                                     AS channel,
    CASE
        WHEN status_rand < 92 THEN 'CLEARED'
        WHEN status_rand < 97 THEN 'PENDING'
        ELSE 'REJECTED'
    END                                     AS status,
    CASE WHEN debit_credit = 'DEBIT' THEN
        '20-' || LPAD((ABS(RANDOM()) % 90 + 10)::VARCHAR, 2, '0') || '-' ||
                 LPAD((ABS(RANDOM()) % 90 + 10)::VARCHAR, 2, '0')
    ELSE NULL END                           AS counterparty_sort,
    CASE WHEN debit_credit = 'DEBIT' THEN
        LPAD((ABS(RANDOM()) % 90000000 + 10000000)::VARCHAR, 8, '0')
    ELSE NULL END                           AS counterparty_acct,
    CURRENT_TIMESTAMP()                     AS created_at
FROM enriched;

-- =============================================================================
-- Verify row counts
-- =============================================================================
SELECT 'PRODUCTS'     AS table_name, COUNT(*) AS row_count FROM RAW.PRODUCTS     UNION ALL
SELECT 'CUSTOMERS'    AS table_name, COUNT(*) AS row_count FROM RAW.CUSTOMERS    UNION ALL
SELECT 'ACCOUNTS'     AS table_name, COUNT(*) AS row_count FROM RAW.ACCOUNTS     UNION ALL
SELECT 'LOANS'        AS table_name, COUNT(*) AS row_count FROM RAW.LOANS        UNION ALL
SELECT 'TRANSACTIONS' AS table_name, COUNT(*) AS row_count FROM RAW.TRANSACTIONS
ORDER BY table_name;
