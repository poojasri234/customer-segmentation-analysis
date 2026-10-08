-- Customer Value & Repeat Buying Analysis (SQLite)
--
-- Source table expected: online_retail_raw
-- Required columns: InvoiceNo, StockCode, Description, Quantity, InvoiceDate,
-- UnitPrice, CustomerID, Country. Import InvoiceDate as ISO-8601 text
-- (for example, 2010-12-01 08:26:00) so SQLite date functions work reliably.
--
-- This script follows the published project rule: remove exact full-row copies,
-- then retain non-cancelled lines with positive Quantity and UnitPrice. It emits
-- aggregate-only results; do not export customer-level records from this project.
-- It requires SQLite 3.25+ for window functions.

DROP VIEW IF EXISTS customer_rfm;
DROP VIEW IF EXISTS known_customer_lines;
DROP VIEW IF EXISTS eligible_lines;
DROP VIEW IF EXISTS deduplicated_lines;

-- Retain the first copy of each full duplicate row. rowid is used only to make
-- the retained copy deterministic and is not part of the duplicate definition.
CREATE TEMP VIEW deduplicated_lines AS
WITH ranked AS (
    SELECT
        rowid AS source_row_id,
        InvoiceNo,
        StockCode,
        Description,
        Quantity,
        InvoiceDate,
        UnitPrice,
        CustomerID,
        Country,
        ROW_NUMBER() OVER (
            PARTITION BY
                InvoiceNo,
                StockCode,
                Description,
                Quantity,
                InvoiceDate,
                UnitPrice,
                CustomerID,
                Country
            ORDER BY rowid
        ) AS duplicate_rank
    FROM online_retail_raw
)
SELECT
    source_row_id,
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country
FROM ranked
WHERE duplicate_rank = 1;

CREATE TEMP VIEW eligible_lines AS
SELECT
    source_row_id,
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country,
    Quantity * UnitPrice AS gross_invoiced_sales_gbp
FROM deduplicated_lines
WHERE Quantity > 0
  AND UnitPrice > 0
  AND UPPER(COALESCE(InvoiceNo, '')) NOT LIKE 'C%';

-- Customer profiling excludes unidentifiable eligible transactions, but they
-- remain in eligible_lines for the customer-ID coverage denominator.
CREATE TEMP VIEW known_customer_lines AS
SELECT *
FROM eligible_lines
WHERE CustomerID IS NOT NULL
  AND TRIM(CAST(CustomerID AS TEXT)) <> '';

CREATE TEMP VIEW customer_rfm AS
SELECT
    CAST(CustomerID AS TEXT) AS customer_id,
    MAX(InvoiceDate) AS last_purchase_at,
    CAST(
        julianday(date((SELECT MAX(InvoiceDate) FROM eligible_lines), '+1 day'))
        - julianday(date(MAX(InvoiceDate)))
        AS INTEGER
    ) AS recency_days,
    COUNT(DISTINCT InvoiceNo) AS frequency_invoices,
    ROUND(SUM(gross_invoiced_sales_gbp), 2) AS monetary_gbp
FROM known_customer_lines
GROUP BY CustomerID;

-- 1) Input and data-quality validation.
SELECT
    (SELECT COUNT(*) FROM online_retail_raw) AS raw_rows,
    (SELECT COUNT(*) FROM deduplicated_lines) AS rows_after_exact_deduplication,
    (SELECT COUNT(*) FROM online_retail_raw)
      - (SELECT COUNT(*) FROM deduplicated_lines) AS extra_exact_duplicate_copies,
    (SELECT COUNT(*) FROM eligible_lines) AS eligible_transaction_lines,
    (SELECT ROUND(SUM(gross_invoiced_sales_gbp), 2) FROM eligible_lines)
      AS eligible_gross_invoiced_sales_gbp;

-- 2) RFM-style customer profile. Review locally only; do not publish customer IDs.
SELECT
    customer_id,
    last_purchase_at,
    recency_days,
    frequency_invoices,
    monetary_gbp
FROM customer_rfm
ORDER BY monetary_gbp DESC, customer_id;

-- 3) Published aggregate metrics.
WITH metrics AS (
    SELECT
        (SELECT COUNT(*) FROM customer_rfm) AS known_customers,
        (SELECT COUNT(*) FROM customer_rfm WHERE frequency_invoices >= 2) AS repeat_buyers,
        (SELECT SUM(monetary_gbp) FROM customer_rfm) AS known_customer_gross_invoiced_sales_gbp,
        (SELECT SUM(gross_invoiced_sales_gbp) FROM eligible_lines) AS eligible_gross_invoiced_sales_gbp
),
ranked_customers AS (
    SELECT
        monetary_gbp,
        ROW_NUMBER() OVER (ORDER BY monetary_gbp DESC, customer_id) AS value_rank,
        COUNT(*) OVER () AS customer_count
    FROM customer_rfm
)
SELECT
    known_customers,
    repeat_buyers,
    ROUND(100.0 * repeat_buyers / known_customers, 2) AS repeat_buyer_share_percent,
    CAST((known_customers * 20 + 99) / 100 AS INTEGER) AS top_20_percent_customer_count,
    ROUND(
        100.0 * (
            SELECT SUM(monetary_gbp)
            FROM ranked_customers
            WHERE value_rank <= CAST((customer_count * 20 + 99) / 100 AS INTEGER)
        ) / known_customer_gross_invoiced_sales_gbp,
        2
    ) AS top_20_percent_customer_sales_share_percent,
    ROUND(
        100.0 * known_customer_gross_invoiced_sales_gbp / eligible_gross_invoiced_sales_gbp,
        2
    ) AS known_customer_sales_coverage_percent
