# Analysis Decisions & Methodology Log — NYC 311 (2024)

This document records the problems hit while building the project, how each was investigated,
and the decision made — with the actual numbers behind it. It's the "why" behind
`notebooks/01_cleaning_eda.ipynb` and the analysis framing, written so the reasoning (not just
the result) is on the record.

Each entry follows: **Problem → What the data showed → Decision → Why.**

---

## 1. Environment & committed-artifact decisions

### 1.1 Dependencies weren't actually installed
- **Problem:** The project docs claimed pandas/numpy/Jupyter were available; neither the global
  Python nor the `.venv` had them (`ModuleNotFoundError: pandas`).
- **Decision:** Installed pinned versions into `.venv` (pandas 1.5.3, numpy 1.26.4, pyarrow,
  `notebook`), added `requirements.txt`, and registered a Jupyter kernel `nyc311`.
- **Why:** Reproducibility — anyone cloning the repo can recreate the exact environment, and the
  notebook can be executed headlessly.

### 1.2 The cleaned dataset is too big to commit as CSV
- **Problem:** The cleaned full-year CSV is **~961 MB–1 GB**. GitHub hard-rejects any file
  >100 MB, so "commit the cleaned CSV" (as originally specced) is physically impossible.
- **What the data showed (measured, all 3.46M rows):**

  | Format | Size | Fits 100 MB? |
  |---|--:|:--:|
  | CSV | 961 MB | ❌ |
  | CSV gzipped | 157 MB | ❌ |
  | Parquet (snappy) | 101 MB | ❌ |
  | **Parquet (zstd)** | **~79 MB** | ✅ |

- **Decision:** Commit **`data/311_cleaned_2024.parquet`** (zstd, all columns) as the source of
  truth; keep the full CSV local and gitignored (`.gitignore` ignores all `*.csv`). The notebook
  writes both.
- **Why:** Parquet's columnar + dictionary compression crushes the highly repetitive agency
  response text with **no loss of rows or columns**, and both Power BI and pandas read it
  natively. A row sample or Git LFS were considered and rejected (sample loses data; LFS burns
  the ~1 GB free quota).

---

## 2. Reading the raw data

- **Problem:** Raw file is ~2.05 GB, 3,456,770 rows, 44 columns — naive `read_csv` is slow and
  memory-heavy.
- **Decision:** Read only the 10 analysis columns (`usecols`), parse the two timestamps at read
  time, set low-cardinality strings to `category`, and read `incident_zip` as string.
- **Why:** Cuts the load to ~46 s and keeps memory reasonable. Reading `incident_zip` as string
  avoids re-introducing the float artifact described in §3.6.

---

## 3. Cleaning decisions

### 3.1 Date parsing & scope check
- **Decision:** Parse `created_date`/`closed_date` to datetime; assert every `created_date` is in
  2024.
- **What the data showed:** `created_date` 2024-01-01 → 2024-12-31 (clean). `closed_date` spans
  2023-02-22 → 2026-06-19 — i.e. some closes precede creation (errors, §3.3) and some run well
  past year-end (extreme outliers, §3.4).

### 3.2 Null close dates ≠ "status = Open"
- **Problem:** The plan assumed open tickets are `status = 'Open'`. The data is messier.
- **What the data showed:** **64,549** tickets (1.87%) have a null `closed_date`, spread across
  *many* statuses — and **27,573 are marked `Closed` with no close timestamp**; only 5,211 are
  literally `Open`.
- **Decision:** Define "unresolved" by the **null close date itself, not the status string.** Keep
  these rows for volume counts but exclude them from resolution-time stats (they carry `NaN`).
- **Why:** Keying on `status='Open'` would have mislabeled ~59k tickets. Dropping them would
  understate complaint volume.

### 3.3 Negative resolution times
- **What the data showed:** **988** tickets closed *before* they were created.
- **Decision:** Drop the rows (3,456,770 → 3,455,782) and flag the count.
- **Why:** Physically impossible = data-entry error, and there's no defensible way to repair the
  true value.

### 3.4 Extreme outlier cap
- **What the data showed:** Max resolution time ≈ **886 days**; 99th percentile ≈ **6,961 h
  (290 days)**; **33,913** rows above it.
