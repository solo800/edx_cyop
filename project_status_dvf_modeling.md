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
| `calc_rmse()` | 4.3 | RMSE evaluation metric | ✅ Used |
| `calc_mae()` | 4.3 | MAE evaluation metric | ✅ Used |
| `calc_r2()` | 4.3 | R-squared evaluation metric | ✅ Used |
| `evaluate_model()` | 4.3 | Evaluates predictions: overall + per-city breakdown | ✅ Used |
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
| 3B.7 | Join Filosofi 2020 commune-level income data | ✅ Complete — 100% coverage (59,373/59,373 matched) |
| 3C.1 | Overall dataset summary (key variable stats) | ✅ Complete |
| 3C.2 | Price distribution by city (density plot, log scale) | ✅ Complete |
| 3C.3 | Price per m² by city (box plot) | ✅ Complete |
| 3C.4 | Temporal trends — median price/m² by year (line chart) | ✅ Complete |
| 3C.5 | Transaction volume over time (grouped bar chart) | ✅ Complete |
| 3C.6 | Built surface distribution by city (faceted histogram) | ✅ Complete |
| 3C.7 | Ring effect — city center vs suburbs (faceted box plot) | ✅ Complete |
| 3C.8 | Room count distribution (faceted bar chart) | ✅ Complete |
| 3C.9 | Price vs surface scatter (sampled, colored by city) | ✅ Complete |
| 3C.10 | Feature correlations (numeric correlation matrix) | ✅ Complete |
| 3C.11 | Quarterly trend / seasonality (dual-axis volume + price) | ✅ Complete |
| 3C.12 | EDA summary (key findings) | ✅ Complete |

---

## Section 4: Modeling — Status Tracker

| Step | Description | Status |
|------|-------------|--------|
| 4.1 | Train/test temporal split (2020-2023 train, 2024 test) | ✅ Complete — 49,269 train / 10,104 test (83/17%) |
| 4.2 | Feature preparation (clean names, type casting, model matrix) | ✅ Complete — 9 features + 1 target (added median_income) |
| 4.3 | Evaluation metrics + `evaluate_model()` helper | ✅ Complete |
| 4.4 | Linear regression with interaction terms | ✅ Complete — R²=0.596 |
| 4.5 | Random Forest (500 trees) | ✅ Complete — R²=0.676 |
| 4.6 | XGBoost (early stopping at 115 rounds) | ✅ Complete — R²=0.679 |
| 4.7 | K-means clustering (commune-level, k=4, 6 features) | ✅ Complete — 4 market tiers across ~100+ communes |

---

## Section 5: Results — Status Tracker

| Step | Description | Status |
|------|-------------|--------|
| 5.1 | EDA visualizations | ✅ Complete (Section 3C) |
| 5.2 | Model performance comparison | TODO |
| 5.3 | City rankings / recommendations | TODO |

---

## Infrastructure Improvements

| Change | Description | Date |
|--------|-------------|------|
| Quick-start cache | Section 3 wrapped in `if/else`: loads `dvf_houses_clean.csv` directly if it exists, skipping DVF file processing (3.1-3B.7). Save moved to after income join (3B.8) so cached file is complete. | Feb 16, 2026 |
| `cluster` package | Added `if(!require(cluster))` to Section 0 for silhouette analysis in K-means | Feb 16, 2026 |

---

## Modeling Results

### Train/Test Split

| Set | Years | Rows | % |
|-----|-------|------|---|
| Train | 2020-2023 | 49,269 | 83% |
| Test | 2024 | 10,104 | 17% |

Split is even across cities (each city has 16-19% of its data in test).

### Features Used

