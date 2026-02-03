# Capstone Project Status - February 3, 2026

**Project:** "Finding Home in France" - Data-driven city selection for relocation  
**Course:** HarvardX PH125.9x Machine Learning Capstone (Choose Your Own)  
**Due Date:** June 10, 2026  
**Repository:** https://github.com/solo800/edx_cyop.git

---

## Current Phase: City Screening Analysis

We're in **Section 2** of the R script — building the city screening dataset that will determine which cities to analyze for real estate.

**Status:** `city_screening` tibble is built and verified. Composite scoring code is ready but NOT YET EXECUTED.

---

## What's Complete

### Data Acquisition ✅
All raw data downloaded and stored in `data/raw/`:

| File | Source | Rows | Description |
|------|--------|------|-------------|
| `sunshine_climate_france.csv` | Météo France via data.gouv.fr | 55 | Climate normals (likely 1991-2020) for major French cities |
| `population_age_brackets.xlsx` | INSEE 2020 census | 34,980 | Population by age bracket for all communes |
| `communes_2025.csv` | data.gouv.fr | 39,201 | Geographic reference (codes, names, coordinates) |

DVF real estate data in `local_data/`:
- `ValeursFoncieres-2020-S2.txt` through `ValeursFoncieres-2025-S1.txt` (6 files, several GB total)

### R Script Structure ✅
`cyo_script.R` has sections 0-2 built:

- **Section 0 (Lines 7-26):** Setup with `if(!require())` auto-install pattern
- **Section 1 (Lines 28-71):** Data loading functions and execution
- **Section 2 (Lines 73+):** City screening in progress

### City Screening Dataset ✅ VERIFIED
`city_screening` tibble created with **55 rows** (all French cities with climate data), containing:

```
city_name, department_code, department_name, region_name,
pop_total, pct_age_25_54, sunshine_hours_annual,
avg_temp_jan, avg_temp_jul, rainfall_mm_annual
```

**Verified output - Top 10 by sunshine:**

| Rank | City | Sunshine (hrs) | % Age 25-54 | Department |
|------|------|----------------|-------------|------------|
| 1 | Toulon | 2,899 | 34.9% | 83 - Var |
| 2 | Marseille | 2,858 | 37.8% | 13 - Bouches-du-Rhône |
| 3 | Aix-en-Provence | 2,801 | 37.8% | 13 - Bouches-du-Rhône |
| 4 | Ajaccio | 2,726 | 38.5% | 2A - Corse-du-Sud |
| 5 | Nice | 2,724 | 36.4% | 06 - Alpes-Maritimes |
| 6 | Antibes | 2,724 | 36.4% | 06 - Alpes-Maritimes |
| 7 | Cannes | 2,724 | 36.4% | 06 - Alpes-Maritimes |
| 8 | Montpellier | 2,668 | 36.6% | 34 - Hérault |
| 9 | Nîmes | 2,668 | 35.3% | 30 - Gard |
| 10 | Béziers | 2,600 | 36.6% | 34 - Hérault |

---

## What's In Progress

### Section 2.6: Composite Scoring
Code written but **NOT YET EXECUTED**:

```r
## 2.6 Calculate Composite Score ----

city_screening <- city_screening |>
  mutate(
    # Normalize sunshine (higher = better)
    sunshine_norm = (sunshine_hours_annual - min(sunshine_hours_annual, na.rm = TRUE)) /
      (max(sunshine_hours_annual, na.rm = TRUE) - min(sunshine_hours_annual, na.rm = TRUE)),
    
    # Normalize age demographic (higher % working age = better)
    age_norm = (pct_age_25_54 - min(pct_age_25_54, na.rm = TRUE)) /
      (max(pct_age_25_54, na.rm = TRUE) - min(pct_age_25_54, na.rm = TRUE)),
    
    # Normalize rainfall (lower = better, so invert)
    rainfall_norm = 1 - (rainfall_mm_annual - min(rainfall_mm_annual, na.rm = TRUE)) /
      (max(rainfall_mm_annual, na.rm = TRUE) - min(rainfall_mm_annual, na.rm = TRUE)),
    
    # Composite score (equal weights)
    composite_score = (sunshine_norm + age_norm + rainfall_norm) / 3
  ) |>
  arrange(desc(composite_score))
```

