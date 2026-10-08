# ============================================================
# 04 — INMET observations and seasonal definition
# ============================================================

cat("Processing INMET observations...\n")

inmet_file <- file.path(paths$raw, "inmet", "incita_dry_tmax_tmin.xlsx")
inmet <- read_excel(inmet_file) %>%
  rename(ano = 1, TX = 2, TN = 3) %>%
  mutate(ano = as.integer(ano),
         TX  = as.numeric(TX),
         TN  = as.numeric(TN)) %>%
  arrange(ano)

# --- Seasonal regime definition ---
inmet_daily_p <- file.path(paths$raw, "inmet", "precip_belem_daily.csv")
if (file.exists(inmet_daily_p)) {
  p_data <- read_csv(inmet_daily_p, show_col_types = FALSE) %>%
    mutate(date = as.Date(date),
           ano = year(date), mes = month(date))
  p_clim <- p_data %>%
    group_by(mes) %>%
    summarise(P_mean = mean(precip, na.rm = TRUE), .groups = "drop")
  q25 <- quantile(p_clim$P_mean, 0.25)
  q75 <- quantile(p_clim$P_mean, 0.75)
  dry_months <- p_clim %>% filter(P_mean < q25) %>% pull(mes)
  wet_months <- p_clim %>% filter(P_mean > q75) %>% pull(mes)
  cat(sprintf("Dry months: %s\n", paste(dry_months, collapse = ", ")))
  cat(sprintf("Wet months: %s\n", paste(wet_months, collapse = ", ")))
  saveRDS(list(dry = dry_months, wet = wet_months),
          file.path(paths$processed, "seasonal_regimes.rds"))
}

write_csv(inmet, file.path(paths$processed, "inmet_annual_dry.csv"))

# --- Statistical tests ---
welch_p <- function(x1, x2) t.test(x1, x2, var.equal = FALSE)$p.value

pre  <- inmet %>% filter(ano >= CONFIG$period_pre[1],
                         ano <= CONFIG$period_pre[2])
post <- inmet %>% filter(ano >= CONFIG$period_post[1],
                         ano <= CONFIG$period_post[2])

stats <- tibble(
  variable  = c("TX", "TN"),
  mean_pre  = c(mean(pre$TX), mean(pre$TN)),
  mean_post = c(mean(post$TX), mean(post$TN)),
  delta     = c(mean(post$TX) - mean(pre$TX),
                mean(post$TN) - mean(pre$TN)),
  p_value   = c(welch_p(pre$TX, post$TX),
                welch_p(pre$TN, post$TN)),
  trend     = c(coef(lm(TX ~ ano, data = inmet))[2],
                coef(lm(TN ~ ano, data = inmet))[2])
)

write_csv(stats, file.path(paths$tables, "inmet_statistics.csv"))
cat("✓ INMET observations processed\n")
print(stats)
