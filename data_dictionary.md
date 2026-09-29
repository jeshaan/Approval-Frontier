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
## Derived fields (added in loans_parsed and loans_clean, Day 2)

### Parsed from raw fields (loans_parsed)
| Field | Type | Definition |
|---|---|---|
| int_rate_pct | number | Interest rate as a number, % symbol removed (13.56 means 13.56%) |
| revol_util_pct | number | Revolving utilization as a number (balance divided by credit limit, in percent). Can exceed 100; max is 892.3. Not used in any segment or policy |
| issue_date | date | Loan issue month as a real date, parsed from issue_d |
| vintage | integer | Issue year (2012 to 2015) |
| emp_length_yrs | integer | Years employed, 0 to 10. "< 1 year" is 0, "10+ years" is 10 (a floor, not an exact value). NULL if missing |

### Built in loans_clean
| Field | Type | Definition |
|---|---|---|
| defaulted | 0/1 | 1 if loan_status is Charged Off or Default, else 0 |
| net_profit | number | total_pymnt - funded_amnt - collection_recovery_fee. total_pymnt already includes recoveries. Excludes cost of funds, servicing, and acquisition costs. Undiscounted |
| dti_clean | number | dti with values of 100 or more set to NULL (5 loans, implausible values). dti = 0 is kept |
| dti_band | text | 0: Unknown (NULL or 100+), 1: 0-10, 2: 10-20, 3: 20-25, 4: 25-30, 5: 30-40, 6: 40+. Upper bounds inclusive (a DTI of exactly 25 falls in 20-25) |
| fico_band | text | Based on fico_range_low: 1: 660-679, 2: 680-699, 3: 700-719, 4: 720-759, 5: 760+. 680 is an edge so policy (c) maps to a band boundary |
| income_band | text | Based on annual_inc: 0: Unknown (NULL or 0), 1: under 40K, 2: 40-60K, 3: 60-90K, 4: 90K+. Edges are rounded quartiles |
| emp_band | text | Based on emp_length_yrs: <1, 1-4, 5-9, 10+, Unknown. Built but not used in Day 3 segments |
