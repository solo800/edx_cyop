# Executive Summary

[*To be written in final session after all results are complete.*]

# Introduction

## Context & Personal Motivation

My family currently lives in Paris, and like many Parisians, we are considering relocation to a sunnier, more family-friendly region. The decision involves multiple competing priorities: climate preferences (Paris receives only ~1,660 sunshine hours annually), real estate affordability, demographic characteristics suitable for raising a young child, and alignment with family values. My wife plans to open a pilates and yoga studio, requiring both affordable commercial real estate and an affluent client base. Rather than relying on intuition, real estate websites, or anecdotal advice, I decided to combine personal decision-making with rigorous machine learning analysis of the French real estate market.

This project bridges a major family life decision with an academic machine learning capstone, creating authentic motivation to deliver both a useful decision-support tool and a robust analytical product suitable for peer and staff grading.

## Dataset Description: French Real Estate Transactions (DVF)

This project analyzes the **DVF** (Demandes de Valeurs Foncières), a comprehensive open dataset of property transactions published by the French government. The DVF includes all notarized property sales in France, with this analysis focusing on **2020–2024** transactions across seven metropolitan areas and 159 communes.

### Why DVF?

The DVF dataset offers several advantages for this capstone project:

- **Complete coverage**: Every notarized property transaction in France, not a sample or aggregated summary. Approximately 3–5 million transactions nationally per year, providing statistical power across diverse markets.
- **Rich feature set**: Transaction price, property characteristics (built area, room count, land area), precise location codes (commune, department), transaction date, and sale type (distinguishing sales from gifts or inheritance transfers).
- **Government-published**: High data quality with official provenance—appropriate for academic submission and reproducible research.
- **Not overused**: Unlike MovieLens, Iris, or Titanic datasets commonly seen in data science courses, DVF is uncommon in educational contexts, reducing plagiarism concerns and demonstrating independent dataset selection.
- **Personal relevance**: The analysis directly informs a major family decision, creating authentic motivation and compelling narrative for the report.

### Dataset Structure

Raw DVF files are pipe-delimited (`|`) text files with 43 columns capturing cadastral references, property metadata, and transaction details. Key columns for this analysis appear in Table 1.1.

| Column | Type | Definition |
|--------|------|-----------|
| `Valeur fonciere` | Numeric | Sale price in euros (€)—**target variable** for modeling |
| `Surface reelle bati` | Numeric | Built area in square meters (m²)—**primary predictor** across all models |
| `Nombre pieces principales` | Numeric | Number of main rooms (bedrooms, living room, kitchen counted; bathrooms not counted) |
| `Surface terrain` | Numeric | Total land area in m² (including built footprint and gardens) |
| `Date mutation` | Date | Transaction date in dd/mm/yyyy format |
| `Code departement` | Character | 2-digit department code (01–95, excluding Corsica in this analysis) |
| `Code commune` | Character | 3-digit commune code within the department (INSEE standard) |
| `Type local` | Character | Property type (Maison, Appartement, Local industriel, etc.)—**filtered to "Maison" only** |
| `Nature mutation` | Character | Transaction type (Vente, Échange, Apport, Succession, etc.)—**filtered to "Vente" only** |
| Additional columns (33) | Mixed | Cadastral parcels, street addresses, building certificates, etc. |

**Table 1.1**: Key DVF columns used in this analysis. All others retained for traceability but not used in modeling.

### Scope of Analysis

- **Raw volume**: Approximately 3–5 million transactions annually across all of France.
- **Filtered scope**: This analysis retains ~59,000 house (Maison) sales across 159 communes in 7 target departments, years 2020–2024.
- **Property type**: Single-family houses only, excluding apartments, commercial, and mixed-use properties to create a homogeneous comparison class.
- **Geography**: Seven departments (13, 31, 33, 34, 69, 74, 75) covering six candidate cities plus Paris as an international metro-area benchmark.
- **Time window**: 2020–2024 (five complete or near-complete years). Includes post-COVID market recovery, current market state, and sufficient historical context.

Supplementary datasets integrated during analysis:

