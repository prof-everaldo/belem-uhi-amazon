# ============================================================
# 09 — LST–Tair temporal consistency check
# ============================================================

cat("Running LST–Tair consistency check...\n")

lst_core <- read_csv(file.path(paths$processed, "lst_landsat_annual.csv"),
                     show_col_types = FALSE) %>%
  filter(grid_id == CONFIG$grid_id_core) %>%
  group_by(ano) %>%
  summarise(LST_core = mean(LST_dry, na.rm = TRUE), .groups = "drop")

inmet <- read_csv(file.path(paths$processed, "inmet_annual_dry.csv"),
                  show_col_types = FALSE)

val <- lst_core %>% inner_join(inmet, by = "ano")

fit_tx <- lm(LST_core ~ TX, data = val)
fit_tn <- lm(LST_core ~ TN, data = val)

consistency <- tibble(
  predictor = c("TX", "TN"),
  slope     = c(coef(fit_tx)[2], coef(fit_tn)[2]),
  slope_lo  = c(confint(fit_tx)[2,1], confint(fit_tn)[2,1]),
  slope_hi  = c(confint(fit_tx)[2,2], confint(fit_tn)[2,2]),
  R2        = c(summary(fit_tx)$r.squared, summary(fit_tn)$r.squared),
  p_value   = c(coef(summary(fit_tx))[2,4], coef(summary(fit_tn))[2,4]),
  n         = c(nrow(val), nrow(val))
)

write_csv(consistency, file.path(paths$tables, "lst_tair_consistency.csv"))
cat("✓ Consistency check complete\n")
print(consistency)
