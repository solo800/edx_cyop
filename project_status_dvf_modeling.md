# Capstone Project Status — DVF Processing & Modeling

**Project:** "Finding Home in France" - Data-driven city selection for relocation
**Course:** HarvardX PH125.9x Machine Learning Capstone (Choose Your Own)
**Due Date:** June 10, 2026
**Repository:** https://github.com/solo800/edx_cyop.git

---

## Phase Status: IN PROGRESS

DVF data processing, feature engineering, ML modeling, and results analysis. Picks up from completed region selection (see `project_status_region_selection.md`).

---

## What's Already Scaffolded in `scripts/cyo_script.R`

These functions exist in the script but most have not yet been called on real data:

| Function | Section | Description | Status |
|----------|---------|-------------|--------|
| `load_dvf_file()` | 1.4 | Reads a single pipe-delimited DVF file with French locale | ✅ Used |
| `calc_rmse()` | 4.4 | RMSE evaluation metric | Scaffolded |
| `calc_mae()` | 4.4 | MAE evaluation metric | Scaffolded |
| `calc_r2()` | 4.4 | R-squared evaluation metric | Scaffolded |
| `format_eur()` | 6 | Formats numbers as euros (`scales::dollar`) | Scaffolded |
| `summary_stats()` | 6 | Computes n, mean, median, sd, min, max, q25, q75 for a column | Scaffolded |

**Removed in Section 3 rewrite (Feb 12):** `filter_dvf()`, `parse_dvf_dates()`, `calc_price_sqm()` — replaced with inline filtering + commune-level matching logic.

---

## Section 3: DVF Data Processing — Status Tracker

| Step | Description | Status |
|------|-------------|--------|
| 3.1 | Load commune_filter_lookup.csv (159 communes, 10 depts) | ✅ Complete |
| 3.2 | Load & filter DVF files 2020-2024 (commune + Maison + Vente) | ✅ Complete — 68,006 rows |
| 3.3 | Combine years, join commune metadata (target_city, ring) | ✅ Complete |
| 3.4 | Parse dates (year, month, quarter) | ✅ Complete |
| 3.5 | Save filtered dataset (data/dvf_houses_filtered.csv) | ✅ Complete |
| 3B.1 | Deduplicate multi-parcel rows (group by mutation key, sum land area) | ✅ Complete — 68,006 → 61,133 |
| 3B.2 | Drop missing prices | ✅ Complete — 46 rows removed |
| 3B.3 | Outlier filtering (price, surface, rooms bounds) | ✅ Complete — 504 rows removed |
| 3B.4 | Feature engineering (prix_m2, has_land) + 1st/99th percentile trim | ✅ Complete — 1,210 rows removed |
| 3B.5 | Save clean dataset (data/dvf_houses_clean.csv) | ✅ Complete — 59,373 final rows |
| 3B.6 | EDA / exploratory analysis | TODO — next |

---

## Section 4: Modeling — Status Tracker

| Step | Description | Status |
|------|-------------|--------|
| 4.1 | Train/test temporal split (2020-2023 train, 2024 test) | TODO |
| 4.2 | Linear regression baseline | TODO |
| 4.3 | Random Forest or XGBoost | TODO |
| 4.4 | K-means clustering (city similarity) | TODO |
| 4.5 | Cross-validation strategy | TODO |
| 4.6 | Model comparison & evaluation | TODO |

---

## Section 5: Results — Status Tracker

| Step | Description | Status |
|------|-------------|--------|
| 5.1 | EDA visualizations | TODO |
| 5.2 | Model performance comparison | TODO |
| 5.3 | City rankings / recommendations | TODO |

---

## DVF Data Reference

### Source Files

6 files in `local_data/`:

| File | Period |
|------|--------|
| `ValeursFoncieres-2020-S2.txt` | 2020 second semester |
| `ValeursFoncieres-2021.txt` | Full year 2021 |
| `ValeursFoncieres-2022.txt` | Full year 2022 |
| `ValeursFoncieres-2023.txt` | Full year 2023 |
| `ValeursFoncieres-2024.txt` | Full year 2024 |
| `ValeursFoncieres-2025-S1.txt` | 2025 first semester |

