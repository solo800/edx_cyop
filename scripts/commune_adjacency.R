# commune_adjacency.R
# Identify communes adjacent to target cities for DVF filtering
# Steps: load commune boundaries, filter, compute adjacency, create lookup table

# --- Packages ---
if (!require(sf)) install.packages("sf")
if (!require(dplyr)) install.packages("dplyr")
if (!require(tidyr)) install.packages("tidyr")

library(sf)
library(dplyr)
library(tidyr)

# =============================================================================
# STEP 2: Load and filter to target departments
# =============================================================================

cat("=== STEP 2: Load commune boundaries and filter ===\n\n")

# Load full France commune boundaries
communes_all <- st_read("data/raw/communes-50m.geojson", quiet = TRUE)

cat("Full dataset loaded:", nrow(communes_all), "communes\n")
cat("Column names:", paste(names(communes_all), collapse = ", "), "\n\n")

# Inspect the INSEE code column
cat("First few rows:\n")
print(head(communes_all %>% st_drop_geometry() %>% select(1:5), 10))

# Target departments
target_depts <- c("13", "31", "33", "34", "69", "74", "75")

# Filter — adapt column name based on what's in the data
# Expected: 'code' for INSEE, 'departement' for dept code
dept_col <- if ("departement" %in% names(communes_all)) "departement" else if ("DEP" %in% names(communes_all)) "DEP" else NA

if (is.na(dept_col)) {
  cat("WARNING: Could not find department column. Available columns:\n")
  print(names(communes_all))
  stop("Please identify the department column manually.")
}

cat("\nUsing department column:", dept_col, "\n")

communes_target <- communes_all %>%
  filter(.data[[dept_col]] %in% target_depts)

cat("\n--- Communes per target department ---\n")
dept_counts <- communes_target %>%
  st_drop_geometry() %>%
  count(.data[[dept_col]], name = "n_communes") %>%
  arrange(.data[[dept_col]])
print(dept_counts)

cat("\nTotal rows in filtered subset:", nrow(communes_target), "\n")
cat("Column names:", paste(names(communes_target), collapse = ", "), "\n")
cat("CRS:", st_crs(communes_target)$input, "\n")
cat("EPSG:", st_crs(communes_target)$epsg, "\n")

# Save filtered subset as GeoPackage
st_write(communes_target, "data/raw/communes_geo_target_depts.gpkg",
         driver = "GPKG", delete_dsn = TRUE, quiet = TRUE)
cat("\nSaved: data/raw/communes_geo_target_depts.gpkg\n")
cat("File size:", round(file.size("data/raw/communes_geo_target_depts.gpkg") / 1e6, 1), "MB\n")

# =============================================================================
# STEP 3: Identify target city polygons
# =============================================================================

cat("\n=== STEP 3: Identify target city polygons ===\n\n")

# Define target cities
# For arrondissement cities: code ranges for their arrondissements
# For simple cities: single commune code
target_cities <- list(
  list(name = "Marseille",    dept = "13", code = "13055",
       arr_codes = sprintf("132%02d", 1:16),  # 13201-13216
       is_arr = TRUE),
  list(name = "Toulouse",     dept = "31", code = "31555",
       arr_codes = NULL, is_arr = FALSE),
  list(name = "Bordeaux",     dept = "33", code = "33063",
       arr_codes = NULL, is_arr = FALSE),
  list(name = "Montpellier",  dept = "34", code = "34172",
       arr_codes = NULL, is_arr = FALSE),
  list(name = "Lyon",         dept = "69", code = "69123",
       arr_codes = sprintf("6938%d", 1:9),    # 69381-69389
       is_arr = TRUE),
  list(name = "Annecy",       dept = "74", code = "74010",
       arr_codes = NULL, is_arr = FALSE),
  list(name = "Paris",        dept = "75", code = "75056",
       arr_codes = sprintf("751%02d", 1:20),  # 75101-75120
       is_arr = TRUE)
)

# For each city, find polygon(s) and compute merged geometry + area
city_results <- list()

for (city in target_cities) {
  if (city$is_arr) {
    # Arrondissement city: find all arrondissement polygons
    city_polys <- communes_all %>% filter(code %in% city$arr_codes)
    n_polys <- nrow(city_polys)
    # Merge into single polygon
    merged_geom <- st_union(city_polys)
    merged_sf <- st_sf(geometry = merged_geom, crs = st_crs(communes_all))
  } else {
    # Single commune city
    city_polys <- communes_all %>% filter(code == city$code)
    n_polys <- nrow(city_polys)
    merged_geom <- st_geometry(city_polys)
    merged_sf <- city_polys
  }

  # Compute area in km² (transform to a projected CRS for accurate area)
  area_km2 <- as.numeric(st_area(st_transform(merged_sf, 2154))) / 1e6

  city_results[[city$name]] <- list(
    name       = city$name,
    dept       = city$dept,
    code       = city$code,
    is_arr     = city$is_arr,
    arr_codes  = city$arr_codes,
    n_polys    = n_polys,
    area_km2   = round(area_km2, 1),
    merged_sf  = merged_sf,
    raw_polys  = city_polys
  )
}

