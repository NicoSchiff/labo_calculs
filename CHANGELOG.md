# Journal des modifications

## 12 novembre 2026

- Mise à jour de `calc_pop()` : suppression du facteur interne codé en dur de 10; formule calculée avec concentration corrigée du blanc, volume d’extrait et facteur de dilution manuel par échantillon.
- Mise à jour de `calc_bsi()` : formule utilisant explicitement le volume final d’extrait et le facteur de dilution par échantillon.
- Introduction des noms canoniques `Vol_extrait_L` et `Fact_dil`; migration avec message des colonnes historiques `Dilution` et `Dil`.
- Valeur par défaut et remplacement des valeurs `NA` : `Fact_dil = 1`; volume d’extrait par défaut/NA : 0.005 L en POP, 0.025 L en BSi.
- Maintien des calculs POC/PON et conservation du calcul Chla historique dans l’application intégrée.
- Remplacement de `app.R` par une application Shiny multi-onglets Chla, POC/PON, POP et BSi, avec saisie tabulaire éditable, entrées de paramètres, modèles CSV et exports.
- Création de `snippet_new_tabs.R` avec fonctions UI/serveur réutilisables pour POP et BSi dans une application multi-onglets.
- Standardisation de l’export avec `write.csv` : séparateur virgule, point décimal, UTF-8.
- Création de modèles `templates/template_POP.csv` et `templates/template_BSi.csv`, avec les colonnes `Sample,Volume_L,Vol_extrait_L,Fact_dil,Concentration`.
- Ajout de `tests/test_calc.R` couvrant les formules, valeurs de défaut, facteurs mixtes, compatibilité legacy, valeurs BSi de référence, allers-retours CSV et analyse syntaxique Shiny.
- Ajout de `test_report.md`. Les tests R restent à exécuter car R/Rscript et les paquets R requis n’étaient pas disponibles et n’ont pas pu être installés dans le sandbox.
