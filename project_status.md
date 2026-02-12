# Capstone Project State — French Real Estate Analysis

**Last Updated:** February 12, 2026
**Current Phase:** EDA & Modeling Prep (Section 4)

---

## Project Overview

**Goal:** Build a multi-criteria decision support system to identify the best French city for relocation, combining personal needs (sunny climate, house with garden, political alignment, positive demographics) with machine learning analysis of real estate markets.

**Academic Purpose:** edX Machine Learning Capstone "Choose Your Own" project (50 points possible, due June 10, 2026)

---

## Key Decisions Made

### Target Cities (Final Selection — Feb 9, 2026)
- **Toulouse** (dept 31) — #1 composite rank, best balance of climate + politics
- **Marseille** (dept 13) — #2 ranked, sunniest major city in France
- **Lyon** (dept 69) — #4 ranked, strong politics + affluence
- **Annecy** (dept 74) — #8 ranked, affluent Alpine market (small sample expected)
- **Montpellier** (dept 34) — #9 ranked, Mediterranean sunshine + university city
- **Bordeaux** (dept 33) — #12 ranked, TGV to Paris, post-boom market dynamics
- **Paris** (dept 75) — Benchmark only (international mega-city comparison)

**Rejected:** Perpignan (demographic concerns), Corsica (island logistics), Toulon (far-right score too low)

**Selection method:** Weighted composite scoring across 6 normalized criteria (political alignment, sunshine, rainfall, affluence, age demographics, poverty). See `project_status_region_selection.md` for full methodology and iteration history.

**DVF & Modeling:** See `project_status_dvf_modeling.md` for granular tracking of DVF data processing, feature engineering, ML modeling, and results (Sections 3-5).

### Dataset Choice
**Primary:** DVF (Demandes de Valeurs Foncières) from data.gouv.fr
- Government notary records of all French property transactions
- Coverage: 2020-2024 (5 years downloaded)
- Size: Several GB total, ~3-5M transactions/year
- **Decision:** Filter to 7 target departments + depts 92/93/94 (Paris suburbs), houses only, using commune + adjacency ring filtering (see commune_v_department_filtering.md)

**Why DVF:**
- Not a well-known/overused dataset ✔
- Rich features for multiple ML approaches ✔
- Publicly available, can be auto-downloaded ✔
- Personal relevance creates strong narrative ✔

### Modeling Plan (Satisfies 2+ Algorithms Requirement)
1. **Baseline:** Linear regression (price prediction)
2. **Advanced:** Random Forest or XGBoost (price prediction)
3. **Additional:** K-means clustering (city similarity analysis)

### Key Resolved Questions
- **Time window:** All 5 years (2020-2024), include year as feature
- **Train/test split:** Temporal — train on 2020-2023, test on 2024 (real estate is path-dependent)
- **Corsica:** Eliminated despite high sunshine — island logistics impractical
- **Composite weights:** far_right=1.0, sunshine=0.75, rainfall=0.75, affluent=0.75, age=0.5, poverty=0.25

---

## Progress Status

### ✅ Completed
- [x] Project repository created: https://github.com/solo800/edx_cyop.git
- [x] Project structure established (`data/`, `scripts/`, `reports/`, `local_data/`)
- [x] DVF data downloaded (2020-2024, stored in `local_data/`)
- [x] Supporting data acquired (climate, demographics, economics, election results)
- [x] City screening dataset built (55 cities × 23 columns)
- [x] All 6 screening criteria normalized (sunshine, age, rainfall, affluence, poverty, far-right)
- [x] Composite scoring finalized after 5 weighting iterations
- [x] Target departments selected: 13, 31, 33, 34, 69, 74, 75
- [x] Script Sections 0-2 complete and verified
- [x] Commune adjacency analysis complete — 159 communes across 7 city groups
- [x] Commune filter lookup table saved: data/commune_filter_lookup.csv
- [x] Sample sizes validated: ~58,500 estimated training samples (5-year total)
- [x] Paris suburb departments (92, 93, 94) confirmed present in existing DVF files
- [x] DVF files loaded and filtered to target communes — 68,006 house sales (2020-2024)
- [x] Commune metadata joined (target_city, ring, commune_name) and dates parsed
- [x] Filtered dataset saved: data/dvf_houses_filtered.csv
- [x] Script Section 3 complete and verified
- [x] Data cleaning complete: dedup, NA removal, outlier filtering, prix/m² trimming (68,006 → 59,373 rows, 12.7% removed)
- [x] Clean dataset saved: data/dvf_houses_clean.csv
- [x] Script Section 3B complete and verified

### 🔄 Next Up
- [ ] Exploratory data analysis (distributions, city comparisons, temporal trends)
- [ ] Train/test temporal split (2020-2023 train, 2024 test)
- [ ] Model building & comparison (linear regression, Random Forest/XGBoost, K-means)

