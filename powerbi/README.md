# Power BI — Model Reference & Dashboard Build Guide

Two things in one place: **what's in the semantic model** (model reference) and **how the
4-page dashboard is assembled on top of it** (build guide).

---

## Model reference

The semantic model behind `nyc_311_dashboard.pbix`. Built directly into the Power BI
Desktop model via the Power BI modeling MCP, then **verified measure-by-measure against the
Phase 2 SQL oracle** (the queries in `sql/`). This file is the record of what's
in the model — the "why" behind the framing lives in `report/analysis_decisions.md`; don't
restate it, link to it.

> **Scope note.** The MCP builds the *model* (table, columns, measures) — not the report
> visuals. Page/visual assembly is in the **Dashboard build guide** below.

### Data source

One Import-mode table, **`tickets`**, loaded from the committed Parquet via Power Query:

```m
let
    Source = Parquet.Document(File.Contents("C:\01_Projects\analysis\data\311_cleaned_2024.parquet")),
    #"Kept Columns" = Table.SelectColumns(Source,
        {"created_date", "agency", "complaint_type", "borough", "resolution_time_hours", "resolution_category"},
        MissingField.Error)
in
    #"Kept Columns"
```

- **3,455,782 rows.** The model imports only the **6 columns the dashboard actually uses**
  (above) to keep the `.pbix` lean — the full 12-column cleaned schema lives in the Parquet
  (see `data/data_dictionary.md`).
- `created_date` 2024-01-01 → 2024-12-31; **3,391,233** rows carry a resolution time (the rest
  are open — blank `resolution_time_hours`).

### Calculated columns

| Column | Type | Expression | Why |
|---|---|---|---|
| `Month Num` | Int64 | `MONTH('tickets'[created_date])` | 1–12 sort key for `Month`. |
| `Month` | String | `FORMAT('tickets'[created_date], "MMM")` · **Sort by `Month Num`** | Jan–Dec axis for the per-type seasonality trend (single-year data). |
| `Bucket Order` | Int64 | `SWITCH(TRUE(), ISBLANK(h),BLANK(), h<1,1, h<4,2, h<12,3, h<24,4, h<72,5, h<168,6, h<720,7, h<2160,8, 9)` | Sort key (1–9) for `Resolution Bucket`. |
| `Resolution Bucket` | String | `SWITCH(TRUE(), ISBLANK(h),BLANK(), h<1,"<1h", h<4,"1-4h", h<12,"4-12h", h<24,"12-24h", h<72,"1-3d", h<168,"3-7d", h<720,"7-30d", h<2160,"30-90d", ">90d")` · **Sort by `Bucket Order`** | Histogram bins matching SQL query 05. Open tickets (blank hours) stay blank → excluded from the closed distribution. |

(`h` = `'tickets'[resolution_time_hours]`.)

### Measures (display folder: *Key Measures*)

| Measure | DAX | Format | Why |
|---|---|---|---|
| `Total Count` | `COUNTROWS('tickets')` | `#,0` | Volume base (open + closed). |
| `Closed Count` | `COUNT('tickets'[resolution_time_hours])` | `#,0` | Closed = non-blank resolution time (keyed on the metric, not `status`). |
| `Open Count` | `[Total Count] - [Closed Count]` | `#,0` | Open/unresolved. |
| `Open Rate` | `DIVIDE([Open Count], [Total Count])` | `0.0%` | % still open — keyed on null close date, not the status string. |
| `Median Resolution Hours` | `MEDIAN('tickets'[resolution_time_hours])` | `#,0.0` | **PRIMARY metric.** `MEDIAN` ignores blanks, so open tickets drop out. Lead with this. |
| `Mean Resolution Hours` | `AVERAGE('tickets'[resolution_time_hours])` | `#,0.0` | **SECONDARY only**, with the right-skew caveat (mean ≈ 298 h vs median ≈ 8 h). |
| `Substantive Count` | `CALCULATE([Closed Count], 'tickets'[resolution_category] = "Action/Enforcement")` | `#,0` | Closed tickets that were an actual fix/enforcement. |
| `Substantive Rate` | `DIVIDE([Substantive Count], [Closed Count])` | `0.0%` | Effectiveness. **Pair with median everywhere** (speed ≠ effectiveness). |
| `Median Label` | `IF([Median Resolution Hours] >= 6960, ">290 days (long-cycle)", FORMAT([Median Resolution Hours], "#,0.0") & " h")` | text | Cap-aware label: categories pinned to the 290-day (6960 h) cap show `">290 days (long-cycle)"` not a fake-precise number. |
| `Seasonality Index` | see below | `#,0` | Volume index, 100 = the type's own average month. Baseline is per `complaint_type` (matches SQL 03); built for the type × month trend. |

