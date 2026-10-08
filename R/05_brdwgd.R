# ============================================================
# 05 — BR-DWGD gridded reanalysis extraction
# ============================================================

cat("Processing BR-DWGD reanalysis...\n")

bb_expanded <- readRDS(file.path(paths$processed, "bb_expanded.rds"))

brdwgd_dir <- file.path(paths$raw, "brdwgd")
tx_files <- list.files(brdwgd_dir, pattern = "TX.*\\.nc$", full.names = TRUE)
tn_files <- list.files(brdwgd_dir, pattern = "TN.*\\.nc$", full.names = TRUE)

extract_brdwgd <- function(files) {
  r <- terra::rast(files)
  r_dry  <- r[[CONFIG$dry_months]]
  r_mean <- terra::mean(r_dry, na.rm = TRUE)
  terra::crop(r_mean, terra::ext(
    as.numeric(bb_expanded["xmin"]), as.numeric(bb_expanded["xmax"]),
    as.numeric(bb_expanded["ymin"]), as.numeric(bb_expanded["ymax"])
  ))
}

tx_br <- extract_brdwgd(tx_files)
tn_br <- extract_brdwgd(tn_files)

saveRDS(tx_br, file.path(paths$processed, "brdwgd_TX.rds"))
saveRDS(tn_br, file.path(paths$processed, "brdwgd_TN.rds"))

cat("✓ BR-DWGD extraction complete\n")
