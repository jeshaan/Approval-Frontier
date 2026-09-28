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

## Next steps (Day 2)
- Fix `int_rate` and `revol_util` (stored as `%` strings), `emp_length` (text categories), `issue_d` (text dates)
- Apply final-status filter (Fully Paid, Charged Off, Default only)
- Exclude the 33 malformed rows and the credit-policy-prefixed statuses (though the latter has 0 overlap with scope, confirmed above)
- Build derived fields: `defaulted`, `net_profit`, `fico_band`, `dti_band`, `income_band`, `vintage`
- Validate: totals reconcile, default rate rises steadily from grade A to G