```dax
Seasonality Index =
VAR MonthVol = [Total Count]
VAR AvgMonthlyVol =
    CALCULATE(
        AVERAGEX(VALUES('tickets'[Month Num]), [Total Count]),
        ALLEXCEPT('tickets', 'tickets'[complaint_type])
    )
RETURN DIVIDE(MonthVol, AvgMonthlyVol) * 100
```

### Verification — every measure vs the oracle

Run in-model via DAX `EVALUATE` (this session). All matched.

| Check | Model | Oracle |
|---|---|---|
| Row count | 3,455,782 | 3,455,782 |
| Overall median / substantive / open rate | 8.1 h / 29.0% / 1.87% | ~8 h / ~29% / — |
| NYPD agency (median / substantive) | 1.06 h / 36.9% | 1.1 h / 36.9% |
| HPD agency | 92.4 h / 28.4% | 92.4 h / 28.4% |
| DEP agency | 25.4 h / 3.6% | 25.4 h / 3.6% |
| Slowest types | New Tree Request `">290 days (long-cycle)"`; Lot Condition 4623 h; Day Care 4587 h; Mobile Food Vendor 4484 h | same |
| Distribution | <1h 25.18 · 1–4h 18.44 · 4–12h 9.47 · 12–24h 7.15 · 1–3d 12.93 · 3–7d 8.31 · 7–30d 9.92 · 30–90d 4.53 · >90d 4.08 (%) | identical |
| Seasonality (Heat/Hot Water) | Jan 233 · Aug 14 · Dec 285 | 233 / 14 / 285 |
| Seasonality (Noise – Street/Sidewalk) | Jan 27 · Jun 182 · Dec 36 | 27 / 182 / 36 |
| Borough reversal | Bronx overall 13.5 h, Bronx Heat 30.6 h **<** Manhattan Heat 42.8 h | composition reversal |

### Rebuilding the model from scratch

If the `.pbix` is lost, recreate it by: (1) Get Data → Parquet → the file above; (2) add the
calculated columns and measures from the tables here. Or re-run the MCP build sequence against
a fresh Power BI Desktop instance.

---

## Dashboard build guide

The **model is already built and verified** in your running Power BI Desktop instance — table
`tickets`, calculated columns, and all measures (see the **Model reference** above). The Power BI
modeling MCP can author the model but **not** report visuals, so this guide is the click-path for
the 4 pages. Each visual lists its fields + the **oracle number to confirm** it's correct.

Framing rules baked into every page (from `report/analysis_decisions.md`):
**median-first** · **speed ≠ effectiveness (always pair them)** · **complaint type/agency =
signal, borough = caveated** · **trend = volume by type, never resolution-time-over-time** ·
**cap-pinned types labeled, not fake-precise**.

### Step 0 — Save the file first

The model currently lives in memory in the open Desktop instance. **File → Save As →
`C:\01_Projects\analysis\powerbi\nyc_311_dashboard.pbix`** before building, and save often.
In the Fields pane you should see the `tickets` table with a *Key Measures* folder.

Recommended global formatting: one theme (View → Themes), titles on every visual, and turn
**Total Count / Closed Count** number format to whole numbers (already `#,0`).

### Slicers (add to every page, or use a sync'd slicer panel)

| Slicer | Field | Notes |
|---|---|---|
| Complaint type | `complaint_type` | Dropdown (197 values) with search. |
| Agency | `agency` | Dropdown. |
| Month | `Month` | Already sorts Jan→Dec (sorted by `Month Num`). |
| Borough | `borough` | **Add a caption text box under it:** *"Borough is a complaint-mix composition effect — see Recommendations page. Not a standalone efficiency ranking."* |

Use **Format → Edit interactions** / **Sync slicers** so slicers drive all pages.

### Page 1 · Executive

**Three KPI cards** (Card visual), left to right — lead with the median:

| Card | Field | Confirm (no slicer) |
|---|---|---|
| Median resolution time | `Median Resolution Hours` | **8.1 h** |
| Substantive resolution rate | `Substantive Rate` | **29.0%** |
| % still open | `Open Rate` | **1.9%** |

Add a small caption under the median card: *"Median, not mean — distribution is extreme
right-skew (mean ≈ 298 h). Only ~29% of closes are a substantive fix."*

**Bar chart — Top 10 slowest complaint types (by median):**
- Visual: **Clustered bar chart**. Y-axis = `complaint_type`, X = `Median Resolution Hours`.
- Filter (visual-level): `Closed Count` **is ≥ 500** (suppresses noisy tiny categories).
- Filter (visual-level): **Top 10** by `Median Resolution Hours`.
- Sort descending. Add `Median Label` to **Tooltips** so cap-pinned types read
  `">290 days (long-cycle)"` on hover.
- Confirm: top item **New Tree Request** (~6961 h, the cap), then Lot Condition ~4623 h,
  Day Care ~4587 h, Mobile Food Vendor ~4484 h, Food Establishment ~3208 h.
- Caption: *"Cap-pinned types (e.g. New Tree Request) are seasonal long-cycle work, labeled
  '>290 days', not a service failure."*

