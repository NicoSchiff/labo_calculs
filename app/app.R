library(shiny)
library(readxl)
library(DT)
# Résoudre calc_functions.R relativement à app.R, pas au working directory
# de l'appelant (source() depuis RStudio ou test automatisé).
.app_file <- NULL
for (.fr in rev(sys.frames())) {
  if (!is.null(.fr$ofile) && length(.fr$ofile)) {
    .candidate <- as.character(.fr$ofile)[1]
    if (!startsWith(.candidate, "/") && !grepl("^[A-Za-z]:", .candidate)) .candidate <- file.path(getwd(), .candidate)
    .candidate <- normalizePath(.candidate, winslash = "/", mustWork = FALSE)
    if (basename(.candidate) == "app.R") {
      .app_file <- .candidate
      break
    }
  }
}
if (is.null(.app_file)) .app_file <- normalizePath(file.path(getwd(), "app.R"), winslash = "/", mustWork = FALSE)
.app_dir <- dirname(.app_file)
source(file.path(.app_dir, "calc_functions.R"), local = TRUE)
rm(.app_file, .app_dir)

# Calcul de chlorophylle, laissé conforme à la version historique.
calc_Chla <- function(df, K, A, blanks) {
  required <- c("Fb", "Fa", "Vol", "Level_Fb", "Level_Fa")
  missing_cols <- setdiff(required, names(df))
  if (length(missing_cols) > 0) {
    stop("Colonnes manquantes : ", paste(missing_cols, collapse = ", "))
  }
  
  blank_cols <- c("Level", "Fb.blank", "Fa.blank")
  missing_blanks <- setdiff(blank_cols, names(blanks))
  if (length(missing_blanks) > 0) {
    stop("Colonnes manquantes dans les blancs : ", paste(missing_blanks, collapse = ", "))
  }
  
  # Le facteur de dilution vaut 1 par défaut. Les volumes sont facultatifs.
  if ("FD" %in% names(df)) {
    fd <- df$FD
    fd[is.na(fd)] <- 1
  } else if (all(c("V_extrait", "V_acetone") %in% names(df))) {
    fd <- (df$V_extrait + df$V_acetone) / df$V_extrait
    fd[is.na(fd)] <- 1
  } else {
    fd <- rep(1, nrow(df))
  }
  df$FD <- fd
  
  level_fb <- toupper(trimws(as.character(df$Level_Fb)))
  level_fa <- toupper(trimws(as.character(df$Level_Fa)))
  blank_levels <- toupper(trimws(as.character(blanks$Level)))
  idx_fb <- match(level_fb, blank_levels)
  idx_fa <- match(level_fa, blank_levels)
  if (anyNA(idx_fb) || anyNA(idx_fa)) {
    stop("Certains niveaux (L/M/H) sont vides ou n'ont pas de blanc associé.")
  }
  
  Fb_c <- df$Fb - blanks$Fb.blank[idx_fb]
  Fa_c <- df$Fa - blanks$Fa.blank[idx_fa]
  
  df$Chla <- df$FD * K * (Fb_c - Fa_c) / df$Vol
  df$Phaeo <- df$FD * K * (A * Fa_c - Fb_c) / df$Vol
  df
}
# Sérialise via un vrai fichier temporaire comme l'application Chl-a validée.
csv_vers_texte <- function(donnees) {
  fichier_temp <- tempfile(fileext = ".csv")
  on.exit(unlink(fichier_temp), add = TRUE)
  write.csv(donnees, fichier_temp, row.names = FALSE, fileEncoding = "UTF-8", na = "")
  paste(readLines(fichier_temp, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

ecrire_csv <- function(donnees, fichier) {
  # Export uniforme : virgule comme séparateur, point décimal, UTF-8.
  write.csv(donnees, fichier, row.names = FALSE, fileEncoding = "UTF-8")
}

# Lit CSV français/international et XLSX, puis normalise les en-têtes pour
# accepter BOM, espaces périphériques et différences de casse.
lire_fichier <- function(f, id = NULL) {
  if (is.null(f)) {
    return(NULL)
  }
  ext <- tolower(tools::file_ext(f$name))
  if (ext == "csv") {
    premiere_ligne <- readLines(f$datapath, n = 1L, warn = FALSE, encoding = "UTF-8")
    if (!length(premiere_ligne)) stop("Le fichier CSV est vide.")
    ligne <- sub("^\uFEFF", "", premiere_ligne[[1]])
    compter <- function(sep) {
      trouve <- gregexpr(sep, ligne, fixed = TRUE)[[1]]
      sum(trouve >= 0L)
    }
    nb <- c(";" = compter(";"), "," = compter(","), "\t" = compter("\t"))
    separateur <- names(nb)[which.max(nb)]
    if (max(nb) == 0) separateur <- ","
    d <- read.csv(f$datapath,
      sep = separateur, check.names = FALSE,
      stringsAsFactors = FALSE, na.strings = c("", "NA"),
      fileEncoding = "UTF-8-BOM", strip.white = TRUE
    )
  } else if (ext == "xlsx") {
    d <- as.data.frame(readxl::read_excel(f$datapath), check.names = FALSE)
  } else {
    stop("Formats acceptés : CSV ou XLSX.")
  }

  names(d) <- trimws(sub("^\uFEFF", "", enc2utf8(names(d))))
  cle <- function(x) tolower(gsub("[[:space:]_.-]", "", trimws(x)))
  aliases <- switch(id,
    chla = c(fb = "Fb", fa = "Fa", vol = "Vol", levelfb = "Level_Fb", levelfa = "Level_Fa"),
    poc = c(volumel = "Volume_L", pnmg = "PN_mg", pcmg = "PC_mg"),
    pop = c(
      sample = "Sample", volumel = "Volume_L", volextraitl = "Vol_extrait_L",
      fd = "FD", factdil = "FD", dilution = "FD", dil = "FD",
      concentration = "Concentration"
    ),
    bsi = c(
      sample = "Sample", volumel = "Volume_L", volextraitl = "Vol_extrait_L",
      fd = "FD", factdil = "FD", dilution = "FD", dil = "FD",
      concentration = "Concentration"
    ),
    character()
  )
  if (length(aliases)) {
    keys <- cle(names(d))
    alias_keys <- cle(names(aliases))
    idx <- match(keys, alias_keys)
    # FD (insensible à la casse) est prioritaire; sinon Fact_dil, puis
    # Dilution, puis Dil fournit la colonne canonique unique.
    if (id %in% c("pop", "bsi")) {
      fd_idx <- which(keys %in% c("fd", "factdil", "dilution", "dil"))
      if (length(fd_idx) > 1L) {
        priorite <- c("fd", "factdil", "dilution", "dil")
        keep <- fd_idx[match(priorite[priorite %in% keys[fd_idx]][1], keys[fd_idx])]
        d <- d[, -setdiff(fd_idx, keep), drop = FALSE]
        keys <- cle(names(d))
        idx <- match(keys, alias_keys)
      }
    }
    hit <- which(!is.na(idx))
    if (length(hit)) names(d)[hit] <- unname(aliases[idx[hit]])
    if (anyDuplicated(names(d))) {
      stop(
        "En-têtes en double après normalisation : ",
        paste(unique(names(d)[duplicated(names(d))]), collapse = ", "),
        ". Colonnes trouvées : ", paste(names(d), collapse = ", ")
      )
    }
  }
  # Les champs de mesure sont numérisés aussi bien avec 1.25 qu'avec 1,25.
  numeriques <- switch(id,
    chla = c("Fb", "Fa", "Vol"),
    poc = c("Volume_L", "PN_mg", "PC_mg"),
    pop = c("Volume_L", "Vol_extrait_L", "FD", "Concentration"),
    bsi = c("Volume_L", "Vol_extrait_L", "FD", "Concentration"),
    character()
  )
  for (nm in intersect(numeriques, names(d))) {
    valeur <- trimws(as.character(d[[nm]]))
    valeur[valeur %in% c("", "NA")] <- NA_character_
    d[[nm]] <- suppressWarnings(as.numeric(chartr(",", ".", valeur)))
  }
  d
}

sidebar_chla <- sidebarPanel(
  h4("1. Données"),
  fileInput("chla_file", "Charger un fichier (.csv ou .xlsx)", accept = c(".csv", ".xlsx")),
  helpText(
    tagList(
      strong("Colonnes obligatoires :"),
      tags$ul(
        tags$li(strong("Fb"), " : fluorescence avant acidification"),
        tags$li(strong("Fa"), " : fluorescence après acidification"),
        tags$li(strong("Vol"), " : volume filtré (mL)"),
        tags$li(
          strong("Level_Fb"), " / ", strong("Level_Fa"),
          " : gamme de mesure (L, M ou H), qui sert à choisir le bon blanc"
        )
      ),
      strong("Colonne optionnelle :"),
      tags$ul(
        tags$li(strong("FD"), " : facteur de dilution, égal à 1 s'il est absent")
      ),
      p(em("Toutes les autres colonnes sont conservées à l'identique dans le fichier exporté."))
    )
  ),
  h4("2. Facteurs de calibration"),
  numericInput("chla_k", strong("K (inclut le volume d'extraction)"), 1.789, step = 0.001),
  numericInput("chla_a", strong("A (ratio acide)"), 2.052, step = 0.001),
  helpText("Facteur de dilution FD : 1 par défaut (colonne FD optionnelle dans le fichier)."),
  h4("3. Valeurs de blanc"),
  helpText("Fluorescence des blancs pour chaque échelle."),
  fluidRow(column(4, strong("Échelle")), column(4, strong("Fb blanc")), column(4, strong("Fa blanc"))),
  fluidRow(column(4, "L"), column(4, numericInput("fb_l", NULL, 0)), column(4, numericInput("fa_l", NULL, 0))),
  fluidRow(column(4, "M"), column(4, numericInput("fb_m", NULL, 0)), column(4, numericInput("fa_m", NULL, 0))),
  fluidRow(column(4, "H"), column(4, numericInput("fb_h", NULL, 0)), column(4, numericInput("fa_h", NULL, 0))),
  hr(),
  actionButton("chla_template", tagList(icon("download"), " Télécharger un modèle vide (.csv)")),
  helpText("Fichier CSV vide avec les bons noms de colonnes, à remplir puis recharger."),
  actionButton("chla_export", tagList(icon("download"), " Exporter les résultats"))
)

sidebar_poc <- sidebarPanel(
  h4("1. Données"),
  fileInput("poc_file", "Charger un fichier (.csv ou .xlsx)", accept = c(".csv", ".xlsx")),
  # helpText("Colonnes requises : Volume_L, PN_mg et PC_mg. Les colonnes supplémentaires, par exemple Sample, sont conservées dans les résultats."),
  helpText(tagList(
    strong("Colonnes obligatoires :"),
    tags$ul(
      tags$li(strong("Volume_L"), " : volume d'eau filtré (L)"),
      tags$li(strong("PC_mg"), " : poids de carbone mesurée dans l'extrait (mg)"),
      tags$li(strong("PN_mg"), " : poids d'azote mesurée dans l'extrait (mg)")
    ),
    p(em("Toutes les autres colonnes sont conservées à l'identique dans le fichier exporté."))
  )),
  h4("2. Valeurs de blanc"),
  helpText("Concentrations des blancs soustraites aux mesures PN et PC (mg)."),
  uiOutput("poc_blank_inputs"),
  uiOutput("poc_blank_summary"),
  actionButton("poc_add_blank", "+ Ajouter un blanc"),
  actionButton("poc_remove_blank", "− Retirer un blanc"),
  hr(),
  actionButton("poc_template", tagList(icon("download"), " Télécharger un modèle vide (.csv)")),
  helpText("Fichier CSV vide avec les bons noms de colonnes, à remplir puis recharger."),
  actionButton("poc_export", tagList(icon("download"), " Exporter les résultats"))
)

sidebar_pop <- function(id, methode, vol_defaut) {
  sidebarPanel(
    h4("1. Données"),
    fileInput(paste0(id, "_file"), "Charger un fichier (.csv ou .xlsx)", accept = c(".csv", ".xlsx")),
    helpText(tagList(
      strong("Colonnes obligatoires :"),
      tags$ul(
        tags$li(strong("Volume_L"), " : volume d'eau filtré (L)"),
        tags$li(strong("Concentration"), " : concentration mesurée dans l'extrait")
      ),
      strong("Colonnes optionnelles :"),
      tags$ul(
        tags$li(
          strong("Vol_extrait_L"),
          " : volume d'extraction (L). Valeur par défaut : 0.005 L (5 mL)"
        ),
        tags$li(strong("FD"), " : facteur de dilution. Valeur par défaut : 1")
      ),
      p(em(
        "Une valeur saisie dans le fichier est toujours prioritaire sur la valeur par défaut. ",
        "Vous pouvez donc indiquer une dilution pour un seul échantillon.",
        "Toutes les autres colonnes sont conservées à l'identique dans le fichier exporté."
      ))
    )),
    h4("2. Valeurs de blanc"),
    helpText(paste("Concentrations des blancs", methode, "soustraites aux mesures.")),
    uiOutput(paste0(id, "_blank_inputs")),
    uiOutput(paste0(id, "_blank_summary")),
    actionButton(paste0(id, "_add_blank"), "+ Ajouter un blanc"),
    actionButton(paste0(id, "_remove_blank"), "− Retirer un blanc"),
    hr(),
    actionButton(paste0(id, "_template"), tagList(icon("download"), " Télécharger un modèle vide (.csv)")),
    helpText("Fichier CSV vide avec les bons noms de colonnes, à remplir puis recharger."),
    actionButton(paste0(id, "_export"), tagList(icon("download"), " Exporter les résultats"))
  )
}

sidebar_bsi <- function(id, methode, vol_defaut) {
  sidebarPanel(
    h4("1. Données"),
    fileInput(paste0(id, "_file"), "Charger un fichier (.csv ou .xlsx)", accept = c(".csv", ".xlsx")),
    helpText(tagList(
      strong("Colonnes obligatoires :"),
      tags$ul(
        tags$li(strong("Volume_L"), " : volume d'eau filtré (L)"),
        tags$li(strong("Concentration"), " : concentration mesurée dans l'extrait")
      ),
      strong("Colonnes optionnelles :"),
      tags$ul(
        tags$li(
          strong("Vol_extrait_L"),
          " : volume d'extraction (L). Valeur par défaut : 0.025 L (25 mL)"
        ),
        tags$li(strong("FD"), " : facteur de dilution. Valeur par défaut : 1")
      ),
      p(em(
        "Une valeur saisie dans le fichier est toujours prioritaire sur la valeur par défaut. ",
        "Vous pouvez donc indiquer une dilution pour un seul échantillon.",
        "Toutes les autres colonnes sont conservées à l'identique dans le fichier exporté."
      ))
    )),
    h4("2. Valeurs de blanc"),
    helpText(paste("Concentrations des blancs", methode, "soustraites aux mesures.")),
    uiOutput(paste0(id, "_blank_inputs")),
    uiOutput(paste0(id, "_blank_summary")),
    actionButton(paste0(id, "_add_blank"), "+ Ajouter un blanc"),
    actionButton(paste0(id, "_remove_blank"), "− Retirer un blanc"),
    hr(),
    actionButton(paste0(id, "_template"), tagList(icon("download"), " Télécharger un modèle vide (.csv)")),
    helpText("Fichier CSV vide avec les bons noms de colonnes, à remplir puis recharger."),
    actionButton(paste0(id, "_export"), tagList(icon("download"), " Exporter les résultats"))
  )
}

ui <- navbarPage(
  "Analyses de laboratoire",
  tags$head(tags$script(HTML(
    "Shiny.addCustomMessageHandler('telecharger_csv', function(message) {
       var blob = new Blob([\"\ufeff\", message.contenu], {type: 'text/csv;charset=utf-8;'});
       var lien = document.createElement('a');
       lien.href = URL.createObjectURL(blob);
       lien.download = message.nom;
       document.body.appendChild(lien);
       lien.click();
       document.body.removeChild(lien);
       URL.revokeObjectURL(lien.href);
     });"
  ))),
  tabPanel(
    "Chl-a",
    sidebarLayout(
      sidebar_chla,
      mainPanel(
        h3("Calcul de la chlorophylle a et des phéopigments"),
        uiOutput("chla_error"), DTOutput("chla_result")
      )
    )
  ),
  tabPanel(
    "POC / PON",
    sidebarLayout(
      sidebar_poc,
      mainPanel(
        h3("Calcul du POC / PON"),
        uiOutput("poc_error"), DTOutput("poc_result")
      )
    )
  ),
  tabPanel(
    "POP",
    sidebarLayout(
      sidebar_pop("pop", "POP", 0.005),
      mainPanel(
        h3("Calcul du POP"),
        uiOutput("pop_error"), DTOutput("pop_result")
      )
    )
  ),
  tabPanel(
    "BSi",
    sidebarLayout(
      sidebar_bsi("bsi", "BSi", 0.025),
      mainPanel(
        h3("Calcul de la silice biogénique (BSi)"),
        uiOutput("bsi_error"), DTOutput("bsi_result")
      )
    )
  )
)

server <- function(input, output, session) {
  # Constantes de secours pour les colonnes optionnelles.
  vol_extrait_defaults <- list(pop = 0.005, bsi = 0.025)
  fd_default <- 1
  # Valeurs mémorisées lors des changements de taille; les contrôles portant
  # les mêmes identifiants conservent leurs valeurs entre deux rendus.
  blank_counts <- list(poc = reactiveVal(3L), pop = reactiveVal(3L), bsi = reactiveVal(3L))
  blank_values_state <- list(
    poc = reactiveVal(list(pn = rep(0, 3), pc = rep(0, 3))),
    pop = reactiveVal(rep(0, 3)), bsi = reactiveVal(rep(0, 3))
  )
  current_blanks <- function(prefix, count, part = NULL, fallback = rep(0, count)) {
    vapply(seq_len(count), function(i) {
      key <- if (is.null(part)) paste0(prefix, "_blank_", i) else paste0(prefix, "_blank_", part, "_", i)
      val <- input[[key]]
      if (!(key %in% names(input))) {
        fallback[[i]]
      } else if (is.null(val) || !length(val)) {
        NA_real_
      } else {
        as.numeric(val)[1]
      }
    }, numeric(1))
  }
  resume_blancs <- function(x) {
    x <- as.numeric(x)
    x <- x[!is.na(x)]
    list(
      moyenne = if (length(x)) mean(x) else NA_real_, n = length(x),
      ecart_type = if (length(x) > 1) stats::sd(x) else NA_real_
    )
  }
  format_blanc <- function(x) if (is.na(x)) "NA" else format(x, digits = 6, trim = TRUE)

  output$poc_blank_inputs <- renderUI({
    state <- blank_values_state$poc()
    n <- blank_counts$poc()
    tagList(
      fluidRow(column(6, strong("Blanc C / PC (mg)")), column(6, strong("Blanc N / PN (mg)"))),
      lapply(seq_len(n), function(i) {
        fluidRow(
          column(6, numericInput(paste0("poc_blank_pc_", i), paste("Blanc", i, "C"), state$pc[[i]])),
          column(6, numericInput(paste0("poc_blank_pn_", i), paste("Blanc", i, "N"), state$pn[[i]]))
        )
      })
    )
  })
  output$poc_blank_summary <- renderUI({
    n <- blank_counts$poc()
    state <- blank_values_state$poc()
    csum <- resume_blancs(current_blanks("poc", n, "pc", state$pc))
    nsum <- resume_blancs(current_blanks("poc", n, "pn", state$pn))
    tagList(
      p(
        "Moyenne des blancs C : ", format_blanc(csum$moyenne), " (n = ", csum$n,
        ") — SD : ", format_blanc(csum$ecart_type)
      ),
      p(
        "Moyenne des blancs N : ", format_blanc(nsum$moyenne), " (n = ", nsum$n,
        ") — SD : ", format_blanc(nsum$ecart_type)
      )
    )
  })
  observeEvent(input$poc_add_blank, {
    n <- blank_counts$poc()
    old <- blank_values_state$poc()
    old$pc <- current_blanks("poc", n, "pc", old$pc)
    old$pn <- current_blanks("poc", n, "pn", old$pn)
    blank_values_state$poc(list(pc = c(old$pc, 0), pn = c(old$pn, 0)))
    blank_counts$poc(n + 1L)
  })
  observeEvent(input$poc_remove_blank, {
    n <- blank_counts$poc()
    if (n > 1L) {
      old <- blank_values_state$poc()
      old$pc <- current_blanks("poc", n, "pc", old$pc)
      old$pn <- current_blanks("poc", n, "pn", old$pn)
      blank_values_state$poc(list(pc = old$pc[-n], pn = old$pn[-n]))
      blank_counts$poc(n - 1L)
    }
  })

  for (id in c("pop", "bsi")) {
    local({
      nm <- id
      output[[paste0(nm, "_blank_inputs")]] <- renderUI({
        values <- blank_values_state[[nm]]()
        n <- blank_counts[[nm]]()
        tagList(lapply(seq_len(n), function(i) {
          numericInput(paste0(nm, "_blank_", i), paste("Blanc", i), values[[i]])
        }))
      })
      output[[paste0(nm, "_blank_summary")]] <- renderUI({
        sm <- resume_blancs(current_blanks(nm, blank_counts[[nm]](), fallback = blank_values_state[[nm]]()))
        p(
          "Moyenne des blancs : ", format_blanc(sm$moyenne), " (n = ", sm$n,
          ") — SD : ", format_blanc(sm$ecart_type)
        )
      })
      observeEvent(input[[paste0(nm, "_add_blank")]], {
        n <- blank_counts[[nm]]()
        old <- blank_values_state[[nm]]()
        old <- current_blanks(nm, n, fallback = old)
        blank_values_state[[nm]](c(old, 0))
        blank_counts[[nm]](n + 1L)
      })
      observeEvent(input[[paste0(nm, "_remove_blank")]], {
        n <- blank_counts[[nm]]()
        if (n > 1L) {
          old <- blank_values_state[[nm]]()
          old <- current_blanks(nm, n, fallback = old)
          blank_values_state[[nm]](old[-n])
          blank_counts[[nm]](n - 1L)
        }
      })
    })
  }
  blank_mean <- function(id, part = NULL) {
    n <- blank_counts[[id]]()
    state <- blank_values_state[[id]]()
    if (id == "poc") {
      vals <- if (identical(part, "pn")) state$pn else state$pc
      vals <- current_blanks("poc", n, if (identical(part, "pn")) "pn" else "pc", vals)
    } else {
      vals <- current_blanks(id, n, fallback = state)
    }
    resume_blancs(vals)$moyenne
  }
  config <- list(
    chla = list(
      file = "chla_file", required = c("Fb", "Fa", "Vol", "Level_Fb", "Level_Fa"), defaults = data.frame(Fb = 0, Fa = 0, Vol = 1, Level_Fb = "L", Level_Fa = "L", check.names = FALSE),
      calc = function(d) {
        calc_Chla(
          d, input$chla_k, input$chla_a,
          data.frame(Level = c("L", "M", "H"), Fb.blank = c(input$fb_l, input$fb_m, input$fb_h), Fa.blank = c(input$fa_l, input$fa_m, input$fa_h))
        )
      }
    ),
    poc = list(
      file = "poc_file", required = c("Volume_L", "PN_mg", "PC_mg"), defaults = data.frame(Volume_L = 1, PN_mg = 0, PC_mg = 0, check.names = FALSE),
      calc = function(d) calc_poc(d, blank_mean("poc", "pn"), blank_mean("poc", "pc"))
    ),
    pop = list(
      file = "pop_file", required = c("Volume_L", "Concentration"), defaults = data.frame(Sample = "", Volume_L = 1, Vol_extrait_L = vol_extrait_defaults$pop, FD = fd_default, Concentration = 0, check.names = FALSE),
      calc = function(d) {
        if ("FD" %in% names(d)) {
          d$Fact_dil <- d$FD
          d$FD <- NULL
        }
        out <- calc_pop(d, blank_mean("pop"), vol_extrait_defaults$pop, fd_default)
        names(out)[names(out) == "Fact_dil"] <- "FD"
        out
      }
    ),
    bsi = list(
      file = "bsi_file", required = c("Volume_L", "Concentration"), defaults = data.frame(Sample = "", Volume_L = 1, Vol_extrait_L = vol_extrait_defaults$bsi, FD = fd_default, Concentration = 0, check.names = FALSE),
      calc = function(d) {
        if ("FD" %in% names(d)) {
          d$Fact_dil <- d$FD
          d$FD <- NULL
        }
        out <- calc_bsi(d, blank_mean("bsi"), vol_extrait_defaults$bsi, fd_default)
        names(out)[names(out) == "Fact_dil"] <- "FD"
        out
      }
    )
  )
  stores <- lapply(config, function(x) reactiveVal(x$defaults))
  for (nm in names(config)) {
    local({
      id <- nm
      cfg <- config[[id]]
      store <- stores[[id]]
      observeEvent(input[[cfg$file]], {
        d <- tryCatch(lire_fichier(input[[cfg$file]], id), error = function(e) {
          showNotification(paste("Lecture impossible :", conditionMessage(e)), type = "error")
          NULL
        })
        if (!is.null(d)) {
          # Garder les champs de facteurs absents absents jusqu'au calcul : ainsi
          # les paramètres de défaut restent réactifs et remplacent aussi les NA.
          store(d)
        }
      })
      resultat <- reactive({
        req(input[[cfg$file]])
        d <- store()
        manquantes <- setdiff(cfg$required, names(d))
        if (length(manquantes)) {
          stop(
            "Colonnes manquantes : ",
            paste(manquantes, collapse = ", "), ". Colonnes trouvées : ",
            if (length(names(d))) paste(names(d), collapse = ", ") else "(aucune)"
          )
        }
        cfg$calc(d)
      })
      output[[paste0(id, "_error")]] <- renderUI({
        req(input[[cfg$file]])
        res <- tryCatch(resultat(), error = function(e) e)
        if (inherits(res, "error") && nzchar(conditionMessage(res))) {
          div(style = "color:red;", strong("Erreur : "), conditionMessage(res))
        }
      })
      output[[paste0(id, "_result")]] <- renderDT({
        req(input[[cfg$file]])
        res <- tryCatch(resultat(), error = function(e) NULL)
        if (is.null(res)) {
          return(NULL)
        }
        table <- datatable(res, options = list(pageLength = 12, scrollX = TRUE))
        colonnes <- switch(id,
          chla = c("Chla", "Phaeo"),
          poc = c("PON_ug_L", "POC_ug_L", "Ratio_C_N"),
          pop = "POP_umol_L",
          bsi = "BSi_umol_L"
        )
        table |> formatRound(colonnes, 3)
      })
      observeEvent(input[[paste0(id, "_export")]], {
        if (is.null(input[[cfg$file]]) || is.null(store())) {
          showNotification("Veuillez d’abord charger un fichier de données.", type = "warning")
          return()
        }
        res <- tryCatch(resultat(), error = function(e) {
          showNotification(paste("Export impossible :", conditionMessage(e)), type = "error")
          NULL
        })
        if (!is.null(res)) {
          session$sendCustomMessage("telecharger_csv", list(
            nom = paste0(id, "_resultats_", Sys.Date(), ".csv"),
            contenu = csv_vers_texte(res)
          ))
        }
      }, ignoreInit = TRUE)
      observeEvent(input[[paste0(id, "_template")]], {
        session$sendCustomMessage("telecharger_csv", list(
          nom = paste0("modele_", id, ".csv"),
          contenu = csv_vers_texte(cfg$defaults[0, , drop = FALSE])
        ))
      }, ignoreInit = TRUE)
    })
  }
}
shinyApp(ui, server)
