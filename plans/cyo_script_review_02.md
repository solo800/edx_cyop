# cyo_script.R — Remaining Fixes Checklist

Guide for final polish before submission. Each item includes the problem, location, and what the fix should look like.

---

## 1. ✅ XGBoost Test Leakage — RESOLVED

Validation split applied. No further action needed.

---

## 2. ✅ Election Column References (Section 1.6.2) — RESOLVED

Comment block added above the `transmute()` explaining the positional column mapping. No further action needed.

## 3. Update Hardcoded Values (Section 5.2.6)

**Problem:** The "after" values in the income impact table (Section 5.2.6) are pulled dynamically from `all_results`, so they now reflect the post-fix XGBoost numbers (R²=0.670 instead of 0.679). The "before" values are hardcoded and remain correct. No code change needed, but verify the printed output looks right — the XGBoost R² gain will now show +0.071 instead of +0.080.

**Task:** Run Section 5.2.6 and confirm the table prints without errors and the numbers are internally consistent.

---

## Summary

| # | Item | Type | Priority |
|---|------|------|----------|
| 1 | XGBoost leakage | ✅ Done | — |
| 2 | Election column comments | Add comments | Medium |
| 3 | Repo file check | Verify git tracking | High |
| 4 | Fresh clone test | End-to-end run | High |
| 5 | Section 5.2.6 output check | Verify only | Low |