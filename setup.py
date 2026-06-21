import pandas as pd
import os
import time
import urllib.parse

base_url = "https://data.cityofnewyork.us/resource/erm2-nwe9.csv"
where_clause = "created_date between '2024-01-01T00:00:00' and '2024-12-31T23:59:59'"
output_file = os.getenv("NYC_311_OUTPUT", "nyc_311_2024.csv")
page_size = int(os.getenv("NYC_311_PAGE_SIZE", "50000"))
max_retries = int(os.getenv("NYC_311_MAX_RETRIES", "6"))
app_token = os.getenv("NYC_311_APP_TOKEN")  # optional; raises rate limits

# Paginate through the FULL 2024 result set.
# $order=:id gives a stable sort so $offset paging never skips or duplicates rows
# (the original pull capped at $limit=3,000,000 with no order, truncating ~457k rows).


def fetch_page(offset):
    """Fetch one page, retrying transient network errors with backoff."""
    params = {
        "$where": where_clause,
        "$order": ":id",
        "$limit": page_size,
        "$offset": offset,
    }
    if app_token:
        params["$$app_token"] = app_token
    url = f"{base_url}?{urllib.parse.urlencode(params)}"

    for attempt in range(1, max_retries + 1):
        try:
            return pd.read_csv(url, low_memory=False)
        except Exception as exc:  # noqa: BLE001 - retry any transient read failure
            if attempt == max_retries:
                raise
            wait = min(2 ** attempt, 60)
            print(f"  retry {attempt}/{max_retries} after error: {exc} (waiting {wait}s)")
            time.sleep(wait)


# Resume: if the output file already exists, count its data rows and skip past them.
rows_written = 0
if os.path.exists(output_file):
    with open(output_file, "r", encoding="utf-8") as f:
        rows_written = sum(1 for _ in f) - 1  # minus header
    rows_written = max(rows_written, 0)
    if rows_written:
        print(f"Resuming: {rows_written:,} rows already on disk")

offset = rows_written

while True:
    chunk = fetch_page(offset)

    if chunk.empty:
        break

    file_exists = os.path.exists(output_file) and rows_written > 0
    chunk.to_csv(
        output_file,
        mode="a" if file_exists else "w",
        index=False,
        header=not file_exists,
    )

    rows_written += len(chunk)
    offset += len(chunk)
    print(f"Saved {rows_written:,} rows to {output_file}")

    # Last page is short -> no more data.
    if len(chunk) < page_size:
        break

print(f"Done. Saved {rows_written:,} rows to {output_file}")
