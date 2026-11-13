# Lab Analysis Calculator (Chl-a · POC/PON · POP · BSi)

A Shiny app for processing common oceanography/limnology lab measurements:
chlorophyll-a and phaeopigments, particulate organic carbon and nitrogen (POC/PON),
particulate organic phosphorus (POP) and biogenic silica (BSi).
It runs entirely in the browser through [Shinylive](https://posit-dev.github.io/r-shinylive/):
nothing to install.

**Live app:** https://nicoschiff.github.io/labo_calculs/

## Features

- Four tabs: **Chl-a**, **POC / PON**, **POP**, **BSi**
- Upload `.csv` (comma, semicolon or tab separated, `1.25` or `1,25`) or `.xlsx`
- Tolerant column headers: case, spaces, underscores and UTF-8 BOM are ignored
- Blank correction
  - Chl-a: one Fb/Fa blank per measurement range (L, M, H)
  - POC/PON, POP, BSi: any number of replicate blanks; the mean is subtracted
    (mean, n and SD are displayed)
- **Dilution factor (FD)** supported in Chl-a, POP and BSi (see below)
- Results in an interactive table (3 decimals on screen, full precision in the export)
- **CSV export** done directly in the browser
- **Empty template download** for each analysis, with the correct column names
- Extra columns (sample ID, station, depth…) are kept unchanged in the export

## Input columns

| Tab | Required | Optional |
|---|---|---|
| Chl-a | `Fb`, `Fa`, `Vol`, `Level_Fb`, `Level_Fa` | `FD`, or `V_extrait` + `V_acetone` |
| POC / PON | `Volume_L`, `PC_mg`, `PN_mg` | — |
| POP | `Volume_L`, `Concentration` | `Vol_extrait_L` (default 0.005 L), `FD` (default 1) |
| BSi | `Volume_L`, `Concentration` | `Vol_extrait_L` (default 0.025 L), `FD` (default 1) |

- `Fb` / `Fa`: fluorescence before / after acidification
- `Vol`: filtered volume
- `Level_Fb` / `Level_Fa`: measurement range `L`, `M` or `H`, used to pick the blank
  (trimmed, case-insensitive; an error is shown if a level has no matching blank)
- For POP and BSi, `FD` may also be named `Fact_dil`, `Dilution` or `Dil`
- A value present in the file always overrides the default, so a dilution can be
  set for a single sample

Tip: use **Télécharger un modèle vide (.csv)** in each tab to get a ready-to-fill file.

## Chl-a calculation

Blank correction by range:

```text
Fb_c = Fb − Fb.blank[Level_Fb]
Fa_c = Fa − Fa.blank[Level_Fa]
```

Dilution factor, in order of priority:

1. `FD` column present → its values are used (`NA` → 1)
2. Otherwise, `V_extrait` and `V_acetone` both present →
   `FD = (V_extrait + V_acetone) / V_extrait` (e.g. 2 + 6 → FD = 4)
3. Otherwise `FD = 1`

The `FD` actually used is added to the results.

```text
Chla  = FD × K × (Fb_c − Fa_c) / Vol
Phaeo = FD × K × (A × Fa_c − Fb_c) / Vol
```

Defaults: `K = 1.789` (includes extraction volume), `A = 2.052` (acid ratio),
blanks = 0. All are editable in the interface.

Example:

| Fb | Fa | Vol | Level_Fb | Level_Fa | FD |
|---|---|---|---|---|---|
| 120 | 45 | 10 | L | L | 1 |
| 210 | 80 | 10 | M | M | 2 |

POC/PON, POP and BSi formulas are defined in `app/calc_functions.R`.

## CSV export

- Comma separator, `.` decimal mark, UTF-8 with BOM (opens correctly in Excel)
- Missing values written as empty cells
- File name: `<analysis>_resultats_YYYY-MM-DD.csv` (e.g. `chla_resultats_2026-11-13.csv`)
- The download is generated client-side (JavaScript `Blob`), because Shiny's
  `downloadHandler` returns an `.html` file under Shinylive

## Run locally

```r
install.packages(c("shiny", "readxl", "DT"))
shiny::runApp("app")
```

## Update the online version

From the repository root (keep it outside iCloud, e.g. `~/GitHub/labo_calculs`):

```r
setwd("~/GitHub/labo_calculs")
unlink("docs", recursive = TRUE)
shinylive::export("app", "docs")
```

Then in GitHub Desktop: **Commit to main** → **Push origin**.
GitHub Pages is set to deploy from `main` / `docs`. Allow a few minutes after the push;
if an old version still shows up, hard-refresh (**Cmd+Shift+R**) or unregister the
service worker (DevTools → Application → Service workers → Unregister).

## Repository structure

```text
labo_calculs/
├── app/
│   ├── app.R             # Shiny UI and server (Chl-a, POC/PON, POP, BSi)
│   └── calc_functions.R  # POC/PON, POP and BSi calculations
├── docs/                 # Shinylive export served by GitHub Pages
├── templates/            # Example input files
├── tests/                # Tests
├── CHANGELOG.md
└── README.md
```

## Troubleshooting

- **"Colonnes manquantes"**: check column names (see table above, or download a template).
- **"Certains niveaux (L/M/H) sont vides ou n'ont pas de blanc associé"**:
  `Level_Fb` / `Level_Fa` must be `L`, `M` or `H` on every row.
- **Dilution seems ignored**: check the `FD` column in the results table. If it shows 1,
  the file has no `FD` (or `V_extrait`/`V_acetone`) column, or the header is misspelled.
- **Download gives an `.html` file**: the site is serving an old export; re-export `docs/`
  and clear the service worker.
