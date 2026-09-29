-- 02_clean.sql
-- Runs top to bottom on a fresh DuckDB. Run from the repo root:  duckdb < sql/02_clean.sql
-- Builds loans_parsed -> loans_clean from the raw LendingClub accepted-loans CSV.

-- Raw CSV as a view (no data copied).
CREATE OR REPLACE VIEW raw_loans AS
SELECT * FROM read_csv_auto('data/accepted*.csv', ignore_errors=true);


-- ============================================================
-- STEP 1: Scope funnel
-- Row count after each scope filter, in order. Last row = target population.
-- Expect: 2,260,701 -> 2,260,668 -> 1,609,754 -> 589,635 -> 589,488
-- ============================================================
WITH f AS (
    SELECT *, EXTRACT(year FROM strptime(issue_d, '%b-%Y')) AS yr
    FROM raw_loans
)
SELECT 1 AS step, 'all rows'                  AS filter_applied, COUNT(*) AS n FROM f
UNION ALL SELECT 2, 'loan_amnt not null',      COUNT(*) FROM f WHERE loan_amnt IS NOT NULL
UNION ALL SELECT 3, '+ 36-month term',         COUNT(*) FROM f WHERE loan_amnt IS NOT NULL AND TRIM(term) = '36 months'
UNION ALL SELECT 4, '+ issued 2012-2015',      COUNT(*) FROM f WHERE loan_amnt IS NOT NULL AND TRIM(term) = '36 months'
                                                 AND yr BETWEEN 2012 AND 2015
UNION ALL SELECT 5, '+ resolved status',       COUNT(*) FROM f WHERE loan_amnt IS NOT NULL AND TRIM(term) = '36 months'
                                                 AND yr BETWEEN 2012 AND 2015
                                                 AND loan_status IN ('Fully Paid', 'Charged Off', 'Default')
ORDER BY step;


-- ============================================================
-- STEP 2: loans_parsed
-- Applies the scope filters and parses messy text fields:
-- int_rate_pct / revol_util_pct (strip %), issue_date, vintage, emp_length_yrs.
-- Expect: 589,488 rows
-- ============================================================
CREATE OR REPLACE TABLE loans_parsed AS
SELECT
    *,
    TRY_CAST(REPLACE(CAST(int_rate AS VARCHAR), '%', '') AS DOUBLE)    AS int_rate_pct,
    TRY_CAST(REPLACE(CAST(revol_util AS VARCHAR), '%', '') AS DOUBLE)  AS revol_util_pct,
    CAST(strptime(issue_d, '%b-%Y') AS DATE)                           AS issue_date,
    EXTRACT(year FROM strptime(issue_d, '%b-%Y'))                      AS vintage,
    CASE TRIM(emp_length)
        WHEN '< 1 year'  THEN 0
        WHEN '1 year'    THEN 1
        WHEN '2 years'   THEN 2
        WHEN '3 years'   THEN 3
        WHEN '4 years'   THEN 4
        WHEN '5 years'   THEN 5
        WHEN '6 years'   THEN 6
        WHEN '7 years'   THEN 7
        WHEN '8 years'   THEN 8
        WHEN '9 years'   THEN 9
        WHEN '10+ years' THEN 10
        ELSE NULL
    END                                                                AS emp_length_yrs
FROM raw_loans
WHERE loan_amnt IS NOT NULL
  AND TRIM(term) = '36 months'
  AND EXTRACT(year FROM strptime(issue_d, '%b-%Y')) BETWEEN 2012 AND 2015
  AND loan_status IN ('Fully Paid', 'Charged Off', 'Default');


-- Parse checks on loans_parsed
-- Expect: first query all zeros (no parse failures); second: dates 2012-01 to 2015-12, 589,488 rows, max dti 999 (handled in Step 3)
SELECT
    SUM(CASE WHEN int_rate     IS NOT NULL AND int_rate_pct     IS NULL THEN 1 ELSE 0 END) AS int_rate_failed,
    SUM(CASE WHEN revol_util   IS NOT NULL AND revol_util_pct   IS NULL THEN 1 ELSE 0 END) AS revol_util_failed,
    SUM(CASE WHEN issue_d      IS NOT NULL AND issue_date       IS NULL THEN 1 ELSE 0 END) AS issue_date_failed,
    SUM(CASE WHEN emp_length   IS NOT NULL AND emp_length_yrs   IS NULL THEN 1 ELSE 0 END) AS emp_length_unmapped
