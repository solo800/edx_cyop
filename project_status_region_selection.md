# Capstone Project Status - February 5, 2026 (Updated)

**Project:** "Finding Home in France" - Data-driven city selection for relocation  
**Course:** HarvardX PH125.9x Machine Learning Capstone (Choose Your Own)  
**Due Date:** June 10, 2026  
**Repository:** https://github.com/solo800/edx_cyop.git

---

## Current Phase: City Screening Analysis — Political Data Integrated

We're in **Section 2** of the R script — building the multi-criteria city screening dataset. All screening criteria (climate, demographics, economics, politics) are now loaded and normalized.

**Status:** `city_screening` tibble contains **55 rows × 23 columns** with all normalized criteria ready for composite scoring.

---

## What's Complete

### Data Acquisition ✅
All raw data downloaded and stored in `data/raw/`:

| File | Source | Description |
|------|--------|-------------|
| `sunshine_climate_france.csv` | Météo France | Climate normals for 55 major French cities |
| `population_age_brackets.xlsx` | INSEE 2020 census | Population by age bracket for all communes |
| `communes_2025.csv` | data.gouv.fr | Geographic reference (codes, names, coordinates) |
| `filosofi_2020/FILO2020_DISP_DEP.csv` | INSEE Filosofi 2020 | Department-level income data |
| `filosofi_2020/FILO2020_DISP_PAUVRES_DEP.csv` | INSEE Filosofi 2020 | Department-level poverty rates |
| `presidentielle_2022_tour1_departements.xlsx` | Ministère de l'Intérieur | 2022 presidential election 1st round by department |

DVF real estate data in `local_data/`:
- `ValeursFoncieres-2020-S2.txt` through `ValeursFoncieres-2025-S1.txt` (6 files, several GB total)

### City Screening Dataset ✅ COMPLETE
`city_screening` tibble contains **55 rows × 23 columns**:
```
city_name, department_code, department_name, region_name,
pop_total, pct_age_25_54, sunshine_hours_annual, avg_temp_jan, avg_temp_jul, rainfall_mm_annual,
sunshine_norm, age_norm, rainfall_norm, composite_score,
median_income, affluent_income, poverty_rate, affluent_norm, poverty_norm,
pct_le_pen, pct_zemmour, pct_far_right, far_right_norm
```

### Normalized Variables (0-1 scale) ✅
| Variable | Raw Source | Direction |
|----------|------------|-----------|
| `sunshine_norm` | sunshine_hours_annual | Higher = better |
| `age_norm` | pct_age_25_54 | Higher = better |
| `rainfall_norm` | rainfall_mm_annual | Lower = better (inverted) |
| `affluent_norm` | affluent_income (Q320) | Higher = better |
| `poverty_norm` | poverty_rate (TP6020) | Lower = better (inverted) |
| `far_right_norm` | pct_far_right (Le Pen + Zemmour) | Lower = better (inverted) |

**Note:** `composite_score` exists but uses old equal-weight formula with only sunshine/age/rainfall. Needs recalculation with all 6 criteria and final weights.

---

## Key Findings: Target City Comparison

| City | Sunshine Norm | Affluent Norm | Poverty Norm | Far-Right Norm |
|------|---------------|---------------|--------------|----------------|
| Marseille | 0.97 | 0.26 | 0.68 | 0.23 |
| Montpellier | 0.84 | 0.17 | 0.65 | 0.29 |
| Toulouse | 0.39 | 0.33 | 0.85 | 0.62 |
| Bordeaux | 0.39 | 0.27 | 0.89 | 0.53 |

**Key Tradeoff Identified:**
- **Mediterranean cities (Marseille, Montpellier):** Best sunshine, but higher far-right vote share and higher poverty
- **Southwest cities (Toulouse, Bordeaux):** Less sunshine, but more politically aligned and stronger economically

---

## Personal Context for Criteria Weighting

**Situation:**
- Remote work income → local wages don't affect household directly
- Buying a house with garden → want reasonable housing prices
- Wife plans to open pilates/yoga studio and coaching practice → needs affluent neighbors with disposable income
- Family values alignment matters → prefer areas with lower far-right voting patterns

**Implication:** Need weighted scoring that balances primary motivation (sunshine) against secondary factors (economics, politics).

---

## R Script Structure (Updated)

`scripts/cyo_script.R` sections:

- **Section 0 (Lines 7-26):** Setup with `if(!require())` auto-install pattern
- **Section 1 (Lines 28-117):** Data loading
  - 1.1-1.4: Communes, population, climate, DVF file paths
  - 1.5: Filosofi economic data
  - 1.6: Presidential election data (auto-download + load)
