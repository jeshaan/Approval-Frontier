# Day 1 Notes: Data Profiling and Scope Decisions

## Dataset overview
- Source: Lending Club accepted loans, 2007Q2 through 2018Q4 (confirmed via parsed `issue_d` min/max, June 2007 to December 2018)
- Raw row count: 2,260,701
- 33 rows are malformed: null across nearly every field (loan_amnt, funded_amnt, term, grade, loan_status, etc). Confirmed these are the same 33 rows across multiple null-rate checks. Excluded from all analysis going forward.
- Clean row count: 2,260,668

## loan_status distribution (full dataset)
| Status | Count | % |
|---|---|---|
| Fully Paid | 1,076,751 | 47.63% |
| Current | 878,317 | 38.85% |
| Charged Off | 268,559 | 11.88% |
| Late (31-120 days) | 21,467 | 0.95% |
| In Grace Period | 8,436 | 0.37% |
| Late (16-30 days) | 4,349 | 0.19% |
| Does not meet the credit policy. Status:Fully Paid | 1,988 | 0.09% |
| Does not meet the credit policy. Status:Charged Off | 761 | 0.03% |
| Default | 40 | 0.00% |
| (null, malformed rows) | 33 | 0.00% |

## Scope decisions

**Term: 36-month loans only.**
Restricting to one term avoids mixing two products with different maturity horizons and risk profiles in the same analysis. A 60-month loan issued in this window would not have had time to fully mature within the dataset's coverage, which would require a separate seasoning cutoff and double the segmentation work. Cost: excludes roughly a quarter to a third of total originations, primarily larger loan amounts.

**Date range: issued 2012 through 2015.**
Chosen so every 36-month loan in the window has reached a final outcome by the end of the data's coverage (2018Q4). Confirmed full, continuous monthly coverage within this window (steady growth, no gaps). Also avoids the 2008-2009 financial crisis period, keeping the analysis in a more comparable, stated-as-such "benign" credit environment (see brief limitations).

**Credit-policy-prefixed statuses: excluded.**
"Does not meet the credit policy" statuses mark loans approved under an older, since-tightened underwriting policy. These represent a different population than loans evaluated under current-era standards, and are not appropriate to compare against for this analysis. Full-dataset volume is negligible (0.12% combined). Confirmed via direct query that within the 36-month/2012-2015 scope, this affects 0 loans, these statuses are concentrated in pre-2012 originations and don't overlap with the analysis window at all.

**Final statuses only: Fully Paid, Charged Off, Default (Default treated as Charged Off).**
Current, Late, and In Grace Period loans haven't reached a resolved outcome and can't be scored as good/bad. To be applied in Day 2's cleaning step.

## Target population
- After term (36-month) and date (2012-2015) filters: 589,635 loans
- This is pre-final-status-filter; Day 2 will apply the Fully Paid/Charged Off/Default filter and this number will drop further.

## Null rates (key fields, full dataset)
- `emp_length`: 146,940 null (6.5%). Real and expected (undisclosed employment status), not a data error. To be banded as "Unknown" in Day 2, not dropped.
- `dti`: 1,744 null (0.08%). Negligible.
- `revol_util`: 1,835 null (0.08%). Negligible.
- `annual_inc`: 37 null (0.002%). Negligible.
- All other key fields: null only on the 33 malformed rows already excluded.

## Known structural nulls (not data quality issues)
- `member_id`: null on 100% of rows. Scrubbed by Lending Club for privacy in the public release.
- `settlement_*` fields (`settlement_date`, `settlement_amount`, `settlement_percentage`, `settlement_term`): null except for loans that went through formal debt settlement, a small subset of charged-off loans. High null rate is expected, not missing data.

## Day 2: Cleaning assumptions

