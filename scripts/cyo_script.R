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

# Preview the data for target departments
election_dept |>
  filter(code_departement %in% TARGET_DEPTS) |>
  select(code_departement, dept_name_election, pct_le_pen, pct_macron, pct_melenchon)

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

#-------------------------------------------------------------------------------
# 4. MODELING APPROACH
#-------------------------------------------------------------------------------

## 4.1 Train/Test Split ----
# [TODO: Define temporal split strategy]

## 4.2 Model Definitions ----
# [TODO: Define candidate models]
# - Linear regression baseline
# - Random forest
# - XGBoost
# - etc.

## 4.3 Cross-Validation Setup ----
# [TODO: Define CV strategy]

## 4.4 Evaluation Metrics ----

calc_rmse <- function(actual, predicted) {
  sqrt(mean((actual - predicted)^2, na.rm = TRUE))
}

calc_mae <- function(actual, predicted) {
  mean(abs(actual - predicted), na.rm = TRUE)
}

calc_r2 <- function(actual, predicted) {
  1 - sum((actual - predicted)^2) / sum((actual - mean(actual))^2)
}

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