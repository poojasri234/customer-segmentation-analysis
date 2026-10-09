# Customer Value & Repeat Buying Analysis

[View the live dashboard](https://poojasri234.github.io/customer-segmentation-analysis/)

I used the public [UCI Online Retail dataset](https://doi.org/10.24432/C5BW33) to examine repeat buying, sales concentration, and how much transaction value can be linked to a customer ID. The data covers one UK retailer from December 2010 to December 2011; values are in GBP (£).

## Question

How much repeat buying is visible among identified customers, how concentrated is sales value, and how complete is the customer-ID coverage?

## Method

- Removed extra exact duplicate rows and excluded cancellations and non-positive values.
- Defined gross invoiced sales as `Quantity × UnitPrice`.
- Used known `CustomerID` values for customer profiling while retaining all eligible lines in the coverage calculation.
- Calculated recency, distinct-invoice frequency, and gross invoiced sales.
- Recreated the repeat-buyer, concentration, and validation checks in [SQLite](sql/customer_value_analysis.sql).

## Results

- **4,338** identified customers met the documented rules; **2,845 (65.58%)** made at least two eligible purchases.
- The top **20%** of identified customers (**868**) generated **74.68%** of known-customer gross invoiced sales.
- **83.51%** of eligible gross invoiced sales could be linked to a CustomerID. The remaining **16.49%** limits customer-level analysis.
- **872 customers with six or more eligible invoices** represented **£5.89M** (66.32%) of known-customer gross-invoice value.
- **1,493 customers** had one eligible invoice and form a useful group for a future repeat-purchase test.

## Recommended next step

First find out why eligible invoices are missing a CustomerID, then test a privacy-appropriate account or loyalty-capture flow at checkout. Separately, run a randomized post-first-purchase journey and compare repeat purchase, gross invoiced sales, returns, and cost with a holdout group.

A five-point gain in CustomerID coverage would make roughly **£0.53M** more of the comparable £10.64M eligible gross-invoice base traceable to a customer. It would improve measurement, not create £0.53M in sales. A five-point lift in repeat rate among 1,493 comparable one-invoice customers would equal about **75 additional repeat customers**, but the data cannot estimate their future value or margin.

## Notes on the data

- This is one historical public retailer dataset, not employer data or a forecast.
- Gross invoiced sales is not net revenue, margin, or profit.
- Missing CustomerIDs can bias customer profiles.
- Historical concentration does not prove that a campaign will change customer behaviour.
- Customer IDs and transaction rows are intentionally not published.

## Project files

- [SQL analysis](sql/customer_value_analysis.sql)
- [Python analysis](src/customer_value_analysis.py)
- [Power BI measures and report plan](powerbi/)
- [Aggregate output](data/customer_value_summary.json)

## Run it

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python src/customer_value_analysis.py --download
```

The raw workbook is not committed. [Data instructions](data/README.md) explain how to obtain it.
