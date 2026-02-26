# Methods & Analysis

## Part 1: City Selection & Screening

Before analyzing real estate transactions, we systematically screened France's major metropolitan areas using climate, demographic, economic, and political criteria. This section describes the screening methodology, key tradeoffs discovered, and justification for the final seven-city selection.

### Data Sources for Screening

Five supplementary datasets enabled city-level comparison across 55 major French cities:

| Source | Dataset | Geography | Variables |
|--------|---------|-----------|-----------|
| Météo France | Climate normals (30-year averages) | 55 major cities | Sunshine hours/year, avg temp (Jan/Jul), rainfall mm/year |
| INSEE | Population census 2020, age brackets | All communes | Population by 10 age brackets; aggregated to city/dept level |
| INSEE | Filosofi 2020, income distribution | All communes | Median disposable income (Q220), affluent threshold (Q320), poverty rate (TP6020) |
| Ministère de l'Intérieur | Presidential election 2022, 1st round | Departments | Vote share by candidate (Macron, Le Pen, Mélenchon, Zemmour) |
| data.gouv.fr | Communes reference database | All communes | Geographic and administrative identifiers (INSEE codes, postal codes, regions) |

All data were downloaded from official French government sources (data.gouv.fr, INSEE.fr, or Météo France) as of early February 2026.

### Screening Criteria & Normalization