| Feature | Clean Name | Type | Notes |
|---------|-----------|------|-------|
| Surface reelle bati | `surface` | numeric | Built area (m²) — **#1 predictor across all models** |
| Nombre pieces principales | `rooms` | numeric | Number of main rooms |
| Surface terrain | `land` | numeric | Land area (m²), 0 where no land |
| target_city | `target_city` | factor (7) | City group — **#2 predictor** |
| ring | `ring` | integer 0/1 | City proper vs adjacent suburb — **#3 predictor** |
| year | `year` | numeric | Transaction year (2020-2024) |
| quarter | `quarter` | integer 1-4 | Seasonality |
| has_land | `has_land` | integer 0/1 | Whether property has land |
| median_income_commune | `median_income` | numeric | Filosofi 2020 commune-level median disposable income — **#2 predictor in XGBoost (19.2% gain), #4 in RF** |

**Target variable:** `price` (Valeur fonciere, sale price in euros)

**Excluded from features:** `prix_m2` (derived from price/surface — would leak the target)

**Data source for median_income:** INSEE Filosofi 2020 commune-level (`base-cc-filosofi-2020-geo2023.xlsx`, sheet "COM", column MED20). Downloaded from https://www.insee.fr/fr/statistiques/fichier/6692392/base-cc-filosofi-2020_XLSX.zip. 100% join coverage — all 59,373 transactions matched to commune income data.

### Overall Model Comparison (Test Set)

| Model | RMSE | MAE | R² | Notes |
|-------|------|-----|-----|-------|
| Linear Regression | €250,599 | €166,492 | 0.596 | Interaction terms: `target_city * (surface + ring) + median_income` |
| Random Forest | €224,212 | €140,149 | 0.676 | 500 trees, mtry=3, OOB R²=0.714 |
| **XGBoost** | **€223,268** | **€138,184** | **0.679** | **Best model. 115 rounds (early stopped from 1000), depth=6, eta=0.1** |

**Improvement over baseline:** XGBoost reduces RMSE by 10.9% and MAE by 17.0% vs linear regression.

**Impact of adding median_income feature (before → after):**

| Model | R² (before) | R² (after) | Δ R² | RMSE (before) | RMSE (after) | Δ RMSE |
|-------|-------------|------------|------|---------------|--------------|--------|
| Linear Regression | 0.554 | 0.596 | +0.042 | €263,169 | €250,599 | -4.8% |
| Random Forest | 0.597 | 0.676 | +0.079 | €250,315 | €224,212 | -10.4% |
| XGBoost | 0.599 | 0.679 | +0.080 | €249,607 | €223,268 | -10.6% |

The commune-level income feature was a major breakthrough — tree models gained ~8 R² points, nearly doubling the improvement gap over linear regression.

### Per-City Breakdown (Test Set)

#### Linear Regression

| City | n | RMSE | MAE | R² |
|------|---|------|-----|----|
| Toulouse | 2,132 | €186,009 | €132,102 | 0.304 |
| Montpellier | 1,060 | €193,961 | €128,399 | 0.439 |
| Bordeaux | 2,646 | €189,719 | €138,578 | 0.494 |
| Marseille | 1,897 | €251,519 | €159,418 | 0.484 |
| Lyon | 839 | €324,743 | €225,699 | 0.506 |
| Annecy | 419 | €311,367 | €211,559 | 0.488 |
| Paris | 1,111 | €398,625 | €285,680 | 0.652 |

#### Random Forest

| City | n | RMSE | MAE | R² |
|------|---|------|-----|----|
| Toulouse | 2,132 | €166,082 | €108,842 | 0.445 |
| Montpellier | 1,060 | €169,632 | €110,908 | 0.571 |
| Bordeaux | 2,646 | €169,729 | €115,187 | 0.595 |
| Marseille | 1,897 | €220,902 | €132,029 | 0.602 |
| Lyon | 839 | €311,343 | €201,584 | 0.546 |
| Annecy | 419 | €289,692 | €193,472 | 0.557 |
| Paris | 1,111 | €346,440 | €234,935 | 0.737 |

#### XGBoost

| City | n | RMSE | MAE | R² |
|------|---|------|-----|----|
| Toulouse | 2,132 | €168,679 | €112,038 | 0.428 |
| Montpellier | 1,060 | €170,601 | €108,153 | 0.566 |
| Bordeaux | 2,646 | €166,000 | €112,698 | 0.613 |
| Marseille | 1,897 | €216,471 | €128,000 | 0.618 |
| Lyon | 839 | €315,368 | €200,998 | 0.534 |
| Annecy | 419 | €284,364 | €185,329 | 0.573 |
| Paris | 1,111 | €346,027 | €229,884 | 0.737 |

