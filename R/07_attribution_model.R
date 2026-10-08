# ============================================================
# 07 — Parametric attribution model (mixed-effects)
# ============================================================

cat("Fitting attribution model...\n")

lst_annual <- read_csv(file.path(paths$processed, "lst_landsat_annual.csv"),
                       show_col_types = FALSE) %>%
  mutate(
    t_centered = ano - CONFIG$reference_year,
    ln_D = log(frac_urbana),
    dwgd_id = paste(round(lon_c / 0.1), round(lat_c / 0.1), sep = "_")
  ) %>%
  filter(is.finite(ln_D), ln_D < 0)

# --- Full interaction model ---
m_full <- lmer(
  LST_dry ~ t_centered:ln_D + ln_D + t_centered + (1 | dwgd_id),
  data = lst_annual, REML = FALSE
)
m_additive <- lmer(
  LST_dry ~ ln_D + t_centered + (1 | dwgd_id),
  data = lst_annual, REML = FALSE
)
lrt <- anova(m_full, m_additive)
print(lrt)

# --- Refit with REML ---
m_final <- lmer(
  LST_dry ~ t_centered:ln_D + ln_D + t_centered + (1 | dwgd_id),
  data = lst_annual, REML = TRUE
)

coefs <- summary(m_final)$coefficients
write_csv(as.data.frame(coefs), file.path(paths$tables, "attribution_coefs.csv"))

a2    <- coefs["ln_D", "Estimate"]
b2    <- coefs["t_centered", "Estimate"]
gamma <- coefs["t_centered:ln_D", "Estimate"]

saveRDS(list(a2 = a2, b2 = b2, gamma = gamma, model = m_final),
        file.path(paths$processed, "attribution_model.rds"))

cat(sprintf("a2 = %.3f | b2 = %.4f | gamma = %.4f\n", a2, b2, gamma))

# --- Attribution decomposition ---
mean_ln_D <- mean(lst_annual$ln_D, na.rm = TRUE)
delta_ln_D <- mean(
  log(lst_annual$frac_urbana[lst_annual$ano == CONFIG$year_end]) -
    log(lst_annual$frac_urbana[lst_annual$ano == CONFIG$year_start]),
  na.rm = TRUE)
delta_t <- CONFIG$year_end - CONFIG$year_start

y_global <- (gamma * mean_ln_D + b2) * delta_t
y_urban  <- a2 * delta_ln_D

attribution <- tibble(
  component = c("Global", "Urban"),
  value_C   = c(y_global, y_urban),
  pct       = c(100 * y_global / (y_global + y_urban),
                100 * y_urban  / (y_global + y_urban))
)
write_csv(attribution, file.path(paths$tables, "attribution_decomposition.csv"))
print(attribution)

# --- SUHI decomposition ---
expansion      <- a2 * delta_ln_D
amplification  <- gamma * delta_t * mean_ln_D
suhi_decomp <- tibble(
  component = c("Expansion", "Amplification"),
  pct       = c(100 * expansion / (expansion + amplification),
                100 * amplification / (expansion + amplification))
)
write_csv(suhi_decomp, file.path(paths$tables, "suhi_decomposition.csv"))
print(suhi_decomp)
