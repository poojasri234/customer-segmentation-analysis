# Power BI build notes

This folder contains reproducible material to rebuild the Customer Value & Repeat Buying Analysis report in Power BI Desktop. It does not include a PBIX file or a published Power BI service report.

## Data source and scope

Use a local copy of the public UCI Online Retail workbook. The source represents a UK-based retailer from December 2010 through December 2011, so monetary fields are GBP.

Keep the workbook and all customer-level tables local. This repository publishes only aggregate, identifier-free outputs. Do not publish CustomerID values, transaction rows, or a report with exportable customer detail.

The report describes historical patterns in a public dataset. It does not estimate employer outcomes, forecasts, customer lifetime value, net revenue, profit, or causal impact.

## Build the model

1. In Power BI Desktop, import a local copy of Online Retail.xlsx and name the query OnlineRetailRaw.
2. Set InvoiceNo, StockCode, Description, CustomerID, and Country to text; Quantity to whole number; InvoiceDate to date/time; and UnitPrice to fixed decimal.
3. Duplicate the query as EligibleSales. Remove exact duplicates across the eight UCI source columns before filtering.
4. Keep positive Quantity and UnitPrice rows whose invoice number does not start with C. Add GrossInvoicedSalesGBP as Quantity multiplied by UnitPrice.
5. Reference EligibleSales as KnownCustomerSales and retain nonblank CustomerID values.
6. Group KnownCustomerSales into CustomerProfile with last purchase, distinct invoice frequency, gross invoiced sales, and recency days.

The expected checks are 4,338 known customers, 2,845 repeat buyers (65.58%), 74.68% contribution from the top 20% (868 customers), and 83.51% customer-ID sales coverage. Use the SQL file and aggregate data folder to reconcile these values.

## Build the report

1. Add the disconnected selector tables and measures from measures.dax.
2. Follow dashboard-spec.md for the visual layout, labels, and scope note.
3. Format monetary values as GBP and percentage measures as percentages with one or two decimal places.
4. Retain the limitation: Customer metrics cover eligible transactions with a known CustomerID. Gross invoiced sales is not net revenue or profit.
