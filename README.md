# Transporte Escolar — Optimización de Rutas (VRP básico)

Caso de estudio de portfolio: optimización de rutas de transporte escolar,
combinando un **modelo de datos real** (extraído de un documento de
requerimientos funcionales de un módulo de transporte interinstitucional)
con la **metodología de optimización** descrita en Bertsimas et al. (2019),
*"Optimizing schools' start time and bus routes"* (PNAS) — el caso real de
Boston Public Schools.

## Motivación

- El documento de requerimientos define el modelo de negocio: Empresas,
  Lotes de Transporte, Vehículos, Rutas, Paradas y Centros educativos.
- El paper de Boston demuestra, con un caso real, que optimizar
  algorítmicamente el transporte escolar genera ahorros significativos
  (BPS reinvirtió ~$18M en aulas gracias a este tipo de optimización).

Este proyecto toma el modelo de datos del primer documento y le aplica una
versión simplificada del segundo: un **Vehicle Routing Problem (VRP)
capacitado**, resuelto con una heurística de vecino más cercano.

## Alcance de esta versión (nivel básico)

| Etapa | Alcance |
|---|---|
| 1. Modelo de datos | Diagrama ER + diccionario de datos, sin BD real |
| 2. Dataset | Sintético (coordenadas aleatorias dentro de un bounding box de Mallorca) |
| 3. Optimización | VRP capacitado, heurística vecino más cercano, **sin** ventanas horarias ni GQAP de horarios de campana |
| 4. Visualización | Quarto Dashboard (mapa Leaflet + KPIs + tablas) |

**Fuera de alcance (posibles extensiones futuras):**
- Ventanas horarias por parada (VRPTW).
- Solver exacto/MILP (OR-Tools, ompr) en lugar de heurística.
- Geodatos reales de centros educativos (OpenStreetMap / Nominatim).
- Optimización conjunta de horarios de campana (GQAP, como en el paper original).

## Estructura del repo

```
transporte-escolar-vrp/
├── dashboard.qmd           # Dashboard Quarto (punto de entrada)
├── _quarto.yml
├── R/
│   ├── 01_generate_data.R  # Genera el dataset sintético
│   ├── 02_vrp_heuristic.R  # Resuelve el VRP (vecino más cercano + capacidad)
│   └── 03_kpis.R           # Calcula KPIs y compara vs. escenario sin optimizar
└── data/
    └── synthetic/          # CSVs generados (no versionados, ver .gitignore)
```

## Cómo correrlo

Requisitos: R (≥4.2), Quarto (≥1.4), y los paquetes:

```r
install.packages(c(
  "dplyr", "readr", "tibble", "purrr", "tidyr",
  "leaflet", "DT", "gt", "scales"
))
```

Luego, desde la raíz del proyecto:

```bash
quarto render dashboard.qmd
```

o simplemente abrir `dashboard.qmd` en Positron/RStudio y hacer clic en
**Render** (el propio dashboard corre el pipeline completo —
`01 -> 02 -> 03` — en su chunk de setup).

## Metodología del VRP

Para cada Centro:
1. Se recorren sus Paradas asignando vehículos de forma round-robin.
2. Cada ruta se construye con una heurística de **vecino más cercano**:
   desde el centro (depot), se agrega siempre la parada no visitada más
   cercana que todavía quepa en la capacidad restante del vehículo
   (medida en alumnos).
3. Se cierra la ruta cuando no queda capacidad para ninguna parada
   restante, y se abre una ruta nueva (mismo u otro vehículo).

Para cuantificar el valor de la optimización, se compara contra un
**escenario naive**: las mismas asignaciones parada→vehículo, pero
visitadas en el orden en que fueron generadas (sin heurística de
cercanía). La diferencia de kilómetros entre ambos escenarios es el
KPI de "ahorro" que se muestra en el dashboard.

## Fuentes

- Documento de requerimientos funcionales del módulo de Transporte Inter (v1.1).
- Bertsimas, D., Delarue, A., Martin, S. (2019). *Optimizing schools' start
  time and bus routes*. PNAS.
