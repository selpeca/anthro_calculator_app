# Anthro Calculator App

Calculadora educativa **offline-first** de antropometría pediátrica, basada en las
tablas de referencia de crecimiento **OMS 2006/2007** y la **Resolución 2465 de 2016**
de Colombia.

Aplicación Flutter (Material 3, temas claro y oscuro, español por defecto)
implementada a partir del proyecto de diseño *Anthro OMS Calculator*.

## Resumen

La app calcula los indicadores antropométricos de niñas y niños (0–5 años) a partir
de sexo, fechas de nacimiento y medición, peso, talla y perímetro cefálico. Con
esos datos obtiene la edad exacta, el IMC y el **Z-score + percentil** de cada
indicador contra la referencia LMS de la OMS, con **clasificación por rangos** de
referencia (Normal · Riesgo · Agudo/Severo). Todo el cálculo y el almacenamiento ocurren
en el dispositivo, sin envío a servidores.

**Indicadores calculados** (`computeAnthro`): Peso/Edad, Talla/Edad, Peso/Talla,
IMC/Edad y Perímetro cefálico/Edad, con el ajuste ±0.7 cm por posición
(acostado/de pie) y las ventanas de validez por edad de cada uno.

**Qué se puede hacer:**

- **Calcular** una medición con edad e IMC en vivo y coloreado de plausibilidad
  por campo según la edad.
- **Ver resultados** por indicador (Z, percentil, clasificación) con leyenda de
  semaforización.
- **Graficar** las curvas de crecimiento LMS (bandas ±3 DS) con la trayectoria
  del paciente y el **análisis cuantitativo de déficit/exceso** frente a cada corte.
- **Velocidad de crecimiento** entre dos evaluaciones.
- **Gestionar pacientes**: base local con búsqueda, ficha por paciente e historial
  de mediciones (crear, actualizar/editar mediciones sin duplicar).
- **Exportar** mediciones a **CSV** y las curvas de crecimiento a **PDF**, e
  **importar** mediciones desde CSV (los indicadores se recalculan con el motor).
- **Mantener la base de datos** local: estado, integridad, tamaño en disco y
  acciones de limpieza (fichas vacías, huérfanos, VACUUM, borrar todo).
- **Ajustes**: sistema de unidades (métrico / imperial) y estándar de referencia
  (OMS 2006 / Resolución 2465).

## Pantallas (`lib/screens/`)

| Archivo | Pantalla |
|---------|----------|
| `splash.dart` | Splash con carga de la referencia y sello offline |
| `home.dart` | Panel: acción rápida, vista previa de pacientes, tendencia de mediciones por semana/mes, menú lateral |
| `calculator.dart` | Captura de datos — fechas editables, edad e IMC en vivo, plausibilidad real, toggles de referencia y posición |
| `results.dart` | Z-scores por indicador + hoja de leyenda de semaforización |
| `charts_screen.dart` | Curvas de crecimiento LMS + análisis cuantitativo de déficit |
| `growth_curve_view.dart` | Widget compartido de la curva LMS con la trayectoria del paciente (usado por curvas y ficha) |
| `velocity.dart` | Velocidad de crecimiento entre evaluaciones |
| `patients.dart` | Base de pacientes con búsqueda |
| `patient_detail.dart` | Ficha del paciente con historial, tendencia y curva |
| `reference_status.dart` | Estado (solo lectura) de las tablas de referencia instaladas |
| `database_status.dart` | Monitoreo y mantenimiento de la base local (SQLite) |
| `app_drawer.dart` · `about_dialog.dart` | Menú lateral (unidades, base de datos, acerca de) y diálogo de créditos |

## Estructura

- `main.dart` — raíz de la app, `themeModeNotifier`, locale `es`.
- `theme.dart` — tokens de diseño (`AppPalette` claro/oscuro), semáforo `ClinicalStatus`.
- `data.dart` — modelos, datos de ejemplo y helpers clínicos `Anthro` (IMC, notas de posición).
- `settings.dart` — enums `UnitSystem` / `ReferenceStandard` y sus notifiers globales.
- `widgets.dart` — componentes compartidos (tarjetas, chips, control segmentado, marca…).
- `charts.dart` — `CustomPainter`s `LmsChart` y `ZScoreChart`.

### Motor antropométrico (`lib/anthro/`)

Cálculo real de Z-score contra la referencia LMS de la OMS 2006 (0–5 años):

- `age.dart` — edad a partir de fechas (`dd/MM/yyyy`), conteo de días seguro en UTC.
- `lms.dart` — `valueFromLms` / `rawZFromLms` / `restrictedZ` de la OMS (aplanado con |Z|>3) / CDF normal.
- `reference.dart` — `ReferenceTable` (búsqueda binaria + interpolación LMS lineal) y `GrowthReference`.
- `indicators.dart` — `computeAnthro`: los cinco indicadores, el ajuste ±0.7 cm por posición,
  las ventanas de validez y el mapeo Z → `ClinicalStatus`.
- `plausibility.dart` — coloreado de campos según la edad.
- `growth_curve.dart` — muestreo de las bandas de curva y filas de análisis de déficit (módulo puro).

### Persistencia (`lib/db/`)

Base local SQLite (`sqflite`), offline-first. Esquema relacional `patients` (1) →
`measurements` (N) → `indicators` (N): guarda toda la entrada del cálculo y todo lo
que muestran los resultados. `database.dart` maneja apertura, migraciones y las
acciones de mantenimiento; `models.dart` son los DTO de lectura para el historial.

### Exportación e importación (`lib/export/`, `lib/import/`)

- `measurement_export.dart` — CSV de mediciones (armado puro y testeable + hoja de compartir).
- `measurement_pdf.dart` — PDF con la ficha, el resumen de indicadores y cada curva LMS con su análisis.
- `measurement_import.dart` — lectura del CSV (mismo formato de exportación); los indicadores se **recalculan**.

### Datos de referencia (`lib/reference/`, `assets/reference/`)

Offline-first y actualizable sin recompilar la app:

- **Semilla de fábrica** en `assets/reference/` (versionada): tablas LMS de la OMS 2006 +
  clasificación de Colombia (Res. 2465), para calcular correctamente desde el primer arranque sin red.
- **Almacén local** en `<appDocs>/reference/`: los paquetes importados ganan a la semilla. `store.dart`
  maneja carga, resolución, validación (esquema, `sha256`, claves monótonas, reconstrucción de cortes SD ±0.01)
  e `install` atómica. `reference_repository.dart` expone el store cargado de forma síncrona a las pantallas.
- `store.dart` indexa los estándares por id; Colombia declara `tablesFrom: oms-2006` (adopta las curvas
  de la OMS y solo difiere en la nomenclatura). La vista de estado es `screens/reference_status.dart`.

La semilla la genera `tool/generate_reference.py` (solo desarrollo, no se distribuye): extrae los `.xlsx`
de las páginas de indicadores de la OMS, parsea las tablas z-score expandidas (`zipfile` de la stdlib, sin
openpyxl), valida el LMS contra las columnas SD publicadas y emite los paquetes CSV + `test/fixtures/who_spot_checks.dart`.

El ícono de la app se dibuja en código (`BrandMark`); el logo original no pudo recuperarse íntegro por la
API de diseño (el tope de lectura de 256 KiB truncaba el PNG).

## Ejecutar

```bash
flutter run
```

El tema claro/oscuro se alterna desde la cabecera del home.

## Pruebas

```bash
flutter test
```

---
Desarrollado por [selpeca](https://www.linkedin.com/in/selpeca/).
