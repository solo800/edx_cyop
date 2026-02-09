# Capstone Project Status — Region Selection (COMPLETE)

**Project:** "Finding Home in France" - Data-driven city selection for relocation  
**Course:** HarvardX PH125.9x Machine Learning Capstone (Choose Your Own)  
**Due Date:** June 10, 2026  
**Repository:** https://github.com/solo800/edx_cyop.git

---

## Phase Status: COMPLETE ✅

City screening and composite scoring are finished. Target departments selected for DVF analysis.

---

## Final Target Departments

| Dept | City | Composite Score | Role |
|------|------|----------------|------|
| 31 | Toulouse | 0.585 | #1 ranked — best balance of climate + politics |
| 13 | Marseille | 0.566 | #2 ranked — strongest sunshine, weaker politics |
| 69 | Lyon | 0.542 | #4 ranked — strong politics + affluence, less sun |
| 74 | Annecy | 0.517 | #8 ranked — affluent Alpine market, small sample expected |
| 34 | Montpellier | 0.502 | #9 ranked — Mediterranean sunshine + university city |
| 33 | Bordeaux | 0.470 | #12 ranked — TGV to Paris, post-boom market dynamics |
| 75 | Paris | N/A (excluded from ranking) | Benchmark — international mega-city comparison |

**Exclusions applied:** Île-de-France (departing region) and Corsica (island logistics impractical) filtered from ranking. Paris included separately as benchmark only.

---

## Final Composite Scoring Formula

```r
weights <- c(
  far_right = 1.00,   # Primary: political alignment (family values)
  sunshine  = 0.75,   # Secondary: climate — main motivation for leaving Paris
  rainfall  = 0.75,   # Secondary: dry climate (low correlation with sunshine, r = -0.16)
  affluent  = 0.75,   # Secondary: affluent population (wife's business potential)
  age       = 0.50,   # Tertiary: working-age demographics
  poverty   = 0.25    # Minimal: poverty rate
)
# Total weight: 4.00

composite_score = (
  far_right_norm * 1.00 +
  sunshine_norm  * 0.75 +
  rainfall_norm  * 0.75 +
  affluent_norm  * 0.75 +
  age_norm       * 0.50 +
  poverty_norm   * 0.25
) / 4.00
```

### Weighting Evolution (5 iterations)

| Iteration | Key Change | Result |
|-----------|-----------|--------|
| 1 | sunshine=1.0, affluent=1.0, age=0.75 | Paris #1 — too affluence-heavy |
| 2 | Lowered affluent to 0.5, raised rainfall to 0.75 | Mediterranean cities rose |
| 3 | Lowered age to 0.25, poverty to 0.25 | Sunshine-first: Marseille #1 |
| 4 | Lowered affluent to 0.25, raised age to 0.5 | Climate-dominant ranking |
| 5 (final) | Raised far_right to 1.0, affluent to 0.75 | Toulouse #1 — balanced result |

**Key insight:** Weighting dramatically affects rankings. The final scheme reflects family discussions prioritizing political alignment alongside climate, with affluence restored after wife's confidence in creating a premium product regardless of local wealth levels.

---

## Data Acquisition — Complete ✅

| File | Source | Description |
|------|--------|-------------|
| `sunshine_climate_france.csv` | Météo France | Climate normals for 55 major French cities |
| `population_age_brackets.xlsx` | INSEE 2020 census | Population by age bracket for all communes |
| `communes_2025.csv` | data.gouv.fr | Geographic reference (codes, names, coordinates) |
| `filosofi_2020/FILO2020_DISP_DEP.csv` | INSEE Filosofi 2020 | Department-level income data |
| `filosofi_2020/FILO2020_DISP_PAUVRES_DEP.csv` | INSEE Filosofi 2020 | Department-level poverty rates |
| `presidentielle_2022_tour1_departements.xlsx` | Ministère de l'Intérieur | 2022 presidential election 1st round |

DVF real estate data in `local_data/`:
- `ValeursFoncieres-2020-S2.txt` through `ValeursFoncieres-2025-S1.txt` (6 files)

---

## City Screening Dataset

`city_screening` tibble: **55 rows × 23 columns**

### Normalized Variables (0-1 scale)

| Variable | Raw Source | Direction |
|----------|------------|-----------|
| `sunshine_norm` | sunshine_hours_annual | Higher = better |
| `age_norm` | pct_age_25_54 | Higher = better |
| `rainfall_norm` | rainfall_mm_annual | Lower = better (inverted) |
| `affluent_norm` | affluent_income (Q320) | Higher = better |
| `poverty_norm` | poverty_rate (TP6020) | Lower = better (inverted) |
| `far_right_norm` | pct_far_right (Le Pen + Zemmour) | Lower = better (inverted) |