# Print summary table
cat("--- Target city polygons ---\n\n")
summary_df <- data.frame(
  City            = sapply(city_results, `[[`, "name"),
  Dept            = sapply(city_results, `[[`, "dept"),
  INSEE_Code      = sapply(city_results, `[[`, "code"),
  N_Polygons      = sapply(city_results, `[[`, "n_polys"),
  Arrondissement  = sapply(city_results, `[[`, "is_arr"),
  Area_km2        = sapply(city_results, `[[`, "area_km2"),
  row.names       = NULL
)
print(summary_df)

# Also show which arrondissement codes were found vs expected
cat("\n--- Arrondissement detail ---\n")
for (city in target_cities) {
  if (city$is_arr) {
    found <- communes_all %>%
      st_drop_geometry() %>%
      filter(code %in% city$arr_codes) %>%
      pull(code) %>%
      sort()
    missing <- setdiff(city$arr_codes, found)
    cat(sprintf("\n%s: found %d/%d arrondissements\n",
                city$name, length(found), length(city$arr_codes)))
    if (length(missing) > 0) {
      cat("  MISSING:", paste(missing, collapse = ", "), "\n")
    }
  }
}

# =============================================================================
# STEP 4: Compute adjacent communes
# =============================================================================

cat("\n\n=== STEP 4: Compute adjacent communes ===\n\n")

# Project everything to Lambert-93 (EPSG:2154) for reliable planar operations
# s2 spherical geometry can be unreliable for touch detection on simplified boundaries
sf_use_s2(FALSE)
communes_all_proj <- st_transform(communes_all, 2154)

# Strategy: for arrondissement cities, st_touches() on the st_union() merged polygon
# can fail because simplification artifacts leave tiny gaps between arrondissements.
# Instead, find communes that touch ANY individual arrondissement polygon.
# For all cities, also try a small-buffer st_intersects() as a safety net.

adjacent_list <- list()

for (city_name in names(city_results)) {
  cr <- city_results[[city_name]]

  # Codes to exclude: the city's own commune(s)
  if (cr$is_arr) {
    exclude_codes <- c(cr$code, cr$arr_codes)
  } else {
    exclude_codes <- cr$code
  }

  if (cr$is_arr) {
    # Arrondissement city: find communes touching ANY individual arrondissement
    arr_polys_proj <- st_transform(cr$raw_polys, 2154)
    all_touch_idx <- c()
    for (i in seq_len(nrow(arr_polys_proj))) {
      tidx <- st_touches(arr_polys_proj[i, ], communes_all_proj)[[1]]
      all_touch_idx <- c(all_touch_idx, tidx)
    }
    all_touch_idx <- unique(all_touch_idx)

    touching <- communes_all_proj[all_touch_idx, ] %>%
      filter(!code %in% exclude_codes)
  } else {
    # Single commune city: straightforward st_touches
    city_proj <- st_transform(cr$merged_sf, 2154)
    touches_idx <- st_touches(city_proj, communes_all_proj)[[1]]
    touching <- communes_all_proj[touches_idx, ] %>%
      filter(!code %in% exclude_codes)
  }

  # Safety net: also check st_intersects with a 50m buffer to catch any
  # communes missed by st_touches due to simplification gaps
  city_merged_proj <- st_transform(cr$merged_sf, 2154)
  buffered <- st_buffer(city_merged_proj, 50)
  intersects_idx <- st_intersects(buffered, communes_all_proj)[[1]]
  extra <- communes_all_proj[intersects_idx, ] %>%
    filter(!code %in% exclude_codes, !code %in% touching$code)

  if (nrow(extra) > 0) {
    cat(sprintf("  [buffer safety net added %d extra communes for %s]\n",
                nrow(extra), city_name))
    touching <- bind_rows(touching, extra)
  }

  if (nrow(touching) > 0) {
    adj_df <- touching %>%
      st_drop_geometry() %>%
      transmute(
        target_city           = city_name,
        adjacent_insee_code   = code,
        adjacent_commune_name = nom,
        adjacent_dept         = departement
      ) %>%
      as.data.frame()
  } else {
    adj_df <- data.frame(
      target_city           = character(0),
      adjacent_insee_code   = character(0),
      adjacent_commune_name = character(0),
      adjacent_dept         = character(0)
    )
  }

  adjacent_list[[city_name]] <- adj_df
  cat(sprintf("  %s: %d adjacent communes found\n", city_name, nrow(adj_df)))
}

