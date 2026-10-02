# Customer Value & Repeat Buying Analysis

A reproducible customer analytics project using the public [UCI Online Retail dataset](https://doi.org/10.24432/C5BW33), which contains transactions from a UK-based online retailer between December 2010 and December 2011. It uses GBP because the source data is from a UK retailer.

## Business question

How much repeat buying is visible among identified customers, how concentrated is their observed spending, and how much eligible sales value can be tied to a customer ID?

## Results

| Measure | Result | Definition |
| --- | ---: | --- |
| Known customers | 4,338 | Customers with an ID and at least one eligible invoice |
| Repeat buyers | 65.6% | Known customers with at least two distinct eligible invoices |
| Top-customer value concentration | 74.7% | Share of known-customer gross invoiced sales from the top 20% (868) customers by observed spend |
| Customer-ID coverage | 83.5% | Share of eligible gross invoiced sales attached to a known customer ID |

These are descriptive results from a public historical dataset. They are not employer results, customer forecasts, or evidence that any intervention caused a change.

## Method

1. Read the source workbook and remove extra exact duplicate copies, retaining the first full-row occurrence.
2. Keep non-cancelled invoice lines with positive quantity and positive unit price. Gross invoiced sales are `Quantity × UnitPrice`.
3. Exclude rows without a `CustomerID` from customer-level profiling, while retaining them when calculating overall eligible sales for the coverage denominator.
4. Build RFM-style customer features in memory:
   - **Recency:** days between a customer's last purchase and the day after the dataset's final transaction;
   - **Frequency:** distinct eligible invoices per customer;
   - **Monetary:** eligible gross invoiced sales per customer.
5. Rank known customers by observed monetary value and calculate the top 20% contribution. The script writes aggregate results only.

## Reproduce

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python src/customer_value_analysis.py --download
```

Or download `Online Retail.xlsx` from the UCI source, save it as `data/Online Retail.xlsx`, then run:

```bash
python src/customer_value_analysis.py --input "data/Online Retail.xlsx"
```

The output is written to [`data/customer_value_summary.json`](data/customer_value_summary.json). The raw workbook is deliberately excluded from the repository; see [`data/README.md`](data/README.md).

## Validation

The script checks the expected source schema and verifies that the output metrics reproduce the published results within a small rounding tolerance. No customer-level records or identifiers are exported.

## Tools

Python, pandas, openpyxl

## Source and limitations

- Source: [UCI Machine Learning Repository — Online Retail](https://doi.org/10.24432/C5BW33), Daqing Chen (2015), CC BY 4.0.
- The source represents one UK retailer and a limited historical period.
- “Gross invoiced sales” is not net revenue or profit: it excludes cancellation/non-positive lines under the stated rule and does not include costs or a returns reconciliation.
- Missing customer IDs can affect customer-level profiles. The customer results apply only to identified customers in this dataset.
