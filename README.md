# Bimodal urban heat island in Amazonian conurbation: dual attribution and open workflow for equatorial metropolises

This repository contains the complete analytical pipeline for the manuscript:

> **Bimodal urban heat island in Amazonian conurbation: dual attribution and open workflow for equatorial metropolises**
>
> Submitted to *npj Urban Sustainability*, 2026.

## Overview

The analytical workflow implements a multi-platform attribution framework to separate the contributions of global climate change and urbanization to observed warming in the Belém conurbation, eastern Brazilian Amazonia. It integrates:

- **Landsat LST** (30 m, 1985–2025) — spatial structure and attribution coefficients
- **MODIS LST** (1 km, 2000–2025) — independent cross-check of spatial pattern
- **BR-DWGD gridded reanalysis** (0.1°, 1985–2025) — atmospheric temperature cross-check
- **INMET in-situ station** (1985–2025) — ground-truth atmospheric record
- **Three global temperature products** (HadCRUT5, NASA GISTEMP v4, NOAAGlobalTemp v6) — physical anchoring of the temporal term

## Requirements

- **R** ≥ 4.3.0
- **R packages** (install with `install.packages()` or `renv::install()`):
  `terra`, `sf`, `dplyr`, `tidyr`, `readr`, `readxl`, `ggplot2`, `patchwork`,
  `ggspatial`, `metR`, `fields`, `viridis`, `scales`, `lme4`, `lmerTest`
- **External data** (not tracked — see `data/raw/README.md`):
  MapBiomas Collection 11, Landsat Collection 2 Level-2 ST, MODIS MOD11A2/MYD11A2,
  BR-DWGD v3.2.4, INMET Belém station, HadCRUT5, NASA GISTEMP v4, NOAAGlobalTemp v6.

## Repository structure

| Script | Purpose |
|---|---|
| `R/00_setup.R` | Libraries, paths, global configuration |
| `R/01_lulc_mapbiomas.R` | LULC classification and urban fraction per cell |
| `R/02_landsat_lst.R` | Landsat LST extraction and sensor harmonization |
| `R/03_modis_lst.R` | MODIS LST extraction |
| `R/04_inmet_seasonal.R` | INMET series and seasonal regime definition |
| `R/05_brdwgd.R` | BR-DWGD gridded extraction |
| `R/06_suhi_metrics.R` | SUHI detection, centroids, paired bootstrap |
| `R/07_attribution_model.R` | Parametric attribution (mixed-effects) |
| `R/08_global_tair_validation.R` | Multi-dataset global temperature check |
| `R/09_lst_tair_consistency.R` | LST–Tair temporal consistency |
| `R/10_figures.R` | All main and supplementary figures |
| `R/11_tables.R` | All main and supplementary tables |

## How to run

```r
# 1. Clone this repository
git clone https://github.com/[user]/belem-uhi-amazon.git
cd belem-uhi-amazon

# 2. Place raw data in data/raw/ (see data/raw/README.md for URLs)

# 3. Run the full pipeline from R:
source("run_all.R") 

