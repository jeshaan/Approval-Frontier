# Data Dictionary

Key fields used in this analysis. Full definitions for all ~150 columns are in
Lending Club's own data dictionary (LCDataDictionary), this covers only the
fields this project actually uses.

| Field | Type | Description |
|---|---|---|
| `loan_amnt` | numeric | Amount borrower requested |
| `funded_amnt` | numeric | Amount actually funded (can differ from loan_amnt if not fully funded) |
| `term` | text | Loan length in months; this project uses 36-month loans only |
| `int_rate` | numeric | Interest rate on the loan, stored as a `%` string in the raw file, needs parsing |
| `grade` | text | Lending Club's risk grade, A (lowest risk) through G (highest risk) |
| `sub_grade` | text | Finer-grained risk grade within each letter grade (e.g. B1-B5) |
| `emp_length` | text | Borrower's employment length, in years; "n/a" for undisclosed (about 6.5% of rows) |
| `home_ownership` | text | Borrower's home ownership status (RENT, OWN, MORTGAGE, etc) |
| `annual_inc` | numeric | Borrower's self-reported annual income |
| `dti` | numeric | Debt-to-income ratio, excludes mortgage |
| `fico_range_low` / `fico_range_high` | numeric | Lower/upper bound of borrower's FICO score range at origination |
| `revol_util` | numeric | Revolving credit line utilization rate, stored as a `%` string, needs parsing |
| `purpose` | text | Borrower-stated reason for the loan |
| `issue_d` | text | Month and year the loan was issued, stored as text (e.g. "Dec-2015"), needs parsing to a real date |
| `loan_status` | text | Current status of the loan (Fully Paid, Charged Off, Current, etc); this project uses final statuses only |
| `total_pymnt` | numeric | Total amount received from borrower to date; only known after loan matures, not usable as a predictor |
| `total_rec_prncp` | numeric | Total principal received to date; same caveat as above |
| `total_rec_int` | numeric | Total interest received to date; same caveat as above |
| `recoveries` | numeric | Post-charge-off recovery amount; same caveat as above |
