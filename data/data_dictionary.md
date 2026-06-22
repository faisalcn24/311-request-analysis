# Data Dictionary — NYC 311 Service Requests (2024)

## Source

| | |
|---|---|
| **Dataset** | NYC Open Data — 311 Service Requests (2020–Present) |
| **API resource** | `erm2-nwe9` (Socrata) |
| **Scope** | Calendar year 2024 (`created_date` between 2024-01-01 and 2024-12-31) |
| **Raw size** | ~2.05 GB · **3,456,770 rows** · 44 columns |
| **Raw file** | `data/raw/nyc_311_2024.csv` (gitignored — too large to commit) |
| **Cleaned file** | `data/311_cleaned_2024.parquet` (committed, ~83 MB; source for SQL + Power BI). An equivalent `data/311_cleaned_2024.csv` (~961 MB) is produced locally but gitignored — too big for GitHub's 100 MB limit. |
| **Official dictionary** | `311_ServiceRequest_2020-present_DataDictionary_Updated_2025.xlsx` (NYC Open Data) |

---

## Core metric

**Resolution Time** = `closed_date − created_date`, expressed in **hours**.

```
resolution_time_hours = (closed_date - created_date).total_seconds() / 3600
```

This is the anchor metric for the whole project. It only exists for **closed** tickets
(open tickets have a null `closed_date` and are excluded from resolution analysis but
still counted for volume).

---

## Cleaned dataset schema — `data/311_cleaned_2024.csv`

The cleaned file keeps the 10 analysis-relevant raw columns plus one derived metric.
Casing/standardisation rules are applied during cleaning (see `notebooks/01_cleaning_eda.ipynb`).

| Column | Type | Description | Cleaning applied |
|---|---|---|---|
| `unique_key` | integer | Unique ticket ID assigned by 311. Primary key. | — |
| `created_date` | datetime | When the service request was opened. | Parsed from ISO string `YYYY-MM-DDThh:mm:ss.000` |
| `closed_date` | datetime | When the request was resolved/closed. Null while open. | Parsed; nulls retained for open tickets |
| `agency` | category | Acronym of the responding agency (e.g. `HPD`, `NYPD`, `DSNY`). | — |
| `complaint_type` | category | High-level category of the complaint (e.g. `Noise - Residential`). | Casing normalised; variants grouped |
| `descriptor` | string | More specific detail under the complaint type. | — |
| `borough` | category | NYC borough where the request originated. | Normalised to Title Case; `Unspecified`/blank → `Unspecified` |
| `incident_zip` | string | ZIP code of the incident. Stored as string (leading-zero safe). | Cast to clean string; invalid/blank → null |
| `status` | category | Ticket lifecycle state (e.g. `Closed`, `Open`, `In Progress`). | — |
| `resolution_description` | string | Free-text describing the action taken to resolve. | — |
| `resolution_time_hours` | float | **Derived metric.** Hours between created and closed. Null for open tickets. | Negative dropped; capped at 99th percentile |
| `resolution_category` | category | **Derived.** Outcome parsed from `resolution_description`: `Action/Enforcement`, `No issue found`, `Gone/No access`, `Referred/Info`, `Open/Unresolved`, or `Other` (~17% unclassified long tail). Distinguishes a substantive fix from a fast non-resolution. | Regex on standardised agency templates |

### Standardised value sets (after cleaning)

- **`borough`** — `Bronx`, `Brooklyn`, `Manhattan`, `Queens`, `Staten Island`, `Unspecified`
  (raw data mixes `BROOKLYN` / `Brooklyn` and uses `Unspecified` for missing).
- **`status`** — dominated by `Closed`; `Open` / `In Progress` / `Pending` / `Assigned` etc.
  remain open and carry no `closed_date`.

---

## Full raw column reference (44 columns)

✅ = kept in cleaned dataset · ⬇ = dropped (not needed for the resolution question)

| Column | Keep | Notes |
|---|:--:|---|
| `unique_key` | ✅ | Primary key |
| `created_date` | ✅ | Ticket open timestamp |
| `closed_date` | ✅ | Ticket close timestamp (null = open) |
| `agency` | ✅ | Responding agency acronym |
| `agency_name` | ⬇ | Full agency name — redundant with `agency` |
| `complaint_type` | ✅ | Primary analysis dimension |
| `descriptor` | ✅ | Sub-category detail |
| `descriptor_2` | ⬇ | Rarely populated secondary descriptor |
| `location_type` | ⬇ | Not needed for resolution analysis |
| `incident_zip` | ✅ | Geographic detail |
| `incident_address` | ⬇ | Street-level PII; not used |
| `street_name` | ⬇ | Address component |
| `cross_street_1` | ⬇ | Address component |
| `cross_street_2` | ⬇ | Address component |
| `intersection_street_1` | ⬇ | Address component |
| `intersection_street_2` | ⬇ | Address component |
| `address_type` | ⬇ | Address metadata |
| `city` | ⬇ | Coarser than borough; not used |
| `landmark` | ⬇ | Sparsely populated |
| `facility_type` | ⬇ | Not used |
| `status` | ✅ | Open/closed lifecycle — needed for open-rate metric |
| `due_date` | ⬇ | SLA target; out of scope for actual resolution time |
| `resolution_description` | ✅ | Context for how tickets were resolved |
| `resolution_action_updated_date` | ⬇ | Redundant with `closed_date` for this analysis |
| `community_board` | ⬇ | Finer geography than borough; not used |
| `council_district` | ⬇ | Political geography; not used |
| `police_precinct` | ⬇ | Not used |
| `bbl` | ⬇ | Borough-Block-Lot parcel ID; not used |
| `borough` | ✅ | Primary geographic dimension |
| `x_coordinate_state_plane` | ⬇ | Projected coordinate; lat/long preferred and unused |
| `y_coordinate_state_plane` | ⬇ | Projected coordinate |
| `open_data_channel_type` | ⬇ | Intake channel (PHONE/ONLINE/etc.); not used |
| `park_facility_name` | ⬇ | Mostly `Unspecified` |
| `park_borough` | ⬇ | Duplicate of `borough` for park tickets |
| `vehicle_type` | ⬇ | Taxi-specific; almost always null |
| `taxi_company_borough` | ⬇ | Taxi-specific; almost always null |
| `taxi_pick_up_location` | ⬇ | Taxi-specific; almost always null |
| `bridge_highway_name` | ⬇ | DOT-specific; almost always null |
| `bridge_highway_direction` | ⬇ | DOT-specific |
| `road_ramp` | ⬇ | DOT-specific |
| `bridge_highway_segment` | ⬇ | DOT-specific |
| `latitude` | ⬇ | Point geometry; not used (borough is the geo grain) |
| `longitude` | ⬇ | Point geometry |
| `location` | ⬇ | `POINT(long lat)` string; duplicate of lat/long |

**Kept (10 + 2 derived):** `unique_key`, `created_date`, `closed_date`, `agency`,
`complaint_type`, `descriptor`, `borough`, `incident_zip`, `status`,
`resolution_description`, **`resolution_time_hours`**, **`resolution_category`**.