- **Decision:** Winsorize (clip) at the 99th percentile rather than drop. Kept the cap loose and
  lean on the **median** at the analysis layer (see §5.1).
- **Why:** Clipping keeps the rows counting toward volume and their borough/complaint type while
  stopping a handful of multi-year tickets from dominating means. Dropping would lose real volume.

### 3.5 Standardising `borough` and `complaint_type`
- **What the data showed:** `borough` is ALL-CAPS (`BROOKLYN`, `STATEN ISLAND`) + `Unspecified`.
  `complaint_type` has **197** distinct values mixing cases (`HEAT/HOT WATER` vs `Illegal
  Parking`).
- **Decision:** Title-case both. Borough → 6 clean values (unknowns kept as `Unspecified`, not
  dropped). Complaint type → **195** (only pure casing-duplicates collapsed).
- **Why — the key judgment:** We deliberately **did not over-merge** complaint types. The
  `Noise - Residential / Commercial / Street/Sidewalk / Vehicle` split is a real operational
  distinction (different agencies, different fixes), so collapsing them to "Noise" would destroy
  signal.

### 3.6 `incident_zip` float artifact
- **Problem:** ZIPs arrive as `11226.0` (the original download read them as floats).
- **Decision:** Strip the trailing `.0`, keep as string; blanks stay null.
- **Why:** A ZIP is an identifier, not a number. NYC ZIPs have no leading zeros, so nothing is lost.

---

## 4. The investigations that shaped the analysis

These went beyond mechanical cleaning and are the real analytical contribution.

### 4.1 Are the sub-1-hour "instant closes" real resolutions?
- **Trigger:** 25% of closed tickets close in **under 1 hour** — suspiciously fast. Are they fixes
  or non-resolutions?
- **What the data showed:** The sub-1h population is **87.6% NYPD** (noise/parking/vehicle). Read
  from `resolution_description`:
  - ~38% genuine fixes ("took action to fix" / "issued a summons")
  - ~33% **clearly nothing fixed** ("no evidence of the violation", "gone on arrival", duplicate,
    wrong jurisdiction)
  - ~18% "no action necessary" dispositions
- **Decision:** Treat **speed and effectiveness as separate things.** Derive a
  `resolution_category` column (§4.2) instead of trusting resolution time alone.
- **Why:** Left unflagged, NYPD-heavy complaint types look hyper-efficient (~0 h), which would
  drive a *wrong* "reallocate away from NYPD" recommendation. ~8–13% of *all* closed tickets are
  fast non-resolutions.

### 4.2 Building `resolution_category` — and fixing the first attempt
- **First attempt (rejected):** Regex tuned on the NYPD sub-1h text. Result: **46% of closed
  tickets fell into `Other`**, and the substantive rate was NYPD-biased and *wrong* — Heat/Hot
  Water showed **0–1.6% substantive**, which is false (HPD inspects and issues violations
  constantly; it just uses different wording that landed in `Other`).
