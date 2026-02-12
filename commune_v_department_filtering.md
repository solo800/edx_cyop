# DVF Filtering Strategy: Commune vs Department

**Date:** February 11, 2026  
**Based on:** 2024 DVF data (single year exploration)

---

## The Problem

DVF data is organized by department, but departments are much larger than the cities we're comparing. Département 31 (Haute-Garonne) includes Toulouse plus ~500 other communes. Using full department data would mix urban house prices with rural farmhouses, muddying city-to-city comparisons.

---

## Options Considered

### Option A: Filter to Commune Level (SELECTED)

Filter DVF transactions to only the commune codes that make up each target city proper.

**Pros:**
- Clean city-to-city comparison
- Defensible methodology for the report
- Removes rural noise entirely

**Cons:**
- Reduces sample size significantly (especially Annecy, Lyon)
- Misses suburbs where house-hunters actually look

**Estimated training samples (2020-2024, ~5x the 2024 figures):**

| City | 2024 Transactions | Est. 5-Year Total | Commune Codes |
|------|-------------------|-------------------|---------------|
| Marseille | 1,677 | ~8,400 | 1-16 (arrondissements) |
| Toulouse | 1,101 | ~5,500 | 555 |
| Bordeaux | 961 | ~4,800 | 63 |
| Montpellier | 461 | ~2,300 | 172 |
| Annecy | 176 | ~880 | 10 |
| Lyon | 171 | ~850 | 381-389 (arrondissements) |
| **Total** | **4,547** | **~22,700** | |

**Note on multi-code cities:**
- Marseille: 16 arrondissements, commune codes 1-16
- Lyon: 8 arrondissements with transactions, commune codes 381-389
- Paris: 15 arrondissements with house sales, codes 105-120
- All others: single commune code

### Option B: Filter to Urban Area / Agglomération

Include each city plus its immediate suburban communes (intercommunalité or EPCI boundaries).

**Pros:**
- More realistic for actual house-hunting (suburbs matter)
- Larger sample sizes, especially for Lyon and Annecy
- EPCI boundaries are officially defined — not arbitrary

**Cons:**
- Need to source EPCI-to-commune mappings
- Different agglomérations have very different geographic extents
- Adds complexity to data pipeline
- Suburban dynamics may differ from city proper

**To explore this later:** Would need the EPCI reference table from INSEE and a join to commune codes. The Filosofi data already has EPCI-level files (`FILO2020_DEC_EPCI.csv`) which could help define boundaries.

### Option C: Full Department Level

Keep all transactions within each department.

**Pros:**
- Simplest approach — no filtering beyond department code
- Maximum sample size (~53,000 transactions in 2024 alone across 7 departments)
- No risk of missing relevant transactions

**Cons:**
- Rural transactions dominate (e.g., only 12% of dept 31 transactions are in Toulouse proper)
- City-to-city price comparisons become meaningless
- Model would learn "department effects" not "city effects"
- Contradicts the project narrative of comparing cities

---

## Decision: Option A

Commune-level filtering selected. ~22,700 estimated training samples across 6 cities is sufficient for linear regression and Random Forest models.

**Paris dropped from modeling:** Only 136 house transactions in 2024 across the entire city. Paris is fundamentally an apartment market. Retained in the report narrative as motivation for relocation but excluded from the ML pipeline.

**Risks to monitor:**
- Annecy (~880) and Lyon (~850) are thin — check if model performance degrades for these cities
- 2025-S1 test set has seasonal bias (no autumn/winter transactions) — note as limitation

---

## Key Department-Level Context (for reference)

From the 2024 exploration, full department transaction counts for houses:

| Dept | Department Name | Total House Transactions | Main City % |
|------|----------------|------------------------|-------------|
| 33 | Gironde | 14,272 | 6.7% (Bordeaux) |
| 34 | Hérault | 9,534 | 4.8% (Montpellier) |
| 31 | Haute-Garonne | 9,315 | 11.8% (Toulouse) |
| 13 | Bouches-du-Rhône | 9,011 | 18.6% (Marseille) |
| 69 | Rhône | 6,734 | 2.5% (Lyon) |
| 74 | Haute-Savoie | 4,329 | 4.1% (Annecy) |
| 75 | Paris | 136 | 100% (all Paris) |

This confirms that city-proper transactions are a small fraction of department totals, validating the need for commune-level filtering.