### Key Findings from Modeling

**Performance patterns:**
1. Tree models explain ~68% of price variance — a strong result for house price prediction with 9 features
2. Tree models (RF, XGBoost) substantially outperform linear regression (~11% RMSE reduction, ~8 R² points)
3. RF and XGBoost perform nearly identically (R²=0.676 vs 0.679) — further algorithmic gains are limited
4. Adding commune-level income data was a breakthrough: +8 R² points for tree models, +4 for linear

**Per-city insights:**
5. **Paris is most predictable** (R²=0.737 in RF/XGBoost) — income variation across Paris communes provides strong signal
6. **Toulouse is hardest to predict** (R²~0.30-0.45) despite having the most training data — its market is heterogeneous
7. **Marseille improved the most** from income data (R²=0.430→0.618 in XGBoost) — large income variation across communes
8. **Annecy** (smallest sample, n=419 test) performs mid-pack (R²=0.573) — sample imbalance is NOT the main issue

**Feature importance (consistent across RF and XGBoost):**
1. **Surface area** — dominant predictor (~36.5% of XGBoost gain, highest %IncMSE in RF)
2. **Median income** — #2 in XGBoost (19.2% gain), #4 in RF (%IncMSE=76.5) — the key new feature
3. **City (target_city)** — #2 in RF (%IncMSE=128.5), Paris dummy alone is 13.7% of XGBoost gain
4. **Rooms** — 12.2% of XGBoost gain
5. **Land area** — 8.0% of XGBoost gain, #3 in RF (%IncMSE=92.4)
6. **Ring** (center vs suburb) — 4.8% of XGBoost gain
7. **Year** and **quarter** — weak temporal signal (prices relatively stable in this 5-year window)

**Interpretation for relocation decision:**
- The models confirm large price differences across cities: Toulouse ~€3,500/m² vs Paris ~€13,000/m² in city center
- Ring 0 (city proper) commands a premium in most cities, especially Paris (€13,040 vs €7,995/m²)
- Montpellier is the exception: suburbs slightly more expensive (€4,198 vs €3,962/m²), possibly driven by desirable coastal communes
- Commune-level income is a powerful proxy for neighborhood quality — it captures the "desirability" that surface area alone cannot

**Limitations (for report):**
- R² of ~0.68 means 32% of price variance is unexplained
- Missing features that matter: house condition/age, proximity to transit, school quality, garden size, DPE rating
- DVF does not include property condition, renovation status, or energy performance rating (DPE)
- 2020 only has S2 data, so seasonal patterns in that year are incomplete
- Filosofi income data is from 2020 (single year, applied to all transaction years)

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
| City sample imbalance | Interaction terms (linear) + per-city evaluation (all models) | Bordeaux ~14K train rows vs Annecy ~1.8K. Pooled model would learn slopes dominated by large cities. Linear regression uses `target_city * Surface reelle bati` interactions so each city gets its own coefficients. Tree models (RF/XGBoost) handle this naturally via splits. All models report per-city RMSE/MAE alongside overall metrics. | Feb 12, 2026 |
| Filosofi commune income | Add MED20 (median income) as feature | Commune-level median disposable income from INSEE Filosofi 2020 provides neighborhood economic context. 100% join coverage on CODGEO. Improved tree model R² by ~8 points (0.599→0.679). Poverty rate (TP6020) also available but not used (highly correlated with MED20). | Feb 12, 2026 |

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

### February 12, 2026 — EDA, Train/Test Split & First Three Models

**Goal:** Complete EDA, build train/test split, and run linear regression, Random Forest, and XGBoost.

