# Fonctions de calcul pures : aucune dépendance Shiny ni accès aux fichiers.

.moyenne_blanc <- function(x, nom) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (!length(x)) stop("Fournir au moins une valeur numérique pour le blanc ", nom, ".")
  mean(x)
}

calc_poc <- function(df, blank_pn = 0, blank_pc = 0) {
  requis <- c("Volume_L", "PN_mg", "PC_mg")
  manquants <- setdiff(requis, names(df))
  if (length(manquants)) stop("Colonnes manquantes : ", paste(manquants, collapse = ", "))
  vol <- as.numeric(df$Volume_L)
  if (any(!is.na(vol) & vol == 0)) stop("Volume_L doit être différent de zéro.")
  df$PON_ug_L <- ((as.numeric(df$PN_mg) - .moyenne_blanc(blank_pn, "PN")) / vol) * 10^3
  df$POC_ug_L <- ((as.numeric(df$PC_mg) - .moyenne_blanc(blank_pc, "PC")) / vol) * 10^3
  df$Ratio_C_N <- df$POC_ug_L / df$PON_ug_L
  df
}

# Renomme les colonnes historiques et initialise les facteurs manquants.
# Dilution correspond au volume d'extrait; Dil correspond à la dilution manuelle.
.preparer_pop_bsi <- function(df, Vol_extrait_L, Fact_dil) {
  if ("Dilution" %in% names(df)) {
    if (!("Vol_extrait_L" %in% names(df))) {
      message("Colonne legacy 'Dilution' renommée en 'Vol_extrait_L'.")
      names(df)[names(df) == "Dilution"] <- "Vol_extrait_L"
    } else {
      warning("Les colonnes 'Dilution' et 'Vol_extrait_L' sont présentes; 'Vol_extrait_L' est conservée.", call. = FALSE)
    }
  }
  if ("Dil" %in% names(df)) {
    if (!("Fact_dil" %in% names(df))) {
      message("Colonne legacy 'Dil' renommée en 'Fact_dil'.")
      names(df)[names(df) == "Dil"] <- "Fact_dil"
    } else {
      warning("Les colonnes 'Dil' et 'Fact_dil' sont présentes; 'Fact_dil' est conservée.", call. = FALSE)
    }
  }
  if (!"Vol_extrait_L" %in% names(df)) df$Vol_extrait_L <- Vol_extrait_L
  df$Vol_extrait_L <- as.numeric(df$Vol_extrait_L)
  df$Vol_extrait_L[is.na(df$Vol_extrait_L)] <- Vol_extrait_L
  if (!"Fact_dil" %in% names(df)) df$Fact_dil <- Fact_dil
  df$Fact_dil <- as.numeric(df$Fact_dil)
  df$Fact_dil[is.na(df$Fact_dil)] <- Fact_dil
  df
}

calc_pop <- function(df, blank_concentration = 0,
                     Vol_extrait_L = 0.005, Fact_dil = 1) {
  requis <- c("Volume_L", "Concentration")
  manquants <- setdiff(requis, names(df))
  if (length(manquants)) stop("Colonnes manquantes : ", paste(manquants, collapse = ", "))
  df <- .preparer_pop_bsi(df, Vol_extrait_L, Fact_dil)
  vol <- as.numeric(df$Volume_L)
  if (any(!is.na(vol) & vol == 0)) stop("Volume_L doit être différent de zéro.")
  df$POP_umol_L <- ((as.numeric(df$Concentration) -
                       .moyenne_blanc(blank_concentration, "POP")) *
                      df$Vol_extrait_L * df$Fact_dil) / vol
  df
}

calc_bsi <- function(df, blank_concentration = 0,
                     Vol_extrait_L = 0.025, Fact_dil = 1) {
  requis <- c("Volume_L", "Concentration")
  manquants <- setdiff(requis, names(df))
  if (length(manquants)) stop("Colonnes manquantes : ", paste(manquants, collapse = ", "))
  df <- .preparer_pop_bsi(df, Vol_extrait_L, Fact_dil)
  vol <- as.numeric(df$Volume_L)
  if (any(!is.na(vol) & vol == 0)) stop("Volume_L doit être différent de zéro.")
  df$BSi_umol_L <- ((as.numeric(df$Concentration) -
                       .moyenne_blanc(blank_concentration, "BSi")) *
                      df$Vol_extrait_L * df$Fact_dil) / vol
  df
}
