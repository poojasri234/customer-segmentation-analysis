# Dashboard specification

## Purpose

Build a single-page descriptive dashboard titled Customer Value & Repeat Buying Analysis. It should make repeat buying, customer-value concentration, and customer-ID sales coverage easy to review in the public UCI dataset.

Use a restrained visual system: white background, dark slate text, one blue accent, standard Power BI tooltips, and no decorative or animated visuals. Keep the central insights visible without scrolling on a typical laptop display.

## Header

- Title: Customer Value & Repeat Buying Analysis
- Subtitle: Public UCI Online Retail data · UK-based retailer · Dec 2010–Dec 2011 · GBP
- Source label: UCI Online Retail (CC BY 4.0)

## KPI row

Place four cards across the top:

| Card | Measure | Expected result |
| --- | --- | ---: |
| Known customers | Known Customers | 4,338 |
| Repeat buyers | Repeat Buyer Share % | 65.58% |
| Top 20% contribution | Top Customer Contribution % | 74.68% |
| Customer-ID sales coverage | Known Customer Sales Coverage % | 83.51% |

The top-20% card should also show 868 customers in a subtitle or tooltip. These values are descriptive observations, not a target or forecast.

## Interactive visuals

### Customer value concentration

- Use a line chart with Customer Share Bands on the X axis and Customer Value Contribution % on the Y axis.
- Add a Top Customer Share slicer with 5% increments from 5% to 100%.
- Show dynamic callouts for Top Customer Contribution % and Top Customer Count Selected.

### Repeat purchase distribution

- Use a clustered column chart by frequency band: 1 invoice, 2–3 invoices, 4–5 invoices, and 6+ invoices.
- Show customer count as the value and gross invoiced sales in the tooltip.
- Add a compact table with the same band, customer count, and gross invoiced sales for review.

## Scope note

Customer metrics cover eligible transactions with a known CustomerID. Gross invoiced sales is not net revenue or profit. Results are descriptive for one historical public UK retailer dataset; missing customer IDs can affect customer-level profiles.

## Reconciliation checklist

1. Remove exact duplicates before applying the eligibility filter.
2. Eligibility means positive quantity, positive unit price, and invoice numbers not beginning with C.
3. Build customer metrics only from nonblank CustomerID values.
4. Reconcile the KPI cards to the aggregate project outputs.
5. Verify that a 20% slicer selection returns 868 customers and 74.68% contribution.