### Page 2 · Resolution Deep Dive — *speed ≠ effectiveness*

**Scatter chart (the centerpiece):**
- Values: **X = `Median Resolution Hours`**, **Y = `Substantive Rate`**,
  **Size = `Closed Count`**, **Details = `complaint_type`** (swap to `agency` for the agency view).
- Filter (visual-level): `Closed Count` ≥ 500.
- Read: bottom-left = fast + shallow; top-right = slow + substantive. Confirm at the **agency**
  grain: **NYPD ≈ 1.1 h / 36.9%** (fast), **HPD ≈ 92.4 h / 28.4%**, **DEP ≈ 25.4 h / 3.6%**
  (fast but barely substantive), **DPR ≈ 597 h / 22%**.

**Distribution histogram:**
- Visual: **Column chart**. X-axis = `Resolution Bucket` (already sorted <1h → >90d),
  Y = `Closed Count`.
- Confirm shares: **<1h = 25.18%**, 1–4h 18.44%, … 30–90d 4.53%, >90d 4.08%. (A blank bucket =
  open tickets; filter it out or ignore — `Closed Count` is 0 there.)
- Caption: *"25% of closes happen in under an hour — the reason we lead with the median."*

**Top-20 table:** Table visual — `complaint_type`, `Median Label`, `Substantive Rate`,
`Closed Count`. Visual filter `Closed Count` ≥ 500; sort by `Median Resolution Hours` desc.
(`Median Label` gives the cap-aware text; don't add the raw median column next to it.)

### Page 3 · Trends — *per-type seasonality only*

**Line chart — monthly volume by complaint type:**
- Visual: **Line chart**. X-axis = `Month` (sorts Jan→Dec), **Y = `Total Count`**,
  **Legend = `complaint_type`**.
- Visual filter: limit legend to a few clear types — **Heat/Hot Water, Noise - Residential,
  Noise - Street/Sidewalk, Illegal Parking**.
- Confirm shape: Heat/Hot Water peaks **Dec/Jan**, bottoms **Aug**; Noise - Street/Sidewalk
  peaks **Jun**; Illegal Parking ~flat. (For a normalized view, swap Y to `Seasonality Index`
  — Heat Dec ≈ 285, Aug ≈ 14; baseline 100 = the type's own average month.)

> **Do NOT** add a resolution-time-over-time line (do-not-report rule #1 — it's the noisiest
> series). Trend = **volume**; resolution time stays a snapshot/distribution (Page 2).

Caption: *"Aggregate monthly volume looks flat because winter Heat and summer Noise cancel out.
Seasonality is real but lives per complaint type."*

### Page 4 · Recommendations — *borough is a composition artifact*

**Clustered bar — borough within complaint type:**
- Visual: **Clustered bar**. Y-axis = `complaint_type` (a few high-volume types: Heat/Hot Water,
  Unsanitary Condition, Illegal Parking), **Legend = `borough`** (exclude `Unspecified`),
  Value = `Median Resolution Hours`.
- Confirm the reversal: **Bronx is slowest overall (13.5 h) yet fastest for Heat/Hot Water
  (30.6 h)** vs **Manhattan Heat 42.8 h**; Unsanitary Condition slowest in Manhattan (259 h).

**Recommendation text boxes** (3–4, each backed by a number — polished versions go in the
Phase 4 `report/findings_summary.md`). Seed text, grounded in the verified numbers:
1. **Reallocate by complaint type, not borough.** Borough rankings reverse once you control for
   complaint type — chase the slow *work types* (long-cycle inspections, food/childcare permits),
   not a "slow borough."
2. **Pair speed targets with a substantive-resolution floor.** NYPD closes in ~1 h but only
   ~37% substantively; DEP ~3.6%. Fast-close SLAs without an effectiveness floor reward
   non-resolutions (~52% of closes fix nothing).
3. **Staff Heat/Hot Water for the Dec–Jan peak (index ~285 vs ~14 in Aug)** and Noise for
   summer — the per-type seasonal swings, invisible in aggregate.
4. **Treat long-cycle types (New Tree Request, ">290 days") as backlog/throughput problems,**
   not resolution-speed failures — different operational lever.

### Done criteria (Phase 3)

- [ ] `.pbix` saved to `powerbi/nyc_311_dashboard.pbix`.
- [ ] 4 pages, working/synced slicers (complaint type, agency, month, borough + caveat).
- [ ] Median-first throughout; mean only as a caveated secondary.
- [ ] Speed paired with effectiveness on the scatter + table.
- [ ] Each headline number matches the confirms above (8.1 h · 29.0% · 25.18% · NYPD 1.1h/36.9%
      · Heat Dec ~285 · Bronx-Heat reversal).
- [ ] Borough shown only as within-type comparison, never a standalone ranking.
- [ ] One dashboard screenshot exported (PNG) for the Phase 5 README.
