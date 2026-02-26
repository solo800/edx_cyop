# CYO Report Writing Plan

**Project:** "Finding Home in France" — cyo_report.Rmd → PDF
**Target:** 25/25 Report + 20/20 Code = 45/45 (+ 5 pts files)
**Approach:** Linear, front-to-back. Executive Summary written last.

---

## Session Plan

### Session 1 — Introduction (Rmd Sections 1–2) ✅
- [x] Executive Summary (written inline, not deferred to Session 6)
- [x] Dataset description: DVF, what it contains, why it's interesting
- [x] Project goal: framed as both a personal decision and an ML problem
- [x] Personal motivation: Paris → sunnier city, wife's business, family needs
- **Purpose:** Set the hook — grader should understand *why* before *how*

### Session 2 — Methods Part 1: City Selection ✅
- [x] City screening methodology: 6 criteria, normalization, composite scoring
- [x] Final 7-city selection with justification
- [x] Screening table visualization (composite score + key metrics)
- ~~Data sources table~~ — sources woven into Dataset Description prose instead
- ~~Tradeoff plot (sunshine vs politics)~~ — tension covered in ES narrative; not needed as standalone viz
- **Purpose:** Show the decision framework that narrowed 55 cities to 7

### Session 3 — Methods Part 2: DVF Processing & Feature Engineering ✅
- [x] Commune adjacency approach (why city-proper wasn't enough, ring concept)
- [x] Data cleaning pipeline (68K → 59K, dedup logic, outlier bounds)
- [x] Feature engineering decisions, especially median income breakthrough
- [x] Justify temporal train/test split (2020–2023 train / 2024 test)
- **Purpose:** Demonstrate data wrangling rigor; rubric rewards explaining *why* each choice was made

### Session 4 — Methods Part 3: Modeling ✅
- [x] Three supervised models: linear regression (baseline), Random Forest, XGBoost
- [x] Explain *why* each model was chosen and what it adds
- [x] K-means as unsupervised complement — what question it answers
- [x] Hyperparameter choices, early stopping rationale, validation split
- [x] Sample imbalance handling (interaction terms for LM, natural splits for trees)
- **Purpose:** Satisfy "2+ algorithms, one advanced" requirement with clear justification

### Session 5 — Results ✅
- [x] Overall model comparison (R² table, bar chart)
- [x] Per-city breakdown — Paris most predictable, Toulouse hardest, why
- [x] Feature importance — surface dominates, median income was the breakthrough
- [x] Income feature impact (before/after table — best "insight" moment)
- [x] K-means clustering results (centroids table + PCA biplot)
- [x] City rankings and standard house prediction
- [x] Multi-criteria comparison and final recommendation
- ~~Residual analysis~~ — per-city R² breakdown + "missing features" narrative covers same ground
- **Purpose:** Present findings clearly; make the income feature story the centerpiece insight

### Session 6 — Conclusion + Executive Summary ✅
- [x] Summary of findings and recommendation
- [x] Limitations (missing DPE/condition, single-year income, 2020 S2-only)
- [x] Future work (DPE integration, geospatial features, stacked ensemble, valuation tool)
- [x] References (complete and formatted)
- [x] Executive Summary (written in Session 1, not deferred)
- **Purpose:** Wrap up cleanly; ES gives graders the TL;DR up front

---

## Key Rubric Targets

### Report (25 pts) — targeting "Excellent"
> "Includes all required sections, is easy to follow with good supporting detail throughout, and is insightful and innovative."

- **All required sections:** Introduction, Methods/Analysis, Results, Conclusion, References ✓
- **Easy to follow:** Define DVF, explain communes, assume reader knows nothing about France ✓
- **Good supporting detail:** Every methodological choice gets a *why* (split rationale, model selection, weight iterations) ✓
- **Insightful and innovative:** Two headline insights featured prominently: ✓
  1. Median income feature breakthrough (+8 R² points for tree models)
  2. Sunshine vs politics tradeoff (Mediterranean cities score high on climate, low on alignment)

### Code (20 pts) — targeting full marks
- [x] Runs without errors
- [x] Well-commented
- [x] Relative file paths (here::here())
- [x] Auto-install packages (if(!require))
- [ ] Dataset accessible (dvf_houses_clean.csv in repo)
- [ ] Final commenting pass

### Files (5 pts)
- [x] PDF (knit from Rmd) — cyo_report.pdf exists
- [x] Rmd file
- [x] R script
- [ ] All three submitted to grading platform

---

## Report Guidelines

- **Length:** ~15–20 pages knit to PDF (including figures)
- **Figures:** ~8–12 total, each supporting a specific claim
- **Tone:** Professional but with authentic personal voice (the relocation story is a strength)
- **Code chunks in Rmd:** Load processed data and reproduce key plots; don't re-run the full pipeline
- **Audience:** Grader unfamiliar with DVF, French geography, or this specific dataset

---

## Workflow

1. Claude drafts prose + R code chunks for each session
2. Adam pastes into RStudio, knits to check rendering
3. Adam shares any output or issues
4. Iterate within session, then move to next
5. Local LLM handles file ops, git, and mechanical code tasks as needed

---

*Created: February 18, 2026*
*Updated: February 25, 2026 — all sessions complete, remaining items are pre-submission checklist*
