#===============================================================================
# CYO Project: Finding Home in France
# HarvardX PH125.9x Data Science Capstone
# Author: Adam Solomon
#===============================================================================

#-------------------------------------------------------------------------------
# 0. SETUP & CONFIGURATION
#-------------------------------------------------------------------------------

# Load required libraries
if(!require(tidyverse)) install.packages("tidyverse", repos = "http://cran.us.r-project.org")
if(!require(readxl)) install.packages("readxl", repos = "http://cran.us.r-project.org")
if(!require(scales)) install.packages("scales", repos = "http://cran.us.r-project.org")
if(!require(lubridate)) install.packages("lubridate", repos = "http://cran.us.r-project.org")
if(!require(here)) install.packages("here", repos = "http://cran.us.r-project.org")
if(!require(randomForest)) install.packages("randomForest", repos = "http://cran.us.r-project.org")
if(!require(xgboost)) install.packages("xgboost", repos = "http://cran.us.r-project.org")

# Set paths
# Run this from the project root directory
PROJECT_ROOT <- here::here()
DATA_RAW <- file.path(PROJECT_ROOT, "data", "raw")
DATA_PROCESSED <- file.path(PROJECT_ROOT, "data")
LOCAL_DATA <- file.path(PROJECT_ROOT, "local_data")

# Display settings
options(scipen = 999)  # Disable scientific notation

#-------------------------------------------------------------------------------
# 1. DATA LOADING
#-------------------------------------------------------------------------------

## 1.1 Load Communes Reference Data ----
communes <- read_csv(
file.path(DATA_RAW, "communes_2025.csv"),
  show_col_types = FALSE
)

## 1.2 Load Population by Age Data ----
# Sheet "COM" contains commune-level data
pop_age <- read_excel(
  file.path(DATA_RAW, "population_age_brackets.xlsx"),
  sheet = "COM"
)

## 1.3 Load Climate Data ----
climate <- read_csv(
  file.path(DATA_RAW, "sunshine_climate_france.csv"),
  show_col_types = FALSE
)

## 1.4 Load DVF Real Estate Data ----
# Note: DVF files are pipe-delimited, stored in local_data
dvf_files <- list.files(LOCAL_DATA, pattern = "ValeursFoncieres.*\\.txt$", full.names = TRUE)

# Function to load a single DVF file
load_dvf_file <- function(filepath) {
  read_delim(
    filepath,
    delim = "|",
    locale = locale(decimal_mark = ","),
    col_types = cols(
      `Code departement` = col_character(),
      `Code postal` = col_character(),
      `Code commune` = col_character()
    ),
    show_col_types = FALSE
  )
}

## 1.5 Load Economic Data (Filosofi 2020) ----

# Department-level income data
income_dept <- read_delim(
  file.path(DATA_RAW, "filosofi_2020", "FILO2020_DISP_DEP.csv"),
  delim = ";",
  show_col_types = FALSE
)

# Department-level poverty data
poverty_dept <- read_delim(
  file.path(DATA_RAW, "filosofi_2020", "FILO2020_DISP_PAUVRES_DEP.csv"),
  delim = ";",
  show_col_types = FALSE
)

#-------------------------------------------------------------------------------
# SECTION 1.6: LOAD PRESIDENTIAL ELECTION DATA
#-------------------------------------------------------------------------------
# Source: Ministère de l'Intérieur - data.gouv.fr
# Dataset: "Election présidentielle des 10 et 24 avril 2022 - Résultats définitifs du 1er tour"
# URL: https://www.data.gouv.fr/datasets/election-presidentielle-des-10-et-24-avril-2022-resultats-definitifs-du-1er-tour
# License: Open Licence 2.0

## 1.6.1 Download election results by department ----
election_url <- "https://www.data.gouv.fr/api/1/datasets/r/18847484-f622-4ccc-baa9-e6b12f749514"
election_file <- file.path(DATA_RAW, "presidentielle_2022_tour1_departements.xlsx")

# Download if not already present
if (!file.exists(election_file)) {
  download.file(election_url, election_file, mode = "wb")
  message("Downloaded: Presidential election 2022 - 1st round by department")
}

## 1.6.2 Load and process election data ----
# The XLSX contains vote counts by candidate for each department
election_raw <- read_excel(election_file)

# Inspect column names (they may be in French with special characters)
# Expected columns include: Code du département, Libellé du département,
# and then pairs of columns for each candidate: Voix, % Voix/Exp

# Process to extract Le Pen (RN) vote percentage
# Note: Marine LE PEN is typically candidate #8 in the official ordering
election_dept <- election_raw |>
  transmute(
    code_departement = as.character(`Code du département`),
    dept_name_election = `Libellé du département`,
    pct_le_pen = as.numeric(`...47`),
    pct_macron = as.numeric(`...35`),
    pct_melenchon = as.numeric(`...59`),
    pct_zemmour = as.numeric(`...53`)
  ) |>
  mutate(code_departement = str_remove(code_departement, "^0"))

# Load all DVF files (uncomment when ready to process full dataset)
# dvf_raw <- map_dfr(dvf_files, load_dvf_file, .id = "source_file")

#-------------------------------------------------------------------------------
# 2. CITY SCREENING & SELECTION
#-------------------------------------------------------------------------------

## 2.1 Define Target Departments ----
# Final selection based on composite scoring (Section 2.9) combining climate,
# demographics, economics, and political alignment criteria.
# Paris (75) included as international mega-city benchmark.
TARGET_DEPTS <- c("13", "31", "33", "34", "69", "74", "75")
TARGET_DEPT_NAMES <- c(
  "13" = "Bouches-du-Rhône (Marseille)",
  "31" = "Haute-Garonne (Toulouse)",
  "33" = "Gironde (Bordeaux)",
  "34" = "Hérault (Montpellier)",
  "69" = "Rhône (Lyon)",
  "74" = "Haute-Savoie (Annecy)",
  "75" = "Paris (benchmark)"
)

