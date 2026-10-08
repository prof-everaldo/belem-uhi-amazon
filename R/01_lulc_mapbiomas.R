# ============================================================
# 01 — LULC classification and urban fraction
# ============================================================

cat("Loading municipal shapefile...\n")
shp_path <- file.path(paths$raw, "ibge_2022/PA_Municipios_2022.shp")
mun_conurb <- st_read(shp_path, quiet = TRUE) %>%
  filter(CD_MUN %in% CONFIG$mun_codes) %>%
  st_transform(CONFIG$target_crs)

bb <- st_bbox(mun_conurb)
margin <- 0.02
bb_expanded <- st_bbox(c(
  xmin = as.numeric(bb["xmin"]) - margin,
  xmax = as.numeric(bb["xmax"]) + margin,
  ymin = as.numeric(bb["ymin"]) - margin,
  ymax = as.numeric(bb["ymax"]) + margin
), crs = st_crs(mun_conurb))

bbox_ext <- terra::ext(
  as.numeric(bb_expanded["xmin"]), as.numeric(bb_expanded["xmax"]),
  as.numeric(bb_expanded["ymin"]), as.numeric(bb_expanded["ymax"])
)
mun_vect <- terra::vect(mun_conurb)

# --- Process LULC per year ---
processar_lulc <- function(ano) {
  path <- file.path(paths$raw, "mapbiomas",
                    sprintf("brazil_coverage-col11_%d.tif", ano))
  r  <- terra::rast(path)
  rc <- terra::crop(r, bbox_ext, snap = "out")
  rc <- terra::classify(rc, LULC_MAP, others = NA)
  rc <- terra::mask(rc, mun_vect)
  rc
}

lulc_1985 <- processar_lulc(CONFIG$year_start)
lulc_2025 <- processar_lulc(CONFIG$year_end)

# --- Compute urban fraction per 0.025° cell for every year ---
grid_025 <- st_read(file.path(paths$raw, "grade_0025grau_conurbacao.gpkg"),
                    quiet = TRUE)

compute_urban_fraction <- function(ano) {
  lulc <- processar_lulc(ano)
  lulc_agg <- terra::aggregate(lulc, fact = 3, fun = "modal", na.rm = TRUE)
  vals <- terra::extract(lulc_agg, terra::vect(grid_025),
                         fun = function(x) mean(x == 6, na.rm = TRUE),
                         na.rm = TRUE)
  grid_025$frac_urbana <- vals[, 2]
  grid_025$ano <- ano
  grid_025
}

cat("Computing urban fraction per year...\n")
urban_frac <- bind_rows(lapply(CONFIG$year_start:CONFIG$year_end,
                               compute_urban_fraction))

write_csv(urban_frac %>% st_drop_geometry(),
          file.path(paths$processed, "urban_fraction_by_year.csv"))
saveRDS(lulc_1985, file.path(paths$processed, "lulc_1985.rds"))
saveRDS(lulc_2025, file.path(paths$processed, "lulc_2025.rds"))
saveRDS(mun_conurb, file.path(paths$processed, "mun_conurb.rds"))
saveRDS(bb_expanded, file.path(paths$processed, "bb_expanded.rds"))

cat("✓ LULC and urban fraction saved\n")
