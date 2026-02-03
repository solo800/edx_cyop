# Capstone Project Status - February 3, 2026 (Updated)

**Project:** "Finding Home in France" - Data-driven city selection for relocation  
**Course:** HarvardX PH125.9x Machine Learning Capstone (Choose Your Own)  
**Due Date:** June 10, 2026  
**Repository:** https://github.com/solo800/edx_cyop.git

---

## Current Phase: City Screening Analysis — Economic Data Integrated

We're in **Section 2** of the R script — building the multi-criteria city screening dataset. Economic indicators have been added and normalized.

**Status:** `city_screening` tibble now contains climate, demographics, AND economic data with normalized scores.

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

DVF real estate data in `local_data/`:
- `ValeursFoncieres-2020-S2.txt` through `ValeursFoncieres-2025-S1.txt` (6 files, several GB total)

### City Screening Dataset ✅ COMPLETE
`city_screening` tibble contains **55 rows** with the following columns:
```
city_name, department_code, department_name, region_name,
pop_total, pct_age_25_54, sunshine_hours_annual, avg_temp_jan, avg_temp_jul, rainfall_mm_annual,
sunshine_norm, age_norm, rainfall_norm, composite_score,
median_income, affluent_income, poverty_rate, affluent_norm, poverty_norm
```

### Normalized Variables (0-1 scale) ✅
| Variable | Raw Source | Direction |
|----------|------------|-----------|
| `sunshine_norm` | sunshine_hours_annual | Higher = better |
| `age_norm` | pct_age_25_54 | Higher = better |
| `rainfall_norm` | rainfall_mm_annual | Lower = better (inverted) |
| `affluent_norm` | affluent_income (Q320) | Higher = better |
| `poverty_norm` | poverty_rate (TP6020) | Lower = better (inverted) |

**Note:** `composite_score` exists but uses old equal-weight formula with only sunshine/age/rainfall. Needs recalculation once all criteria and weights are finalized.

---

## Key Findings: Target City Comparison

| City | Sunshine | Sunshine Norm | Affluent Income | Affluent Norm | Poverty Rate | Poverty Norm |
|------|----------|---------------|-----------------|---------------|--------------|--------------|
| Marseille | 2,858 hrs | 0.92 | €30,250 | 0.26 | 17.9% | 0.68 |
| Montpellier | 2,668 hrs | 0.80 | €28,500 | 0.17 | 18.7% | 0.65 |
| Toulouse | 2,047 hrs | 0.42 | €31,680 | 0.33 | 13.3% | 0.85 |
| Bordeaux | 2,035 hrs | 0.41 | €30,400 | 0.27 | 12.4% | 0.89 |

**Interpretation:**
- **Toulouse & Bordeaux:** Best for wife's business (lower poverty, more affluent customers), but less sunshine
- **Marseille:** Most sunshine, but higher poverty rate could mean smaller premium wellness customer base
- **Montpellier:** Weakest economically of the four

---

## Personal Context for Criteria Weighting

**Situation:**
- Remote work income → local wages don't affect household directly
- Buying a house with garden → want reasonable housing prices
- Wife plans to open pilates/yoga studio and coaching practice → needs affluent neighbors with disposable income

**Implication:** Looking for places where:
- People have money (high `affluent_income` / Q320)
- But housing hasn't gone crazy (will assess via DVF data later)
- Low poverty indicates solid customer base for premium services

---

## R Script Structure (Updated)

`scripts/cyo_script.R` sections:

- **Section 0 (Lines 7-26):** Setup with `if(!require())` auto-install pattern
- **Section 1 (Lines 28-88):** Data loading — includes Filosofi economic data (1.5)
- **Section 2 (Lines 90-206+):** City screening
  - 2.1: Target departments (TODO)
  - 2.2: Climate screening
  - 2.3: Department/region lookup
  - 2.4: Population aggregation by age
  - 2.5: Create city_screening dataset
  - 2.6: Normalize climate/demographic variables
  - 2.7: Add economic indicators + normalize them
- **Sections 3-6:** Stubbed for DVF processing, modeling, results

---

## What's In Progress

### Political Data (Not Yet Started)
User wants to add political affiliation/extremism metrics to avoid areas with conflicting values.

**Suggested approach:**
- French presidential or legislative election results (2022)
- Calculate % vote for far-right (RN) and/or far-left (LFI) as extremism proxy
- Source: data.gouv.fr (Ministère de l'Intérieur election results by department)

Search terms for data:
- `France election 2022 results department data.gouv.fr`
- `résultats élections présidentielles 2022 département`

---

## What's Not Started

### Composite Scoring
- [ ] Decide on final criteria weights (sunshine is primary motivation)
- [ ] Recalculate composite score with all 5+ normalized variables
- [ ] Generate ranked city list

### Section 3: DVF Data Processing
- [ ] Filter DVF to target departments
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
2. **Political data:** Which election (presidential vs. legislative)? Which threshold for "extreme"?
3. **Corsica:** Ajaccio ranks high on sunshine — include despite being an island?
4. **Time window for DVF:** Use all 5 years (2020-2024) or focus on recent?
5. **Train/test split:** Temporal (train on older, test on newer) or random?

---

## File Locations
```
cyo_edx/
├── scripts/
│   └── cyo_script.R          # Main analysis script (current work)
├── reports/
│   └── cyo_report.Rmd        # Report template (sections stubbed)
├── data/
│   └── raw/
│       ├── communes_2025.csv
│       ├── population_age_brackets.xlsx
│       ├── sunshine_climate_france.csv
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
2. Source `scripts/cyo_script.R` through Section 2.7 to rebuild `city_screening` with all variables
3. Verify with: `names(city_screening)` — should show 19 columns including economic metrics
4. Next steps:
   - Search for political/election data
   - OR proceed to composite scoring with current 5 criteria
   - OR proceed to DVF processing

---

## Session Notes

**Feb 3, 2026 (Session 2):**
- Integrated INSEE Filosofi 2020 economic data (income + poverty)
- Added to script: Section 1.5 (data loading) and Section 2.7 (join + normalize)
- Key columns added: `median_income`, `affluent_income` (75th percentile), `poverty_rate`, `affluent_norm`, `poverty_norm`
- Discovered tension in criteria: sunshine-optimized cities (Marseille, Montpellier) have higher poverty; economically stronger cities (Toulouse, Bordeaux) have less sunshine
- User's dual needs identified: remote income (local wages irrelevant) + wife's pilates business (needs affluent customers)
- Political data identified as next data source to integrate

**Feb 2-3, 2026 (Session 1):**
- Built city_screening dataset by joining climate (55 cities), communes (department/region lookup), and population demographics (aggregated to department level)
- Verified 55 rows with all expected columns
- Mediterranean cities dominate sunshine rankings as expected
- Initial normalization of sunshine, age, rainfall completed

---

*Status saved: February 3, 2026*