# Data

This repository does **not** include the UCI source workbook or any customer-level export.

To reproduce the analysis, either:

1. Run `python src/customer_value_analysis.py --download`, which downloads the official UCI archive at runtime; or
2. Download `Online Retail.xlsx` from [UCI](https://doi.org/10.24432/C5BW33) and place it in this directory as `Online Retail.xlsx`.

The workbook is excluded by `.gitignore`. The only committed output is `customer_value_summary.json`, an aggregate-only summary with no customer IDs or row-level transactions.
