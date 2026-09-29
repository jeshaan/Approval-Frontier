CREATE OR REPLACE VIEW raw_loans AS
SELECT * FROM read_csv_auto('/Users/eshaanjalali/Desktop/Approval-Frontier/data/accepted*.csv', ignore_errors=true);

select * from raw_loans limit 5;
SELECT COUNT(*) AS total_rows FROM raw_loans;
--2,260,701
DESCRIBE raw_loans;

SELECT
  loan_status,
  COUNT(*) AS cnt,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM raw_loans
GROUP BY loan_status
ORDER BY cnt DESC;
-- loan status counts/pct grouped by loan_status

SELECT term, COUNT(*) AS cnt
FROM raw_loans
GROUP BY term
ORDER BY cnt DESC;
-- 36 months: 1,569,905 *doesn't pass maturity date*
-- 60 months: 690,796 *passes maturity date*
-- NULL: 33

SELECT MIN(issue_d) AS min_raw, MAX(issue_d) AS max_raw FROM raw_loans;
-- min_raw: Apr 2008
-- max_raw: Sep 2018

SELECT
  strftime(strptime(issue_d, '%b-%Y'), '%Y-%m') AS issue_month,
  COUNT(*) AS n
FROM raw_loans
WHERE strptime(issue_d, '%b-%Y') BETWEEN '2012-01-01' AND '2015-12-31'
GROUP BY issue_month
ORDER BY issue_month;
-- steady increase over time, good data

SELECT
  COUNT(*) AS total_rows,
  SUM(CASE WHEN loan_amnt IS NULL THEN 1 ELSE 0 END) AS null_loan_amnt,
  SUM(CASE WHEN funded_amnt IS NULL THEN 1 ELSE 0 END) AS null_funded_amnt,
  SUM(CASE WHEN term IS NULL THEN 1 ELSE 0 END) AS null_term,
  SUM(CASE WHEN int_rate IS NULL THEN 1 ELSE 0 END) AS null_int_rate,
  SUM(CASE WHEN grade IS NULL THEN 1 ELSE 0 END) AS null_grade,
  SUM(CASE WHEN sub_grade IS NULL THEN 1 ELSE 0 END) AS null_sub_grade,
  SUM(CASE WHEN emp_length IS NULL THEN 1 ELSE 0 END) AS null_emp_length,
  SUM(CASE WHEN home_ownership IS NULL THEN 1 ELSE 0 END) AS null_home_ownership,
  SUM(CASE WHEN annual_inc IS NULL THEN 1 ELSE 0 END) AS null_annual_inc,
  SUM(CASE WHEN dti IS NULL THEN 1 ELSE 0 END) AS null_dti,
  SUM(CASE WHEN fico_range_low IS NULL THEN 1 ELSE 0 END) AS null_fico_low,
  SUM(CASE WHEN fico_range_high IS NULL THEN 1 ELSE 0 END) AS null_fico_high,
  SUM(CASE WHEN revol_util IS NULL THEN 1 ELSE 0 END) AS null_revol_util,
  SUM(CASE WHEN purpose IS NULL THEN 1 ELSE 0 END) AS null_purpose,
  SUM(CASE WHEN issue_d IS NULL THEN 1 ELSE 0 END) AS null_issue_d,
  SUM(CASE WHEN total_pymnt IS NULL THEN 1 ELSE 0 END) AS null_total_pymnt,
  SUM(CASE WHEN total_rec_prncp IS NULL THEN 1 ELSE 0 END) AS null_total_rec_prncp,
  SUM(CASE WHEN total_rec_int IS NULL THEN 1 ELSE 0 END) AS null_total_rec_int,
  SUM(CASE WHEN recoveries IS NULL THEN 1 ELSE 0 END) AS null_recoveries
FROM raw_loans;
-- 33 junk rows dropped

SELECT COUNT(*) AS target_population
FROM raw_loans
WHERE term LIKE '%36%'
  AND strptime(issue_d, '%b-%Y') BETWEEN '2012-01-01' AND '2015-12-31'
  AND loan_amnt IS NOT NULL
  AND loan_status NOT LIKE 'Does not meet the credit policy%';
  -- 589,635 rows in target population