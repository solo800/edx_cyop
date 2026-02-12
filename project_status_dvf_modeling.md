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

| Function | Line | Section | Description | Status |
|----------|------|---------|-------------|--------|
| `filter_dvf()` | 371 | 3.1 | Filters by department, property type (`Maison`), mutation nature (`Vente`) | Scaffolded |
| `parse_dvf_dates()` | 390 | 3.4 | Extracts `year`, `month`, `quarter` from `Date mutation` via `lubridate::dmy()` | Scaffolded |
| `calc_price_sqm()` | 401 | 3.4 | Computes `prix_m2 = valeur_fonciere_num / Surface reelle bati`, filters invalid | Scaffolded |
| `calc_rmse()` | 432 | 4.4 | RMSE evaluation metric | Scaffolded |
| `calc_mae()` | 436 | 4.4 | MAE evaluation metric | Scaffolded |
| `calc_r2()` | 440 | 4.4 | R-squared evaluation metric | Scaffolded |
| `format_eur()` | 462 | 6 | Formats numbers as euros (`scales::dollar`) | Scaffolded |
| `summary_stats()` | 467 | 6 | Computes n, mean, median, sd, min, max, q25, q75 for a column | Scaffolded |

---

## Section 3: DVF Data Processing — Status Tracker

| Step | Description | Status |
|------|-------------|--------|
| 3.1 | Filter DVF to target depts (13, 31, 33, 34, 69, 74, 75) + houses + sales | Scaffolded |
| 3.2 | Handle missing values | TODO |
| 3.3 | Outlier treatment | TODO |
| 3.4 | Feature engineering (dates, price/m²) | Partially scaffolded |
| 3.5 | Merge supplementary data (communes, population, climate) | TODO |
| 3.6 | EDA / exploratory analysis | TODO |

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
| | | | |

---

## Session Notes

*Session-by-session progress tracking.*

---

*This document tracks DVF processing and modeling progress. Update as project evolves.*
