# Chlorophyll-a and Phaeopigment Calculator

A Shiny app for calculating chlorophyll-a (Chla) and phaeopigment (Phaeo) from fluorescence measurements, with blank correction, optional dilution-factor handling, and CSV export.

**Live app:** <[https://nicoschiff.github.io/chla_app/](https://nicoschiff.github.io/projet_chla/)>

## Features

- Upload measurement data as a `.csv` or `.xlsx` file.
- Set the calibration factors **K** and **A** and the fluorescence blanks for the **L**, **M**, and **H** levels. The app starts with `K = 1.789`, `A = 2.052`, and zero for each blank value; these values can be changed in the interface.
- Calculate Chla and Phaeo and inspect the results in a browsable table. The displayed `FD`, `Chla`, and `Phaeo` values are rounded to three decimal places.
- Download the results as a CSV file in the browser.

## Input file format

The uploaded file must contain these columns:

| Column | Purpose |
|---|---|
| `Fb` | Fluorescence measurement before acidification |
| `Fa` | Fluorescence measurement after acidification |
| `Vol` | Volume value used as the denominator in the calculations |
| `Level_Fb` | Blank level associated with `Fb` (`L`, `M`, or `H`) |
| `Level_Fa` | Blank level associated with `Fa` (`L`, `M`, or `H`) |

The level labels are trimmed and compared without regard to letter case. The app reports an error if a non-empty level does not match an available `L`, `M`, or `H` blank.

The dilution factor is optional:

- If `FD` is present, its values are used; missing (`NA`) `FD` values default to `1`.
- If `FD` is absent and both `V_extrait` and `V_acetone` are present, the app calculates `FD = (V_extrait + V_acetone) / V_extrait`. For example, `V_extrait = 2` and `V_acetone = 6` give `FD = 4`.
- If neither condition applies, `FD` defaults to `1` for every row.

Illustrative CSV-style example (measurement values are placeholders):

| Fb | Fa | Vol | Level_Fb | Level_Fa | FD |
|---:|---:|---:|:---:|:---:|---:|
| 120 | 45 | 10 | L | L | 1 |
| 210 | 80 | 10 | M | M | 2 |

CSV uploads may use comma or semicolon separators. The app selects a CSV reader based on the first line and tries the alternate reader if parsing fails. Excel uploads must be `.xlsx` files.

## Calculations

For each measurement, the app subtracts the blank matching its fluorescence level:

- `Fb_c = Fb - Fb.blank[Level_Fb]`
- `Fa_c = Fa - Fa.blank[Level_Fa]`

It then calculates:

```text
Chla  = FD × K × (Fb_c − Fa_c) / Vol
Phaeo = FD × K × (A × Fa_c − Fb_c) / Vol
```

The interface defaults are `K = 1.789` and `A = 2.052`. Blank inputs for each of `L`, `M`, and `H` start at zero. These are user-adjustable calibration and blank values.

For CSV input, blank lines are retained by the CSV import settings; blank measurement records yield missing calculated values rather than numeric Chla/Phaeo values. Missing values are written as empty cells in the downloaded CSV. (Excel files are read with `readxl`.)

## Export

Select **Download result (.csv)** to initiate a browser-side download. The exported file:

- uses a comma separator and `.` as the decimal mark;
- is UTF-8 encoded and includes a UTF-8 BOM;
- writes missing values as empty cells;
- is named `chla_resultats_YYYY-MM-DD.csv`, using the app server's current date.

The export contains the result data, not the three-decimal display formatting applied to the interactive table.

## Run locally

Install R, then install the packages used by the app:

```r
install.packages(c("shiny", "readxl", "dplyr", "tibble", "DT"))
```

From the repository's parent directory, run:

```r
shiny::runApp("chla_app")
```

## Deploy or update on GitHub Pages

From the repository's parent directory, export the app for shinylive:

```r
shinylive::export(appdir = "chla_app", destdir = "docs")
```

After export, use GitHub Desktop to commit and push the updated files. In the repository's GitHub Pages settings, select deployment from the `main` branch and the `/docs` folder.

## Repository structure

```text
chla_app/
└── app.R       # Shiny application

docs/           # shinylive export served by GitHub Pages
.gitignore
```

## Notes and troubleshooting

- Check that the required column names are spelled exactly as shown, including capitalization and underscores.
- Confirm that each non-empty `Level_Fb` and `Level_Fa` entry is `L`, `M`, or `H`, and that the relevant blank values are set in the app.
- If the browser appears to show an older deployed version, try a hard refresh: **Cmd+Shift+R** on macOS.

## License

**License: To be determined.** Add the applicable license before redistributing the app.
