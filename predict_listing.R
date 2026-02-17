#===============================================================================
# predict_listing.R — XGBoost House Price Prediction Utility
# Requires: cyo_script.R Sections 0-4.6 to have been run (xgb_fit in memory)
#===============================================================================

#-------------------------------------------------------------------------------
# PREDICTION FUNCTION
#-------------------------------------------------------------------------------

predict_house_price <- function(listing, model = NULL, training_data = NULL,
                                income_data = NULL) {
  # Use defaults from global environment if not provided
  if (is.null(model)) model <- get0("xgb_fit", envir = .GlobalEnv)
  if (is.null(training_data)) training_data <- get0("train_model", envir = .GlobalEnv)
  if (is.null(income_data)) income_data <- get0("filosofi_commune", envir = .GlobalEnv)
  
  # Check prerequisites
  if (is.null(model)) {
    stop("XGBoost model not found in memory. Run cyo_script.R through Section 4.6 first.")
  }
  if (is.null(training_data)) {
    stop("Training data (train_model) not found. Run cyo_script.R through Section 4.2 first.")
  }
  
  # Valid cities (from training data)
  valid_cities <- levels(training_data$target_city)
  
  # Validate city if provided
  if (!is.null(listing$target_city) && !listing$target_city %in% valid_cities) {
    stop(paste0(
      "Unknown city: '", listing$target_city, "'\n",
      "Valid cities: ", paste(valid_cities, collapse = ", ")
    ))
  }
  
  # --- Filosofi income lookup ---
  income_resolved <- NULL
  income_source   <- NULL
  
  # Priority: explicit median_income > commune_code > commune_name > training median
  if (!is.null(listing$median_income) && !is.na(listing$median_income)) {
    income_resolved <- listing$median_income
    income_source   <- "provided directly"
    
  } else if (!is.null(income_data)) {
    
    # Try commune_code first (exact match)
    if (!is.null(listing$commune_code)) {
      match <- income_data |>
        filter(code_commune_insee == as.character(listing$commune_code))
      if (nrow(match) == 1) {
        income_resolved <- match$median_income_commune
        income_source   <- paste0("Filosofi lookup: code ", listing$commune_code)
      } else if (nrow(match) == 0) {
        warning(paste0("Commune code '", listing$commune_code,
                       "' not found in Filosofi data."))
      }
    }
    
    # Try commune_name if code didn't resolve
    if (is.null(income_resolved) && !is.null(listing$commune_name)) {
      # Also load commune reference for name-to-code matching
      commune_ref <- get0("communes", envir = .GlobalEnv)
      
      if (!is.null(commune_ref)) {
        # Fuzzy-friendly: case-insensitive, accent-insensitive partial match
        search_term <- tolower(listing$commune_name)
        
        name_matches <- commune_ref |>
          filter(str_detect(tolower(nom_commune), fixed(search_term))) |>
          select(code_commune = code_commune_INSEE, nom_commune) |>
          distinct()
        
        if (nrow(name_matches) == 1) {
          code <- name_matches$code_commune
          fi_match <- income_data |>
            filter(code_commune_insee == as.character(code))
          if (nrow(fi_match) == 1) {
            income_resolved <- fi_match$median_income_commune
            income_source   <- paste0("Filosofi lookup: '", name_matches$nom_commune,
                                      "' (", code, ")")
          }
        } else if (nrow(name_matches) > 1) {
          # Filter to target departments if possible
          dept_filter <- NULL
          if (!is.null(listing$target_city)) {
            cl <- get0("commune_lookup", envir = .GlobalEnv)
            if (!is.null(cl)) {
              dept_filter <- cl |>
                filter(target_city == listing$target_city) |>
                pull(dept_code) |>
                unique()
            }
          }
          
          if (!is.null(dept_filter)) {
            name_matches <- name_matches |>
              filter(str_sub(code_commune, 1, 2) %in% dept_filter |
                     str_sub(code_commune, 1, 3) %in% dept_filter)
          }
          
          if (nrow(name_matches) == 1) {
            code <- name_matches$code_commune
            fi_match <- income_data |>
              filter(code_commune_insee == as.character(code))
            if (nrow(fi_match) == 1) {
              income_resolved <- fi_match$median_income_commune
              income_source   <- paste0("Filosofi lookup: '", name_matches$nom_commune,
                                        "' (", code, ")")
            }
          } else if (nrow(name_matches) > 1) {
            warning(paste0(
              "Multiple communes match '", listing$commune_name, "':\n  ",
              paste(name_matches$nom_commune, " (", name_matches$code_commune, ")",
                    sep = "", collapse = "\n  "),
              "\nUse commune_code for exact match. Falling back to training median."
            ))
          } else {
            warning(paste0("No communes match '", listing$commune_name,
                           "' in target departments."))
          }
        } else {
          warning(paste0("Commune name '", listing$commune_name,
                         "' not found in communes reference data."))
        }
      } else {
        warning("communes reference data not in memory — can't look up by name. ",
                "Provide commune_code or median_income directly.")
      }
    }
    
  } else if (is.null(income_resolved)) {
    message("Filosofi data (filosofi_commune) not in memory — ",
            "income lookup unavailable. Using training median.")
  }
  
  # Compute training medians for fallback defaults
  medians <- list(
    surface       = median(training_data$surface, na.rm = TRUE),
    rooms         = median(training_data$rooms, na.rm = TRUE),
    land          = median(training_data$land, na.rm = TRUE),
    target_city   = "Toulouse",
    ring          = 1L,
    year          = max(training_data$year),
    quarter       = 2L,
    has_land      = 1L,
    median_income = median(training_data$median_income, na.rm = TRUE)
  )
  
  # Fill missing fields with medians
  filled <- list()
  defaults_used <- character()
  
  for (field in names(medians)) {
    if (field == "median_income") {
      # Use resolved income from lookup, or fall back to median
      if (!is.null(income_resolved)) {
        filled$median_income <- income_resolved
      } else {
        filled$median_income <- medians$median_income
        defaults_used <- c(defaults_used,
                           paste0("median_income = ", round(medians$median_income)))
      }
    } else if (!is.null(listing[[field]]) && !is.na(listing[[field]])) {
      filled[[field]] <- listing[[field]]
    } else {
      filled[[field]] <- medians[[field]]
      defaults_used <- c(defaults_used, paste0(field, " = ", medians[[field]]))
    }
  }
  
  # Report income source
  if (!is.null(income_source)) {
    message("Median income (", format(round(income_resolved), big.mark = " "),
            " EUR) — ", income_source)
  }
  
  # Report other defaults if any were used
  if (length(defaults_used) > 0) {
    message("Using training medians for missing fields:\n  ",
            paste(defaults_used, collapse = "\n  "))
  }
  
  # Build prediction tibble
  pred_input <- tibble(
    surface       = as.numeric(filled$surface),
    rooms         = as.numeric(filled$rooms),
    land          = as.numeric(filled$land),
    target_city   = factor(filled$target_city, levels = valid_cities),
    ring          = as.integer(filled$ring),
    year          = as.numeric(filled$year),
    quarter       = as.integer(filled$quarter),
    has_land      = as.integer(filled$has_land),
    median_income = as.numeric(filled$median_income)
  )
  
  # Build model matrix and predict
  pred_x <- model.matrix(
    ~ surface + rooms + land + target_city + ring +
      year + quarter + has_land + median_income,
    data = pred_input
  )[, -1, drop = FALSE]
  
  pred_dmat <- xgb.DMatrix(data = pred_x)
  predicted_price <- predict(model, pred_dmat)
  
  # Return structured result
  list(
    predicted_price = predicted_price,
    predicted_m2    = predicted_price / filled$surface,
    inputs_used     = as.data.frame(pred_input),
    income_source   = income_source,
    defaults_filled = defaults_used
  )
}

