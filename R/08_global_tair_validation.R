# ============================================================
# 08 — Multi-dataset global temperature validation
# ============================================================

cat("Validating b2 against global temperature products...\n")

lst_core <- read_csv(file.path(paths$processed, "lst_landsat_annual.csv"),
                     show_col_types = FALSE) %>%
  filter(grid_id == CONFIG$grid_id_core) %>%
  group_by(ano) %>%
  summarise(LST_core = mean(LST_dry, na.rm = TRUE), .groups = "drop") %>%
  filter(ano >= CONFIG$year_start, ano <= CONFIG$year_end)

load_hadcrut5 <- function() {
  read_csv(file.path(paths$raw, "global_tair/HadCRUT5_global_monthly.txt"),
           show_col_types = FALSE) %>%
    rename(ano_mes = 1, anomaly = 2) %>%
    mutate(ano = as.integer(substr(ano_mes, 1, 4)),
           mes = as.integer(substr(ano_mes, 6, 7))) %>%
    filter(mes %in% CONFIG$dry_months,
           ano %in% CONFIG$year_start:CONFIG$year_end) %>%
    group_by(ano) %>%
    summarise(tair_global = mean(anomaly, na.rm = TRUE), .groups = "drop") %>%
    mutate(source = "HadCRUT5", baseline = "1961–1990")
}

load_gistemp <- function() {
  path <- file.path(paths$raw, "global_tair/GLB.Ts+dSST.csv")
  lines <- readLines(path, warn = FALSE)
  h_idx <- which(grepl("^Year,", trimws(lines)))[1]
  txt <- paste(lines[h_idx:length(lines)], collapse = "\n")
  df <- read.csv(text = txt, check.names = FALSE)
  months <- c("Jul", "Aug", "Sep", "Oct", "Nov")
  df %>%
    select(Year, all_of(months)) %>%
    mutate(across(all_of(months),
                  ~ suppressWarnings(as.numeric(gsub("[^0-9.-]", "", .))))) %>%
    rowwise() %>%
    mutate(tair_global = mean(c_across(all_of(months)), na.rm = TRUE)) %>%
    ungroup() %>%
    transmute(ano = as.integer(Year), tair_global,
              source = "GISTEMP v4", baseline = "1951–1980") %>%
    filter(ano %in% CONFIG$year_start:CONFIG$year_end, is.finite(tair_global))
}

load_noaa <- function() {
  path <- file.path(paths$raw,
                    "global_tair/aravg.mon.land_ocean.90S.90N.v6.0.0.202512.asc")
  df <- read.table(path, header = FALSE, fill = TRUE,
                   colClasses = "character", stringsAsFactors = FALSE)
  df <- df[, 1:3]
  colnames(df) <- c("year", "month", "anomaly")
  df$year    <- as.integer(df$year)
  df$month   <- as.integer(df$month)
  df$anomaly <- as.numeric(df$anomaly)
  df %>%
    filter(!is.na(year), !is.na(month), !is.na(anomaly), anomaly > -900) %>%
    filter(month %in% CONFIG$dry_months,
           year %in% CONFIG$year_start:CONFIG$year_end) %>%
    group_by(year) %>%
    summarise(tair_global = mean(anomaly, na.rm = TRUE),
              n = n(), .groups = "drop") %>%
    filter(n >= 4) %>%
    transmute(ano = year, tair_global,
              source = "NOAAGlobalTemp v6", baseline = "1991–2020")
}

bases <- list(load_hadcrut5(), load_gistemp(), load_noaa())

regression_table <- bind_rows(lapply(bases, function(base) {
  df <- lst_core %>% inner_join(base, by = "ano")
  fit <- lm(LST_core ~ tair_global, data = df)
  s <- summary(fit)
  tibble(
    dataset  = unique(base$source),
    baseline = unique(base$baseline),
    n        = nrow(df),
    slope    = coef(fit)[2],
    slope_lo = confint(fit)[2, 1],
    slope_hi = confint(fit)[2, 2],
    R2       = s$r.squared,
    p_value  = s$coefficients[2, 4]
  )
}))

write_csv(regression_table, file.path(paths$tables, "global_tair_slopes.csv"))
cat("✓ Multi-dataset validation complete\n")
print(regression_table)