**Format:** Pipe-delimited (`|`), comma decimal marks (e.g., `10000,00`), no quoting.

### DVF Columns (43 total)

Key columns for this project are **bolded**:

| # | Column | Notes |
|---|--------|-------|
| 1 | Identifiant de document | |
| 2 | Reference document | |
| 3-7 | 1-5 Articles CGI | Tax code references |
| 8 | No disposition | |
| 9 | **Date mutation** | Transaction date (dd/mm/yyyy) |
| 10 | **Nature mutation** | Filter to `"Vente"` |
| 11 | **Valeur fonciere** | Sale price (comma decimal) |
| 12 | No voie | Street number |
| 13 | B/T/Q | |
| 14 | Type de voie | |
| 15 | Code voie | |
| 16 | Voie | Street name |
| 17 | **Code postal** | Postal code |
| 18 | **Commune** | City name |
| 19 | **Code departement** | Filter to TARGET_DEPTS |
| 20 | **Code commune** | INSEE commune code |
| 21 | Prefixe de section | |
| 22 | Section | Cadastral section |
| 23 | No plan | Cadastral plan number |
| 24 | No Volume | |
| 25-34 | 1er-5eme lot + Surface Carrez | Lot numbers and Carrez surfaces |
| 35 | Nombre de lots | Number of lots |
| 36 | Code type local | |
| 37 | **Type local** | Filter to `"Maison"` |
| 38 | Identifiant local | |
| 39 | **Surface reelle bati** | Built surface area (m²) |
| 40 | **Nombre pieces principales** | Number of main rooms |
| 41 | Nature culture | Land use type |
| 42 | Nature culture speciale | |
| 43 | **Surface terrain** | Land area (m²) |

---

## Key Decisions to Track

*Record decisions made during DVF processing and modeling here.*

| Decision | Choice | Rationale | Date |
|----------|--------|-----------|------|
| Commune filtering | Commune + adjacency ring (Option D) | City-proper alone left Paris (136), Lyon (171), Annecy (176) unusable. Adjacency ring using IGN boundary polygons adds immediate suburbs, bringing totals to ~58,500 est. 5-year samples | Feb 12, 2026 |
| Leading zeros in commune codes | Strip from lookup to match DVF format | DVF uses "63" not "063" — join failures discovered and fixed | Feb 12, 2026 |
| Paris extra departments | Include depts 92, 93, 94 | Paris petite couronne suburbs span 3 departments outside original 7. National DVF files already contain these — no extra downloads needed | Feb 12, 2026 |
| DVF loading approach | Process files one at a time, filter immediately | Files are 500-600MB each; loading all at once would exhaust memory. Filter to target communes inline then bind_rows | Feb 12, 2026 |
| DVF years used | 2020-S2 through 2024 (exclude 2025-S1) | Project scope is 2020-2024; 2020 only has second semester data | Feb 12, 2026 |
| Dedup strategy | Group by mutation key, max(surface/rooms), sum(land area) | Multi-parcel = same house on different cadastral parcels; land should be summed, built area is identical across rows | Feb 12, 2026 |
| Outlier bounds | Price €10K-5M, built 20-1000m², rooms 1-20, prix_m² 1st-99th pctile | Conservative bounds for houses in major French metros; percentile trim catches remaining data quality issues | Feb 12, 2026 |

---

## Session Notes

*Session-by-session progress tracking.*

### February 12, 2026 — Commune Adjacency Analysis

**Goal:** Expand DVF filtering from city-proper to include adjacent suburban communes.

**Approach:**
- Downloaded IGN commune boundary polygons (communes-50m.geojson)
- Used sf package: st_union() for arrondissement cities, st_touches() for adjacency
- Created data/commune_filter_lookup.csv: 159 communes, ring 0 (city) + ring 1 (adjacent)

**Key results (2024 house transactions):**

| City | Ring 0 | Ring 1 | Total | Est. 5-Year |
|------|--------|--------|-------|-------------|
| Bordeaux | 961 | 1,987 | 2,948 | ~14,700 |
| Toulouse | 1,101 | 1,241 | 2,342 | ~11,700 |
| Marseille | 1,426 | 767 | 2,193 | ~11,000 |
| Paris | 136 | 1,216 | 1,352 | ~6,800 |
| Montpellier | 461 | 812 | 1,273 | ~6,400 |
| Lyon | 171 | 921 | 1,092 | ~5,500 |
| Annecy | 176 | 312 | 488 | ~2,400 |
| **Total** | **4,432** | **7,256** | **11,688** | **~58,500** |

