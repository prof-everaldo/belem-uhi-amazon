# ============================================================
# 02 — Landsat LST extraction and harmonization
# ============================================================

cat("Processing Landsat LST...\n")

grid_025 <- st_read(file.path(paths$raw, "grade_0025grau_conurbacao.gpkg"),
                    quiet = TRUE)

scene_dir <- file.path(paths$raw, "landsat")
scenes <- list.files(scene_dir, pattern = "\\.tif$",
                     full.names = TRUE, recursive = TRUE)

parse_sensor <- function(fname) {
  if (grepl("LT05|L5", fname)) return("L5")
  if (grepl("LE07|L7", fname)) return("L7")
  if (grepl("LC08|L8", fname)) return("L8")
  if (grepl("LC09|L9", fname)) return("L9")
  NA_character_
}

extract_lst <- function(scene_path) {
  r <- terra::rast(scene_path)
  lst_k <- r * 0.00341802 + 149.0
  lst_c <- lst_k - 273.15
  lst_c[lst_c < 5 | lst_c > 60] <- NA
  mean_lst <- terra::extract(lst_c, terra::vect(grid_025),
                             fun = mean, na.rm = TRUE)
  data.frame(grid_id = seq_len(nrow(grid_025)),
             LST = mean_lst[, 2],
             scene = basename(scene_path))
}

lst_all <- bind_rows(lapply(scenes, extract_lst))

lst_all <- lst_all %>%
  mutate(
    ano = as.integer(sub(".*_(\\d{4})\\d{4}_.*", "\\1", scene)),
    sensor = sapply(scene, parse_sensor),
    sensor_ano = ifelse(sensor %in% c("L8", "L9"), "L8/9", "L5/7")
  ) %>%
  filter(ano >= CONFIG$year_start, ano <= CONFIG$year_end)

lst_all <- lst_all %>%
  mutate(LST_corrigida = ifelse(sensor_ano == "L8/9",
                                LST - abs(CONFIG$sensor_bias), LST))

lst_annual <- lst_all %>%
  group_by(grid_id, ano) %>%
  summarise(LST_dry = mean(LST_corrigida, na.rm = TRUE),
            n_scenes = n(), .groups = "drop") %>%
  filter(n_scenes >= 3)

grid_coords <- grid_025 %>% st_drop_geometry() %>%
  select(grid_id, lon_c, lat_c)

urban_frac <- read_csv(file.path(paths$processed, "urban_fraction_by_year.csv"),
                       show_col_types = FALSE) %>%
  select(grid_id, ano, frac_urbana)

lst_annual <- lst_annual %>%
  left_join(grid_coords, by = "grid_id") %>%
  left_join(urban_frac, by = c("grid_id", "ano"))

write_csv(lst_annual, file.path(paths$processed, "lst_landsat_annual.csv"))
cat(sprintf("✓ Landsat LST: %d obs across %d cells and %d years\n",
            nrow(lst_annual), n_distinct(lst_annual$grid_id),
            n_distinct(lst_annual$ano)))
