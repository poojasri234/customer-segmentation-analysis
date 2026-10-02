#!/usr/bin/env python3
"""Reproduce aggregate customer value results from UCI Online Retail.

No raw or customer-level data is written to the repository. Run with --download
or pass a local copy of the UCI Online Retail.xlsx workbook.
"""
from __future__ import annotations

import argparse
import io
import json
import math
from pathlib import Path
import urllib.request
import zipfile

import pandas as pd

SOURCE_URL = "https://doi.org/10.24432/C5BW33"
DOWNLOAD_URL = "https://archive.ics.uci.edu/static/public/352/online%2Bretail.zip"
EXPECTED_COLUMNS = [
    "InvoiceNo",
    "StockCode",
    "Description",
    "Quantity",
    "InvoiceDate",
    "UnitPrice",
    "CustomerID",
    "Country",
]
# Values independently reproduced from the cited UCI workbook under the documented rule.
EXPECTED_RESULTS = {
    "known_customers": 4338,
    "repeat_customer_share_percent": 65.58321807284463,
    "top_20_percent_customer_count": 868,
    "top_20_percent_customer_sales_share_percent": 74.68374942194758,
    "known_customer_sales_coverage_percent": 83.50983237892623,
}


def percentage(numerator: float, denominator: float) -> float:
    if denominator == 0:
        raise ValueError("Cannot calculate a percentage with a zero denominator.")
    return numerator / denominator * 100


def ensure_input(input_path: Path, download: bool) -> None:
    """Provide the official workbook locally without committing it to Git."""
    if input_path.exists():
        return
    if not download:
        raise FileNotFoundError(
            f"Missing {input_path}. Download the UCI workbook or rerun with --download."
        )

    with urllib.request.urlopen(DOWNLOAD_URL, timeout=120) as response:
        archive_bytes = response.read()
    with zipfile.ZipFile(io.BytesIO(archive_bytes)) as archive:
        member = next(
            name for name in archive.namelist() if name.endswith("Online Retail.xlsx")
        )
        input_path.parent.mkdir(parents=True, exist_ok=True)
        input_path.write_bytes(archive.read(member))


def analyze(workbook: Path) -> dict:
    """Return aggregate-only customer value results."""
    raw = pd.read_excel(
        workbook,
        engine="openpyxl",
        dtype={"InvoiceNo": str, "StockCode": str},
    )
    if list(raw.columns) != EXPECTED_COLUMNS:
        raise ValueError(f"Unexpected source schema: {list(raw.columns)!r}")

    # Keep the first of any exact full-row copies before applying transaction rules.
    deduplicated = raw.drop_duplicates(keep="first").copy()
    invoice_number = deduplicated["InvoiceNo"].fillna("").str.upper()
    eligible = deduplicated.loc[
        (deduplicated["Quantity"] > 0)
        & (deduplicated["UnitPrice"] > 0)
        & ~invoice_number.str.startswith("C")
    ].copy()
    eligible["gross_invoiced_sales_gbp"] = (
        eligible["Quantity"] * eligible["UnitPrice"]
    )

    # Customer-level profiling only applies to rows with an identifier.
    known = eligible.loc[eligible["CustomerID"].notna()].copy()
    customers = known.groupby("CustomerID", as_index=True).agg(
        last_purchase=("InvoiceDate", "max"),
        frequency=("InvoiceNo", "nunique"),
        monetary_gbp=("gross_invoiced_sales_gbp", "sum"),
    )
    if customers.empty:
        raise ValueError("No known customers remain after the documented transaction rules.")

    reference_date = pd.to_datetime(eligible["InvoiceDate"]).max().normalize() + pd.Timedelta(days=1)
    customers["recency_days"] = (
        reference_date - pd.to_datetime(customers["last_purchase"]).dt.normalize()
    ).dt.days

    top_customer_count = math.ceil(len(customers) * 0.20)
    top_customer_sales = float(
        customers.nlargest(top_customer_count, "monetary_gbp")["monetary_gbp"].sum()
    )
    known_sales = float(known["gross_invoiced_sales_gbp"].sum())
    eligible_sales = float(eligible["gross_invoiced_sales_gbp"].sum())
    repeat_customer_count = int((customers["frequency"] >= 2).sum())

    results = {
        "project": "Customer Value & Repeat Buying Analysis",
        "source": {
            "name": "UCI Online Retail",
            "url": SOURCE_URL,
            "license": "CC BY 4.0",
            "scope": "Public historical transactions from a UK-based online retailer, December 2010 to December 2011.",
            "currency": "GBP",
        },
        "method": {
            "deduplication": "Retain the first exact full-row occurrence.",
            "eligible_sales_rule": "Quantity > 0, UnitPrice > 0, and InvoiceNo does not begin with C.",
            "customer_scope": "Only eligible lines with a CustomerID are included in customer profiling.",
            "rfm_style_features": {
                "recency": "Days from last purchase to the day after the final dataset transaction.",
                "frequency": "Distinct eligible invoices per known customer.",
                "monetary": "Eligible gross invoiced sales per known customer (Quantity × UnitPrice).",
            },
        },
        "results": {
            "known_customers": int(len(customers)),
            "repeat_buying": {
                "definition": "At least two distinct eligible invoices in the observed period.",
                "share_percent": round(percentage(repeat_customer_count, len(customers)), 1),
            },
            "top_customer_value_concentration": {
                "definition": "Top 20% of known customers ranked by observed gross invoiced sales.",
                "customer_count": int(top_customer_count),
                "share_of_known_customer_gross_invoiced_sales_percent": round(
                    percentage(top_customer_sales, known_sales), 1
                ),
            },
            "known_customer_id_coverage": {
                "definition": "Eligible gross invoiced sales tied to a known CustomerID.",
                "share_of_eligible_gross_invoiced_sales_percent": round(
                    percentage(known_sales, eligible_sales), 1
                ),
            },
        },
        "limitations": [
            "Results are descriptive portfolio analysis, not employer outcomes or forecasts.",
            "Gross invoiced sales are not net revenue or profit and do not include cost or returns reconciliation.",
            "Missing customer IDs may bias customer-level profiles.",
        ],
    }

    # Validate calculations against the reproducible UCI benchmark before publishing output.
    observed = {
        "known_customers": len(customers),
        "repeat_customer_share_percent": percentage(repeat_customer_count, len(customers)),
        "top_20_percent_customer_count": top_customer_count,
        "top_20_percent_customer_sales_share_percent": percentage(top_customer_sales, known_sales),
        "known_customer_sales_coverage_percent": percentage(known_sales, eligible_sales),
    }
    for key, expected in EXPECTED_RESULTS.items():
        actual = observed[key]
        if isinstance(expected, int):
            if actual != expected:
                raise AssertionError(f"{key}: expected {expected}, found {actual}")
        elif abs(actual - expected) > 1e-6:
            raise AssertionError(f"{key}: expected {expected}, found {actual}")

    return results


def main() -> None:
    project_root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--input",
        type=Path,
        default=project_root / "data" / "Online Retail.xlsx",
        help="Path to the source UCI workbook.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=project_root / "data" / "customer_value_summary.json",
        help="Aggregate JSON output path.",
    )
    parser.add_argument(
        "--download",
        action="store_true",
        help="Download the official UCI archive if --input is missing.",
    )
    args = parser.parse_args()

    ensure_input(args.input, args.download)
    results = analyze(args.input)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote aggregate-only results to {args.output}")


if __name__ == "__main__":
    main()