- **Investigation:** Dumped the dominant `resolution_description` templates across *all* closed
  tickets (not just sub-1h) — found large HPD ("No violations were issued" 190k; "Violations were
  issued" 125k), DSNY ("cleaned the location", "found no condition"), DOT ("repaired the
  problem"), DEP, and Parks templates the first rules missed.
- **Decision:** Rebuilt the classifier on **strong outcome verbs**, with **rule ordering** so
  "**no** violation" is matched *before* "violation issued". Final 5-class scheme:

  | Category | Substantive? | Share of all rows |
  |---|:--:|--:|
  | No issue found | — | 30.7% |
  | Action/Enforcement | ✅ | 28.5% |
  | Other (long tail) | — | 17.1% |
  | Gone/No access | — | 12.5% |
  | Referred/Info | — | 9.3% |
  | Open/Unresolved | — | 1.9% |

- **Result:** `Other` dropped **46% → 17%**, and substantive rates became credible (Heat/Hot Water
  **25.9%**, Unsanitary **31.6%**, Plumbing **26.1%**).
- **Honest limitation:** ~17% stays `Other` (a genuinely diverse agency-specific tail). Report the
  substantive rate "of classified tickets" where it matters, and don't over-claim precision on
  `Other`-heavy categories like Street Condition (41% Other).
- **Headline it produced:** only **~29% of closed tickets are substantive**; **~52% are closed
  without fixing anything** (no issue found / gone / referred).

### 4.3 Signal vs noise — will the dashboard show trends or randomness?
- **Trigger:** Would the planned visuals show interpretable patterns, or mostly noise?
- **What the data showed (diagnostic):**
  - **Borough is mostly a composition artifact.** Median-by-borough rankings *reverse* once you
    control for complaint type: Bronx is **slowest overall (13.5 h)** but **fastest for Heat/Hot
    Water (30.6 h)**. Borough looks slow only because of its complaint *mix*, not its efficiency.
  - **Complaint type is strong, clean signal:** median 0 h (Rodent) → 6,961 h (New Tree Request).
  - **Seasonality is strong *per type*, flat in aggregate:** Heat/Hot Water volume index swings
    **14 (Aug) → 285 (Dec)**; Noise-Residential peaks in summer; Illegal Parking is flat. Aggregate
    monthly volume looks flat only because winter and summer peaks cancel out.
  - **Monthly resolution-time trend is the noisiest series** — weak, avoid leading with it.
- **Decision:** Lead with **complaint type + agency**; treat **borough as a secondary, caveated
  slicer** (show borough-within-type so the composition effect is visible). Make trend visuals
  **per complaint type**.
- **Why:** The literal "which borough is slowest" framing points at the weakest dimension. The
  honest, defensible story lives in complaint type, agency, effectiveness, and per-type
  seasonality.

---

## 5. Analytical framing decisions (apply to SQL + dashboard)

1. **Median is the headline metric.** Resolution time is extreme-right-skewed (mean ≈ 298 h vs
   **median ≈ 8 h**). Report median first; mean only as secondary with the skew caveat. This also
   makes the loose p99 cap nearly irrelevant to the headline numbers.
2. **Label cap-pinned categories.** Where a category's median sits *on* the 290-day cap (e.g.
   *New Tree Request* — seasonal Parks planting), report ">290 days (long-cycle)" rather than a
   fake precise figure.
3. **Complaint type + agency primary; borough secondary & caveated** (per §4.3).
4. **Keep the cleaning cap as-is.** The p99 cap stays in the cleaned data; if a mean-based visual
   is ever needed, p95-clip *in the SQL layer only* — don't re-cap the source.
5. **Pair speed with effectiveness** — every resolution-time visual sits next to the
   substantive-resolution rate (`resolution_category == 'Action/Enforcement'`).

---

## 6. Known data quirks / limitations

- **Rodent median = 0 h** (39k tickets): DOHMH appears to close the intake instantly and track the
  inspection separately — reinforces "speed ≠ effectiveness".
- **27,573 tickets are `status = Closed` with no `closed_date`** — handled as unresolved (§3.2).
- **`resolution_category` has a ~17% `Other`** long tail — acceptable for storytelling, not a
  precise per-category effectiveness measure everywhere.
- The cap (290 days) is intentionally loose; it tames the extreme tail but isn't a "typical" value
  — which is exactly why the analysis leads with the median.

### Do-not-report rules for the dashboard/report (so an artifact never becomes a fake insight)

1. **Don't lead with a resolution-time-over-time line chart** — the monthly resolution-time trend is
   the noisiest series. Trend visuals show *volume* by complaint type; resolution time stays a
   snapshot/distribution.
2. **Don't read `0% substantive` as "fixes nothing" for Parks/long-cycle types** (e.g. *New Tree
   Request*). It's a classifier gap — Parks planting language doesn't match the enforcement regex.
   For those types the story is the *long cycle*, not effectiveness.
3. **Cite substantive % as "of classified tickets"** and avoid effectiveness headlines on
   `Other`-heavy types (e.g. Street Condition ~41% `Other`).

---

## 7. Quick-reference: cleaning outcomes

| Step | Result |
|---|---|
| Raw rows | 3,456,770 |
| Dropped (negative duration) | 988 |
| Final rows | 3,455,782 |
| Open / unresolved (kept, no resolution time) | 64,549 |
| Tickets with a resolution time | 3,391,233 |
| Outliers winsorized (≥ p99 = 6,961 h) | 33,913 |
| Boroughs after standardising | 6 |
| Complaint types after standardising | 195 (from 197) |
| Final columns | 12 (10 kept + `resolution_time_hours` + `resolution_category`) |
| Duplicate `unique_key` | 0 |