### Scope and filtering
- Final population: 589,488 loans (36-month term, issued 2012 to 2015, final statuses only).
- Funnel: 2,260,701 raw rows, minus 33 malformed rows, filtered to 36-month loans issued 2012 to 2015 (589,635), then to final statuses (589,488).
- Only loans with a final outcome are kept. Default rate and net profit are not measurable on open loans: a loan still being repaid would look like a loss on net_profit and a non-default on defaulted, and neither would be true. The 2012 to 2015, 36-month window was chosen so that every loan has had time to resolve before the 2018Q4 data cutoff.
- 147 loans (0.025% of scope) were dropped at the final-status filter because they had not reached a final outcome. All are from the 2015 vintage: 72 Current, 61 Late (31-120 days), 9 In Grace Period, 5 Late (16-30 days). These were issued late in 2015 and were still open at the data cutoff. The 75 late or grace-period loans are more likely than average to charge off, so dropping them slightly understates the default rate. Upper bound: if all 75 had charged off, the overall default rate would move from 14.03% to 14.04%, which is negligible.
- "Default" status had 0 loans in scope, so folding it into charged off changed nothing.
- No loans with "does not meet the credit policy" statuses fall in scope (verified: none among the 147 dropped loans, and none carry that prefix in the scoped population).

### Field parsing
- int_rate and revol_util were stored as % strings. Stripped the symbol and cast to numeric (13.56 means 13.56%).
- issue_d converted from text to a real date. vintage is the issue year.
- emp_length mapped to 0 to 10 years ("< 1 year" is 0, "10+ years" is 10 and is a floor, not an exact value). Missing values stay NULL and are banded "Unknown" (about 6.5% of loans).
- Parse checks: 0 silent failures across all four parsed fields.
- Source table is raw_loans. loans_parsed and loans_clean are the stages built from it, so the raw data is never modified.

### Outliers and missing values
- 5 loans with DTI of 100 or more were set to NULL in dti_clean and banded "Unknown". Values are implausible for a monthly payment ratio, and 5 loans cannot move any result. dti = 0 (191 loans) is kept as a real value: its default rate (14.7%) matches the overall population, so there is no evidence it is a placeholder.
- revol_util maximum of 892.3% was left as is. It is a legitimate feature of the metric (balance over a small or reduced limit), and the field is not used in any segment or policy. Revisit and cap only if it is added to the optional model.
- 2 loans with zero income banded "Unknown". Income is self-reported and the maximum is $9M, so income is banded rather than used raw.

### Derived fields
- defaulted: 1 if Charged Off or Default, else 0. Overall default rate is 14.03% (82,728 of 589,488).
- net_profit = total_pymnt - funded_amnt - collection_recovery_fee.
  - Verified that total_pymnt already includes recoveries (principal + interest + late fees + recoveries, average gap of 0).
  - Collection fees averaged $148.57 on charged-off loans (about $12.3M total, about 2% of portfolio net profit) and are subtracted.
  - Not included: cost of funds, servicing costs, and acquisition costs, none of which are in the data. Cost of funds is modeled as an assumption on Day 4.
  - Undiscounted: no time value of money is applied to payments received over the life of the loan.
- fico_band uses fico_range_low. Lending Club reports FICO in 5-point buckets, so low and high carry the same information. Bands: 660-679, 680-699, 700-719, 720-759, 760+. 680 is a band edge so policy (c) maps to a boundary. No band holds under 4.8% of loans, so no band's default rate is noisy.
- income_band edges are rounded quartiles: under $40K, $40-60K, $60-90K, $90K+.
- dti_band edges sit at 10, 20, 25, 30, and 40 so policies (b) and (c) map to band boundaries. Only 34 loans are at 40 or above, so 40+ is the top band.
- emp_band (<1, 1-4, 5-9, 10+, Unknown) is built but not used in Day 3 segments.

### Validation
- Default rate rises at every step from grade A (5.5%) to grade G (40.2%).
- Default counts reconcile between loans_clean and loans_parsed (82,728 in both).
- net_profit signs are correct: Fully Paid averages +$1,936 per loan, Charged Off averages -$4,587. Portfolio net profit is about +$601M.
- Default rate falls as FICO and income rise. FICO separates risk about 4x (18.3% to 4.7%) and income about 2x (19.2% to 10.1%).
- Grades F and G total 4,515 loans (0.77% of the portfolio), so policy (a) will likely have a small effect on total losses.
