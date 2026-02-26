# CYO Script Review — Recommendations

**Context:** These are prioritized changes to `scripts/cyo_script.R` for the HarvardX PH125.9x Machine Learning Capstone. The grading rubric awards up to 20 points for code that "runs easily, is easy to follow, is consistent with the report, and is well-commented." Each recommendation below targets a specific rubric requirement or quality issue.

---

## 1. Solve the Data Access Problem (CRITICAL — Rubric Requirement)

**Why:** The rubric explicitly states: "The dataset you use should either be automatically downloaded by your code or provided in your GitHub repo along with the rest of your files." A grader who clones the repo cannot run the script without access to the data. This alone can drop code from 20 → 15 points.

**Current state:** The script relies on:
- `local_data/ValeursFoncieres-*.txt` — multi-GB DVF source files (not in repo, not auto-downloaded)
- `data/commune_filter_lookup.csv` — produced by a separate script (`scripts/commune_adjacency.R`)
- `data/dvf_houses_clean.csv` — the processed 59,373-row dataset (produced by Sections 3–3B)
- `data/raw/filosofi_2020_commune/base-cc-filosofi-2020-geo2023.xlsx` — downloaded manually

**Recommended approach:**

1. **Include `data/dvf_houses_clean.csv` in the GitHub repo.** This is the processed dataset (~15-20MB as CSV, well within GitHub's 100MB file limit). Since the script already has a quick-start cache that loads this file directly when it exists, a grader who clones the repo will hit that path automatically — Sections 3–3B get skipped, and the script proceeds to EDA and modeling without needing the raw DVF files.

2. **Include `data/commune_filter_lookup.csv` in the repo** (it's tiny — 159 rows). It's already there based on the directory tree, so just confirm it's tracked in git.

3. **Include the other `data/raw/` files that are small enough** (climate CSV, communes CSV, population XLSX, election XLSX, Filosofi commune XLSX). Check each file's size — anything under ~50MB can go in the repo.

4. **Add a comment block at the top of the script** (after Section 0) explaining:
   - The script has two modes: quick-start (loads pre-processed `dvf_houses_clean.csv`) and full processing (requires raw DVF files)
   - A grader only needs the quick-start path; raw DVF files are optional for reproducibility of the data cleaning pipeline
   - List which files must be present in the repo for the script to run

5. **For the election data download** (Section 1.6): the current URL is an API endpoint (`data.gouv.fr/api/1/datasets/r/...`). These are unstable. Since the file is small, include it in the repo and remove the download logic, or keep the download as a fallback with a clear comment that the file is also in the repo.

**What to do:** Verify file sizes of all `data/raw/` files. Commit any under ~50MB to git. Ensure `dvf_houses_clean.csv` is committed. Add a "Data Access" comment block after Section 0. Test by cloning to a fresh directory and running the script.

---

## 2. Strip `cat()` Prose Paragraphs (Code Quality)

**Why:** The rubric says the script should contain "all of the code and comments." Comments means `#`-prefixed annotations, not multi-line `cat()` paragraphs that print narrative to the console. These prose blocks belong in the Rmd report. They add visual clutter, make the script harder to scan, and blur the line between code output and documentation.

**Specific blocks to remove or convert to comments:**

| Location | Content | Action |
|----------|---------|--------|
| 3C.12 | `cat("\n=== EDA KEY FINDINGS ===\n")` + 6 lines of findings | **Remove entirely.** These findings go in the report narrative, not the script. |
| 4.7 (end) | `cat("\n--- K-Means clustering summary ---\n")` + 8 lines of narrative | **Remove entirely.** This is a report paragraph printed to console. |
| 5.1 | Entire subsection — just prints "EDA was presented in Section 3C" | **Remove entirely.** This is a no-op. |
| 5.2.5 (end) | `cat("Residuals show mild heteroscedasticity...")` | **Convert to a 1-line comment** above the plot: `# Residuals show mild heteroscedasticity — typical for real estate` |
| 5.3.5 (end) | 6 lines of `cat()` explaining the blended score weights | **Remove.** This is report content. |
| 5.3.6 | The entire city profiles loop prints narrative prose | **Keep the data output** (prices, R², etc.) but **remove the strengths/weaknesses auto-generation** — that's analysis that belongs in the report, not computed at runtime in the script |

**What `cat()` to keep:**
- Data summaries that help verify output (e.g., row counts, cleaning pipeline summaries, model metrics)
- Section headers like `cat("\n=== TRAIN/TEST SPLIT ===\n")` — these help a grader follow the script's progress
- Anything a grader would want to see in the console to confirm the script ran correctly

**Rule of thumb:** If the `cat()` text would make sense as a paragraph in your report PDF, it belongs in the Rmd, not the R script.

---

## 3. Remove Dead Code (Code Quality)

**Why:** Dead code signals to a grader that the script wasn't cleaned up. It also makes the script longer than necessary and can cause confusion ("was this supposed to run?").

**Items to remove:**

1. **Section 5.1** — The entire subsection is:
   ```r
   cat("\n=== EDA VISUALIZATIONS ===\n")
   cat("Exploratory data analysis was presented in Section 3C.\n")
   # ... etc
   ```
   This does nothing. Remove it or collapse to a single comment: `# 5.1 — EDA visualizations are in Section 3C above`.

2. **Section 6 utility functions** — `format_eur()` and `summary_stats()` are defined but never called anywhere in the script. Either:
   - Remove them entirely, or
   - If you plan to use them in the Rmd report, move them to a shared utilities file and source it, or
   - Actually use them in the script (e.g., replace inline `scales::dollar()` calls with `format_eur()`)

3. **Commented-out code in Section 1.4:**
   ```r
   # Load all DVF files (uncomment when ready to process full dataset)
   # dvf_raw <- map_dfr(dvf_files, load_dvf_file, .id = "source_file")
   ```
   This is leftover from early development. Remove it.

4. **The `dvf_files` variable** (Section 1.4) — `list.files(LOCAL_DATA, ...)` runs at the top of the script and lists all DVF files, but the actual loading in Section 3.2 uses its own `list.files()` call with a different pattern. The Section 1.4 version is unused. Remove it.

---

## 4. Document the `commune_adjacency.R` Dependency (Reproducibility)

**Why:** `commune_filter_lookup.csv` is a critical input — without it, Section 3.1 fails. It's produced by `scripts/commune_adjacency.R`, which is a separate preprocessing script. But nothing in `cyo_script.R` tells the grader this. If the lookup CSV is in the repo (Recommendation 1), the grader doesn't need to run the adjacency script, but the dependency should still be documented for transparency.

**What to do:**

Add a comment block near the top of the script (or at Section 3.1) like:

```r
# NOTE: commune_filter_lookup.csv was generated by scripts/commune_adjacency.R
# using IGN commune boundary polygons (sf::st_touches) to identify communes
# adjacent to each target city. The lookup file is included in the repository
# so this preprocessing step does not need to be repeated.
```

Also mention this in your report's Methods section — the adjacency ring strategy is an interesting methodological choice that deserves explanation.

---

## 5. Fix the Hardcoded "Before" Values in 5.2.6 (Reproducibility)

**Why:** Section 5.2.6 ("Impact of Median Income Feature") contains:

```r
before <- tibble(
  model = c("Linear Regression", "Random Forest", "XGBoost"),
  r2_before   = c(0.554, 0.597, 0.599),
  rmse_before = c(263169, 250315, 249607)
)
```

These are results from a prior run of the script *without* the median income feature. They cannot be reproduced by running the current script. If anything upstream changes (outlier bounds, dedup logic, new data), these numbers silently become stale. A grader who re-runs the script will get the "after" values from the models but has no way to verify the "before" values.

**Options (pick one):**

**Option A (recommended): Move the before/after comparison to the report only.** Remove Section 5.2.6 from the script. In the Rmd report, include a manually created table showing the before/after results with a footnote: "Before values obtained by running the model pipeline without the `median_income_commune` feature." This is honest, transparent, and doesn't pretend the values are computed.

**Option B: Keep it but add a clear comment.** If you want the chart in the script output:
```r
# These "before" values were obtained from a prior run without the
# median_income_commune feature. They are hardcoded here because the
# current script always includes median_income. See project_status_dvf_modeling.md
# for the full before/after comparison.
before <- tibble(...)
```

**Option C (most rigorous but may not be worth the effort): Actually re-run the models without income.** Train a second set of models excluding `median_income` from the feature list, capture their metrics, then compare. This makes the comparison fully reproducible but adds ~30 seconds of runtime and code complexity.

---

## 6. Consolidate and Tighten EDA (Length Reduction)

**Why:** Section 3C has 12 subsections producing 10+ plots. This is thorough but excessive for a script that a grader needs to follow. Many of these plots will appear in the report — the script just needs to produce them, not frame each one with setup and narrative.

**Suggested consolidation:**

| Keep as-is | Merge or simplify | Consider removing from script |
|------------|-------------------|-------------------------------|
| 3C.2 Price distribution (essential) | 3C.1 Summary stats → just the code, no `cat()` framing | 3C.8 Room count distribution (minor insight) |
| 3C.3 Price/m² by city (essential) | 3C.6 + 3C.7 → combine surface distribution and ring effect into one faceted figure | 3C.11 Quarterly seasonality (weak signal per your own findings) |
| 3C.4 Temporal trends (essential) | 3C.9 + 3C.10 → scatter + correlation matrix are related | |
| 3C.5 Transaction volume (essential) | | |

This could reduce 12 subsections to ~7-8, saving 80-100 lines without losing analytical substance.

**Alternative:** Keep all plots but remove the `cat()` framing around each one. Just let the plots speak — the report will provide the narrative context.

---

## 7. Review Section 5.3.6 City Profiles (Scope Creep)

**Why:** The city profiles loop (5.3.6) auto-generates strengths and weaknesses for each city using threshold-based logic. This is ~80 lines of code that essentially duplicates what you'll write in the report's conclusion. It's clever, but it's also:
- Fragile (thresholds are arbitrary — why 0.7 and 0.3?)
- Redundant with the report narrative
- The kind of thing a grader might question ("why is 0.7 the cutoff for 'excellent sunshine'?")

**Options:**

**Option A (recommended):** Simplify to just print the key numbers per city (predicted price, R², sunshine hours, far-right %). Remove the strengths/weaknesses auto-generation. Write the qualitative assessment in the report.

**Option B:** Keep it but add a comment explaining the thresholds: `# Thresholds: ≥0.7 = strength, ≤0.3 = weakness (on 0-1 normalized scale)`

---

## 8. Minor Cleanup Items

These are small fixes that collectively improve code quality:

1. **Remove the `code_departement` column leak in Section 2.7:** The line `mutate(code_departement = str_remove(department_code, "^0"))` creates a column that's then removed by `select(-code_departement)`. This is fine functionally but slightly messy — the join could use a temporary variable instead.

2. **The `ring_label` column created in 3C.7** (`mutate(ring_label = ifelse(ring == 0, "City proper", "Adjacent suburb"))`) is added to `dvf_houses` permanently but only used for one plot. Consider creating it inline in the plot's `aes()` or in a temporary variable.

3. **Consistent comment style:** Some sections use `## 3.1 Load Commune Filter Lookup ----` (with trailing dashes for RStudio code folding) while others don't. Standardize to always include the trailing `----` for all section headers — this makes the script navigable in RStudio's document outline.

4. **The `scatter_sample` and `resid_sample` objects** persist in the environment after creation. Not a real problem, but `rm(scatter_sample)` after the plot would keep the environment clean.

5. **Section numbering gap:** There is no Section 3B.6 (the comment says "Save moved to after 3B.7"). Renumber 3B.7 → 3B.6 and 3B.8 → 3B.7, or just remove the gap comment and renumber cleanly.

---

## 9. Remove the Model Checkpoint (Length Reduction + Cleanup)

**Why:** Section 4.8 saves and restores all model objects (`lm_fit`, `rf_fit`, `xgb_fit`, predictions, etc.) to `data/model_checkpoint.RDS`. This was useful during development to avoid re-training models on every run, but it's unnecessary for submission:

- A grader runs the script once. The full model training pipeline (RF + XGBoost + K-means on ~49K rows) takes ~1-2 minutes — not a pain point for a single run.
- The checkpoint logic adds ~20 lines of code and a subtle bug: the condition `file.exists(checkpoint_path) && !exists("lm_fit")` means a partially failed run could load stale results on retry without the grader realizing.
- The `.RDS` file in the repo raises questions ("do I need this? what's in it?").
- It's development scaffolding that should come down before submission.

**What to do:**

1. **Delete Section 4.8 entirely** (the `if/else` block that saves/loads `model_checkpoint.RDS`).
2. **Delete `data/model_checkpoint.RDS` from the repo:** `git rm data/model_checkpoint.RDS`
3. **Add `model_checkpoint.RDS` to `.gitignore`** so it doesn't accidentally get recommitted if you regenerate it locally.
4. Verify the script still runs end-to-end without it — the models train in Sections 4.4–4.7 and their objects (`lm_fit`, `rf_fit`, `xgb_fit`, `all_results`) persist in the R environment for Section 5.

**Important distinction:** The DVF quick-start cache (`dvf_houses_clean.csv` in Section 3) is a *different* pattern and should stay. That cache is what makes the script runnable without the multi-GB raw DVF files — it's a data access strategy, not a convenience shortcut. The model checkpoint is pure convenience.

---

## Summary — Expected Impact

| Recommendation | Lines saved (est.) | Rubric impact |
|----------------|-------------------|---------------|
| 1. Data access | +20 (comments) | **15 → 20 points** (code grade) |
| 2. Strip `cat()` prose | -60 to -80 | Clarity, consistency with report |
| 3. Remove dead code | -30 to -40 | Cleanliness |
| 4. Document dependency | +5 (comments) | Reproducibility |
| 5. Fix hardcoded values | -15 to +5 | Reproducibility, honesty |
| 6. Consolidate EDA | -60 to -100 | Length reduction, focus |
| 7. Simplify city profiles | -40 to -60 | Length, avoid over-engineering |
| 8. Minor cleanup | -10 to -15 | Polish |
| 9. Remove checkpoint | -20 | Cleanliness, remove subtle bug |

**Net effect:** Script goes from ~950 lines to ~630-680 lines, with better grader experience, full reproducibility, and no loss of analytical content.