**Completed:**
- Section 3C: 12 EDA subsections (distributions, trends, correlations, ring effects)
- Section 4.1: Temporal split — 49,269 train (2020-2023) / 10,104 test (2024)
- Section 4.2: Feature prep — 8 features, clean column names for package compatibility
- Section 4.3: Evaluation metrics + `evaluate_model()` helper (overall + per-city)
- Section 4.4: Linear regression with `target_city * (surface + ring)` interactions → R²=0.554
- Section 4.5: Random Forest (500 trees, mtry=2) → R²=0.597
- Section 4.6: XGBoost (early stopped at 51/1000 rounds) → R²=0.599

**Technical issues resolved:**
- `randomForest` formula interface fails on column names with spaces → renamed to clean names in 4.2
- `xgboost` 3.x renamed `watchlist` → `evals`, and `evaluation_log` accessed via `attr()` not `$`
- `rename(!!!vec)` requires `new_name = "old_name"` direction (not reverse)

**Key insight (before income feature):** Tree models only modestly outperformed linear regression (~5% RMSE gain). The performance ceiling was driven by missing features rather than model complexity.

### February 12, 2026 — Filosofi Income Feature Integration

**Goal:** Break through the feature ceiling by adding commune-level economic data.

**Approach:**
- Downloaded INSEE Filosofi 2020 commune-level data (`base-cc-filosofi-2020-geo2023.xlsx`)
- Joined MED20 (median disposable income) to DVF data via CODGEO/insee_code
- Added `median_income` as 9th feature in all three models

**Results — dramatic improvement for tree models:**

| Model | R² (before) | R² (after) | RMSE (before) | RMSE (after) |
|-------|-------------|------------|---------------|--------------|
| Linear Regression | 0.554 | 0.596 | €263,169 | €250,599 |
| Random Forest | 0.597 | 0.676 | €250,315 | €224,212 |
| XGBoost | 0.599 | 0.679 | €249,607 | €223,268 |

**Why tree models benefit more:** Tree models can use median_income to create non-linear splits (e.g., "if income > €25K AND surface > 100m², predict premium") while linear regression only gets a single additive coefficient.

**Technical issues resolved:**
- `insee_code` type mismatch (double vs character) on join → added `as.character()`
- NAs from coercion in Filosofi data (statistical secrets marked as "s") → `as.numeric()` handles gracefully
- `TARGET_DEPTS` used before definition (dangling preview lines) → removed lines 128-130

**Feature importance (XGBoost by gain):** surface (36.5%) > **median_income (19.2%)** > target_cityParis (13.7%) > rooms (12.2%) > land (8.0%) > ring (4.8%)

**Still TODO at that time:** K-means clustering (4.7), model comparison visualization, results/report

### February 16, 2026 — K-Means Clustering & Quick-Start Cache

**Goal:** Implement Section 4.7 (K-means as unsupervised complement to supervised models) and add a quick-start cache to skip slow DVF file loading on re-runs.

**K-Means Clustering (Section 4.7):**
- Aggregated 59,373 transactions to commune level: median price/m², surface, rooms, land, transaction count, income
- Filtered to communes with >= 10 transactions for stable aggregates
- Scaled 6 features with `scale()` (mean=0, sd=1)
- Tested k=2..8 via elbow (WSS) and silhouette analysis
- Silhouette-optimal k=6 produced singleton/tiny clusters; overridden to k=4 (silhouette 0.404 vs 0.414) for interpretable market tiers
- PCA biplot (PC1 vs PC2, colored by cluster, shaped by city)
- Cluster centroids table in original units
- City × cluster stacked bar chart showing market homogeneity/diversity per city

**Quick-Start Cache:**
- Wrapped Sections 3.1-3B.7 in `if (file.exists(dvf_clean_path)) / else` block
- If `data/dvf_houses_clean.csv` exists: loads in ~2 seconds instead of ~60+ seconds of DVF file processing
- Moved CSV save from 3B.6 (before income join) to 3B.8 (after income join) so cached file includes `median_income_commune`

**Still TODO:** Section 5.2 (model comparison visualization), Section 5.3 (city rankings), report writing

---

*This document tracks DVF processing and modeling progress. Update as project evolves.*
