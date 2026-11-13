# Calculateur d’analyses de laboratoire (Chl-a · POC/PON · POP · BSi)

Application Shiny pour traiter les mesures courantes en laboratoire d’océanographie et de limnologie :
chlorophylle a et phéopigments, carbone et azote organiques particulaires (POC/PON),
phosphore organique particulaire (POP) et silice biogénique (BSi).
Elle s’exécute entièrement dans le navigateur grâce à [Shinylive](https://posit-dev.github.io/r-shinylive/) :
rien à installer.

**Application en ligne :** https://nicoschiff.github.io/labo_calculs/

## Fonctionnalités

- Quatre onglets : **Chl-a**, **POC / PON**, **POP**, **BSi**
- Import de fichiers `.csv` (séparés par des virgules, des points-virgules ou des tabulations, avec `1.25` ou `1,25`) ou `.xlsx`
- En-têtes de colonnes flexibles : la casse, les espaces, les tirets bas et le BOM UTF-8 sont ignorés
- Correction du blanc
  - Chl-a : un blanc Fb/Fa par plage de mesure (L, M, H)
  - POC/PON, POP, BSi : nombre quelconque de blancs répétés ; leur moyenne est soustraite
    (la moyenne, n et l’écart-type sont affichés)
- **Facteur de dilution (FD)** pris en charge pour Chl-a, POP et BSi (voir ci-dessous)
- Résultats dans un tableau interactif (3 décimales à l’écran, précision complète dans l’export)
- **Export CSV** effectué directement dans le navigateur
- **Téléchargement d’un modèle vide** pour chaque analyse, avec les noms de colonnes appropriés
- Les colonnes supplémentaires (ID d’échantillon, station, profondeur…) sont conservées sans modification dans l’export

## Colonnes d’entrée

| Onglet | Obligatoires | Facultatives |
|---|---|---|
| Chl-a | `Fb`, `Fa`, `Vol`, `Level_Fb`, `Level_Fa` | `FD`, ou `V_extrait` + `V_acetone` |
| POC / PON | `Volume_L`, `PC_mg`, `PN_mg` | — |
| POP | `Volume_L`, `Concentration` | `Vol_extrait_L` (par défaut : 0.005 L), `FD` (par défaut : 1) |
| BSi | `Volume_L`, `Concentration` | `Vol_extrait_L` (par défaut : 0.025 L), `FD` (par défaut : 1) |

- `Fb` / `Fa` : fluorescence avant / après acidification
- `Vol` : volume filtré
- `Level_Fb` / `Level_Fa` : plage de mesure `L`, `M` ou `H`, utilisée pour sélectionner le blanc
  (espaces de début et de fin supprimés, sans distinction de casse ; une erreur s’affiche si aucun blanc correspondant n’existe pour une plage)
- Pour POP et BSi, `FD` peut aussi être nommé `Fact_dil`, `Dilution` ou `Dil`
- Une valeur présente dans le fichier remplace toujours la valeur par défaut ; la dilution peut donc être définie pour un seul échantillon

Conseil : utilisez **Télécharger un modèle vide (.csv)** dans chaque onglet pour obtenir un fichier prêt à remplir.

## Calcul de Chl-a

Correction du blanc par plage :

```text
Fb_c = Fb − Fb.blank[Level_Fb]
Fa_c = Fa − Fa.blank[Level_Fa]
```

Facteur de dilution, par ordre de priorité :

1. Colonne `FD` présente → ses valeurs sont utilisées (`NA` → 1)
2. Sinon, si `V_extrait` et `V_acetone` sont toutes deux présentes →
   `FD = (V_extrait + V_acetone) / V_extrait` (ex. : 2 + 6 → FD = 4)
3. Sinon, `FD = 1`

Le `FD` effectivement utilisé est ajouté aux résultats.

```text
Chla  = FD × K × (Fb_c − Fa_c) / Vol
Phaeo = FD × K × (A × Fa_c − Fb_c) / Vol
```

Valeurs par défaut : `K = 1.789` (inclut le volume d’extraction), `A = 2.052` (rapport d’acidification),
blancs = 0. Ces valeurs peuvent toutes être modifiées dans l’interface.

Exemple :

| Fb | Fa | Vol | Level_Fb | Level_Fa | FD |
|---|---|---|---|---|---|
| 120 | 45 | 10 | L | L | 1 |
| 210 | 80 | 10 | M | M | 2 |

Les formules de POC/PON, POP et BSi sont définies dans `app/calc_functions.R`.

## Export CSV

- Séparateur : virgule ; séparateur décimal : `.` ; encodage UTF-8 avec BOM (s’ouvre correctement dans Excel)
- Les valeurs manquantes sont écrites dans des cellules vides
- Nom du fichier : `<analysis>_resultats_YYYY-MM-DD.csv` (ex. : `chla_resultats_2026-11-13.csv`)
- Le téléchargement est généré côté client (JavaScript `Blob`), car le `downloadHandler` de Shiny renvoie un fichier `.html` dans Shinylive

## Exécution en local

```r
install.packages(c("shiny", "readxl", "DT"))
shiny::runApp("app")
```

## Mise à jour de la version en ligne

Depuis la racine du dépôt (en dehors d’iCloud, par exemple `~/GitHub/labo_calculs`) :

```r
setwd("~/GitHub/labo_calculs")
unlink("docs", recursive = TRUE)
shinylive::export("app", "docs")
```

Ensuite, dans GitHub Desktop : **Commit to main** → **Push origin**.
GitHub Pages est configuré pour publier depuis `main` / `docs`. Attendez quelques minutes après l’envoi ;
si l’ancienne version s’affiche toujours, forcez l’actualisation (**Cmd+Shift+R**) ou désenregistrez le
service worker (DevTools → Application → Service workers → Unregister).

## Structure du dépôt

```text
labo_calculs/
├── app/
│   ├── app.R             # Interface et serveur Shiny (Chl-a, POC/PON, POP, BSi)
│   └── calc_functions.R  # Calculs POC/PON, POP et BSi
├── docs/                 # Export Shinylive publié par GitHub Pages
├── templates/            # Fichiers d’entrée d’exemple
├── tests/                # Tests
├── CHANGELOG.md
└── README.md
```

## Dépannage

- **« Colonnes manquantes »** : vérifiez les noms de colonnes (voir le tableau ci-dessus ou téléchargez un modèle).
- **« Certains niveaux (L/M/H) sont vides ou n'ont pas de blanc associé »** :
  `Level_Fb` / `Level_Fa` doivent être `L`, `M` ou `H` sur chaque ligne.
- **La dilution semble ignorée** : vérifiez la colonne `FD` dans le tableau des résultats. Si elle indique 1,
  le fichier ne contient pas de colonne `FD` (ni `V_extrait`/`V_acetone`), ou l’en-tête est mal orthographié.
- **Le téléchargement produit un fichier `.html`** : le site utilise un ancien export ; réexportez `docs/`
  et effacez le service worker.
