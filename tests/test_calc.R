# Tests d'intégration des calculs et des exports.
# Fonctionne depuis le dossier projet avec source("tests/test_calc.R") ou
# Rscript tests/test_calc.R.
options(warn = 1)

# Déduire la racine du projet du chemin du script (source/Rscript), puis du
# répertoire courant. Tester aussi le parent, car le script vit dans tests/.
.candidats_script <- character()
for (.fr in sys.frames()) {
  if (!is.null(.fr$ofile) && length(.fr$ofile))
    .candidats_script <- c(.candidats_script, as.character(.fr$ofile)[1])
}
.args_file <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(.args_file)) .candidats_script <- c(.candidats_script, sub("^--file=", "", .args_file[1]))
.dossiers <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
for (.f in .candidats_script) {
  .f <- path.expand(.f)
  if (!startsWith(.f, "/") && !grepl("^[A-Za-z]:", .f)) .f <- file.path(getwd(), .f)
  .f <- normalizePath(.f, winslash = "/", mustWork = FALSE)
  .dossiers <- c(.dossiers, dirname(.f), dirname(dirname(.f)))
}
# Ajouter les parents du working directory pour les exécutions depuis tests/.
.wd <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
.repeat <- TRUE
while (.repeat) {
  .parent <- dirname(.wd)
  if (identical(.parent, .wd)) .repeat <- FALSE else {
    .dossiers <- c(.dossiers, .parent)
    .wd <- .parent
  }
}
.dossiers <- unique(normalizePath(.dossiers, winslash = "/", mustWork = FALSE))
.root_candidates <- unique(c(.dossiers, dirname(.dossiers)))
.root_matches <- .root_candidates[vapply(.root_candidates, function(.d)
  file.exists(file.path(.d, "calc_functions.R")) && file.exists(file.path(.d, "app.R")), logical(1))]
if (!length(.root_matches)) stop("Racine du projet introuvable (calc_functions.R et app.R requis).")
root <- .root_matches[1]
source(file.path(root, "calc_functions.R"))
resultats <- data.frame(Test=character(), Resultat=character(), Detail=character())
verifier <- function(nom, code) {
  erreur <- tryCatch({ force(code); NULL }, error=function(e) conditionMessage(e))
  ok <- is.null(erreur)
  resultats <<- rbind(resultats, data.frame(Test=nom,
    Resultat=if (ok) "PASS" else "FAIL", Detail=if (ok) "Conforme" else erreur))
  if (!ok) message("ÉCHEC — ", nom, " : ", erreur)
  invisible(ok)
}
proche <- function(x, y, tol=1e-12) isTRUE(all.equal(as.numeric(x), as.numeric(y), tolerance=tol))

# POP : même formule que la cellule Excel (((G*10)-(N13*10))*F)/E.
# Le tableau POP du classeur fourni ne contient pas de concentrations d'échantillon,
# on compare donc avec l'équivalence algébrique de la formule sur données d'essai.
pop_ref <- data.frame(Sample=c("A","B"), Volume_L=c(1, 0.5),
  Vol_extrait_L=c(0.005, 0.005), Fact_dil=c(10,10), Concentration=c(2.5,3.2))
pop_excel <- ((pop_ref$Concentration*10 - 0*10) * pop_ref$Vol_extrait_L) / pop_ref$Volume_L
verifier("POP Fact_dil=10 équivaut à la formule Excel", {
  x <- calc_pop(pop_ref, blank_concentration=0)
  stopifnot(proche(x$POP_umol_L, pop_excel), proche(x$Fact_dil, c(10,10)))
})
verifier("POP sans Fact_dil : défaut 1", {
  d <- pop_ref[, setdiff(names(pop_ref), "Fact_dil")]
  x <- calc_pop(d, blank_concentration=0)
  stopifnot(proche(x$Fact_dil, c(1,1)), proche(x$POP_umol_L,
    pop_ref$Concentration*0.005/pop_ref$Volume_L))
})
verifier("POP Fact_dil manquant/NA et facteurs par ligne", {
  d <- data.frame(Volume_L=c(1,1,1), Vol_extrait_L=c(.005,NA,.005),
    Fact_dil=c(1,NA,4), Concentration=c(10,10,10))
  x <- calc_pop(d, blank_concentration=0)
  stopifnot(proche(x$Fact_dil,c(1,1,4)), proche(x$Vol_extrait_L,c(.005,.005,.005)),
    proche(x$POP_umol_L,c(.05,.05,.2)))
})
verifier("BSi Fact_dil=1 correspond aux résultats du classeur", {
  d <- data.frame(Volume_L=1, Vol_extrait_L=.025, Fact_dil=1, Concentration=10.203)
  x <- calc_bsi(d, blank_concentration=5.41094)
  stopifnot(proche(x$BSi_umol_L, .1198015))
})
verifier("BSi Fact_dil=2 double le résultat", {
  d <- data.frame(Volume_L=1, Vol_extrait_L=.025, Fact_dil=c(1,2), Concentration=10.203)
  x <- calc_bsi(d, blank_concentration=5.41094)
  stopifnot(proche(x$BSi_umol_L[2], 2*x$BSi_umol_L[1]))
})
verifier("Colonnes legacy Dilution et Dil acceptées", {
  d <- data.frame(Volume_L=1, Dilution=.005, Dil=10, Concentration=2.5)
  x <- suppressMessages(calc_pop(d, blank_concentration=0))
  stopifnot(all(c("Vol_extrait_L","Fact_dil") %in% names(x)), proche(x$POP_umol_L,.125))
})
verifier("Noms de colonnes canoniques Vol_extrait_L/Fact_dil", {
  d <- data.frame(Volume_L=1, Vol_extrait_L=.005, Fact_dil=10, Concentration=2.5)
  x <- calc_pop(d, blank_concentration=0)
  stopifnot(proche(x$POP_umol_L,.125))
})