---

## Key Tradeoffs Identified

- **Mediterranean cities (Marseille, Montpellier):** Best sunshine but higher far-right vote share and higher poverty
- **Southwest cities (Toulouse, Bordeaux):** Less sunshine but more politically aligned and stronger economically
- **Alpine (Annecy):** Affluent, moderate politics, but less sunshine and high rainfall — small house market expected
- **Lyon:** Strong all-rounder but mid-tier on sunshine
- **Sunshine vs. rainfall:** Only r = -0.16 correlation — they measure different climate dimensions

---

## Qualitative Factors Considered (Not Modeled)

These were discussed but deliberately kept as qualitative assessment rather than adding analytical complexity for marginal benefit:

- **International airports:** All target cities have major airports except Annecy (relies on Geneva ~45min)
- **Mountain access:** Annecy (Alps), Toulouse (Pyrenees ~1hr) benefit; others neutral
- **TGV connections:** All targets well-connected; Bordeaux notably 2hrs to Paris

---

## R Script Structure (Sections 0-2)

| Section | Description | Status |
|---------|-------------|--------|
| 0 | Setup, `if(!require())` auto-install | ✅ |
| 1.1-1.4 | Communes, population, climate, DVF paths | ✅ |
| 1.5 | Filosofi economic data | ✅ |
| 1.6 | Presidential election data (auto-download) | ✅ |
| 2.1 | Target departments definition (TARGET_DEPTS) | ✅ |
| 2.2 | Climate screening | ✅ |
| 2.3 | Department/region lookup | ✅ |
| 2.4 | Population aggregation | ✅ |
| 2.5 | Create city_screening dataset | ✅ |
| 2.6 | Normalize climate/demographic variables | ✅ |
| 2.7 | Economic indicators + normalize | ✅ |
| 2.8 | Political indicators + normalize | ✅ |
| 2.9 | Composite scoring + target confirmation | ✅ |

---

## Session Notes

**Feb 9, 2026 (Session 5) — Region Selection Finalized:**
- Ran final composite scoring with weights: far_right=1.0, sunshine=0.75, rainfall=0.75, affluent=0.75, age=0.5, poverty=0.25
- Reviewed ranked list excluding Île-de-France and Corsica
- Selected 5 target cities: Toulouse, Lyon, Annecy, Montpellier, Bordeaux
- Added Paris (dept 75) as international mega-city benchmark
- Discussed ML implications: transaction volume imbalance (Annecy small), geographic diversity aids generalization, temporal split valid across all departments
- Considered adding airport/mountain criteria — decided to keep as qualitative factors only
- Updated cyo_script.R: Section 2.1 (TARGET_DEPTS), 2.9 comments, verification filters, Section 3.1 default
- Phase complete — ready for DVF data processing (Section 3)

**Feb 5, 2026:**

*Session 3 (Morning) — Political Data Integration:*
- Integrated presidential election data (2022 first round by department)
- Fixed Section 2.8.1 join: uses `department_code` not `code_departement`
- Added columns: `pct_le_pen`, `pct_zemmour`, `pct_far_right`, `far_right_norm`
- Saved updated `city_screening` to `data/city_screening.csv` (23 columns)
- Key tradeoff identified: Mediterranean = sun + politics risk; Southwest = less sun + better alignment

*Session 4 (Afternoon) — Composite Score Experimentation:*
- Calculated composite scores using multiple weighting schemes
- Experimented with 5 different weight configurations (see Weighting Evolution table)
- Key insight: Sunshine-first approach produces dramatically different rankings than affluence-first
- Final weights reflect family discussion prioritizing political alignment

**Feb 3, 2026 (Session 2):**
- Integrated INSEE Filosofi 2020 economic data (income + poverty)
- Added Section 1.5 (data loading) and Section 2.7 (join + normalize)
- Discovered tension: sunshine-optimized cities have higher poverty; economically stronger cities have less sunshine
- Dual needs identified: remote income (local wages irrelevant) + wife's pilates business (needs affluent customers)

**Feb 2-3, 2026 (Session 1):**
- Built city_screening dataset joining climate (55 cities), communes, and population demographics
- Verified 55 rows with all expected columns
- Mediterranean cities dominate sunshine rankings as expected
- Initial normalization of sunshine, age, rainfall completed

---

*Phase completed: February 9, 2026*