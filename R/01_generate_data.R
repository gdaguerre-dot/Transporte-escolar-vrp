# =============================================================================
# 01_generate_data.R
# -----------------------------------------------------------------------------
# Genera un dataset sintético coherente con el modelo de datos descrito en
# "Requerimientos Transportes V1.1" (Empresa, Lote_Transporte, Ruta, Vehiculo,
# Parada, Centro), para poder ejercitar sobre él un VRP básico.
#
# Nivel de profundidad: BÁSICO — datos sintéticos, sin geodatos reales.
# =============================================================================

library(dplyr)
library(tibble)
library(purrr)
library(readr)

set.seed(123)

# --- Bounding box aproximado de la isla de Mallorca (solo para dar
#     plausibilidad geográfica a los puntos, no son ubicaciones reales) -------
lat_range <- c(39.45, 39.70)
lon_range <- c(2.55, 3.05)

random_point <- function(n) {
  tibble(
    lat = runif(n, lat_range[1], lat_range[2]),
    lon = runif(n, lon_range[1], lon_range[2])
  )
}

# -----------------------------------------------------------------------------
# EMPRESA
# -----------------------------------------------------------------------------
empresas <- tibble(
  id_empresa   = 1:4,
  razon_social = c(
    "Transportes Illes S.L.",
    "Autocares Serra",
    "Mobilitat Balear S.A.",
    "Acompanya't Cooperativa"
  ),
  tipo_empresa = c("Transporte", "Transporte", "Transporte", "Acompañante")
)

# -----------------------------------------------------------------------------
# CENTRO (colegios)
# -----------------------------------------------------------------------------
municipios <- c("Palma", "Inca", "Manacor", "Calvia", "Llucmajor", "Marratxi")
n_centros  <- 6

centros <- bind_cols(
  tibble(
    id_centro     = 1:n_centros,
    nombre_centro = paste0(
      "CEIP ",
      c("Es Pilari", "Son Ferriol", "Camp Redo",
        "Rafal Vell", "Verge de Lluc", "Gabriel Vallseca")
    ),
    municipio = sample(municipios, n_centros, replace = TRUE)
  ),
  random_point(n_centros)
)

# -----------------------------------------------------------------------------
# LOTE_TRANSPORTE
# -----------------------------------------------------------------------------
lotes <- tibble(
  id_lote               = 1:3,
  nombre_lote           = paste0("Lote-", 1:3),
  id_empresa_transporte = c(1, 2, 3),
  isla                  = "Mallorca",
  zona_geografica       = c("Palma-Levante", "Raiguer", "Migjorn")
)

# -----------------------------------------------------------------------------
# VEHICULO
# -----------------------------------------------------------------------------
n_vehiculos <- 8
vehiculos <- tibble(
  id_vehiculo       = 1:n_vehiculos,
  nombre            = sprintf("V%03d", 1:n_vehiculos),
  id_lote           = sample(lotes$id_lote, n_vehiculos, replace = TRUE),
  plazas_ordinarias = sample(c(20, 30, 40), n_vehiculos, replace = TRUE),
  plazas_pmr        = sample(c(0, 2, 4), n_vehiculos, replace = TRUE)
)

# -----------------------------------------------------------------------------
# PARADA
# -----------------------------------------------------------------------------
# Cada centro tiene entre 4 y 7 paradas a su alrededor (jitter ~1km),
# cada una con una demanda de alumnos a recoger.
paradas_por_centro <- function() sample(4:7, 1)

paradas <- centros %>%
  select(id_centro, centro_lat = lat, centro_lon = lon, nombre_centro) %>%
  pmap_dfr(function(id_centro, centro_lat, centro_lon, nombre_centro) {
    n <- paradas_por_centro()
    tibble(
      id_centro     = id_centro,
      nombre_parada = paste0("Parada ", nombre_centro, " ", seq_len(n)),
      lat           = centro_lat + rnorm(n, sd = 0.012),
      lon           = centro_lon + rnorm(n, sd = 0.012),
      alumnos       = sample(3:15, n, replace = TRUE)
    )
  }) %>%
  mutate(id_parada = row_number()) %>%
  select(id_parada, id_centro, nombre_parada, lat, lon, alumnos)

# -----------------------------------------------------------------------------
# Guardar
# -----------------------------------------------------------------------------
dir.create("data/synthetic", recursive = TRUE, showWarnings = FALSE)

write_csv(empresas,  "data/synthetic/empresas.csv")
write_csv(centros,   "data/synthetic/centros.csv")
write_csv(lotes,     "data/synthetic/lotes.csv")
write_csv(vehiculos, "data/synthetic/vehiculos.csv")
write_csv(paradas,   "data/synthetic/paradas.csv")

message(sprintf(
  "Dataset generado: %d centros, %d paradas, %d vehiculos, %d lotes.",
  nrow(centros), nrow(paradas), nrow(vehiculos), nrow(lotes)
))