# Contrôle facultatif des valeurs source BSi du classeur (cache Excel).
# TEMPLATE_XLSX peut préciser un emplacement; sinon chercher dans les dossiers
# usuels du projet. L'absence du classeur n'est pas un échec de calcul.
.xlsx_env <- Sys.getenv("TEMPLATE_XLSX", unset="")
.xlsx_candidates <- c(if (nzchar(.xlsx_env)) path.expand(.xlsx_env),
  file.path(root, "Template_Calcul.xlsx"),
  file.path(root, "data", "Template_Calcul.xlsx"),
  file.path(root, "templates", "Template_Calcul.xlsx"))
classeur <- .xlsx_candidates[file.exists(.xlsx_candidates)]
classeur <- if (length(classeur)) normalizePath(classeur[1], mustWork=TRUE) else NULL
if (is.null(classeur)) {
  resultats <- rbind(resultats, data.frame(
    Test="BSi : comparaison de plusieurs lignes du Template_Calcul.xlsx",
    Resultat="SKIP", Detail="Classeur non fourni dans root, root/data ou root/templates"))
  message("SKIP — comparaison BSi : classeur Template_Calcul.xlsx non fourni")
} else verifier("BSi : comparaison de plusieurs lignes du Template_Calcul.xlsx", {
  if (!requireNamespace("readxl", quietly=TRUE)) stop("Paquet readxl absent; comparaison XLSX impossible")
  wb <- readxl::read_excel(classeur, sheet="BSi", range="A3:O14", col_names=FALSE)
  d <- data.frame(Volume_L=as.numeric(wb[[6]]), Vol_extrait_L=as.numeric(wb[[7]]),
    Fact_dil=1, Concentration=as.numeric(wb[[8]]))
  ref <- as.numeric(wb[[11]])
  ix <- which(is.finite(ref) & is.finite(d$Concentration) & is.finite(d$Volume_L))
  x <- calc_bsi(d[ix,], blank_concentration=5.41094)
  stopifnot(length(ix)>=3, proche(x$BSi_umol_L, ref[ix]))
})

# Tests des CSV avec la même fonction write.csv que l'app (séparateur virgule).
ecrire_csv <- function(d, fichier) write.csv(d, fichier, row.names=FALSE, fileEncoding="UTF-8")
chla <- data.frame(Fb=120, Fa=45, Vol=10, Level_Fb="L", Level_Fa="L")
chla$Chla <- 1.789*(120-45)/10; chla$Phaeo <- 1.789*(2.052*45-120)/10
poc <- calc_poc(data.frame(Volume_L=1, PN_mg=.2, PC_mg=.1), blank_pn=0, blank_pc=0)
pop <- calc_pop(pop_ref, blank_concentration=0)
bsi <- calc_bsi(data.frame(Volume_L=1, Vol_extrait_L=.025, Fact_dil=2, Concentration=10.203))
exports <- list(Chla=chla, POC=poc, POP=pop, BSi=bsi)
for (nm in names(exports)) local({
  param <- nm; data <- exports[[param]]
  verifier(paste("CSV", param, "aller-retour colonnes et valeurs"), {
    f <- tempfile(fileext=".csv"); on.exit(unlink(f), add=TRUE)
    ecrire_csv(data, f)
    contenu <- readLines(f, n=1, warn=FALSE)
    stopifnot(grepl(",", contenu, fixed=TRUE), !grepl(";", contenu, fixed=TRUE))
    relu <- read.csv(f, check.names=FALSE)
    stopifnot(identical(names(relu), names(data)), nrow(relu)==nrow(data))
    numeriques <- names(data)[vapply(data, is.numeric, logical(1))]
    for (col in numeriques) stopifnot(proche(relu[[col]], data[[col]]))
    if (param %in% c("POP","BSi")) stopifnot("Fact_dil" %in% names(relu))
  })
})

# L'application doit au moins parser; objet shiny.appobj vérifié si dépendances disponibles.
verifier("app.R : analyse syntaxique R", parse(file.path(root,"app.R")))
verifier("snippet_new_tabs.R : analyse syntaxique R", parse(file.path(root,"snippet_new_tabs.R")))
verifier("Création shinyApp objet", {
  if (!all(vapply(c("shiny","readxl","DT"), requireNamespace, logical(1), quietly=TRUE)))
    stop("Paquets shiny/readxl/DT absents : construction shinyApp non vérifiable")
  env <- new.env(parent=globalenv())
  source(file.path(root, "app.R"), local=env, chdir=TRUE)
  stopifnot(inherits(env$shinyApp(ui=env$ui, server=env$server), "shiny.appobj"))
})

cat("\n", paste(capture.output(print(resultats, row.names=FALSE)), collapse="\n"), "\n")
rapport <- file.path(root, "test_report.md")
writeLines(c("# Résultats des tests R — calculs Chla / POC / POP / BSi", "",
  "Exécution de la suite automatisée `tests/test_calc.R`.", "",
  "| Test | Résultat | Détail |", "|---|---|---|",
  paste0("| ", resultats$Test, " | ", ifelse(resultats$Resultat == "PASS", "RÉUSSI",
         ifelse(resultats$Resultat == "SKIP", "IGNORÉ", "ÉCHEC")),
         " | ", resultats$Detail, " |"), "",
  "Les validations de construction et de démarrage Shiny exigent les paquets R indiqués."), rapport)
if (any(resultats$Resultat == "FAIL"))
  message("La suite comporte des échecs; voir le tableau et test_report.md.")