- **Communes reference data**: Geographic and administrative metadata for all French municipalities (INSEE)
- **INSEE population by age**: Demographic structure (10 age brackets) at commune level (2020 census)
- **Météo France climate normals**: Sunshine hours, temperature, and rainfall (30-year averages) for 55 major cities
- **INSEE Filosofi income & poverty**: Median disposable income and poverty rates by commune (2020), used to contextualize neighborhood economic conditions
- **2022 presidential election results**: First-round vote share by candidate and department, reflecting local political alignment

## Project Goal

The overarching goal is to **develop a machine learning framework that recommends an optimal French city for relocation by synthesizing real estate market dynamics with climate, demographics, and personal criteria**.

This goal decomposes into two parallel objectives:

1. **Personal decision support**: Use DVF price modeling to compare real estate affordability across candidate cities, contextualized by climate (sunshine hours, rainfall), demographic (% working-age population), and political screening. Culminates in a ranked list of recommendations with estimated costs for a typical family home (100 m², 4 rooms, with land).

2. **Academic ML demonstration**: Build and compare multiple supervised machine learning algorithms (linear regression baseline, Random Forest, XGBoost) and complement with unsupervised learning (K-means clustering) to uncover latent real estate market tiers. Demonstrate competence across the full ML pipeline: exploratory data analysis, feature engineering, temporal train/test design, model selection with early stopping, evaluation, and interpretation.

## Scope: What This Analysis Does and Does Not Do

### In Scope

- Predict house prices across seven cities using DVF data and multiple algorithms
- Identify which cities have more predictable (homogeneous) vs. volatile (heterogeneous) markets
- Rank candidate cities by a composite score combining climate, demographics, economics, and politics
- Estimate real estate affordability differences across cities
- Discover latent market tiers using unsupervised clustering

### Out of Scope

- Predict individual house prices with perfect accuracy (impossible; real estate has inherent uncertainty from omitted features)
- Account for subjective neighborhood quality, school district reputation, or cultural amenities (data unavailable in DVF)
- Include property condition, renovation status, or energy performance ratings (DVF does not capture these details)
- Model supply and demand dynamics or market participation rates (transaction frequency)
- Recommend a city as objectively "best" for all families (the ranking reflects our family's priorities: climate + affordability + political alignment; others may weight these differently)
- Provide investment advice or predict future price appreciation (static cross-sectional analysis of recent years, not time-series forecasting)

The analysis is a **structured decision-support tool**, not a crystal ball or universal recommendation engine.

## Key Methodological Decisions

To constrain scope and ensure academic rigor, the following decisions were made upfront:

**Houses only**: Filtered to "Maison" property type (single-family homes) to create a homogeneous comparison class. Apartments (Appartement), commercial property, and mixed-use structures are excluded. This simplifies model interpretation—coefficients reflect price drivers for houses specifically.

**2020–2024 time window**: Captures five years of recent data, including post-COVID recovery, current market conditions, and sufficient historical context for stable estimates. First-semester 2025 data excluded for consistency.

**Seven-department geographic scope**: Derived from systematic screening of 55 French cities across climate, demographic, economic, and political dimensions (detailed in Section 2.1). Seven departments emerged as the optimal set balancing candidate quality, data availability, and computational tractability.

**Temporal train/test split**: Training set uses transactions from 2020–2023; test set uses 2024 only. Real estate markets are path-dependent—prices in year *t* depend on market conditions in year *t*–1. A random train/test split would leak future market information into the training set, producing overly optimistic test metrics. Temporal splitting respects the inherent structure of real estate data.

**Commune-level filtering with adjacency ring**: City-proper boundaries alone provided inadequate sample sizes (Paris proper: 136 transactions; Lyon proper: 171). Adjacent communes (Ring 1), identified using spatial adjacency, expanded samples to ~1,300–3,000 per city. This captures both central urban markets and immediate suburban expansion.

**Median income feature engineering**: Filosofi 2020 commune-level median income was added as a model feature in Section 3B.6 after initial modeling revealed feature ceiling (~R² = 0.60). This feature captures neighborhood economic context and proved transformative, boosting tree model R² from 0.60 to 0.68—a 13% improvement—demonstrating the power of thoughtful feature engineering over algorithmic sophistication.