# Invest IQ Data Ingestion

This repository contains the command-line importer for stock transaction
spreadsheets. It reads a selected row range from CSV, TSV, Excel, or a live
Google Sheet, validates and previews transactions, and can optionally insert
them into PostgreSQL.

The importer is safe by default: it performs a dry run unless `--commit` is
provided.

## Requirements and setup

Use Python 3.10 or newer. From this directory, create a virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
```

Install dependencies for the input and operation you need:

```bash
python -m pip install openpyxl
python -m pip install "psycopg[binary]"  # required only when committing to PostgreSQL
python -m pip install google-api-python-client google-auth  # live Google Sheets only
```

## Import a local spreadsheet

Row numbers are 1-based and inclusive. `--header-row` selects the header row;
`--from-row` and `--to-row` select the data range. For example, from this
directory, import the workbook stored one level above:

```bash
python ingest_sheet.py \
  --file ../Stocks.xlsx \
  --tab Sheet1 \
  --header-row 2 \
  --from-row 6 \
  --to-row 105
```

This example uses row 2 for headers and begins data at row 6 to skip the
workbook's blank/category rows. Adjust the path, sheet, and row range for your
input.

The importer requires a symbol/ticker and quantity, plus either purchase price
or invested amount. It recognises common header names without regard to case,
spacing, or parenthetical notes. Use `--map FIELD="Column name"` for non-standard
headers:

```bash
python ingest_sheet.py --file stocks.csv --from-row 2 --to-row 150 \
  --map ticker="GF Symbol" --map quantity="Qty"
```

Add `--out cleaned-transactions.json` or `--out cleaned-transactions.csv` to
write valid rows to a local output file.

## Commit to PostgreSQL

Review the dry-run report first. Set the database URL in your environment
rather than hard-coding credentials in a shared command or source file:

```bash
export DATABASE_URL='postgresql://IMPORT_USER:URL_ENCODED_PASSWORD@HOST:5432/DATABASE'
```

For a TLS-enabled database such as Aurora, pass `sslmode=require` in the URL or
use a database connection environment configured for TLS:

```bash
python ingest_sheet.py \
  --file ../Stocks.xlsx \
  --tab Sheet1 \
  --header-row 2 \
  --from-row 6 \
  --to-row 105 \
  --db-url "$DATABASE_URL" \
  --commit
```

The importer creates `instruments` and `transactions` tables if necessary. Use
a database account with the required DDL and write privileges. Do not use the
read-only account configured for the API.

If selected non-empty rows are invalid, the importer will not commit by
default. After reviewing invalid rows, `--skip-invalid` commits only valid
rows:

```bash
python ingest_sheet.py --file ../Stocks.xlsx --tab Sheet1 \
  --header-row 2 --from-row 6 --to-row 105 \
  --db-url "$DATABASE_URL" --commit --skip-invalid
```

For private Aurora clusters, run the importer from a host with private VPC
connectivity, such as a VPN-connected workstation or controlled EC2 instance.
See the backend repository's
[`AWS_DEPLOYMENT.md`](../backend/AWS_DEPLOYMENT.md) for VPC and security-group
guidance.

## Live Google Sheet

Create a Google service account, share the sheet with its email address as a
Viewer, and set its credential-file path and the sheet ID:

```bash
export SHEET_ID='YOUR_SPREADSHEET_ID'
export GOOGLE_APPLICATION_CREDENTIALS='/path/to/service-account.json'
python ingest_sheet.py --tab 'Purchases' \
  --header-row 2 --from-row 3 --to-row 150
```

Add `--db-url "$DATABASE_URL" --commit` only after reviewing the dry run.
Credential files should not be committed.

## Data mapping and repeat imports

- Blank transaction types default to `BUY`.
- If purchase price is blank but invested amount exists, price is derived as
  `invested_amount / quantity`.
- US exchange tickers with an explicitly provided purchase price are treated
  as USD. Other prices use `--base-currency` (default `INR`); invested amounts
  are assumed to use that base currency.
- Current price/amount and purchase performance fields are saved as a
  transaction snapshot. Historical comparison columns are reported as ignored.
- The importer hashes transaction values to avoid reinserting unchanged rows
  on repeat imports. Editing a row's values may result in a new transaction.

Run `python ingest_sheet.py --help` to see all options.

## SQL example

[`query.sql`](./query.sql) contains an example query for summarising BUY
quantities, average prices, and invested amounts by symbol for non-USD-priced
transactions.

The local `Stocks.xlsx` workbook remains one directory above this repository
in the project workspace; it is not required for the importer itself.
[`run-code.txt`](./run-code.txt) contains an example invocation.
