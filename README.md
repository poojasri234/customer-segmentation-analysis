# Customer Value & Repeat Buying Analysis

[Open the live dashboard](https://poojasri234.github.io/customer-segmentation-analysis/)

**Tools:** Python/pandas · SQL/SQLite · Excel source-data handling · RFM-style customer analytics · interactive HTML dashboard · Power BI report specification and DAX measures

A reproducible customer analytics case study using the public [UCI Online Retail dataset](https://doi.org/10.24432/C5BW33), representing one UK retailer from December 2010 to December 2011. Values are in GBP (£).

## Business question

How much repeat buying is visible among identified customers, how concentrated is observed gross invoiced sales, and how much eligible sales value can be connected to a customer ID?

## Approach

1. Validated the source workbook and removed extra exact full-row copies, retaining the first occurrence.
2. Kept non-cancelled invoice lines with positive quantity and unit price; `gross invoiced sales = Quantity × UnitPrice`.
3. Used eligible lines with a known `CustomerID` for customer profiling while retaining all eligible lines in the CustomerID-coverage denominator.
4. Calculated RFM-style recency, distinct-invoice frequency, and gross invoiced sales.
5. Reproduced repeat-buyer, value-concentration, and validation results with [SQLite queries](sql/customer_value_analysis.sql).

## Findings

- **4,338** identified customers remained after the documented rules; **2,845 (65.58%)** made at least two distinct eligible purchases.
- The top **20%** of identified customers (**868**) generated **74.68%** of known-customer gross invoiced sales. This is historical value concentration, not an individual targeting list.
- **83.51%** of eligible gross invoiced sales could be tied to a CustomerID. The remaining **16.49%** is an identity and measurement gap that limits repeat-behaviour analysis.
- The **872 customers with 6+ eligible invoices** represented **£5.89M** or **66.32%** of known-customer gross-invoice value. The **1,493 one-invoice customers** are the clearest future repeat-purchase test population.

## Recommendation

First diagnose why eligible invoices lack a CustomerID, then test a privacy-appropriate account or loyalty-capture flow at checkout. This improves measurement before attempting customer-level retention or cross-sell work.

In parallel, run a randomized post-first-purchase journey for a selected group of one-invoice customers and compare future repeat purchase, gross invoiced sales, return rate, and incremental cost with a holdout.

## Potential business value — illustrative only

A **five-percentage-point increase in CustomerID coverage** would make roughly **£0.53M** more of a comparable **£10.64M eligible gross-invoice base** traceable to a customer. That is better measurement, **not £0.53M of new sales**.

Likewise, a five-point incremental repeat rate among a comparable group of **1,493** one-invoice customers is about **75 additional repeat customers**. The data cannot estimate their future order value, margin, or profit.

## Limitations

- This is one historical public retailer dataset, not employer data or a forecast.
- Gross invoiced sales is not net revenue, margin, or profit; cancellation and non-positive lines are excluded rather than reconciled into net sales.
- Missing CustomerID values can bias customer-level profiles.
- Historical concentration does not prove that a campaign or intervention will change behaviour.
- Customer identifiers and transaction rows are deliberately not published in this repository.

## SQL and dashboard evidence

- [`sql/customer_value_analysis.sql`](sql/customer_value_analysis.sql) — eligibility, RFM-style profiling, repeat distribution, concentration, and validation queries.
- [`src/customer_value_analysis.py`](src/customer_value_analysis.py) — reproducible aggregate analysis.
- [`powerbi/`](powerbi/) — DAX measures and report specification. A completed `.pbix` file is not included.
- [`data/customer_value_summary.json`](data/customer_value_summary.json) — aggregate-only output.

## 3-minute interview walkthrough

- **0:00–0:25:** Frame the decision as repeat purchasing, value concentration, and data traceability — not a recommendation engine.
- **0:25–1:10:** Explain exact-dedupe, cancellation/positive-value rules, CustomerID scope, and gross-invoice definition.
- **1:10–1:50:** State 4,338 identified customers, 65.58% repeat buyers, top 20% contributing 74.68%, and 83.51% CustomerID coverage.
- **1:50–2:25:** Show the SQL validation path and explain that top-20% is an aggregate concentration measure, not a personal-data target list.
- **2:25–3:00:** Recommend identity capture plus a randomized first-purchase test. With business data, add returns, margin, product availability, consent, and campaign exposure.

## Reproduce

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python src/customer_value_analysis.py --download
```

The raw source workbook is not committed. See [data/README.md](data/README.md) for source and placement instructions.