FROM metrics;

-- 4) Repeat-purchase distribution for the dashboard. Frequency is the count of
-- distinct eligible invoices, not the number of invoice lines.
WITH frequency_bands AS (
    SELECT
        CASE
            WHEN frequency_invoices = 1 THEN '1 invoice'
            WHEN frequency_invoices BETWEEN 2 AND 3 THEN '2–3 invoices'
            WHEN frequency_invoices BETWEEN 4 AND 5 THEN '4–5 invoices'
            ELSE '6+ invoices'
        END AS frequency_band,
        CASE
            WHEN frequency_invoices = 1 THEN 1
            WHEN frequency_invoices BETWEEN 2 AND 3 THEN 2
            WHEN frequency_invoices BETWEEN 4 AND 5 THEN 3
            ELSE 4
        END AS band_sort,
        monetary_gbp
    FROM customer_rfm
)
SELECT
    frequency_band,
    COUNT(*) AS customers,
    ROUND(SUM(monetary_gbp), 2) AS gross_invoiced_sales_gbp
FROM frequency_bands
GROUP BY frequency_band, band_sort
ORDER BY band_sort;

-- 5) Customer-value concentration curve. The ceiling expression is portable in
-- SQLite and makes 20% of 4,338 customers equal 868 customers.
WITH RECURSIVE shares(top_customer_share_percent) AS (
    VALUES (5)
    UNION ALL
    SELECT top_customer_share_percent + 5
    FROM shares
    WHERE top_customer_share_percent < 100
),
ranked_customers AS (
    SELECT
        customer_id,
        monetary_gbp,
        ROW_NUMBER() OVER (ORDER BY monetary_gbp DESC, customer_id) AS value_rank,
        COUNT(*) OVER () AS customer_count,
        SUM(monetary_gbp) OVER () AS total_known_customer_sales_gbp
    FROM customer_rfm
)
SELECT
    shares.top_customer_share_percent,
    CAST((MAX(ranked_customers.customer_count) * shares.top_customer_share_percent + 99) / 100 AS INTEGER)
      AS customer_count,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN ranked_customers.value_rank <= CAST(
                    (ranked_customers.customer_count * shares.top_customer_share_percent + 99) / 100
                    AS INTEGER
                ) THEN ranked_customers.monetary_gbp
                ELSE 0
            END
        ) / MAX(ranked_customers.total_known_customer_sales_gbp),
        2
    ) AS share_of_known_customer_gross_invoiced_sales_percent
FROM shares
CROSS JOIN ranked_customers
GROUP BY shares.top_customer_share_percent
ORDER BY shares.top_customer_share_percent;

-- 6) Benchmark check against the published aggregate-only repository output.
-- Each status should be PASS when run against the official UCI workbook under
-- the documented import and cleaning assumptions.
WITH observed AS (
    SELECT
        (SELECT COUNT(*) FROM customer_rfm) AS known_customers,
        (SELECT COUNT(*) FROM customer_rfm WHERE frequency_invoices >= 2) AS repeat_buyers,
        (SELECT ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM customer_rfm), 2)
         FROM customer_rfm WHERE frequency_invoices >= 2) AS repeat_buyer_share_percent,
        (SELECT ROUND(
            100.0 * SUM(monetary_gbp) / (SELECT SUM(monetary_gbp) FROM customer_rfm),
            2
         )
         FROM (
             SELECT monetary_gbp
             FROM customer_rfm
             ORDER BY monetary_gbp DESC, customer_id
             LIMIT 868
         )) AS top_20_percent_customer_sales_share_percent,
        (SELECT ROUND(
            100.0 * (SELECT SUM(monetary_gbp) FROM customer_rfm)
            / (SELECT SUM(gross_invoiced_sales_gbp) FROM eligible_lines),
            2
         )) AS known_customer_sales_coverage_percent
),
expected(metric, expected_value, observed_value) AS (
    SELECT 'known_customers', 4338.00, known_customers FROM observed
    UNION ALL SELECT 'repeat_buyers', 2845.00, repeat_buyers FROM observed
    UNION ALL SELECT 'repeat_buyer_share_percent', 65.58, repeat_buyer_share_percent FROM observed
    UNION ALL SELECT 'top_20_percent_customer_sales_share_percent', 74.68, top_20_percent_customer_sales_share_percent FROM observed
    UNION ALL SELECT 'known_customer_sales_coverage_percent', 83.51, known_customer_sales_coverage_percent FROM observed
)
SELECT
    metric,
    expected_value,
    observed_value,
    CASE WHEN ABS(observed_value - expected_value) <= 0.01 THEN 'PASS' ELSE 'CHECK IMPORT OR RULES' END AS status
FROM expected;