## 2.2 Climate Screening ----
# Filter cities meeting sunshine threshold
SUNSHINE_THRESHOLD <- 2000  # hours per year

climate_qualified <- climate |>
  filter(sunshine_hours_annual >= SUNSHINE_THRESHOLD) |>
  arrange(desc(sunshine_hours_annual))

## 2.3 Department/Region Lookup ----
# Get unique department-to-region mapping for joining
dept_region_lookup <- communes |>
  select(code_departement, nom_departement, nom_region) |>
  distinct()

## 2.4 Aggregate Population by Age to Department Level ----

# Calculate population totals and % aged 25-54 by department
pop_by_dept <- pop_age |>
  # Remove the "D" prefix from DEP to match other datasets
  mutate(code_departement = str_remove(DEP, "^D")) |>
  # Group by department and sum all age brackets
  group_by(code_departement) |>
  summarise(
    pop_total = sum(`F0-2` + `F3-5` + `F6-10` + `F11-17` + `F18-24` + 
                      `F25-39` + `F40-54` + `F55-64` + `F65-79` + `F80+` +
                      `H0-2` + `H3-5` + `H6-10` + `H11-17` + `H18-24` + 
                      `H25-39` + `H40-54` + `H55-64` + `H65-79` + `H80+`, na.rm = TRUE),
    pop_25_54 = sum(`F25-39` + `F40-54` + `H25-39` + `H40-54`, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(pct_age_25_54 = pop_25_54 / pop_total * 100)

## 2.5 Create City Screening Dataset ----

# Join climate with department names and population data
city_screening <- climate |>
  # Remove leading zeros from department_code for matching
  mutate(code_departement = str_remove(department_code, "^0")) |>
  # Add department and region names
  left_join(dept_region_lookup, by = "code_departement") |>
  # Add population demographics
  left_join(pop_by_dept, by = "code_departement") |>
  # Clean up columns
  select(
    city_name,
    department_code,
    department_name = nom_departement,
    region_name = nom_region,
    pop_total,
    pct_age_25_54,
    sunshine_hours_annual,
    avg_temp_jan,
    avg_temp_jul,
    rainfall_mm_annual
  ) |>
  arrange(desc(sunshine_hours_annual))

## 2.6 Normalize Screening Variables ----

city_screening <- city_screening |>
  mutate(
    # Normalize sunshine (higher = better) -> 0 to 1
    sunshine_norm = (sunshine_hours_annual - min(sunshine_hours_annual, na.rm = TRUE)) /
      (max(sunshine_hours_annual, na.rm = TRUE) - min(sunshine_hours_annual, na.rm = TRUE)),
    
    # Normalize age demographic (higher % working age = better) -> 0 to 1
    age_norm = (pct_age_25_54 - min(pct_age_25_54, na.rm = TRUE)) /
      (max(pct_age_25_54, na.rm = TRUE) - min(pct_age_25_54, na.rm = TRUE)),
    
    # Normalize rainfall (lower = better, so invert) -> 0 to 1
    rainfall_norm = 1 - (rainfall_mm_annual - min(rainfall_mm_annual, na.rm = TRUE)) /
      (max(rainfall_mm_annual, na.rm = TRUE) - min(rainfall_mm_annual, na.rm = TRUE))
  )

# Verify the new columns
city_screening |>
  select(city_name, sunshine_hours_annual, sunshine_norm, 
         pct_age_25_54, age_norm, 
         rainfall_mm_annual, rainfall_norm) |>
  head(10)

## 2.7 Add Economic Indicators ----

# Extract and join economic metrics to city_screening
economic_metrics <- income_dept |>
  select(CODGEO, Q220, Q320) |>
  left_join(
    poverty_dept |> select(CODGEO, TP6020),
    by = "CODGEO"
  ) |>
  # Normalize department code to match city_screening (remove leading zeros)
  mutate(code_departement = str_remove(CODGEO, "^0")) |>
  select(-CODGEO)

# Join to city_screening and convert to numeric
city_screening <- city_screening |>
  mutate(code_departement = str_remove(department_code, "^0")) |>
  left_join(economic_metrics, by = "code_departement") |>
  mutate(
    median_income = as.numeric(Q220),
    affluent_income = as.numeric(Q320),
    poverty_rate = as.numeric(TP6020)
  ) |>
  select(-Q220, -Q320, -TP6020, -code_departement)

# Verify: cities with most affluent populations
city_screening |>
  select(city_name, department_name, median_income, affluent_income, poverty_rate) |>
  arrange(desc(affluent_income)) |>
  head(15)

# Normalize economic indicators
city_screening <- city_screening |>
  mutate(
    # Normalize affluent income (higher = better for wife's business)
    affluent_norm = (affluent_income - min(affluent_income, na.rm = TRUE)) /
      (max(affluent_income, na.rm = TRUE) - min(affluent_income, na.rm = TRUE)),
    
    # Normalize poverty rate (lower = better, so invert)
    poverty_norm = 1 - (poverty_rate - min(poverty_rate, na.rm = TRUE)) /
      (max(poverty_rate, na.rm = TRUE) - min(poverty_rate, na.rm = TRUE))
  )

# Verify target cities
city_screening |>
  filter(city_name %in% c("Marseille", "Toulouse", "Bordeaux", "Montpellier", 
                           "Lyon", "Annecy", "Paris")) |>
  select(city_name, affluent_income, affluent_norm, poverty_rate, poverty_norm)

#-------------------------------------------------------------------------------
# SECTION 2.8: ADD POLITICAL INDICATORS TO CITY SCREENING
#-------------------------------------------------------------------------------

## 2.8.1 Join election data to city_screening ----
city_screening <- city_screening |>
  left_join(
    election_dept |> select(code_departement, pct_le_pen, pct_zemmour),
    by = c("department_code" = "code_departement")
  ) |>
  # Calculate combined far-right vote (RN + Reconquête)
  mutate(
    pct_far_right = pct_le_pen + pct_zemmour
  )

## 2.8.2 Normalize political indicator ----
# Lower far-right vote = better (for this family's preferences)
# Inverted normalization: 0 = highest far-right, 1 = lowest far-right
city_screening <- city_screening |>
  mutate(
    far_right_norm = 1 - (pct_far_right - min(pct_far_right, na.rm = TRUE)) / 
      (max(pct_far_right, na.rm = TRUE) - min(pct_far_right, na.rm = TRUE))
  )

## 2.8.3 Verify the join for target cities ----
city_screening |>
  filter(department_code %in% TARGET_DEPTS) |>
  select(city_name, department_code, pct_le_pen, pct_zemmour, pct_far_right, far_right_norm) |>
  arrange(desc(pct_far_right))

#-------------------------------------------------------------------------------
# SECTION 2.9: COMPOSITE SCORING
#-------------------------------------------------------------------------------

## 2.9.1 Define weights ----
# Political alignment is primary criterion (family values)
# Climate factors (sunshine, rainfall) and affluence are secondary
# Age demographics tertiary, poverty minimal weight
# Weights iterated through multiple rounds — see project_status_region_selection.md
weights <- c(
  far_right = 1,
  sunshine  = 0.75,
  rainfall  = 0.75,
  affluent  = 0.75,
  age       = 0.5,
  poverty   = 0.25
)

## 2.9.2 Calculate weighted composite score ----
city_screening <- city_screening |>
  mutate(
    composite_score = (
      sunshine_norm  * weights["sunshine"] +
      rainfall_norm  * weights["rainfall"] +
      affluent_norm  * weights["affluent"] +
      far_right_norm * weights["far_right"] +
      age_norm       * weights["age"] +
      poverty_norm   * weights["poverty"]
    ) / sum(weights)
  )

## 2.9.3 Generate ranked city list ----
# Clean ranking: exclude Île-de-France and Corsica (personal constraints)
# Île-de-France: departing region; Corsica: island logistics impractical
city_screening |>
  filter(!region_name %in% c("Île-de-France", "Corse")) |>
  arrange(desc(composite_score)) |>
  mutate(rank = row_number()) |>
  select(rank, city_name, department_name, department_code, composite_score,
         sunshine_norm, rainfall_norm, affluent_norm, far_right_norm) |>
  print(n = 15)

## 2.9.4 Confirm target cities from composite ranking ----
# Final selection: Toulouse, Lyon, Annecy, Montpellier, Bordeaux + Paris benchmark
# Selection justified by composite score ranking and qualitative factors
# (TGV connections, international airports, university/tech presence)
city_screening |>
  filter(department_code %in% TARGET_DEPTS) |>
  arrange(desc(composite_score)) |>
  select(city_name, department_name, department_code, composite_score,
         sunshine_norm, rainfall_norm, affluent_norm, far_right_norm)

#-------------------------------------------------------------------------------
# 3. DVF DATA LOADING & FILTERING
#-------------------------------------------------------------------------------
# Load 2020-2024 DVF transaction files, filter to target communes (houses only),
# and join commune metadata (target_city, ring). Saves filtered dataset to CSV
# so subsequent runs can skip this step.

## 3.1 Load Commune Filter Lookup ----
# 159 communes across 7 city groups (ring 0 = city proper, ring 1 = adjacent)
# Includes Paris suburb departments (92, 93, 94)
commune_lookup <- read_csv(
  file.path(DATA_PROCESSED, "commune_filter_lookup.csv"),
  col_types = cols(
    dept_code = col_character(),
    commune_code = col_character(),
    insee_code = col_character()
  )
)

target_dept_codes <- unique(commune_lookup$dept_code)
cat("Target departments:", paste(sort(target_dept_codes), collapse = ", "), "\n")
cat("Total communes to match:", nrow(commune_lookup), "\n")

## 3.2 Load and Filter DVF Files ----
# Process each year individually to manage memory (~500-600MB per file)
# Pre-filter by department, then match exact communes

dvf_files_to_load <- list.files(
  LOCAL_DATA,
  pattern = "ValeursFoncieres-(2020|2021|2022|2023|2024)",
  full.names = TRUE
)
cat("DVF files to load:\n")
cat(paste(" ", basename(dvf_files_to_load)), sep = "\n")

dvf_filtered_list <- map(dvf_files_to_load, function(f) {
  cat("\nProcessing:", basename(f), "...")

  raw <- load_dvf_file(f)
  cat(" loaded", format(nrow(raw), big.mark = ","), "rows ->")

  # Filter: target departments + houses + sales, then match communes
  filtered <- raw |>
    filter(
      `Code departement` %in% target_dept_codes,
      `Type local` == "Maison",
      `Nature mutation` == "Vente"
    ) |>
    mutate(
      insee_code = paste0(
        `Code departement`,
        str_pad(`Code commune`, 3, pad = "0")
      )
    ) |>
    filter(insee_code %in% commune_lookup$insee_code)

  cat(" filtered to", format(nrow(filtered), big.mark = ","), "house sales\n")
  filtered
})

## 3.3 Combine All Years ----
dvf_houses <- bind_rows(dvf_filtered_list)
cat("\n=== Total filtered house sales:", format(nrow(dvf_houses), big.mark = ","), "===\n")

# Free memory
rm(dvf_filtered_list)

## 3.4 Join Commune Metadata ----
dvf_houses <- dvf_houses |>
  left_join(
    commune_lookup |> select(insee_code, target_city, ring, commune_name),
    by = "insee_code"
  )

## 3.5 Parse Dates ----
dvf_houses <- dvf_houses |>
  mutate(
    date_mutation = dmy(`Date mutation`),
    year = year(date_mutation),
    month = month(date_mutation),
    quarter = quarter(date_mutation)
  )

## 3.6 Validation Summary ----
cat("\n--- Transactions by city ---\n")
dvf_houses |> count(target_city, sort = TRUE) |> print()

cat("\n--- Transactions by year ---\n")
dvf_houses |> count(year) |> print()

cat("\n--- Transactions by ring ---\n")
dvf_houses |> count(ring) |> print()

## 3.7 Save Filtered Dataset ----
write_csv(dvf_houses, file.path(DATA_PROCESSED, "dvf_houses_filtered.csv"))
cat("\nSaved:", file.path(DATA_PROCESSED, "dvf_houses_filtered.csv"), "\n")

#-------------------------------------------------------------------------------
# 3B. DATA CLEANING
#-------------------------------------------------------------------------------
# Raw filtered data: 68,006 rows
# Issues found in diagnostic:
#   - 5,302 multi-row mutation groups (12,175 rows) — same house on multiple parcels
#   - 64 NA prices, 7,786 NA land areas (11.4%)
#   - Outliers: symbolic €1 sales, €84M max, 1 m² built area, 54 rooms

n_start <- nrow(dvf_houses)

## 3B.1 Deduplicate Multi-Parcel Rows ----
# DVF repeats house rows when property spans multiple cadastral parcels.
# Same price/surface/rooms, different Section/No plan. Sum land area across parcels.
dvf_houses <- dvf_houses |>
  group_by(`No disposition`, `Date mutation`, `Valeur fonciere`,
           `Code departement`, `Code commune`) |>
  summarise(
    across(c(`Surface reelle bati`, `Nombre pieces principales`), max),
    `Surface terrain` = sum(`Surface terrain`, na.rm = TRUE),
    across(c(`Code postal`, Commune, insee_code, target_city, ring,
             commune_name, date_mutation, year, month, quarter,
             `No voie`, `Type de voie`, Voie), first),
    n_parcels = n(),
    .groups = "drop"
  )

cat("Dedup:", n_start, "->", nrow(dvf_houses),
    "(removed", n_start - nrow(dvf_houses), "duplicate parcel rows)\n")

## 3B.2 Drop Missing Prices ----
dvf_houses <- dvf_houses |>
  filter(!is.na(`Valeur fonciere`))

cat("After dropping NA prices:", nrow(dvf_houses), "\n")

## 3B.3 Outlier Filtering ----
# Conservative bounds for French houses in major metros
dvf_houses <- dvf_houses |>
  filter(
    `Valeur fonciere` >= 10000,          # Exclude symbolic/tax-free transfers
    `Valeur fonciere` <= 5000000,        # Exclude mega-estates
    `Surface reelle bati` >= 20,         # Min plausible house
    `Surface reelle bati` <= 1000,       # Max plausible house (not château)
    `Nombre pieces principales` >= 1,    # At least 1 room
    `Nombre pieces principales` <= 20    # Max plausible rooms
  )

cat("After outlier filtering:", nrow(dvf_houses), "\n")

## 3B.4 Feature Engineering ----
dvf_houses <- dvf_houses |>
  mutate(
    prix_m2 = `Valeur fonciere` / `Surface reelle bati`,
    has_land = !is.na(`Surface terrain`) & `Surface terrain` > 0
  )

# Remove extreme price/m² (catches remaining data quality issues)
q01 <- quantile(dvf_houses$prix_m2, 0.01, na.rm = TRUE)
q99 <- quantile(dvf_houses$prix_m2, 0.99, na.rm = TRUE)
cat("Price/m² 1st-99th percentile: ", round(q01), "-", round(q99), "EUR/m²\n")

dvf_houses <- dvf_houses |>
  filter(prix_m2 >= q01, prix_m2 <= q99)

cat("After prix_m2 trimming:", nrow(dvf_houses), "\n")

## 3B.5 Cleaning Summary ----
cat("\n=== CLEANING SUMMARY ===\n")
cat("Started:", n_start, "-> Final:", nrow(dvf_houses),
    "(", round((1 - nrow(dvf_houses)/n_start) * 100, 1), "% removed)\n")

cat("\n--- Final distribution by city ---\n")
dvf_houses |> count(target_city, sort = TRUE) |> print()

cat("\n--- Final distribution by year ---\n")
dvf_houses |> count(year) |> print()

cat("\n--- Price summary by city ---\n")
dvf_houses |>
  group_by(target_city) |>
  summarise(
    n = n(),
    median_price = median(`Valeur fonciere`),
    median_m2 = median(prix_m2),
    median_surface = median(`Surface reelle bati`),
    .groups = "drop"
  ) |>
  arrange(desc(median_m2)) |>
  print()

## 3B.6 Save Clean Dataset ----
write_csv(dvf_houses, file.path(DATA_PROCESSED, "dvf_houses_clean.csv"))
cat("\nSaved:", file.path(DATA_PROCESSED, "dvf_houses_clean.csv"), "\n")

## 3B.7 Join Commune-Level Income Data ----
# Filosofi 2020 commune-level median income gives the model neighborhood-level
# economic context. Previously we only had department-level income (same value
# for all 159 communes within a department). This captures within-city variation.

filosofi_commune <- read_excel(
  file.path(DATA_RAW, "filosofi_2020_commune", "base-cc-filosofi-2020-geo2023.xlsx"),
  sheet = "COM",
  skip = 5
) |>
  select(
    code_commune_insee = CODGEO,
    median_income_commune = MED20,
    poverty_rate_commune = TP6020
  ) |>
  mutate(across(c(median_income_commune, poverty_rate_commune), as.numeric))

dvf_houses <- dvf_houses |>
  mutate(insee_code = as.character(insee_code)) |>
  left_join(filosofi_commune, by = c("insee_code" = "code_commune_insee"))

cat("Median income coverage:",
    sum(!is.na(dvf_houses$median_income_commune)), "/", nrow(dvf_houses),
    "transactions matched\n")

# Quick sanity check: income should vary within cities
dvf_houses |>
  group_by(target_city) |>
  summarise(
    min_income = min(median_income_commune, na.rm = TRUE),
    median_income = median(median_income_commune, na.rm = TRUE),
    max_income = max(median_income_commune, na.rm = TRUE),
    n_communes = n_distinct(insee_code),
    .groups = "drop"
  ) |>
  print()

#-------------------------------------------------------------------------------
# 3C. EXPLORATORY DATA ANALYSIS
#-------------------------------------------------------------------------------
# Examine distributions, city comparisons, temporal trends, and feature
# relationships before modeling. All plots use the clean dataset (59,373 rows).

# Consistent city color palette (ordered roughly south→north + benchmark)
city_colors <- c(
  "Marseille"   = "#E63946",  # warm red — Mediterranean
  "Montpellier" = "#F4A261",  # orange
  "Toulouse"    = "#E9C46A",  # gold
  "Bordeaux"    = "#2A9D8F",  # teal — Atlantic
  "Lyon"        = "#457B9D",  # steel blue
  "Annecy"      = "#1D3557",  # navy — Alpine
  "Paris"       = "#6C757D"   # grey — benchmark
)

# Reorder target_city as factor for consistent plot ordering (by median prix_m2)
city_order <- dvf_houses |>
  group_by(target_city) |>
  summarise(med = median(prix_m2), .groups = "drop") |>
  arrange(med) |>
  pull(target_city)

dvf_houses <- dvf_houses |>
  mutate(target_city = factor(target_city, levels = city_order))

## 3C.1 Overall Dataset Summary ----
cat("\n=== EXPLORATORY DATA ANALYSIS ===\n")
cat("Dataset:", nrow(dvf_houses), "house transactions across",
    n_distinct(dvf_houses$target_city), "cities,",
    min(dvf_houses$year), "-", max(dvf_houses$year), "\n\n")

# Summary statistics for key numeric variables
cat("--- Key variable summaries ---\n")
dvf_houses |>
  summarise(
    across(
      c(`Valeur fonciere`, `Surface reelle bati`,
        `Nombre pieces principales`, prix_m2),
      list(
        median = ~median(., na.rm = TRUE),
        mean   = ~mean(., na.rm = TRUE),
        sd     = ~sd(., na.rm = TRUE),
        min    = ~min(., na.rm = TRUE),
        max    = ~max(., na.rm = TRUE)
      )
    )
  ) |>
  pivot_longer(everything(),
               names_to = c("variable", "stat"),
               names_pattern = "(.+)_(.+)") |>
  pivot_wider(names_from = stat, values_from = value) |>
  print(n = Inf)

## 3C.2 Price Distribution by City ----
# Density plot of log10(price) — log scale handles the right-skewed distribution
ggplot(dvf_houses, aes(x = `Valeur fonciere`, fill = target_city)) +
  geom_density(alpha = 0.5) +
  scale_x_log10(labels = label_comma(big.mark = " ", prefix = "€")) +
  scale_fill_manual(values = city_colors) +
  labs(
    title = "House Price Distribution by City",
    subtitle = "Log-scaled density — clean dataset (2020–2024)",
    x = "Sale Price (log scale)", y = "Density", fill = "City"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

## 3C.3 Price per m² by City ----
# Box plot — the key metric for cross-city comparison
ggplot(dvf_houses, aes(x = target_city, y = prix_m2, fill = target_city)) +
  geom_boxplot(outlier.alpha = 0.1, outlier.size = 0.5) +
  scale_y_continuous(labels = label_comma(big.mark = " ", suffix = " €/m²")) +
  scale_fill_manual(values = city_colors) +
  labs(
    title = "Price per m² by City",
    subtitle = "Box plot of €/m² — median, IQR, and outliers",
    x = NULL, y = "Price per m²"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")

## 3C.4 Temporal Trends — Median Price/m² by Year ----
yearly_city <- dvf_houses |>
  group_by(target_city, year) |>
  summarise(
    n = n(),
    median_prix_m2 = median(prix_m2),
    median_price = median(`Valeur fonciere`),
    .groups = "drop"
  )

ggplot(yearly_city, aes(x = year, y = median_prix_m2,
                        color = target_city, group = target_city)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5) +
  scale_y_continuous(labels = label_comma(big.mark = " ", suffix = " €/m²")) +
  scale_color_manual(values = city_colors) +
  labs(
    title = "Median Price per m² Over Time",
    subtitle = "Annual trend by city (2020–2024)",
    x = "Year", y = "Median €/m²", color = "City"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

# Print the underlying data
cat("\n--- Median price/m² by city and year ---\n")
yearly_city |>
  select(target_city, year, n, median_prix_m2) |>
  pivot_wider(names_from = year, values_from = c(n, median_prix_m2)) |>
  print()

## 3C.5 Transaction Volume Over Time ----
ggplot(yearly_city, aes(x = year, y = n, fill = target_city)) +
  geom_col(position = "dodge") +
  scale_fill_manual(values = city_colors) +
  scale_y_continuous(labels = label_comma()) +
  labs(
    title = "House Transaction Volume by City and Year",
    subtitle = "Note: 2020 includes only second semester",
    x = "Year", y = "Transactions", fill = "City"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

## 3C.6 Built Surface Distribution ----
ggplot(dvf_houses, aes(x = `Surface reelle bati`, fill = target_city)) +
  geom_histogram(binwidth = 10, alpha = 0.7, position = "identity") +
  facet_wrap(~target_city, scales = "free_y", ncol = 2) +
  scale_fill_manual(values = city_colors) +
  scale_x_continuous(labels = label_comma(suffix = " m²")) +
  labs(
    title = "Distribution of Built Surface Area by City",
    x = "Built Surface (m²)", y = "Count", fill = "City"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "none")

## 3C.7 Ring Effect — City Center vs Suburbs ----
dvf_houses <- dvf_houses |>
  mutate(ring_label = ifelse(ring == 0, "City proper", "Adjacent suburb"))

cat("\n--- Price/m² by ring and city ---\n")
dvf_houses |>
  group_by(target_city, ring_label) |>
  summarise(
    n = n(),
    median_prix_m2 = median(prix_m2),
    median_surface = median(`Surface reelle bati`),
    .groups = "drop"
  ) |>
  print(n = Inf)

ggplot(dvf_houses, aes(x = ring_label, y = prix_m2, fill = ring_label)) +
  geom_boxplot(outlier.alpha = 0.1, outlier.size = 0.5) +
  facet_wrap(~target_city, scales = "free_y", ncol = 4) +
  scale_y_continuous(labels = label_comma(big.mark = " ", suffix = " €/m²")) +
  scale_fill_brewer(palette = "Set2") +
  labs(
    title = "Price per m² — City Center vs Adjacent Suburbs",
    x = NULL, y = "Price per m²", fill = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        axis.text.x = element_blank())

## 3C.8 Room Count Distribution ----
ggplot(dvf_houses, aes(x = `Nombre pieces principales`, fill = target_city)) +
  geom_bar(position = "dodge") +
  facet_wrap(~target_city, scales = "free_y", ncol = 2) +
  scale_fill_manual(values = city_colors) +
  labs(
    title = "Number of Rooms per House by City",
    x = "Number of Main Rooms", y = "Count", fill = "City"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "none")

## 3C.9 Price vs Surface Scatter ----
# Sample for readability (full dataset makes dense scatter)
set.seed(42)
scatter_sample <- dvf_houses |> slice_sample(n = min(5000, nrow(dvf_houses)))

ggplot(scatter_sample, aes(x = `Surface reelle bati`, y = `Valeur fonciere`,
                           color = target_city)) +
  geom_point(alpha = 0.3, size = 1) +
  scale_y_continuous(labels = label_comma(big.mark = " ", prefix = "€")) +
  scale_x_continuous(labels = label_comma(suffix = " m²")) +
  scale_color_manual(values = city_colors) +
  labs(
    title = "Sale Price vs Built Surface Area",
    subtitle = paste0("Random sample of ", nrow(scatter_sample), " transactions"),
    x = "Built Surface (m²)", y = "Sale Price", color = "City"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

## 3C.10 Feature Correlations ----
cat("\n--- Correlation matrix (numeric features) ---\n")
numeric_features <- dvf_houses |>
  select(`Valeur fonciere`, `Surface reelle bati`,
         `Nombre pieces principales`, `Surface terrain`, prix_m2, year) |>
  rename(
    price = `Valeur fonciere`,
    surface = `Surface reelle bati`,
    rooms = `Nombre pieces principales`,
    land = `Surface terrain`,
    price_m2 = prix_m2
  )

cor_matrix <- cor(numeric_features, use = "pairwise.complete.obs")
round(cor_matrix, 2) |> print()

## 3C.11 Quarterly Trend (Seasonality Check) ----
quarterly <- dvf_houses |>
  mutate(yq = paste0(year, "-Q", quarter)) |>
  group_by(yq, year, quarter) |>
  summarise(
    n = n(),
    median_prix_m2 = median(prix_m2),
    .groups = "drop"
  ) |>
  arrange(year, quarter)

ggplot(quarterly, aes(x = reorder(yq, year + quarter/10), y = n)) +
  geom_col(fill = "#457B9D") +
  geom_line(aes(y = median_prix_m2 * max(quarterly$n) / max(quarterly$median_prix_m2),
                group = 1), color = "#E63946", linewidth = 1) +
  scale_y_continuous(
    labels = label_comma(),
    sec.axis = sec_axis(
      ~ . * max(quarterly$median_prix_m2) / max(quarterly$n),
      labels = label_comma(suffix = " €/m²"),
      name = "Median €/m²"
    )
  ) +
  labs(
    title = "Quarterly Transaction Volume and Median Price/m²",
    subtitle = "Bars = transaction count, red line = median price per m²",
    x = NULL, y = "Transactions"
  ) +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

## 3C.12 EDA Summary ----
cat("\n=== EDA KEY FINDINGS ===\n")
cat("1. Paris and Annecy are the most expensive markets (~€5,500-8,300/m²)\n")
cat("2. Toulouse offers the lowest price/m² (~€3,500) among target cities\n")
cat("3. Transaction volume peaked in 2021 (post-COVID rebound) and has declined since\n")
cat("4. Strong positive correlation between surface area and price (as expected)\n")
cat("5. City-proper typically commands a premium over adjacent suburbs\n")
cat("6. Most houses have 3-5 main rooms across all cities\n")
cat("\nEDA complete. Proceeding to modeling.\n")

#-------------------------------------------------------------------------------
# 4. MODELING APPROACH
#-------------------------------------------------------------------------------

## 4.1 Train/Test Split ----
# Temporal split: train on 2020-2023, test on 2024.
# Real estate prices are path-dependent — random splitting would leak
# future market conditions into training data.

train <- dvf_houses |> filter(year <= 2023)
test  <- dvf_houses |> filter(year == 2024)

cat("\n=== TRAIN/TEST SPLIT ===\n")
cat("Train (2020-2023):", nrow(train), "rows (",
    round(nrow(train) / nrow(dvf_houses) * 100, 1), "%)\n")
cat("Test  (2024):     ", nrow(test), "rows (",
    round(nrow(test) / nrow(dvf_houses) * 100, 1), "%)\n")

cat("\n--- Train set by city ---\n")
train |> count(target_city, name = "n_train") |> print()

cat("\n--- Test set by city ---\n")
test |> count(target_city, name = "n_test") |> print()

cat("\n--- Train set by year ---\n")
train |> count(year) |> print()

## 4.2 Feature Preparation ----
# Select modeling features and target variable.
# Exclude prix_m2 (derived from target — would leak) and address/ID columns.
#
# SAMPLE SIZE IMBALANCE: Bordeaux has ~14K training rows vs Annecy ~1.8K.
# A pooled model's learned relationships (e.g., price ~ surface slope) will
# be dominated by high-volume cities. To address this:
#   - Linear regression: use target_city interaction terms so each city
#     learns its own coefficients (e.g., target_city * Surface reelle bati)
#   - Tree models (RF/XGBoost): handle city-specific patterns naturally
#     via splits — no special treatment needed
#   - All models: evaluate per-city RMSE/MAE alongside overall metrics
#     to confirm no city is systematically underserved

model_features <- c(
  "Surface reelle bati",       # built area (m²)
  "Nombre pieces principales", # number of rooms
  "Surface terrain",           # land area (m²)
  "target_city",               # city (factor, 7 levels)
  "ring",                      # 0 = city proper, 1 = adjacent suburb
  "year",                      # transaction year
  "quarter",                   # seasonality (1-4)
  "has_land",                  # whether property has land
  "median_income_commune"      # commune-level median income (Filosofi 2020)
)
target_var <- "Valeur fonciere"

# Ensure proper types for modeling
train <- train |>
  mutate(
    target_city = factor(target_city),
    ring = as.integer(ring),
    quarter = as.integer(quarter),
    has_land = as.integer(has_land)
  )

test <- test |>
  mutate(
    target_city = factor(target_city, levels = levels(train$target_city)),
    ring = as.integer(ring),
    quarter = as.integer(quarter),
    has_land = as.integer(has_land)
  )

# Build model matrices (target + features only)
# Rename to clean names — avoids backtick issues with randomForest/xgboost
clean_names <- c(
  price   = "Valeur fonciere",
  surface = "Surface reelle bati",
  rooms   = "Nombre pieces principales",
  land    = "Surface terrain",
  median_income = "median_income_commune"
)

train_model <- train |>
  select(all_of(c(target_var, model_features))) |>
  rename(!!!clean_names)
test_model <- test |>
  select(all_of(c(target_var, model_features))) |>
  rename(!!!clean_names)

cat("\n=== FEATURE PREPARATION ===\n")
cat("Target:", target_var, "\n")
cat("Features (", length(model_features), "):", paste(model_features, collapse = ", "), "\n")
cat("Train matrix:", nrow(train_model), "x", ncol(train_model), "\n")
cat("Test matrix: ", nrow(test_model), "x", ncol(test_model), "\n")

cat("\n--- Feature summary (train) ---\n")
str(train_model)

## 4.3 Evaluation Metrics ----
# Define once, use for all models. Collect results in a single tibble.

calc_rmse <- function(actual, predicted) {
  sqrt(mean((actual - predicted)^2, na.rm = TRUE))
}

calc_mae <- function(actual, predicted) {
  mean(abs(actual - predicted), na.rm = TRUE)
}

calc_r2 <- function(actual, predicted) {
  1 - sum((actual - predicted)^2) / sum((actual - mean(actual))^2)
}

# Evaluate a model's predictions: overall + per-city breakdown
evaluate_model <- function(actual, predicted, city, model_name) {
  overall <- tibble(
    model = model_name,
    scope = "Overall",
    n = length(actual),
    rmse = calc_rmse(actual, predicted),
    mae  = calc_mae(actual, predicted),
    r2   = calc_r2(actual, predicted)
  )
  per_city <- tibble(actual, predicted, city) |>
    group_by(city) |>
    summarise(
      n = n(),
      rmse = calc_rmse(actual, predicted),
      mae  = calc_mae(actual, predicted),
      r2   = calc_r2(actual, predicted),
      .groups = "drop"
    ) |>
    mutate(model = model_name) |>
    rename(scope = city) |>
    select(model, scope, n, rmse, mae, r2)
  bind_rows(overall, per_city)
}

# Master results table — each model appends to this
all_results <- tibble()

## 4.4 Linear Regression (Baseline) ----
# Interaction terms: target_city × Surface reelle bati gives each city
# its own price-per-m² slope. target_city × ring gives each city its own
# urban premium. Shared coefficients for rooms, land, year, quarter.

lm_formula <- price ~
  target_city * (surface + ring) +
  rooms +
  land +
  year +
  quarter +
  has_land +
  median_income

cat("\n=== LINEAR REGRESSION ===\n")
cat("Formula:", deparse(lm_formula, width.cutoff = 200), "\n\n")

lm_fit <- lm(lm_formula, data = train_model)

cat("--- Model summary ---\n")
cat("Coefficients:", length(coef(lm_fit)), "\n")
cat("R² (train):", round(summary(lm_fit)$r.squared, 4), "\n")
cat("Adj R² (train):", round(summary(lm_fit)$adj.r.squared, 4), "\n\n")

# Predict on test set
lm_pred_test <- predict(lm_fit, newdata = test_model)

# Evaluate
lm_results <- evaluate_model(
  actual     = test_model$price,
  predicted  = lm_pred_test,
  city       = as.character(test_model$target_city),
  model_name = "Linear Regression"
)
all_results <- bind_rows(all_results, lm_results)

cat("--- Test set performance ---\n")
lm_results |> print(n = Inf)

cat("\n--- Top 10 coefficients by magnitude ---\n")
coef_tbl <- tibble(
  term = names(coef(lm_fit)),
  estimate = coef(lm_fit)
) |>
  filter(!is.na(estimate)) |>
  arrange(desc(abs(estimate)))
coef_tbl |> head(10) |> print()

## 4.5 Random Forest ----
# RF handles factor variables and non-linear relationships natively.
# No interaction terms needed — tree splits discover them automatically.
# This is the key advantage over linear regression for city-specific patterns.

cat("\n=== RANDOM FOREST ===\n")

set.seed(42)
rf_fit <- randomForest(
  price ~ .,
  data = train_model,
  ntree = 500,
  importance = TRUE
)

cat("Trees:", rf_fit$ntree, "\n")
cat("Variables tried at each split:", rf_fit$mtry, "\n")
cat("R2 (OOB):", round(1 - rf_fit$mse[rf_fit$ntree] /
      var(train_model$price), 4), "\n\n")

# Predict on test set
rf_pred_test <- predict(rf_fit, newdata = test_model)

# Evaluate
rf_results <- evaluate_model(
  actual     = test_model$price,
  predicted  = rf_pred_test,
  city       = as.character(test_model$target_city),
  model_name = "Random Forest"
)
all_results <- bind_rows(all_results, rf_results)

cat("--- Test set performance ---\n")
rf_results |> print(n = Inf)

# Variable importance
cat("\n--- Variable importance (% increase in MSE when permuted) ---\n")
importance(rf_fit) |>
  as.data.frame() |>
  rownames_to_column("feature") |>
  arrange(desc(`%IncMSE`)) |>
  print()

## 4.6 XGBoost ----
# Gradient-boosted trees — requires numeric matrix input.
# One-hot encode target_city; XGBoost learns interactions via boosting.

cat("\n=== XGBOOST ===\n")

# Build numeric matrices (one-hot encode factors)
train_x <- model.matrix(
  ~ surface + rooms + land + target_city + ring +
    year + quarter + has_land + median_income,
  data = train_model
)[, -1]

test_x <- model.matrix(
  ~ surface + rooms + land + target_city + ring +
    year + quarter + has_land + median_income,
  data = test_model
)[, -1]

train_y <- train_model$price
test_y  <- test_model$price

dtrain <- xgb.DMatrix(data = train_x, label = train_y)
dtest  <- xgb.DMatrix(data = test_x, label = test_y)

# Train with early stopping to prevent overfitting
set.seed(42)
xgb_fit <- xgb.train(
  params = list(
    objective = "reg:squarederror",
    max_depth = 6,
    eta = 0.1,
    subsample = 0.8,
    colsample_bytree = 0.8
  ),
  data = dtrain,
  nrounds = 1000,
  evals = list(train = dtrain, test = dtest),
  early_stopping_rounds = 50,
  verbose = 0
)

# Extract best iteration from evaluation log
xgb_log <- attr(xgb_fit, "evaluation_log")
xgb_best_iter <- which.min(xgb_log$test_rmse)
xgb_best_rmse <- xgb_log$test_rmse[xgb_best_iter]
cat("Stopped at:", nrow(xgb_log), "rounds (best:", xgb_best_iter, ")\n")
cat("Best test RMSE:", round(xgb_best_rmse, 0), "\n\n")

# Predict on test set
xgb_pred_test <- predict(xgb_fit, dtest)

# Evaluate
xgb_results <- evaluate_model(
  actual     = test_y,
  predicted  = xgb_pred_test,
  city       = as.character(test_model$target_city),
  model_name = "XGBoost"
)
all_results <- bind_rows(all_results, xgb_results)

cat("--- Test set performance ---\n")
xgb_results |> print(n = Inf)

# Feature importance
cat("\n--- XGBoost feature importance (top 10 by gain) ---\n")
xgb.importance(model = xgb_fit) |> head(10) |> print()

## 4.7 K-Means Clustering ----
# [TODO]

#-------------------------------------------------------------------------------
# 5. RESULTS
#-------------------------------------------------------------------------------

## 5.1 EDA Visualizations ----
# [TODO: Create key visualizations]

## 5.2 Model Comparison ----
# [TODO: Compare model performance]

## 5.3 City Rankings ----
# [TODO: Generate final rankings]

#-------------------------------------------------------------------------------
# 6. UTILITY FUNCTIONS
#-------------------------------------------------------------------------------

# Format currency in euros
format_eur <- function(x) {
  scales::dollar(x, prefix = "", suffix = " EUR", big.mark = " ")
}

# Summary statistics for numeric columns
summary_stats <- function(df, col) {
  df |>
    summarise(
      n = n(),
      mean = mean({{ col }}, na.rm = TRUE),
      median = median({{ col }}, na.rm = TRUE),
      sd = sd({{ col }}, na.rm = TRUE),
      min = min({{ col }}, na.rm = TRUE),
      max = max({{ col }}, na.rm = TRUE),
      q25 = quantile({{ col }}, 0.25, na.rm = TRUE),
      q75 = quantile({{ col }}, 0.75, na.rm = TRUE)
    )
}

#-------------------------------------------------------------------------------
# END OF SCRIPT
#-------------------------------------------------------------------------------