**Next command to run:**
```r
city_screening |>
  select(city_name, sunshine_norm, age_norm, rainfall_norm, composite_score) |>
  head(10)
```

---

## What's Not Started

### Remaining Section 2 Tasks
- [ ] Execute composite scoring code (Section 2.6)
- [ ] Generate 4 visualizations for report Section 3.2
- [ ] Export `city_screening.csv` to `data/`
- [ ] Update `TARGET_DEPARTMENTS` based on composite scores

### Section 3: DVF Data Processing
- [ ] Filter DVF to target departments
- [ ] Filter to houses only (`Type local == "Maison"`)
- [ ] Calculate price per m²
- [ ] Exploratory analysis of filtered data

### Section 4: Modeling
- [ ] Train/test split (temporal or random — still TBD)
- [ ] Linear regression baseline
- [ ] Random Forest or XGBoost
- [ ] K-means clustering for city similarity

### Section 5-6: Results & Report
- [ ] Model comparison metrics
- [ ] Final visualizations
- [ ] Write report narrative in `cyo_report.Rmd`
- [ ] Knit to PDF

---

## Key Technical Decisions Made

### Department Code Normalization
Different datasets use different formats:
- climate: "06", "13" (with leading zeros)
- communes: "6", "13" (no leading zeros)  
- pop_age: "D6", "D13" (with "D" prefix)

**Solution:** `str_remove()` to normalize before joins

### Age Bracket Approximation
- **Target:** 30-49 year olds (families)
- **Available:** 25-39 and 40-54 brackets
- **Decision:** Use combined 25-54 as proxy, document in report

### Composite Scoring Method (Proposed)
Equal-weighted average of three normalized (0-1) criteria:
- Sunshine hours (higher = better)
- % age 25-54 (higher = better)
- Rainfall (lower = better, inverted)

**Note:** This equal weighting may need revisiting — sunshine is the primary motivation for the move.

---

## Open Questions

1. **Sunshine data years:** Likely Météo France 1991-2020 normals, but should verify from source
2. **Time window for DVF:** Use all 5 years (2020-2024) or focus on recent?
3. **Train/test split:** Temporal (train on older, test on newer) or random?
4. **Corsica:** Ajaccio ranks high — include despite being an island?
5. **Composite weighting:** Should sunshine be weighted more heavily than demographics/rainfall?

---

## File Locations

```
cyo_edx/
├── cyo_script.R          # Main analysis script (working here)
├── cyo_report.Rmd        # Report template (sections stubbed)
├── data/
│   ├── raw/
│   │   ├── communes_2025.csv
│   │   ├── population_age_brackets.xlsx
│   │   └── sunshine_climate_france.csv
│   └── city_screening.csv   # TO BE CREATED
├── local_data/
│   └── ValeursFoncieres-*.txt  # DVF files (not in git)
└── scripts/
    └── download_dvf.py
```

---

## To Resume

1. Open RStudio project `cyo_edx.Rproj`
2. Source `cyo_script.R` up through Section 2.5 to rebuild `city_screening`
3. Run Section 2.6 composite scoring code above
4. Check top 10 cities by composite score
5. Decide on final target departments
6. Continue with visualizations or proceed to DVF filtering

---

## Session Notes

**Feb 2-3, 2026:** Built city_screening dataset by joining climate (55 cities), communes (department/region lookup), and population demographics (aggregated to department level). Verified 55 rows with all expected columns. Mediterranean cities dominate sunshine rankings as expected. Composite scoring code prepared but not executed — user indicated they may take a different direction with next session.

---

*Status saved: February 3, 2026*