Six criteria were chosen to balance climate preference (primary motivation for leaving Paris), demographic suitability (young child in household), economic context (wife's planned business), and family values (political alignment). Each criterion was normalized to a 0–1 scale, where 1 represents the best value and 0 the worst, to enable additive composite scoring.

#### **1. Sunshine Hours (Climate Motivation)**

*Why*: Paris receives ~1,660 sunshine hours annually. Family priority is a warmer, sunnier climate.

*Normalization*: 

$$\text{sunshine\_norm} = \frac{\text{sunshine\_hours} - \min(\text{sunshine\_hours})}{\max(\text{sunshine\_hours}) - \min(\text{sunshine\_hours})}$$

*Range across 55 cities*: 1,577–2,858 hours/year. Mediterranean cities (Marseille, Nice, Montpellier) score highest; Alpine and northern cities lowest.

#### **2. Rainfall (Climate Quality)**

*Why*: High rainfall correlates with cloud cover and fewer sunny days. Lower rainfall compounds the sunshine benefit.

*Note*: Rainfall is weakly correlated with sunshine (r = –0.16) across the 55 cities, indicating they capture different climate dimensions. Both are retained.

*Normalization* (inverted—lower rainfall is better):

$$\text{rainfall\_norm} = 1 - \frac{\text{rainfall\_mm} - \min(\text{rainfall\_mm})}{\max(\text{rainfall\_mm}) - \min(\text{rainfall\_mm})}$$

*Range*: 604–1,043 mm/year. Montpellier (~604 mm, driest) scores highest; alpine/oceanic regions highest rainfall.

#### **3. Working-Age Population Percentage (Demographics)**

*Why*: Cities with higher % of 25–54 year-olds signal economic vitality, better services, and age-cohort compatibility (our child will grow up among similarly-aged peers).

*Calculation*: Aggregated 2020 census population by age bracket to department level, computed % aged 25–54.

*Normalization*:

$$\text{age\_norm} = \frac{\text{pct\_25\_54} - \min(\text{pct\_25\_54})}{\max(\text{pct\_25\_54}) - \min(\text{pct\_25\_54})}$$

*Range*: ~33–41% across departments.

#### **4. Affluent Population (Economic Context)**

*Why*: Wife's pilates/yoga business targets high-income clients. INSEE Filosofi defines "affluent" as households above the Q3 (75th percentile) income threshold.

*Calculation*: Department-level aggregation of Filosofi 2020 "DISP" (disposable income) data; Q320 represents the 80th percentile threshold (most restrictive affluence definition available).

*Normalization*:

$$\text{affluent\_norm} = \frac{\text{income\_Q320} - \min(\text{income\_Q320})}{\max(\text{income\_Q320}) - \min(\text{income\_Q320})}$$

*Range*: €27,700–€42,700 (annual disposable income, 80th percentile). Île-de-France and Alpine regions score highest; coastal and southern regions lower.

#### **5. Poverty Rate (Socioeconomic Health)**

*Why*: Very high poverty rates can indicate economic stress, which indirectly affects business stability and neighborhood amenity.

*Calculation*: Department-level Filosofi 2020 poverty rate (TP6020 = % of households below relative poverty threshold).

*Normalization* (inverted—lower poverty is better):

$$\text{poverty\_norm} = 1 - \frac{\text{poverty\_rate} - \min(\text{poverty\_rate})}{\max(\text{poverty\_rate}) - \min(\text{poverty\_rate})}$$

*Range*: ~10–20% across departments.

#### **6. Political Alignment (Family Values)**

*Why*: Family prioritizes liberal democratic values and immigration acceptance. Far-right vote share (National Rally + Reconquête) serves as a proxy for local political environment.

*Calculation*: 2022 presidential election 1st round, combined vote share for Le Pen (National Rally, RN) and Zemmour (Reconquête, far-right challenger).

*Normalization* (inverted—lower far-right vote is better):

$$\text{far\_right\_norm} = 1 - \frac{\text{pct\_far\_right} - \min(\text{pct\_far\_right})}{\max(\text{pct\_far\_right}) - \min(\text{pct\_far\_right})}$$

*Range*: ~11–24% far-right vote across departments. Mediterranean and some rural departments higher; urban, educated regions lower.

### Composite Scoring Formula

After normalizing all six criteria to 0–1, a weighted composite score was calculated. Weights were iteratively refined through five rounds of experimentation (documented in project status file) to reflect family priorities:

$$\text{composite\_score} = \frac{1}{\sum w_i} \left( w_{\text{far\_right}} \times \text{far\_right\_norm} + w_{\text{sunshine}} \times \text{sunshine\_norm} + w_{\text{rainfall}} \times \text{rainfall\_norm} + w_{\text{affluent}} \times \text{affluent\_norm} + w_{\text{age}} \times \text{age\_norm} + w_{\text{poverty}} \times \text{poverty\_norm} \right)$$

**Final weights** (after family discussion):

| Criterion | Weight | Rationale |
|-----------|--------|-----------|
| Political alignment (far-right norm) | 1.00 | Primary: family values are non-negotiable |
| Sunshine hours (sunshine norm) | 0.75 | Secondary: main motivation for leaving Paris |
| Rainfall (rainfall norm) | 0.75 | Secondary: complements sunshine; captures dry climate advantage |
| Affluent population (affluent norm) | 0.75 | Secondary: wife's business depends on affluent client base |
| Working-age % (age norm) | 0.50 | Tertiary: good demographic signal but not decisive |
| Poverty rate (poverty norm) | 0.25 | Minimal weight: poverty is very correlated with affluence; included for completeness |
| **Total** | **4.00** | Normalized by sum for 0–1 output |

**Weight evolution**: Early iterations weight sunshine heavily (1.0) and found Mediterranean cities (Marseille, Montpellier) ranked #1 due to climate dominance. However, these regions showed higher far-right vote shares and higher poverty, creating tension with family values. Final iteration raised far-right weight to 1.0 (equal to sunshine) and restored affluence weight to 0.75, resulting in Toulouse emerging as #1—a balanced choice trading some sunshine for stronger political alignment and economic context.

### Discovered Tradeoffs

City screening revealed a critical geographic tension:

**Mediterranean Advantage (Climate)**: Marseille and Montpellier offer excellent sunshine (2,600–2,858 hrs/year vs Paris's 1,660), low rainfall, and Mediterranean lifestyle appeal. However, both showed:
- Higher far-right vote share (23–24% vs France ~18% median)
- Higher poverty rates (15–17% vs France ~12% median)
- Lower affluent population income thresholds (bottom quartile nationally)

**Southwest Advantage (Values + Economics)**: Toulouse and Bordeaux offer:
- Lower far-right vote share (12–13%, among France's lowest)
- Higher affluent population thresholds (~€35K vs Mediterranean ~€28K)
- Moderate sunshine (2,000–2,035 hrs/year—still +20–25% above Paris)
- Younger working-age population

**Alpine Advantage (Affluence)**: Annecy combines affluent population (top 5% nationally), strong values alignment, but at the cost of:
- Lowest sunshine in the candidate set (~1,951 hrs/year, below Paris!)
- Highest rainfall (~1,000+ mm/year, severe)
- Smallest real estate market (expected ~2,400 house transactions over 5 years vs Toulouse ~11,700)

This geographic tension reflects a broader France pattern: **sunnier regions tend to be more economically challenged or politically divergent from urban-educated populations**. The analysis cannot resolve this tradeoff—it simply makes it transparent, allowing the family to make an informed choice.

### Final City Selection

Applying the composite scoring formula to all 55 cities and filtering to exclude Île-de-France (departing region) and Corsica (island logistics impractical), seven cities were selected:

| Rank | City | Department | Composite Score | Primary Strengths |
|------|------|-----------|-----------------|-------------------|
| **1** | **Toulouse** | 31 | **0.585** | **Best balance**: strong politics + climate + affluence |
| **2** | **Marseille** | 13 | **0.566** | Strongest sunshine (2,858 hrs), Mediterranean lifestyle |
| **4** | **Lyon** | 69 | 0.542 | Strong all-rounder: politics, affluence, moderate climate |
| **8** | **Annecy** | 74 | 0.517 | Highest affluence (Alpine market), strong politics |
| **9** | **Montpellier** | 34 | 0.502 | Mediterranean sunshine + university city culture |
| **12** | **Bordeaux** | 33 | 0.470 | TGV to Paris, post-boom market dynamics, good politics |
| **–** | **Paris** | 75 | (benchmark) | Included as international mega-city benchmark (excluded from city ranking) |

**Ranking notes:**
- Toulouse, Marseille, Lyon, Montpellier, and Bordeaux were selected as primary candidates, each offering distinct tradeoffs (climate vs. values vs. economics).
- Annecy included despite lower sunshine due to extreme affluence and political alignment, though small sample size expected.
- Paris retained as benchmark—an international mega-city with unique market characteristics (highest prices, most predictable market, strongest income variation across communes).
- Excluded from top 12: cities ranking 3, 5–7, 10–11 were rejected for various reasons (high far-right vote, declining demographics, severe climate deficits, or marginal scores).

### Justification for DVF Analysis Scope

The seven selected departments provide:

1. **Diversity**: Geographic spread from Mediterranean (Marseille) to Alpine (Annecy) to Atlantic (Bordeaux), preventing overfitting to a single regional pattern.

2. **Statistical power**: Expected ~59,000 house transactions across five years (2020–2024), with city-level samples ranging from 2,400 (Annecy, smallest) to 14,700 (Bordeaux, largest). This imbalance is addressed in modeling through city-specific interaction terms (linear regression) and natural tree splits (Random Forest, XGBoost).

3. **Real estate market diversity**: Includes both appreciated markets (Paris petite couronne, Lyon, Annecy) and softening markets (Bordeaux post-TGV boom), revealing how modeling performance varies across market conditions.

4. **Feature richness**: Filosofi 2020 commune-level income data provides substantial within-city income variation (e.g., Paris: €20K–€42K by commune), enabling the model to distinguish neighborhood economic context—a key predictor of house prices.

The seven-department scope balances analytical depth, data availability, and computational tractability, making it suitable for a capstone project.