**Issues found & resolved:**
- DVF commune codes have no leading zeros; lookup CSV updated to match
- Paris adjacent communes span depts 92/93/94 — confirmed present in existing DVF national files
- Annecy's 2017 commune merger means ring 0 already includes former suburbs (70 km²)

**Files produced:**
- `data/commune_filter_lookup.csv` — the DVF filter lookup (159 rows)
- `data/raw/communes_geo_target_depts.gpkg` — filtered spatial data
- `scripts/commune_adjacency.R` — preprocessing script (run once)

### February 12, 2026 — DVF Loading & Filtering

**Goal:** Load all DVF files (2020-2024) and filter to target communes using commune_filter_lookup.csv.

**Approach:**
- Rewrote Section 3 of cyo_script.R — replaced department-level skeleton with commune-level filtering
- Each file loaded individually via `load_dvf_file()`, filtered to target dept + Maison + Vente, then matched by constructed INSEE code
- Joined commune metadata (target_city, ring, commune_name), parsed dates
- Saved result to `data/dvf_houses_filtered.csv`

**Actual results (68,006 total house sales):**

| City | Transactions | % of Total |
|------|-------------|------------|
| Bordeaux | 18,158 | 26.7% |
| Toulouse | 13,343 | 19.6% |
| Marseille | 12,479 | 18.4% |
| Paris | 7,708 | 11.3% |
| Montpellier | 7,173 | 10.5% |
| Lyon | 6,566 | 9.7% |
| Annecy | 2,579 | 3.8% |

| Year | Transactions | Note |
|------|-------------|------|
| 2020 | 8,983 | S2 only |
| 2021 | 17,777 | Post-COVID peak |
| 2022 | 16,766 | |
| 2023 | 12,792 | Market cooling |
| 2024 | 11,688 | |

| Ring | Transactions |
|------|-------------|
| 0 (city proper) | 26,073 (38%) |
| 1 (adjacent) | 41,933 (62%) |

**Notes:**
- 68,006 actual vs ~58,500 estimated — estimate was based on 2024 × 5, but earlier years had higher volume
- Minor parsing warnings on all files (typical for DVF) — no impact on filtered data
- 5 parsing warnings (one per file) — likely malformed rows in the raw national data, negligible

**Files produced:**
- `data/dvf_houses_filtered.csv` — 68,006 filtered house sales with commune metadata and parsed dates

### February 12, 2026 — Data Cleaning

**Goal:** Deduplicate, remove bad data, engineer price/m², produce modeling-ready dataset.

**Pipeline (68,006 → 59,373 = 12.7% removed):**

| Step | Rows After | Removed |
|------|-----------|---------|
| Start (raw filtered) | 68,006 | — |
| Dedup multi-parcel | 61,133 | 6,873 |
| Drop NA prices | 61,087 | 46 |
| Outlier bounds | 60,583 | 504 |
| Prix/m² 1-99% trim | 59,373 | 1,210 |

**Outlier bounds used:** Price €10K-5M, built area 20-1000m², rooms 1-20, prix/m² 1st-99th percentile (€1,111-19,579/m²)

**Clean data median price/m² by city:**

| City | n | Median Price | Median €/m² | Median m² |
|------|---|-------------|-------------|-----------|
| Paris | 6,518 | €732,050 | €8,265 | 90 |
| Annecy | 2,259 | €604,500 | €5,512 | 110 |
| Lyon | 5,057 | €590,000 | €5,494 | 107 |
| Marseille | 10,878 | €400,000 | €4,628 | 89 |
| Bordeaux | 16,397 | €417,142 | €4,521 | 94 |
| Montpellier | 6,194 | €410,000 | €4,116 | 100 |
| Toulouse | 12,070 | €350,000 | €3,492 | 98 |

**Files produced:**
- `data/dvf_houses_clean.csv` — 59,373 clean house sales, modeling-ready

---

*This document tracks DVF processing and modeling progress. Update as project evolves.*
