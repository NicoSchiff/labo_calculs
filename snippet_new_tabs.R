# Composants d'onglets POP et BSi réutilisables dans un app.R multi-onglets.
# Pré-requis : shiny, DT, calc_functions.R chargé avec source().
# Les exports utilisent write.csv (séparateur virgule, décimale point), comme app.R.

onglet_pop_bsi_ui <- function(id, titre, vol_extrait_defaut, blanc_defaut) {
  ns <- NS(id)
  tabPanel(titre,
    sidebarLayout(
      sidebarPanel(
        fileInput(ns("fichier"), "Données (.csv/.xlsx)", accept = c(".csv", ".xlsx")),
        numericInput(ns("blanc"), "Concentration moyenne du blanc", blanc_defaut),
        numericInput(ns("vol_extrait"), "Vol_extrait_L par défaut (L)", vol_extrait_defaut, min=0, step=0.001),
        numericInput(ns("fact_dil"), "Fact_dil par défaut", 1, min=0, step=1),
        downloadButton(ns("modele"), "Télécharger le modèle CSV"),
        downloadButton(ns("export"), "Exporter les résultats CSV")
      ),
      mainPanel(
        helpText("Colonnes : Sample, Volume_L, Vol_extrait_L, Fact_dil, Concentration."),
        h4("Données brutes modifiables"), DTOutput(ns("table")),
        h4("Résultats calculés"), DTOutput(ns("resultats"))
      )
    )
  )
}

onglet_pop_bsi_server <- function(id, methode = c("POP", "BSi")) {
  methode <- match.arg(methode)
  moduleServer(id, function(input, output, session) {
    extrait_defaut <- if (methode == "POP") 0.005 else 0.025
    blanc_defaut <- if (methode == "POP") 0 else 5.41094
    donnees <- reactiveVal(data.frame(Sample="", Volume_L=1,
      Vol_extrait_L=extrait_defaut, Fact_dil=1, Concentration=0,
      check.names=FALSE, stringsAsFactors=FALSE))

    observeEvent(input$fichier, {
      f <- input$fichier
      d <- tryCatch({
        if (tolower(tools::file_ext(f$name)) == "csv")
          read.csv(f$datapath, check.names=FALSE, stringsAsFactors=FALSE,
                   na.strings=c("", "NA"))
        else as.data.frame(readxl::read_excel(f$datapath), check.names=FALSE)
      }, error=function(e) {
        showNotification(paste("Lecture impossible :", conditionMessage(e)), type="error"); NULL
      })
      if (!is.null(d)) {
        anciens <- intersect(c("Dilution", "Dil"), names(d))
        d <- .preparer_pop_bsi(d, Vol_extrait_L=extrait_defaut, Fact_dil=1)
        if (length(anciens)) showNotification(
          paste("Colonnes historiques converties :", paste(anciens, collapse=", "),
                "→ Vol_extrait_L / Fact_dil."), type="message")
        donnees(d)
      }
    })
    output$table <- renderDT(datatable(donnees(), editable=TRUE,
      options=list(pageLength=8, scrollX=TRUE)))
    observeEvent(input$table_cell_edit, {
      info <- input$table_cell_edit; d <- donnees()
      d[info$row, info$col] <- DT::coerceValue(info$value, d[info$row, info$col])
      donnees(d)
    })
    resultat <- reactive({
      if (methode == "POP") calc_pop(donnees(), input$blanc, input$vol_extrait, input$fact_dil)
      else calc_bsi(donnees(), input$blanc, input$vol_extrait, input$fact_dil)
    })
    modele <- reactiveVal(data.frame(Sample="", Volume_L=1,
      Vol_extrait_L=extrait_defaut, Fact_dil=1, Concentration=0,
      check.names=FALSE, stringsAsFactors=FALSE))
    output$resultats <- renderDT({
      res <- tryCatch(resultat(), error=function(e) NULL)
      validate(need(!is.null(res), "Corriger les colonnes ou les paramètres."))
      datatable(res, options=list(pageLength=12, scrollX=TRUE))
    })
    output$modele <- downloadHandler(
      filename=function() paste0("modele_", tolower(methode), ".csv"),
      content=function(file) write.csv(modele(), file, row.names=FALSE, fileEncoding="UTF-8"))
    output$export <- downloadHandler(
      filename=function() paste0(tolower(methode), "_resultats_", Sys.Date(), ".csv"),
      content=function(file) write.csv(resultat(), file, row.names=FALSE, fileEncoding="UTF-8"))
  })
}

# Dans l'UI :
# navbarPage("Analyses", onglet_pop_bsi_ui("pop", "POP", 0.005, 0),
#                         onglet_pop_bsi_ui("bsi", "BSi", 0.025, 5.41094))
# Dans le serveur :
# onglet_pop_bsi_server("pop", "POP")
# onglet_pop_bsi_server("bsi", "BSi")
