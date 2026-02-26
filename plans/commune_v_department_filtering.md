# DVF Filtering Strategy: Commune vs Department

**Date:** February 11, 2026  
**Updated:** February 12, 2026 — adjacency approach implemented  
**Based on:** 2024 DVF data (single year exploration)

---

## The Problem

DVF data is organized by department, but departments are much larger than the cities we're comparing. Département 31 (Haute-Garonne) includes Toulouse plus ~500 other communes. Using full department data would mix urban house prices with rural farmhouses, muddying city-to-city comparisons.

---

## Options Considered

### Option A: Filter to Commune Level Only

Filter DVF transactions to only the commune codes that make up each target city proper.

**Pros:**
- Clean city-to-city comparison
- Defensible methodology for the report
- Removes rural noise entirely

**Cons:**
- Reduces sample size significantly (especially Annecy, Lyon, Paris)
- Misses suburbs where house-hunters actually look
- Paris (136 transactions) and Lyon (171) essentially unusable

**2024 city-proper transaction counts:**

| City | 2024 Transactions | Est. 5-Year Total |
|------|-------------------|-------------------|
| Marseille | 1,426 | ~7,100 |
| Toulouse | 1,101 | ~5,500 |
| Bordeaux | 961 | ~4,800 |
| Montpellier | 461 | ~2,300 |
| Annecy | 176 | ~880 |
| Lyon | 171 | ~850 |
| Paris | 136 | ~680 |
| **Total** | **4,432** | **~22,100** |

### Option B: Filter to Urban Area / Agglomération (EPCI)

Include each city plus its immediate suburban communes using official EPCI boundaries.

**Pros:**
- More realistic for actual house-hunting
- Larger sample sizes
- EPCI boundaries are officially defined

**Cons:**
- EPCI boundaries have very different geographic extents across cities
- Adds complexity to data pipeline
- Suburban dynamics may differ from city proper

### Option C: Full Department Level

Keep all transactions within each department.

**Pros:**
- Simplest approach — maximum sample size (~53,000 in 2024)

**Cons:**
- Rural transactions dominate (e.g., only 12% of dept 31 is Toulouse proper)
- City-to-city price comparisons become meaningless
- Contradicts the project narrative

### Option D: Commune + Spatial Adjacency Ring (SELECTED)

Filter to city-proper communes (ring 0) plus all communes that share a geographic border (ring 1), identified programmatically using IGN commune boundary polygons.

**Pros:**
- Captures suburbs where house-hunters actually look
- Dramatically improves sample sizes for thin cities (Paris, Lyon, Annecy)
- Programmatic and reproducible — defensible methodology
- More precise than EPCI boundaries (which can be very large)
- Adjacency is a natural geographic definition, not arbitrary

**Cons:**
- Requires spatial data processing (IGN ADMIN-EXPRESS boundaries + `sf` package)
- Adjacent communes may have different market dynamics than city proper
- Paris suburbs span 3 extra departments (92, 93, 94) requiring additional DVF filtering

---

## Decision: Option D — Commune + Adjacency Ring

### Methodology

1. Downloaded IGN commune boundary polygons (communes-50m.geojson from data.gouv.fr)
2. For arrondissement cities (Paris, Lyon, Marseille): merged arrondissement polygons into single city polygon via `st_union()`
3. Used `st_touches()` to identify all communes sharing a border with each city polygon
4. Created lookup table: `data/commune_filter_lookup.csv` (159 communes across 7 cities)

Script: `scripts/commune_adjacency.R`

### Transaction Counts (2024, houses + sales)

| City | Ring 0 (city) | Ring 1 (adjacent) | Total | Est. 5-Year |
|------|--------------|-------------------|-------|-------------|
| Bordeaux | 961 | 1,987 | 2,948 | ~14,700 |
| Toulouse | 1,101 | 1,241 | 2,342 | ~11,700 |
| Marseille | 1,426 | 767 | 2,193 | ~11,000 |
| Paris | 136 | 1,216 | 1,352 | ~6,800 |
| Montpellier | 461 | 812 | 1,273 | ~6,400 |
| Lyon | 171 | 921 | 1,092 | ~5,500 |
| Annecy | 176 | 312 | 488 | ~2,400 |
| **Total** | **4,432** | **7,256** | **11,688** | **~58,500** |

**Key impact of adjacency ring:**
- Paris: 136 → 1,352 (petite couronne transforms this from unusable to solid)
- Lyon: 171 → 1,092 (houses are in the suburbs, not the city center)
- Annecy: 176 → 488 (lakeside/valley communes where people actually buy)
- Overall: ~22,100 → ~58,500 estimated training samples

### Adjacent Commune Details

| City | Adjacent Communes | Departments Spanned | Notes |
|------|------------------|--------------------|----|
| Paris | 29 | 75, 92, 93, 94 | Classic petite couronne ring |
| Toulouse | 17 | 31 | All within Haute-Garonne |
| Annecy | 17 | 74 | Post-2017 merger means ring 0 already includes former suburbs |
| Lyon | 15 | 69 | Captures Villeurbanne, Caluire, Bron etc. |
| Bordeaux | 12 | 33 | Dense suburban ring |
| Montpellier | 11 | 34 | All within Hérault |
| Marseille | 9 | 13 | Fewer neighbors due to sea + Calanques |

### Paris Department Note

Paris adjacent communes span departments 92 (Hauts-de-Seine), 93 (Seine-Saint-Denis), and 94 (Val-de-Marne). These are outside the original 7 target departments. Confirmed that the national DVF files already contain data for these departments — no additional downloads needed.

### Data Quality Note

DVF commune codes do NOT use leading zeros (e.g., `"63"` not `"063"`). The lookup CSV has been updated to match DVF format to avoid join failures.

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

This confirms that city-proper transactions are a small fraction of department totals, validating the need for commune-level filtering. The adjacency approach captures the relevant suburban transactions without pulling in the full rural department.