# Capstone Project State - French Real Estate Analysis

**Last Updated:** February 2, 2026  
**Current Phase:** Data Filtering & Processing

---

## Project Overview

**Goal:** Build a multi-criteria decision support system to identify the best French city for relocation, combining personal needs (sunny climate, house with garden, positive demographics) with machine learning analysis of real estate markets.

**Academic Purpose:** edX Machine Learning Capstone "Choose Your Own" project (50 points possible, due June 10, 2026)

---

## Key Decisions Made

### Target Cities (Final Selection)
- **Marseille** (dept 13) - Sunniest major city in France
- **Toulouse** (dept 31) - Aerospace hub, young population
- **Bordeaux** (dept 33) - Growing tech/wine city, TGV to Paris
- **Montpellier** (dept 34) - University city, excellent growth

**Rejected:** Perpignan (demographic concerns validated by research)

### Dataset Choice
**Primary:** DVF (Demandes de Valeurs Foncières) from data.gouv.fr
- Government notary records of all French property transactions
- Coverage: 2020-2024 (5 years downloaded)
- Size: Several GB total, ~3-5M transactions/year
- **Decision:** Filter to target departments and houses only

**Why DVF:**
- Not a well-known/overused dataset ✓
- Rich features for multiple ML approaches ✓
- Publicly available, can be auto-downloaded ✓
- Personal relevance creates strong narrative ✓

### Modeling Plan (Satisfies 2+ Algorithms Requirement)
1. **Baseline:** Linear regression (price prediction)
2. **Advanced:** Random Forest or XGBoost (price prediction)
3. **Additional:** K-means clustering (city similarity analysis)

---

## Progress Status

### ✅ Completed
- [x] Project repository created: https://github.com/solo800/edx_cyop.git
- [x] Target cities identified and validated
- [x] DVF data downloaded (2020-2024, stored in `local_data/`)
- [x] Project structure established (`data/`, `scripts/`, etc.)

### 🔄 In Progress
- [ ] Filter DVF files to target departments (13, 31, 33, 34)
- [ ] Extract houses only (exclude apartments)
- [ ] Create filtered dataset for GitHub

### ⏳ Not Started
- [ ] Data exploration & visualization
- [ ] Feature engineering
- [ ] Model building & comparison
- [ ] Report writing (PDF + Rmd)
- [ ] R script finalization

---

## Data Sources & Documentation

### Primary Data
- **DVF Transactions:** https://www.data.gouv.fr/datasets/demandes-de-valeurs-foncieres
- **Downloaded:** 2020-2024 (5 years of transaction data)

### Supporting Data (To Be Added)
- Sunshine hours: Manual addition from Météo France or other sources
- Demographics: INSEE (population growth, age structure)
- Income data: Available in extended DVF datasets

### Key References
- DVF Analysis Example: https://mincong.io/2021/04/16/dvf-real-estate-analysis-idf-2020/
- Sunniest French Cities: https://goodfrance.com/cities-towns-villages/what-are-20-sunniest-cities-france/

---

## Personal Context (For Report Introduction)

**Current Situation:** Living in Paris, planning relocation with wife

**Requirements:**
- House with garden (outdoor space)
- Sunnier climate than Paris (~1,660 hrs/year)
- City with positive demographics (not aging/shrinking)
- Good amenities (top 20 metro areas)

**Why This Matters:** Combines academic ML project with real-life major decision - creates authentic motivation and compelling narrative for report.

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
- [ ] Runs without errors
- [ ] Well-commented
- [ ] Relative file paths (not absolute)
- [ ] Auto-install missing packages (`if(!require)`)
- [ ] Dataset auto-downloadable OR in GitHub repo

---

## Questions to Resolve Later

1. **Time window:** Use all 5 years (2020-2024) or focus on recent years only?
2. **Property filtering:** Strict house-only or include townhouses/villas?
3. **Additional features:** Add commute time to Paris? School ratings?
4. **Train/test split:** Temporal (e.g., 2020-2023 train, 2024 test) or random?

---

## Quick City Comparison Reference

| City | Sunshine hrs/yr | Metro Pop | Growth | Dept Code |
|------|----------------|-----------|--------|-----------|
| Marseille | 2,858 | 1.9M | Moderate | 13 |
| Toulouse | 2,031 | 1.4M | Excellent | 31 |
| Bordeaux | 2,035 | 1.3M | Excellent | 33 |
| Montpellier | 2,668 | 600K | Excellent | 34 |
| Paris | 1,660 | 12.5M | Stable | 75 |

---

*This document tracks decisions and progress. Update as project evolves.*