# =============================================================================
# 03_kpis.R
# -----------------------------------------------------------------------------
# Calcula los KPIs de la solución VRP y los compara contra un escenario
# "naive": las mismas asignaciones parada-vehículo, pero visitando las
# paradas en el orden en que fueron generadas (sin heurística de vecino
# más cercano). Esto da una estimación honesta del ahorro que aporta la
# optimización de orden, sin necesidad de un solver externo.
# =============================================================================

library(dplyr)
library(readr)
library(tibble)

if (!file.exists("data/synthetic/rutas_optimizadas.csv")) {
  source("R/02_vrp_heuristic.R")
}

centros   <- read_csv("data/synthetic/centros.csv",             show_col_types = FALSE)
paradas   <- read_csv("data/synthetic/paradas.csv",             show_col_types = FALSE)
vehiculos <- read_csv("data/synthetic/vehiculos.csv",           show_col_types = FALSE)
rutas     <- read_csv("data/synthetic/rutas_optimizadas.csv",   show_col_types = FALSE)

haversine_km <- function(lat1, lon1, lat2, lon2) {
  r <- 6371
  to_rad <- function(x) x * pi / 180
  dlat <- to_rad(lat2 - lat1)
  dlon <- to_rad(lon2 - lon1)
  a <- sin(dlat / 2)^2 + cos(to_rad(lat1)) * cos(to_rad(lat2)) * sin(dlon / 2)^2
  2 * r * asin(pmin(1, sqrt(a)))
}

# -----------------------------------------------------------------------------
# KPIs de la solución optimizada
# -----------------------------------------------------------------------------
km_por_ruta <- rutas %>%
  group_by(id_ruta, id_centro, id_vehiculo) %>%
  summarise(
    km_ruta      = sum(tramo_km),
    n_paradas    = n(),
    alumnos_ruta = sum(alumnos),
    .groups = "drop"
  ) %>%
  left_join(vehiculos %>% select(id_vehiculo, plazas_ordinarias), by = "id_vehiculo") %>%
  mutate(ocupacion_pct = alumnos_ruta / plazas_ordinarias * 100)

km_total_optimizado <- sum(km_por_ruta$km_ruta)
n_rutas             <- nrow(km_por_ruta)
alumnos_totales     <- sum(km_por_ruta$alumnos_ruta)
ocupacion_media     <- mean(km_por_ruta$ocupacion_pct)

# -----------------------------------------------------------------------------
# Escenario "naive": mismas rutas/vehículos, pero visitando las paradas
# en su orden original (id_parada) en lugar del orden optimizado.
# -----------------------------------------------------------------------------
km_total_naive <- rutas %>%
  left_join(
    centros %>% select(id_centro, depot_lat = lat, depot_lon = lon),
    by = "id_centro"
  ) %>%
  arrange(id_ruta, id_parada) %>%
  group_by(id_ruta) %>%
  mutate(
    prev_lat = lag(lat, default = first(depot_lat)),
    prev_lon = lag(lon, default = first(depot_lon)),
    tramo_km = haversine_km(prev_lat, prev_lon, lat, lon)
  ) %>%
  ungroup() %>%
  summarise(total = sum(tramo_km)) %>%
  pull(total)

ahorro_km  <- km_total_naive - km_total_optimizado
ahorro_pct <- ahorro_km / km_total_naive * 100

kpis <- tibble(
  km_total_optimizado = round(km_total_optimizado, 1),
  km_total_naive       = round(km_total_naive, 1),
  ahorro_km             = round(ahorro_km, 1),
  ahorro_pct            = round(ahorro_pct, 1),
  n_rutas               = n_rutas,
  n_paradas             = nrow(paradas),
  n_centros             = nrow(centros),
  alumnos_totales       = alumnos_totales,
  ocupacion_media_pct   = round(ocupacion_media, 1)
)

write_csv(kpis,        "data/synthetic/kpis.csv")
write_csv(km_por_ruta, "data/synthetic/km_por_ruta.csv")

message("KPIs calculados:")
print(kpis)