### ⏳ Not Started
- [ ] Results analysis and visualization
- [ ] Report writing (PDF + Rmd)
- [ ] R script finalization and commenting pass

---

## Data Sources & Documentation

### Primary Data
- **DVF Transactions:** https://www.data.gouv.fr/datasets/demandes-de-valeurs-foncieres
- **Downloaded:** 2020-2024 (5 years of transaction data)

### Supporting Data (All Acquired)
- **Climate:** Météo France 30-year normals (sunshine, temperature, rainfall)
- **Demographics:** INSEE RP 2020 population by age brackets
- **Economics:** INSEE Filosofi 2020 (income distribution, poverty rates)
- **Politics:** 2022 presidential election 1st round results by department
- **Geography:** communes_2025.csv (administrative boundaries, codes)

### Key References
- DVF Analysis Example: https://mincong.io/2021/04/16/dvf-real-estate-analysis-idf-2020/
- Sunniest French Cities: https://goodfrance.com/cities-towns-villages/what-are-20-sunniest-cities-france/

---

## Processed Data Files

### city_screening.csv
**Location:** `data/city_screening.csv`  
**Description:** Pre-joined dataset of 55 French cities with climate, demographics, economic, and political indicators. All screening variables normalized to 0-1 scale.

**Columns (23):** city_name, department_code, department_name, region_name, pop_total, pct_age_25_54, sunshine_hours_annual, avg_temp_jan, avg_temp_jul, rainfall_mm_annual, sunshine_norm, age_norm, rainfall_norm, composite_score, median_income, affluent_income, poverty_rate, affluent_norm, poverty_norm, pct_le_pen, pct_zemmour, pct_far_right, far_right_norm

**Load in new session:**
```r
city_screening <- read_csv("data/city_screening.csv")
```

**To regenerate:** Source `scripts/cyo_script.R` Sections 0-2, then `write_csv(city_screening, "data/city_screening.csv")`

---

## Personal Context (For Report Introduction)

**Current Situation:** Living in Paris with wife and young child, planning relocation

**Requirements:**
- House with garden (outdoor space for family)
- Sunnier climate than Paris (~1,660 hrs/year)
- Political environment aligned with family values
- City with positive demographics (not aging/shrinking)
- Good amenities (major metro areas)
- Wife plans to open pilates/yoga studio — benefits from affluent population but confident in creating premium product

**Why This Matters:** Combines academic ML project with real-life major decision — creates authentic motivation and compelling narrative for report.

---

## Rubric Alignment Checklist

### Files (5 pts)
- [ ] PDF report (knit from Rmd)
- [ ] Rmd file
- [ ] R script with all code

### Report (25 pts)
Must include:
- [ ] Introduction/overview
- [ ] Methods/analysis (2+ algorithms, one advanced)
- [ ] Results & model performance
- [ ] Conclusion (summary, impact, limitations, future work)
- [ ] References

### Code (20 pts)
Requirements:
- [x] Runs without errors (Sections 0-3B verified)
- [x] Well-commented
- [x] Relative file paths (not absolute) — uses `here::here()`
- [x] Auto-install missing packages (`if(!require)`)
- [ ] Dataset auto-downloadable OR in GitHub repo

---

## Quick City Comparison Reference

| City | Sunshine hrs/yr | Composite Score | Dept Code | Role |
|------|----------------|----------------|-----------|------|
| Toulouse | 2,031 | 0.585 | 31 | #1 target |
| Marseille | 2,858 | 0.566 | 13 | #2 target |
| Lyon | 1,926 | 0.542 | 69 | #4 target |
| Annecy | 1,951 | 0.517 | 74 | #8 target |
| Montpellier | 2,668 | 0.502 | 34 | #9 target |
| Bordeaux | 2,035 | 0.470 | 33 | #12 target |
| Paris | 1,660 | N/A | 75 | Benchmark |

---

## ML Considerations for Target Selection

- **Transaction volume imbalance:** Bordeaux (~14,700) and Toulouse (~11,700) will have far more transactions than Annecy (~2,400) — consider city as a feature and monitor per-city model performance
- **Geographic diversity:** Mediterranean, Atlantic, Alpine, and inland markets prevent overfitting to one local pattern
- **Temporal split:** Training 2020-2023, testing 2024 — valid across all departments
- **Bordeaux dynamics:** Post-TGV boom (2017) means 2020-2024 captures plateau/correction phase
- **Annecy:** Premium lake/mountain market with likely high price variance and fewer transactions
- **Commune adjacency ring:** Ring 0/1 indicator available as a feature — suburban vs city-proper may affect prices differently
- **Paris suburbs:** Petite couronne (depts 92/93/94) included via adjacency — 90% of Paris-area house transactions are in ring 1

---

*This document tracks decisions and progress. Update as project evolves.*