#-------------------------------------------------------------------------------
# DISPLAY HELPER
#-------------------------------------------------------------------------------

print_prediction <- function(result, asking_price = NULL) {
  cat("\n=== PRICE PREDICTION ===\n")
  cat("Predicted price: ", format(round(result$predicted_price), big.mark = " "), " EUR\n")
  cat("Predicted EUR/m2:", format(round(result$predicted_m2), big.mark = " "), " EUR/m2\n")
  
  if (!is.null(result$income_source)) {
    cat("Income source:   ", result$income_source, "\n")
  }
  
  if (!is.null(asking_price)) {
    diff <- asking_price - result$predicted_price
    pct  <- diff / result$predicted_price * 100
    cat("\nAsking price:    ", format(round(asking_price), big.mark = " "), " EUR\n")
    cat("Difference:      ", format(round(diff), big.mark = " "), " EUR (",
        ifelse(pct > 0, "+", ""), round(pct, 1), "%)\n")
    
    if (abs(pct) < 10) {
      cat("Interpretation:   Priced roughly in line with model expectation.\n")
    } else if (pct > 10) {
      cat("Interpretation:   Premium over model estimate — may reflect quality,\n")
      cat("                  features, or location factors not captured in DVF data.\n")
    } else {
      cat("Interpretation:   Below model estimate — potential value, or may reflect\n")
      cat("                  condition/quality issues not visible in the data.\n")
    }
  }
  
  cat("\n--- Inputs used ---\n")
  print(result$inputs_used)
  
  if (length(result$defaults_filled) > 0) {
    cat("\n(Defaults applied for:", paste(result$defaults_filled, collapse = ", "), ")\n")
  }
}

#-------------------------------------------------------------------------------
# EXAMPLE USAGE
#-------------------------------------------------------------------------------

# --- Listing 1: Commune name lookup (simplest) ---
listing_1 <- list(
  surface       = 120,
  rooms         = 5,
  land          = 400,
  target_city   = "Toulouse",
  ring          = 1,
  year          = 2024,
  quarter       = 2,
  has_land      = 1,
  commune_name  = "Colomiers"     # <- income looked up automatically
)

result_1 <- predict_house_price(listing_1)
print_prediction(result_1, asking_price = 380000)

# --- Listing 2: Commune code lookup ---
listing_2 <- list(
  surface      = 90,
  rooms        = 4,
  target_city  = "Marseille",
  commune_code = "13055"          # <- Marseille proper
)

result_2 <- predict_house_price(listing_2)
print_prediction(result_2, asking_price = 320000)

# --- Listing 3: Minimal — everything defaults except the basics ---
listing_3 <- list(
  surface     = 100,
  rooms       = 4,
  target_city = "Bordeaux"
)

result_3 <- predict_house_price(listing_3)
print_prediction(result_3)

# --- Listing 4: Compare same house across cities ---
cat("\n\n=== SAME HOUSE, DIFFERENT CITIES ===\n")
for (city in c("Toulouse", "Montpellier", "Bordeaux", "Marseille",
               "Lyon", "Annecy", "Paris")) {
  r <- predict_house_price(list(
    surface = 110, rooms = 5, land = 500,
    target_city = city, ring = 1, has_land = 1
  ))
  cat(sprintf("%-12s  %s EUR  (%s EUR/m2)\n",
              city,
              format(round(r$predicted_price), big.mark = " "),
              format(round(r$predicted_m2), big.mark = " ")))
}