- **Section 2 (Lines 119-280+):** City screening
  - 2.1: Target departments (TODO)
  - 2.2: Climate screening
  - 2.3: Department/region lookup
  - 2.4: Population aggregation by age
  - 2.5: Create city_screening dataset
  - 2.6: Normalize climate/demographic variables
  - 2.7: Add economic indicators + normalize
  - 2.8: Add political indicators + normalize ✅
- **Sections 3-6:** Stubbed for DVF processing, modeling, results

---

## What's In Progress

### Composite Scoring (Section 2.9 — Next Up)
- [ ] Decide on final criteria weights
- [ ] Recalculate composite score with all 6 normalized variables
- [ ] Generate ranked city list
- [ ] Validate that target cities still make sense

**Proposed weighting discussion:**
- Sunshine is primary motivation — should be weighted highest (40-60%)
- Politics and economics are secondary but meaningful
- Age demographics and rainfall are tertiary

---

## What's Not Started

### Section 3: DVF Data Processing
- [ ] Filter DVF to target departments (13, 31, 33, 34)
- [ ] Filter to houses only (`Type local == "Maison"`)
- [ ] Calculate median house price by department
- [ ] Create affordability ratio: `Median House Price / affluent_income`
- [ ] Exploratory analysis of filtered data

### Section 4: Modeling
- [ ] Train/test split (temporal or random — still TBD)
- [ ] Linear regression baseline
- [ ] Random Forest or XGBoost
- [ ] K-means clustering for city similarity

### Section 5-6: Results & Report
- [ ] Model comparison metrics
- [ ] Final visualizations
- [ ] Write report narrative in `reports/cyo_report.Rmd`
- [ ] Knit to PDF

---

## Open Questions

1. **Weighting scheme:** How to weight sunshine vs. economic factors vs. political factors?
2. **Corsica:** Ajaccio ranks high on sunshine — include despite being an island?
3. **Time window for DVF:** Use all 5 years (2020-2024) or focus on recent?
4. **Train/test split:** Temporal (train on older, test on newer) or random?

---

## File Locations
```
cyo_edx/
├── scripts/
│   └── cyo_script.R          # Main analysis script (current work)
├── reports/
│   └── cyo_report.Rmd        # Report template (sections stubbed)
├── data/
│   ├── city_screening.csv    # Saved screening dataset (23 columns)
│   └── raw/
│       ├── communes_2025.csv
│       ├── population_age_brackets.xlsx
│       ├── sunshine_climate_france.csv
│       ├── presidentielle_2022_tour1_departements.xlsx
│       └── filosofi_2020/
│           ├── FILO2020_DISP_DEP.csv
│           ├── FILO2020_DISP_PAUVRES_DEP.csv
│           └── [other Filosofi files]
├── local_data/
│   └── ValeursFoncieres-*.txt  # DVF files (not in git)
├── project_status.md
└── project_status_region_selection.md
```

---

## To Resume

1. Open RStudio project `cyo_edx.Rproj`
2. Either:
   - **Quick start:** `city_screening <- read_csv("data/city_screening.csv")` to load saved data
   - **Full rebuild:** Source `scripts/cyo_script.R` through Section 2.8 to regenerate from raw data
3. Verify with: `ncol(city_screening)` — should show 23 columns
4. Next step: Composite scoring (Section 2.9)

---

## Session Notes

**Feb 5, 2026 (Session 3):**
- Integrated presidential election data (2022 first round by department)
- Fixed Section 2.8.1 join: uses `department_code` not `code_departement`
- Added columns: `pct_le_pen`, `pct_zemmour`, `pct_far_right`, `far_right_norm`
- Saved updated `city_screening` to `data/city_screening.csv` (23 columns)
- Key tradeoff identified: Mediterranean = sun + politics risk; Southwest = less sun + better alignment
- Ready for composite scoring

**Feb 3, 2026 (Session 2):**
- Integrated INSEE Filosofi 2020 economic data (income + poverty)
- Added to script: Section 1.5 (data loading) and Section 2.7 (join + normalize)
- Key columns added: `median_income`, `affluent_income` (75th percentile), `poverty_rate`, `affluent_norm`, `poverty_norm`
- Discovered tension in criteria: sunshine-optimized cities (Marseille, Montpellier) have higher poverty; economically stronger cities (Toulouse, Bordeaux) have less sunshine
- User's dual needs identified: remote income (local wages irrelevant) + wife's pilates business (needs affluent customers)

**Feb 2-3, 2026 (Session 1):**
- Built city_screening dataset by joining climate (55 cities), communes (department/region lookup), and population demographics (aggregated to department level)
- Verified 55 rows with all expected columns
- Mediterranean cities dominate sunshine rankings as expected
- Initial normalization of sunshine, age, rainfall completed

---

*Status saved: February 5, 2026*