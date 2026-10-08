# ============================================================
# 03 — MODIS LST extraction
# ============================================================

cat("Processing MODIS LST...\n")

grid_025 <- st_read(file.path(paths$raw, "grade_0025grau_conurbacao.gpkg"),
                    quiet = TRUE)

modis_dir <- file.path(paths$raw, "modis")
modis_files <- list.files(modis_dir, pattern = "\\.tif$",
                          full.names = TRUE, recursive = TRUE)

extract_modis <- function(f) {
  r <- terra::rast(f)
  lst_k <- r * 0.02
  lst_k[lst_k < 7500 | lst_k > 65535] <- NA
  lst_c <- lst_k - 273.15
  vals <- terra::extract(lst_c, terra::vect(grid_025), fun = mean, na.rm = TRUE)
  data.frame(grid_id = seq_len(nrow(grid_025)), LST = vals[, 2],
             file = basename(f))
}

modis_all <- bind_rows(lapply(modis_files, extract_modis))

modis_all <- modis_all %>%
  mutate(
    ano = as.integer(sub(".*A(\\d{4})\\d{3}.*", "\\1", file)),
    produto = ifelse(grepl("MOD", file), "MOD11A2", "MYD11A2")
  ) %>%
  filter(ano >= 2000, ano <= CONFIG$year_end)

modis_annual <- modis_all %>%
  group_by(grid_id, ano, produto) %>%
  summarise(LST_dry = mean(LST, na.rm = TRUE), .groups = "drop")

write_csv(modis_annual, file.path(paths$processed, "lst_modis_annual.csv"))
cat(sprintf("✓ MODIS LST: %d observations\n", nrow(modis_annual)))
