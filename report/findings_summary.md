# NYC 311 Service Requests (2024) — Findings & Recommendations

**Business question:** *Which complaint types and boroughs had the slowest resolution times in
2024, and how should the city reallocate response resources?*

## The finding → the recommendation

> **The trend:** NYC closes 311 complaints *fast* — half within ~8 hours, a quarter within the
> hour — but fast isn't the same as fixed. Only **29%** of closed complaints were actually fixed;
> **over half (~54%)** closed with no fix at all (nothing found, no access, or passed to another
> office).
>
> **The recommendation:** judge agencies on **how often they actually fix the problem**, not how fast
> they close the ticket — starting with the fast-but-rarely-fixing ones (**DEP closes in ~25 h but
> fixes only 3.6%**).
>
> *(It also corrects the brief's borough angle: no borough is really "slowest" — rankings flip once
> you compare the same complaint type — so the lever is complaint type, not geography.)*

Everything below is the evidence and operational detail behind that one line.

> Scope: 3,455,782 cleaned tickets created in calendar 2024 (98.1% closed; 1.9% still open).
> Methodology, cleaning judgments, and known limitations live in
> [`analysis_decisions.md`](analysis_decisions.md) — not restated here.

---

## How to read the resolution-time numbers

Two framing rules drive every finding (full reasoning in `analysis_decisions.md`):

1. **Lead with the median.** Resolution time is extreme right-skewed — the **median is 8.1 h**
   but the mean is ≈ 298 h, dragged up by a long tail of multi-month tickets. The median is the
   honest "typical" number; the mean is reported only with that caveat.
2. **Fast ≠ fixed.** Closing a ticket quickly isn't the same as solving the problem. 25% of
   complaints close in **under an hour**, but only **29%** were actually fixed (a repair,
   inspection, or enforcement action). So every speed number is shown next to **how often the
   problem actually got fixed**.

**Where closed tickets actually land** (share of all closed):

| Outcome | Share | Substantive? |
|---|--:|:--:|
| No issue found | 31.3% | — |
| **Action / Enforcement** | **29.0%** | Yes |
| Other (agency-specific tail) | 17.4% | — |
| Gone / No access | 12.8% | — |
| Referred / Info only | 9.5% | — |

**More than half (≈ 54%) of closed tickets close without fixing anything** — no issue found,
gone on arrival, or referred elsewhere. That single fact reframes the whole question.

---

## Recommendations

### 1. Target slow *work types*, not "slow boroughs"

The question's premise — that some borough is slow — doesn't survive the data. The Bronx looks
slowest **overall** (median 13.5 h), yet it is the **fastest** borough for Heat/Hot Water
(30.6 h vs Manhattan's 42.8 h). Borough "slowness" is a **composition effect**: it reflects the
*mix* of complaints a borough generates, not how efficiently it works. The genuine slow signal
is complaint type:

| Slowest complaint types (median) | |
|---|--:|
| New Tree Request | **> 290 days** (long-cycle — see Rec 4) |
| Lot Condition | 4,623 h (≈ 193 days) |
| Day Care | 4,587 h |
| Mobile Food Vendor | 4,484 h |
| Food Establishment | 3,208 h |

These are inspection/permit/long-cycle pipelines (DOB, DOHMH, Parks) — **not** a geography.

> **Action:** Allocate response capacity to the slow complaint-type pipelines, not to a borough.
> A "speed up the Bronx" directive would chase statistical noise; "speed up Lot Condition and
> food/childcare inspections" targets the real bottleneck.

### 2. Don't reward fast closes alone — also track how often the problem actually got fixed

Speed measured alone actively misleads. The agency view is the clearest evidence:

| Agency | Median | Substantive | Closed volume | Reads as |
|---|--:|--:|--:|---|
| **NYPD** | ~1.1 h | 36.9% | ~1.55 M | fast, moderate, enormous volume |
| **DEP** | ~25 h | **3.6%** | ~189 K | fast-ish, but almost never a real fix |
| HPD | ~92 h | 28.4% | ~730 K | slower, substantive, high volume |
| DOB | ~368 h | 13.4% | ~103 K | slow **and** low-substantive |
| **DOE** | ~596 h | **84.4%** | ~14 K | slow, but almost always a substantive action |

A fast-close SLA with no effectiveness floor rewards exactly the wrong behaviour — closing the
ticket without solving the problem (the ~54% non-fix population above).

> **Action:** Put the **substantive-resolution rate next to median time** on every operational
> scorecard. Investigate DEP's 3.6% first (fast closes, almost no recorded fix). Don't "fix"
> DOE's slow median — its 84% substantive rate shows the time buys real outcomes.
>
> *Caveat — investigate, don't indict:* the substantive rate is parsed from agency free-text with
> a ~17% unclassified tail, so treat it as a **diagnostic flag**, not proof of failure.

---

## Supporting operational levers

Lower-stakes than the decision above, but worth acting on once the measurement change is in place.

### 3. Staff seasonally, by complaint type — not on the aggregate line

Aggregate monthly volume looks **flat**, which is a trap: it hides large, *predictable* per-type
swings that cancel each other out. Heat/Hot Water runs **~63 K complaints in December vs ~3 K in
August** (seasonality index 285 vs 14). Street noise is the mirror image, peaking in **June
(~25 K)**. Planning headcount on the flat aggregate systematically under-staffs winter heat and
summer noise.

> **Action:** Shift HPD heat-inspection capacity into **Nov–Feb** and noise enforcement into
> **summer**. The swings are seasonal and forecastable a year out.

### 4. Manage long-cycle and backlog work separately — they aren't speed problems

Two groups should not be judged on resolution speed at all:

- **Long-cycle work.** New Tree Request pins to the 290-day cap because it's seasonal Parks
  planting on an annual cycle — *not* a failure (its 0% "substantive" is a classifier gap, not
  inaction). Speed SLAs are meaningless here.
- **Backlog builders.** Some types barely close: **Homeless Person Assistance is 69.6% open
  (27,553 unresolved tickets)** and **Construction Lead Dust is 100% open**. A
  resolution-time metric never sees these — it only measures tickets that *did* close.

> **Action:** Run long-cycle types on a scheduling/throughput basis, and treat high-open-rate
> types (esp. **Homeless Person Assistance**) as a **backlog to drain** — a capacity problem,
> not a "respond faster" problem.

---

## What this means for the original question

| The question assumed… | The data shows… |
|---|---|
| A borough is slowest → reallocate there | Borough ranking is a composition artifact; it reverses within complaint type |
| Resolution *time* is the KPI | Time without an effectiveness pairing is misleading — ~54% of closes fix nothing |
| One reallocation answer | **Two primary levers** — an effectiveness floor + allocate by *work type* — with seasonal staffing and backlog drainage as supporting plays |

The most defensible reallocation is **by complaint type and agency effectiveness**, with borough
used only as a within-type drill-down.

## Limitations (summary)

- Resolution time is capped at the 99th percentile (≈ 290 days) in cleaning; the analysis leads
  with the median, so the cap barely affects headline numbers.
- `resolution_category` has a ~17% "Other" tail; substantive rates are cited *of classified
  tickets* and effectiveness claims are avoided on Other-heavy types (e.g. Street Condition).
- Full reasoning, cleaning decisions, and do-not-report rules: [`analysis_decisions.md`](analysis_decisions.md).

*All figures verified against the cleaned dataset and reproduced in both the SQL layer (`/sql`)
and the Power BI model (`/powerbi`).*
