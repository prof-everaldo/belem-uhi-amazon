# ============================================================
# 06 — SUHI metrics: k-means detection, centroids, bootstrap
# ============================================================

cat("Computing SUHI metrics...\n")

lst_annual <- read_csv(file.path(paths$processed, "lst_landsat_annual.csv"),
                       show_col_types = FALSE)
grid_coords <- lst_annual %>% distinct(grid_id, lon_c, lat_c)

compute_period <- function(df, ini, fim) {
  df %>%
    filter(ano >= ini, ano <= fim) %>%
    group_by(grid_id) %>%
    summarise(LST_media = mean(LST_dry, na.rm = TRUE),
              urb_media = mean(frac_urbana, na.rm = TRUE),
              n_obs = n(), .groups = "drop") %>%
    filter(n_obs >= 3) %>%
    left_join(grid_coords, by = "grid_id")
}

lst_p1 <- compute_period(lst_annual, CONFIG$period_pre[1], CONFIG$period_pre[2])
lst_p2 <- compute_period(lst_annual, CONFIG$period_post[1], CONFIG$period_post[2])

# --- Fixed k-means partition (reference = P2) ---
set.seed(CONFIG$seed)

bg <- lst_p2 %>% filter(urb_media < CONFIG$bg_threshold) %>%
  summarise(bg = median(LST_media, na.rm = TRUE)) %>% pull(bg)

df_urb <- lst_p2 %>%
  filter(urb_media > CONFIG$urban_threshold) %>%
  mutate(excesso = pmax(LST_media - bg, 0)) %>%
  filter(excesso > 0)

km <- kmeans(cbind(df_urb$lon_c, df_urb$lat_c), centers = 2, nstart = 25)
df_urb$cluster <- km$cluster

centros <- df_urb %>%
  group_by(cluster) %>%
  summarise(lon = weighted.mean(lon_c, excesso), .groups = "drop")
ordem <- order(centros$lon)
df_urb <- df_urb %>%
  mutate(cidade = ifelse(cluster == centros$cluster[ordem[1]],
                         "Belém", "Ananindeua"))

particao_fixa <- df_urb %>% select(grid_id, cidade)

aplicar_particao <- function(df, particao) {
  bg_p <- df %>% filter(urb_media < CONFIG$bg_threshold) %>%
    summarise(bg = median(LST_media, na.rm = TRUE)) %>% pull(bg)
  df %>%
    filter(urb_media > CONFIG$urban_threshold) %>%
    mutate(excesso = pmax(LST_media - bg_p, 0)) %>%
    filter(excesso > 0) %>%
    left_join(particao, by = "grid_id") %>%
    filter(!is.na(cidade)) %>%
    mutate(background = bg_p)
}

lst_p1_p <- aplicar_particao(lst_p1, particao_fixa)
lst_p2_p <- aplicar_particao(lst_p2, particao_fixa)

assign_blocks <- function(df) {
  block_deg <- 0.025 * CONFIG$block_size
  df %>%
    mutate(block_x = floor(lon_c / block_deg),
           block_y = floor(lat_c / block_deg),
           block_id = paste(block_x, block_y, sep = "_"))
}

lst_p1_p <- assign_blocks(lst_p1_p)
lst_p2_p <- assign_blocks(lst_p2_p)

metricas <- function(df) {
  df %>%
    group_by(cidade) %>%
    summarise(
      centro_lon    = weighted.mean(lon_c, excesso, na.rm = TRUE),
      centro_lat    = weighted.mean(lat_c, excesso, na.rm = TRUE),
      intensidade   = max(LST_media, na.rm = TRUE) - unique(background),
      excesso_total = sum(excesso),
      .groups = "drop"
    )
}

paired_bootstrap <- function(df1, df2, n_boot = CONFIG$n_boot) {
  set.seed(CONFIG$seed)
  common_blocks <- intersect(unique(df1$block_id), unique(df2$block_id))
  n_blocks <- length(common_blocks)
  results <- vector("list", n_boot)
  for (b in seq_len(n_boot)) {
    sampled <- sample(common_blocks, size = n_blocks, replace = TRUE)
    df1_b <- bind_rows(lapply(sampled, function(blk) df1[df1$block_id == blk, ]))
    df2_b <- bind_rows(lapply(sampled, function(blk) df2[df2$block_id == blk, ]))
    m1 <- tryCatch(metricas(df1_b), error = function(e) NULL)
    m2 <- tryCatch(metricas(df2_b), error = function(e) NULL)
    if (is.null(m1) || is.null(m2)) next
    combined <- m1 %>%
      rename_with(~ paste0(., "_p1"), -cidade) %>%
      inner_join(m2 %>% rename_with(~ paste0(., "_p2"), -cidade),
                 by = "cidade") %>%
      mutate(iter = b)
    results[[b]] <- combined
  }
  bind_rows(results)
}

cat("Running paired bootstrap...\n")
boot_pair <- paired_bootstrap(lst_p1_p, lst_p2_p)
write_csv(boot_pair, file.path(paths$processed, "suhi_bootstrap.csv"))

resumo <- boot_pair %>%
  group_by(cidade) %>%
  summarise(
    d_int_mean = mean(intensidade_p2 - intensidade_p1),
    d_int_lo   = quantile(intensidade_p2 - intensidade_p1, 0.025),
    d_int_hi   = quantile(intensidade_p2 - intensidade_p1, 0.975),
    d_exc_mean = mean(excesso_total_p2 - excesso_total_p1),
    d_exc_lo   = quantile(excesso_total_p2 - excesso_total_p1, 0.025),
    d_exc_hi   = quantile(excesso_total_p2 - excesso_total_p1, 0.975),
    .groups = "drop"
  )

write_csv(resumo, file.path(paths$tables, "suhi_metrics_summary.csv"))
saveRDS(list(p1 = lst_p1_p, p2 = lst_p2_p, particao = particao_fixa),
        file.path(paths$processed, "suhi_data.rds"))

cat("✓ SUHI metrics computed\n")
print(resumo)
