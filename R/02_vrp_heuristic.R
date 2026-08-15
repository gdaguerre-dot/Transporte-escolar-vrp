# =============================================================================
# 02_vrp_heuristic.R
# -----------------------------------------------------------------------------
# Resuelve un Capacitated VRP BÁSICO (sin ventanas horarias) mediante una
# heurística de vecino más cercano: para cada Centro, se van formando rutas
# tomando siempre la parada no asignada más cercana al último punto visitado,
# hasta agotar la capacidad (en alumnos) del vehículo asignado a esa ruta.
#
# Esta es una heurística constructiva simple (no un solver MILP como OR-Tools
# o ompr) — suficiente para el nivel "básico" y fácil de explicar en el
# dashboard. Queda documentado como posible extensión futura.
# =============================================================================

library(dplyr)
library(readr)
library(purrr)
library(tibble)

# --- Cargar datos (si no existen, generarlos primero) ------------------------
if (!file.exists("data/synthetic/paradas.csv")) {
  source("R/01_generate_data.R")
}

centros   <- read_csv("data/synthetic/centros.csv",   show_col_types = FALSE)
paradas   <- read_csv("data/synthetic/paradas.csv",   show_col_types = FALSE)
vehiculos <- read_csv("data/synthetic/vehiculos.csv", show_col_types = FALSE)

# -----------------------------------------------------------------------------
# Distancia Haversine (km) entre dos puntos lat/lon
# -----------------------------------------------------------------------------
haversine_km <- function(lat1, lon1, lat2, lon2) {
  r <- 6371
  to_rad <- function(x) x * pi / 180
  dlat <- to_rad(lat2 - lat1)
  dlon <- to_rad(lon2 - lon1)
  a <- sin(dlat / 2)^2 + cos(to_rad(lat1)) * cos(to_rad(lat2)) * sin(dlon / 2)^2
  2 * r * asin(pmin(1, sqrt(a)))
}

# -----------------------------------------------------------------------------
# Construye UNA ruta con heurística de vecino más cercano, respetando
# la capacidad (en alumnos) del vehículo.
# -----------------------------------------------------------------------------
build_route <- function(depot_lat, depot_lon, pool, capacidad) {
  ruta <- tibble()
  current_lat <- depot_lat
  current_lon <- depot_lon
  restante <- capacidad

  while (nrow(pool) > 0) {
    pool <- pool %>%
      mutate(dist_tmp = haversine_km(current_lat, current_lon, lat, lon))

    candidatos <- pool %>% filter(alumnos <= restante)
    if (nrow(candidatos) == 0) break

    siguiente <- candidatos %>% slice_min(dist_tmp, n = 1, with_ties = FALSE)

    ruta <- bind_rows(ruta, siguiente %>% select(-dist_tmp))
    restante <- restante - siguiente$alumnos
    current_lat <- siguiente$lat
    current_lon <- siguiente$lon
    pool <- pool %>% filter(id_parada != siguiente$id_parada)
  }

  list(ruta = ruta, pool_restante = pool %>% select(-any_of("dist_tmp")))
}

# -----------------------------------------------------------------------------
# Resuelve el VRP básico para UN centro: reparte sus paradas entre vehículos
# (recorridos en round-robin) hasta cubrirlas todas.
# -----------------------------------------------------------------------------
solve_centro <- function(id_centro_actual, paradas_centro, depot_lat, depot_lon, vehiculos) {
  pool <- paradas_centro
  rutas <- list()
  ruta_n <- 1
  veh_idx <- 1
  intentos_sin_avance <- 0

  while (nrow(pool) > 0 && intentos_sin_avance <= nrow(vehiculos) * 2) {
    vehiculo <- vehiculos[((veh_idx - 1) %% nrow(vehiculos)) + 1, ]
    capacidad <- vehiculo$plazas_ordinarias

    resultado <- build_route(depot_lat, depot_lon, pool, capacidad)

    if (nrow(resultado$ruta) > 0) {
      rutas[[ruta_n]] <- resultado$ruta %>%
        mutate(
          id_ruta      = paste0("C", id_centro_actual, "-R", ruta_n),
          id_centro    = id_centro_actual,
          id_vehiculo  = vehiculo$id_vehiculo,
          orden_parada = row_number()
        )
      ruta_n <- ruta_n + 1
      pool <- resultado$pool_restante
      intentos_sin_avance <- 0
    } else {
      intentos_sin_avance <- intentos_sin_avance + 1
    }
    veh_idx <- veh_idx + 1
  }

  if (length(rutas) == 0) return(tibble())
  bind_rows(rutas)
}

# -----------------------------------------------------------------------------
# Resolver para todos los centros
# -----------------------------------------------------------------------------
resultado_vrp <- centros %>%
  select(id_centro, lat, lon) %>%
  pmap_dfr(function(id_centro, lat, lon) {
    paradas_centro <- paradas %>% filter(id_centro == !!id_centro)
    solve_centro(id_centro, paradas_centro, lat, lon, vehiculos)
  })

# -----------------------------------------------------------------------------
# Distancia por tramo (depot -> primera parada -> ... -> última parada)
# -----------------------------------------------------------------------------
rutas_con_distancia <- resultado_vrp %>%
  left_join(
    centros %>% select(id_centro, depot_lat = lat, depot_lon = lon),
    by = "id_centro"
  ) %>%
  arrange(id_ruta, orden_parada) %>%
  group_by(id_ruta) %>%
  mutate(
    prev_lat = lag(lat, default = first(depot_lat)),
    prev_lon = lag(lon, default = first(depot_lon)),
    tramo_km = haversine_km(prev_lat, prev_lon, lat, lon)
  ) %>%
  ungroup() %>%
  select(
    id_ruta, id_centro, id_vehiculo, orden_parada, id_parada,
    nombre_parada, alumnos, lat, lon, tramo_km
  )

dir.create("data/synthetic", recursive = TRUE, showWarnings = FALSE)
write_csv(rutas_con_distancia, "data/synthetic/rutas_optimizadas.csv")

message(sprintf(
  "VRP resuelto: %d rutas generadas para %d paradas.",
  n_distinct(rutas_con_distancia$id_ruta), nrow(rutas_con_distancia)
))
