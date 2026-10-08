## run_all.R
  
  ```r
# ============================================================
# Master pipeline — Belém UHI attribution
# ============================================================

cat("=============================================================\n")
cat("BELEM UHI ATTRIBUTION — COMPLETE PIPELINE\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("=============================================================\n\n")

t0 <- Sys.time()

scripts <- c(
  "R/00_setup.R",
  "R/01_lulc_mapbiomas.R",
  "R/02_landsat_lst.R",
  "R/03_modis_lst.R",
  "R/04_inmet_seasonal.R",
  "R/05_brdwgd.R",
  "R/06_suhi_metrics.R",
  "R/07_attribution_model.R",
  "R/08_global_tair_validation.R",
  "R/09_lst_tair_consistency.R",
  "R/10_figures.R",
  "R/11_tables.R"
)

for (s in scripts) {
  cat(sprintf("\n─── Running %s ───\n", s))
  t_start <- Sys.time()
  tryCatch({
    source(s, echo = FALSE)
    dt <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))
    cat(sprintf("✓ %s completed in %.1f s\n", s, dt))
  }, error = function(e) {
    cat(sprintf("✗ ERROR in %s: %s\n", s, conditionMessage(e)))
    stop(e)
  })
}

# Save session info
dir.create("output/logs", showWarnings = FALSE, recursive = TRUE)
sink("output/logs/sessionInfo.txt")
cat("Session information — Belem UHI pipeline\n")
cat("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
print(sessionInfo())
sink()

total <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
cat(sprintf("\n=============================================================\n"))
cat(sprintf("PIPELINE COMPLETE — total runtime: %.1f min\n", total))
cat(sprintf("=============================================================\n"))
