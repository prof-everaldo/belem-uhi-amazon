# ============================================================
# 00 — Setup: libraries, paths, global constants
# ============================================================

suppressPackageStartupMessages({
  library(terra); library(sf)
  library(dplyr); library(tidyr); library(readr); library(readxl)
  library(ggplot2); library(patchwork); library(ggspatial)
  library(metR); library(fields); library(viridis); library(scales)
  library(lme4); library(lmerTest)
})

# --- Paths ---
paths <- list(
  raw         = "data/raw",
  processed   = "data/processed",
  figures     = "manuscript/figures",
  tables      = "manuscript/tables",
  diagnostics = "output/diagnostics",
  logs        = "output/logs"
)
for (p in paths) dir.create(p, showWarnings = FALSE, recursive = TRUE)

# --- Global configuration ---
CONFIG <- list(
  # Temporal window
  year_start = 1985,
  year_end   = 2025,
  dry_months = 7:11,              # July–November
  
  # Reference periods (15 years each)
  period_pre  = c(1985, 1999),
  period_post = c(2011, 2025),
  
  # Spatial analysis
  grid_res    = 0.025,
  target_crs  = 4326,
  
  # Landsat harmonization
  sensor_bias = -0.53,            # °C (L8/9 minus L5/7)
  cloud_max   = 30,               # percent
  
  # SUHI detection
  urban_threshold = 0.05,
  bg_threshold    = 0.05,
  
  # Bootstrap
  n_boot     = 1000,
  block_size = 2,                 # 2×2 cells ~5.5 km
  seed       = 42,
  
  # Attribution model
  reference_year = 2005,          # centered time t = year - 2005
  grid_id_core   = 313,           # Belém thermal core pixel
  
  # Municipal codes (IBGE 2022)
  mun_codes = c("1500800", "1501402", "1501501", "1504422"),
  mun_names = c("Belém", "Ananindeua", "Marituba", "Benevides")
)

# --- MapBiomas → 6 classes (Level 1 + Urbanization) ---
LULC_MAP <- matrix(c(
  1,1,  3,1,  4,1,  5,1,  6,1,  49,1,
  10,2, 11,2, 12,2, 13,2, 29,2, 32,2, 50,2,
  9,3,  14,3, 15,3, 18,3, 19,3, 20,3, 21,3, 22,3,
  35,3, 36,3, 39,3, 40,3, 41,3, 46,3, 47,3, 48,3, 62,3,
  67,3, 68,3, 69,3, 70,3, 71,3, 72,3, 73,3, 74,3, 75,3, 76,3,
  23,4, 25,4, 30,4, 31,4,
  26,5, 33,5,
  24,6
), ncol = 2, byrow = TRUE)

LULC_LABELS <- c("Forest", "Non-forest natural", "Farming",
                 "Non-vegetated (other)", "Water body", "Urbanization")

LULC_COLORS <- c(
  "Forest"                 = "#90EE90",
  "Non-forest natural"     = "#e3e9d8",
  "Farming"                = "#f0ead2",
  "Non-vegetated (other)"  = "#c8c8c8",
  "Water body"             = "#6fb5d8",
  "Urbanization"           = "#c62828"
)

set.seed(CONFIG$seed)

cat("Setup complete. Working directory:", getwd(), "\n")
