# Résultats des tests R — calculs Chla / POC / POP / BSi

Exécution de la suite automatisée `tests/test_calc.R`.

| Test | Résultat | Détail |
|---|---|---|
| POP Fact_dil=10 équivaut à la formule Excel | RÉUSSI | Conforme |
| POP sans Fact_dil : défaut 1 | RÉUSSI | Conforme |
| POP Fact_dil manquant/NA et facteurs par ligne | RÉUSSI | Conforme |
| BSi Fact_dil=1 correspond aux résultats du classeur | RÉUSSI | Conforme |
| BSi Fact_dil=2 double le résultat | RÉUSSI | Conforme |
| Colonnes legacy Dilution et Dil acceptées | RÉUSSI | Conforme |
| Noms de colonnes canoniques Vol_extrait_L/Fact_dil | RÉUSSI | Conforme |
| BSi : comparaison de plusieurs lignes du Template_Calcul.xlsx | IGNORÉ | Classeur non fourni dans root, root/data ou root/templates |
| CSV Chla aller-retour colonnes et valeurs | RÉUSSI | Conforme |
| CSV POC aller-retour colonnes et valeurs | RÉUSSI | Conforme |
| CSV POP aller-retour colonnes et valeurs | RÉUSSI | Conforme |
| CSV BSi aller-retour colonnes et valeurs | RÉUSSI | Conforme |
| app.R : analyse syntaxique R | RÉUSSI | Conforme |
| snippet_new_tabs.R : analyse syntaxique R | RÉUSSI | Conforme |
| Création shinyApp objet | ÉCHEC | attempt to apply non-function |

Les validations de construction et de démarrage Shiny exigent les paquets R indiqués.
