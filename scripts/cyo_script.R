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

# Load all DVF files (uncomment when ready to process full dataset)
# dvf_raw <- map_dfr(dvf_files, load_dvf_file, .id = "source_file")

#-------------------------------------------------------------------------------
# 2. CITY SCREENING & SELECTION
#-------------------------------------------------------------------------------

## 2.1 Define Target Departments ----
# Initial candidates based on climate and size
# TODO after we determine which departments to work with.

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

#-------------------------------------------------------------------------------
# 3. DATA PREPARATION
#-------------------------------------------------------------------------------

## 3.1 DVF Data Cleaning ----

# Filter to target departments and property types
filter_dvf <- function(df, departments, type_local = "Maison", nature_mutation = "Vente") {
  df |>
    filter(
      `Code departement` %in% departments,
      `Type local` == type_local,
      `Nature mutation` == nature_mutation
    )
}

## 3.2 Handle Missing Values ----
# [TODO: Implement missing value strategy]

## 3.3 Outlier Treatment ----
# [TODO: Define and handle outliers in property values]

## 3.4 Feature Engineering ----

# Parse date and extract components
parse_dvf_dates <- function(df) {
  df |>
    mutate(
      date_mutation = dmy(`Date mutation`),
      year = year(date_mutation),
      month = month(date_mutation),
      quarter = quarter(date_mutation)
    )
}

# Calculate price per square meter
calc_price_sqm <- function(df) {
  df |>
    mutate(
      valeur_fonciere_num = as.numeric(gsub(",", ".", `Valeur fonciere`)),
      prix_m2 = valeur_fonciere_num / `Surface reelle bati`
    ) |>
    filter(!is.na(prix_m2), is.finite(prix_m2), prix_m2 > 0)
}

## 3.5 Merge Supplementary Data ----
# [TODO: Join communes, population, and climate data]

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
