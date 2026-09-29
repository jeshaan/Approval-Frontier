# Capital One Portfolio Project: Approval vs. Loss on Consumer Loans

## Why this project exists
Target: Capital One Data Analyst Associate, Analyst Development Program (August 2027 cohort).
The project has three jobs:
1. A resume bullet with a real finding in it.
2. A piece of work I can walk through and defend on a Power Day, the same way candidates defend the take-home challenge.
3. Daily SQL reps for the timed online assessment.

## The question
Which tightening of approval criteria would most improve portfolio profit, and what would it cost in lost loan volume and interest income?

## Data
- Source: Lending Club accepted loans, Kaggle mirror ("2007 to 2018Q4", about 2.2M rows, about 150 columns). Column names can vary slightly between mirrors.
- Data dictionary: the LCDataDictionary spreadsheet that ships with most mirrors.

### Scope decisions
- 36-month loans only.
- Issued 2012 through 2015, so every loan has reached a final outcome.
- Final statuses only: Fully Paid, Charged Off, Default (Default treated as charged off).
- Open decision: how to handle the "Does not meet the credit policy" statuses. Decide on Day 1 and log the reason.

### Key fields
loan_amnt, funded_amnt, term, int_rate, grade, sub_grade, emp_length, home_ownership, annual_inc, dti, fico_range_low, fico_range_high, revol_util, purpose, issue_d, loan_status, total_pymnt, total_rec_prncp, total_rec_int, recoveries

### Derived fields
- defaulted: 1 if Charged Off or Default, else 0
- net_profit: total_pymnt minus funded_amnt
- fico_band, dti_band, income_band
- vintage: issue year

## Stack
- DuckDB for SQL directly on the CSV
- Python only for loading and one optional model
- Tableau Public for the dashboard (aggregated exports only)
- GitHub repo with numbered SQL files

## Plan Timeline

- [x] **Day 1: Apply, set up, profile.**
  - Submit the Capital One application first.
  - Load the data into DuckDB.
  - Profile it: row counts, null rates, loan_status values, date range, term split.
  - Lock the scope decisions above.
  - Output: 01_profile.sql, notes file, short data dictionary.
- [x] **Day 2: Clean.**
  - Fix int_rate and revol_util (stored as % strings), emp_length (text), and issue dates.
  - Filter to final statuses and build the derived fields.
  - Validate: totals reconcile, and default rate rises steadily from grade A to G.
  - Output: 02_clean.sql building loans_clean, assumptions log.
- [ ] **Day 3: Segment analysis.**
  - Default rate, average rate, and net return per dollar lent, cut by grade, FICO band, DTI band, purpose, and vintage.
  - Window functions:
    - rank segments by total loss
    - running share of losses with SUM() OVER
    - vintage-over-vintage change with LAG
  - Grade x DTI grid of net return.
  - Output: 03_segments.sql, 5 or 6 result CSVs.
- [ ] **Day 4: Policy simulation.**
  - Run 3 candidate policies (below). For each: loans lost, interest income given up, charge-offs avoided, net profit change.
  - Rerun at an assumed 2% and 4% cost of funds.
  - Pick a recommendation.
  - Optional stretch: a logistic regression risk score to plot approval rate vs. loss rate.
  - Output: 04_policies.sql, policy comparison table.
- [ ] **Day 5: Tableau dashboard.**
  - Three views:
    1. KPI tiles plus the grade x DTI heatmap
    2. Policy comparison
    3. Default rate by vintage
  - Each view gets a headline sentence stating the takeaway.
  - Output: published Tableau Public link.
- [ ] **Day 6: Write-up and repo.**
  - One-page summary, answer first, then method, then limitations.
  - README that leads with the finding.
  - Resume bullet with real numbers.
- [ ] **Day 7: Defend it.**
  - 2-minute verbal walkthrough.
  - Mock Power Day grilling.
  - Patch weak spots, then publish.

**In parallel, every day:** 30 to 45 minutes of assessment prep.
- SQL at easy-to-medium difficulty: joins, window functions, subqueries.
- A few timed Google Sheets exercises.

## Candidate policies (starting point, revise after Day 3)
- (a) Decline grades F and G
- (b) Decline DTI above 30 within grades D to G
- (c) Decline FICO below 680 when DTI is above 25

## Limitations to state up front
- **Selection bias:** only approved loans are observed, so tightening can be evaluated but loosening cannot.
- **Missing costs:** no acquisition or servicing costs in the data; cost of funds is an assumption.
- **Time period:** 2012 to 2015 was a relatively benign credit environment.
- **Product:** these are installment loans, not credit cards.

## Questions I should be able to answer on a call
- Why this time window and loan term?
- Why define net profit this way, and what does it leave out?
- What would change the recommendation?
- How would you test this policy live before rolling it out?
- What does selection bias mean for this analysis?

## Resume bullet template
Analyzed [N] consumer loans in SQL to size the tradeoff between approval volume and charge-offs; found that tightening [criterion] for [segment] would cut losses [X]% while giving up [Y]% of interest income, and built a Tableau dashboard to compare policy scenarios.

## Status log
Update after each session: what got done, decisions made, what's next.

- 9/26: Scoped the project and wrote this brief. Next: Day 1.
- 9/28 (Day 2): Built loans_parsed and loans_clean (589,488 loans, 36-month, 2012-2015, final statuses). Parsed % strings and dates, nulled 5 implausible DTI values, built defaulted, net_profit (net of collection fees), and dti/fico/income/emp bands. Validated: default rate rises A to G (5.5% to 40.2%), 82,728 defaults reconcile, portfolio net profit about +$601M. Dropped 147 unresolved 2015 loans (0.025%, worst-case default rate impact under 0.01 pts). F/G are only 0.77% of loans, so policy (a) will likely have small impact. Next: Day 3 segment analysis (03_segments.sql).