FROM loans_parsed;
-- no parse discrepancies

SELECT
    MIN(int_rate_pct)   AS min_rate,   MAX(int_rate_pct)   AS max_rate,
    MIN(revol_util_pct) AS min_util,   MAX(revol_util_pct) AS max_util,
    MIN(dti)            AS min_dti,    MAX(dti)            AS max_dti,
    MIN(issue_date)     AS first_issue, MAX(issue_date)    AS last_issue,
    COUNT(*)            AS total_rows
FROM loans_parsed;
-- no range discrepancies

SELECT
    SUM(CASE WHEN revol_util_pct > 100 THEN 1 ELSE 0 END) AS over_100,
    SUM(CASE WHEN revol_util_pct > 150 THEN 1 ELSE 0 END) AS over_150,
    SUM(CASE WHEN revol_util_pct > 200 THEN 1 ELSE 0 END) AS over_200
FROM loans_parsed;
-- only 1 revolving utilization > 200, 11 >150
-- (last check: expect 2,203 revol_util > 100, 11 > 150, only 1 > 200)


-- ============================================================
-- STEP 3: loans_clean
-- Adds defaulted flag, net_profit, dti_clean, and dti/fico/income/emp bands.
-- Expect: 589,488 rows (same as loans_parsed)
-- ============================================================
CREATE OR REPLACE TABLE loans_clean AS
SELECT
    *,
    CASE WHEN loan_status IN ('Charged Off', 'Default') THEN 1 ELSE 0 END AS defaulted,
    total_pymnt - funded_amnt - COALESCE(collection_recovery_fee, 0)      AS net_profit,
    CASE WHEN dti >= 100 THEN NULL ELSE dti END                           AS dti_clean,
    CASE WHEN dti IS NULL OR dti >= 100 THEN '0: Unknown'
         WHEN dti <= 10 THEN '1: 0-10'
         WHEN dti <= 20 THEN '2: 10-20'
         WHEN dti <= 25 THEN '3: 20-25'
         WHEN dti <= 30 THEN '4: 25-30'
         WHEN dti <= 40 THEN '5: 30-40'
         ELSE                '6: 40+' END                                 AS dti_band,
    CASE WHEN fico_range_low < 680 THEN '1: 660-679'
         WHEN fico_range_low < 700 THEN '2: 680-699'
         WHEN fico_range_low < 720 THEN '3: 700-719'
         WHEN fico_range_low < 760 THEN '4: 720-759'
         ELSE                           '5: 760+' END                     AS fico_band,
    CASE WHEN annual_inc IS NULL OR annual_inc = 0 THEN '0: Unknown'
         WHEN annual_inc < 40000 THEN '1: <40K'
         WHEN annual_inc < 60000 THEN '2: 40-60K'
         WHEN annual_inc < 90000 THEN '3: 60-90K'
         ELSE                         '4: 90K+' END                       AS income_band,
    CASE WHEN emp_length_yrs IS NULL THEN 'Unknown'
         WHEN emp_length_yrs < 1  THEN '<1'
         WHEN emp_length_yrs < 5  THEN '1-4'
         WHEN emp_length_yrs < 10 THEN '5-9'
         ELSE                          '10+' END                          AS emp_band
FROM loans_parsed;


-- ============================================================
-- VALIDATION
-- ============================================================

-- 1. Grade default rates
-- Expect: default_rate rises steadily from A to G
SELECT grade, COUNT(*) AS n, ROUND(AVG(defaulted), 4) AS default_rate
FROM loans_clean GROUP BY 1 ORDER BY 1;

-- 2. Reconciliation
-- Expect: clean_rows = 589,488 and clean_defaults = direct_defaults
SELECT
    (SELECT COUNT(*) FROM loans_clean)                AS clean_rows,
    (SELECT SUM(defaulted) FROM loans_clean)          AS clean_defaults,
    (SELECT COUNT(*) FROM loans_parsed
      WHERE loan_status IN ('Charged Off','Default')) AS direct_defaults;

-- 3. Net profit by loan status
-- Expect: Fully Paid 506,760 rows, avg ~ +$1,936; Charged Off 82,728 rows, avg ~ -$4,587
SELECT loan_status, COUNT(*) AS n,
       ROUND(AVG(net_profit)) AS avg_net_profit,
       ROUND(SUM(net_profit)) AS total_net_profit
