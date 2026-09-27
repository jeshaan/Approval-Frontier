# Approval-Frontier
SQL analysis of 2.2M Lending Club loans to find the approval policy tightening that maximizes portfolio profit, sized in lost volume and interest income. DuckDB, window functions, policy simulation, Tableau dashboard.

# Approval vs. Loss: Sizing the Tradeoff in Consumer Lending

**Status: in progress. Placeholders below will be replaced with real numbers as the analysis lands.**

## Finding

[One or two sentences once Day 4 is done. Should read like: "Tightening X for Y segment would cut losses by Z% while giving up W% of interest income."]

## The question

Which tightening of approval criteria would most improve portfolio profit, and what would it cost in lost loan volume and interest income?

This matters because every underwriting policy is a tradeoff along the same axis: a tighter cutoff avoids charge-offs but also declines loans that would have paid off fine. The goal here is to size that tradeoff for a few candidate policies rather than argue about it qualitatively.

## Data

- Source: Lending Club accepted loans, Kaggle mirror ("2007 to 2018Q4")
- Scope: 36-month term loans only, issued 2012 through 2015, final statuses only (Fully Paid, Charged Off, Default)
- Rows after scoping: [N, confirmed after Day 1 profiling]
- Why this scope: 36-month loans issued through 2015 have all reached a final outcome by the end of the data window, so outcomes aren't censored. 2012-2015 also avoids the immediate post-crisis years, when Lending Club's underwriting and investor base were still stabilizing.

## Method

1. `01_profile.sql`: row counts, null rates, status values, date range, term split
2. `02_clean.sql`: type fixes (rates and utilization stored as % strings, employment length as text), scope filters, derived fields (default flag, net profit, FICO/DTI/income bands, vintage)
3. `03_segments.sql`: default rate, average rate, and net return per dollar lent by grade, FICO band, DTI band, purpose, and vintage, using window functions for loss ranking, running loss share, and vintage-over-vintage change
4. `04_policies.sql`: three candidate policies simulated against the segment data, each priced out in loans lost, interest income given up, charge-offs avoided, and net profit change, rerun at 2% and 4% assumed cost of funds

Candidate policies tested:
- Decline grades F and G
- Decline DTI above 30 within grades D through G
- Decline FICO below 680 when DTI is above 25

## Key result

[Policy comparison table or summary once Day 4 is done]

## Dashboard

[Tableau Public link, added Day 5]

## Limitations

- **Selection bias:** the data only contains approved loans. Tightening an existing policy can be evaluated this way, but loosening it, or evaluating applicants who were never approved in the first place, cannot.
- **Missing costs:** the data has no acquisition or servicing costs. Cost of funds is an assumption, tested at two rates rather than pinned to one.
- **Time period:** 2012 to 2015 was a relatively benign credit environment. A policy tuned on this window may not hold up in a downturn.
- **Product:** these are fixed-term installment loans, not revolving credit like credit cards, so the risk dynamics don't automatically transfer.

## Stack

DuckDB (SQL directly on the CSV), Python (loading and one optional risk model), Tableau Public (dashboard), all SQL numbered and versioned in this repo.