# Combine into single data frame
adjacent_all <- bind_rows(adjacent_list) %>% as.data.frame()

# Re-enable s2
sf_use_s2(TRUE)

# --- Summary table ---
cat("\n--- Summary: adjacent communes per city ---\n\n")
adj_summary <- adjacent_all %>%
  count(target_city, name = "n_adjacent") %>%
  arrange(target_city)
print(adj_summary)

# --- Full lists for Annecy and Paris ---
cat("\n--- Adjacent communes: Annecy ---\n\n")
annecy_adj <- adjacent_all %>%
  filter(target_city == "Annecy") %>%
  arrange(adjacent_insee_code) %>%
  as.data.frame()
print(annecy_adj)

cat("\n--- Adjacent communes: Paris ---\n\n")
paris_adj <- adjacent_all %>%
  filter(target_city == "Paris") %>%
  arrange(adjacent_insee_code) %>%
  as.data.frame()
print(paris_adj)

# =============================================================================
# STEP 5: Create final commune filter lookup
# =============================================================================

cat("\n\n=== STEP 5: Create commune filter lookup ===\n\n")

# Helper: extract DVF commune code from 5-digit INSEE code
# All our departments are 2-digit, so commune_code = last 3 chars
# Strip leading zeros to match DVF format (e.g., "063" -> "63")
dvf_commune_code <- function(insee_code) {
  as.character(as.integer(substr(insee_code, 3, 5)))
}

# --- Ring 0: city proper communes ---
ring0_list <- list()

for (city_name in names(city_results)) {
  cr <- city_results[[city_name]]

  if (cr$is_arr) {
    # Arrondissement city: each arrondissement is a separate row
    arr_data <- cr$raw_polys %>%
      st_drop_geometry() %>%
      transmute(
        target_city      = city_name,
        dept_code        = departement,
        commune_code     = dvf_commune_code(code),
        insee_code       = code,
        commune_name     = nom,
        ring             = 0L,
        is_arrondissement = TRUE
      ) %>%
      as.data.frame()
    ring0_list[[city_name]] <- arr_data
  } else {
    # Single commune city
    single_data <- cr$raw_polys %>%
      st_drop_geometry() %>%
      transmute(
        target_city      = city_name,
        dept_code        = departement,
        commune_code     = dvf_commune_code(code),
        insee_code       = code,
        commune_name     = nom,
        ring             = 0L,
        is_arrondissement = FALSE
      ) %>%
      as.data.frame()
    ring0_list[[city_name]] <- single_data
  }
}

ring0_df <- bind_rows(ring0_list)

# --- Ring 1: adjacent communes ---
ring1_df <- adjacent_all %>%
  transmute(
    target_city      = target_city,
    dept_code        = adjacent_dept,
    commune_code     = dvf_commune_code(adjacent_insee_code),
    insee_code       = adjacent_insee_code,
    commune_name     = adjacent_commune_name,
    ring             = 1L,
    is_arrondissement = FALSE
  ) %>%
  as.data.frame()

# --- Combine ---
lookup <- bind_rows(ring0_df, ring1_df) %>%
  arrange(target_city, ring, insee_code) %>%
  as.data.frame()

# --- Flag departments outside the original 7 target departments ---
original_target_depts <- c("13", "31", "33", "34", "69", "74", "75")
extra_depts <- lookup %>%
  filter(!dept_code %in% original_target_depts) %>%
  distinct(target_city, dept_code)

if (nrow(extra_depts) > 0) {
  cat("*** NOTE: Adjacent communes span departments OUTSIDE the original 7 targets ***\n")
  cat("*** You will need to include these departments when filtering DVF data ***\n\n")
  cat("Extra departments required:\n")
  print(extra_depts, row.names = FALSE)
  cat("\n")
}

# --- Save ---
write.csv(lookup, "data/commune_filter_lookup.csv", row.names = FALSE)
cat("Saved: data/commune_filter_lookup.csv\n")
cat("File size:", round(file.size("data/commune_filter_lookup.csv") / 1e3, 1), "KB\n\n")

# --- Summary: communes per city by ring ---
cat("--- Communes per city by ring ---\n\n")
ring_summary <- lookup %>%
  count(target_city, ring, name = "n_communes") %>%
  pivot_wider(names_from = ring, values_from = n_communes,
              names_prefix = "ring_") %>%
  mutate(total = ring_0 + ring_1) %>%
  arrange(target_city) %>%
  as.data.frame()
print(ring_summary)

cat("\nTotal rows in lookup:", nrow(lookup), "\n")

# --- Sample rows ---
cat("\n--- Sample rows (first 5 per ring) ---\n\n")
cat("Ring 0 (city proper):\n")
print(head(lookup %>% filter(ring == 0), 5))
cat("\nRing 1 (adjacent):\n")
print(head(lookup %>% filter(ring == 1), 5))