FROM loans_clean GROUP BY 1;

-- 4. Defaulted loans: gap between total_pymnt and its components vs. collection fee
SELECT
    ROUND(AVG(total_pymnt - (total_rec_prncp + total_rec_int + total_rec_late_fee + recoveries)), 2) AS avg_gap,
    ROUND(AVG(collection_recovery_fee), 2) AS avg_collection_fee
FROM loans_clean
WHERE defaulted = 1;


-- ============================================================
-- APPENDIX: exploratory checks used to choose band cutoffs (informational)
-- dti outlier buckets, fico/income distributions, and default rate by fico slice / band.
-- ============================================================
SELECT
    CASE WHEN dti = 0 THEN '0'
         WHEN dti >= 100 THEN '100+'
         WHEN dti > 60 THEN '60-100'
         WHEN dti > 40 THEN '40-60'
         ELSE 'under 40' END          AS dti_bucket,
    COUNT(*)                          AS n,
    AVG(CASE WHEN loan_status IN ('Charged Off','Default') THEN 1.0 ELSE 0 END) AS default_rate
FROM loans_parsed
GROUP BY 1
ORDER BY 1;
-- dti buckets: 0, under 40, 40-60, 60-100, 100+; default rate increases with dti -- expected

SELECT
    MIN(fico_range_low)  AS min_fico_low,
    MAX(fico_range_low)  AS max_fico_low,
    MIN(fico_range_high) AS min_fico_high,
    MAX(fico_range_high) AS max_fico_high,
    SUM(CASE WHEN fico_range_low IS NULL THEN 1 ELSE 0 END) AS fico_nulls
FROM loans_parsed;

SELECT
    MIN(annual_inc)                     AS min_inc,
    QUANTILE_CONT(annual_inc, 0.25)     AS p25,
    QUANTILE_CONT(annual_inc, 0.50)     AS median,
    QUANTILE_CONT(annual_inc, 0.75)     AS p75,
    QUANTILE_CONT(annual_inc, 0.99)     AS p99,
    MAX(annual_inc)                     AS max_inc,
    SUM(CASE WHEN annual_inc = 0 THEN 1 ELSE 0 END) AS zero_inc
FROM loans_parsed;

SELECT
    QUANTILE_CONT(fico_range_low, 0.25) AS p25,
    QUANTILE_CONT(fico_range_low, 0.50) AS median,
    QUANTILE_CONT(fico_range_low, 0.75) AS p75
FROM loans_parsed;

SELECT
    FLOOR(fico_range_low / 20) * 20                                   AS fico_slice_start,
    COUNT(*)                                                          AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)                AS pct_of_loans,
    ROUND(AVG(CASE WHEN loan_status IN ('Charged Off','Default') THEN 1.0 ELSE 0 END), 4) AS default_rate
FROM loans_parsed
GROUP BY 1
ORDER BY 1;

WITH banded AS (
    SELECT
        *,
        CASE WHEN fico_range_low < 680 THEN '1: 660-679'
             WHEN fico_range_low < 700 THEN '2: 680-699'
             WHEN fico_range_low < 720 THEN '3: 700-719'
             WHEN fico_range_low < 760 THEN '4: 720-759'
             ELSE                           '5: 760+' END AS fico_band,
        CASE WHEN annual_inc IS NULL OR annual_inc = 0 THEN '0: Unknown'
             WHEN annual_inc < 40000  THEN '1: <40K'
             WHEN annual_inc < 60000  THEN '2: 40-60K'
             WHEN annual_inc < 90000  THEN '3: 60-90K'
             ELSE                          '4: 90K+' END AS income_band
    FROM loans_parsed
)
SELECT 'fico' AS dim, fico_band AS band, COUNT(*) AS n,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_loans,
       ROUND(AVG(CASE WHEN loan_status IN ('Charged Off','Default') THEN 1.0 ELSE 0 END), 4) AS default_rate
FROM banded GROUP BY 2
UNION ALL
SELECT 'income', income_band, COUNT(*),
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2),
       ROUND(AVG(CASE WHEN loan_status IN ('Charged Off','Default') THEN 1.0 ELSE 0 END), 4)
FROM banded GROUP BY 2
ORDER BY 1, 2;
