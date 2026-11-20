
#################################
# GG 11/16
# This file implements the Upper Tail Pareto functions written by Alexandre G, adjusted for lower tail 
# It is written to loop through HFCS waves (2014, 2017, 2021, 2023) and, separately for each wave,
# through different types of consumption/income, and:
# 1. Run the "eyeball test" on bottom 10% and whole distribution
# 2. Run the function to compute the median optimal cut-off and corresponding PC across sample years
# 3. Compute rank correlations across all goods and produce a heat matrix
#################################

## Load library (install.packages("") if needed)
library(EnvStats)
library(stats)
library(ggplot2)
library(scales)
library(spatstat.geom)
library(simPop)
library(distributionsrd)
library(pracma)
library(distrr)
library(reldist)
library(progress)
library(haven)
library(gslnls)
library(dplyr)
library(kableExtra)
library(wCorr)
library(ggpubr)

#################################
# 1. SET UP AG's FUNCTIONS      #
#################################

# the following code is taken from Alexandre G, and is used in the Tail of Tales paper
{
  ## theme ggplot
  th <- theme(panel.grid.major = element_line(color="#d9d9d9",  size = 0.3, linetype = 2),
              panel.grid.minor = element_line(color="#f5f5f5", size = 0.3, linetype = 2),
              panel.background = element_rect(fill = "white",
                                              colour = "black",
                                              size = 0.5, linetype = "solid"),
              legend.title = element_blank(),
              legend.text = element_text(size = 9.5,color="black"),
              legend.key.width = unit(1,"cm"),
              legend.key = element_rect(fill = "transparent",colour="transparent"),
              legend.background = element_rect(fill = "transparent",colour="transparent"),
              axis.title = element_text(size=10,color="black"),
              axis.text = element_text(size=9,color="black"),
              plot.title = element_text(size=10,face="bold",color="black"))

  
  ###### FUNCTION
  ### do a function for the eyeball test -- lower tail 

  eyeball_test_LT <- function(var, weights, maxval, model_estimation, title_plot){
    
    df <- as.data.frame(cbind(var, weights))
    df <- df[which(df$var <= maxval & df$var > 0), ]
    df <- df[order(df$var), ]
    total_weight <- sum(df$weights)
    
    df$cumul_weight <- cumsum(df$weights) / total_weight
    
    if(model_estimation == "OLS"){
      fitpareto <- lm(log(df$cumul_weight) ~ log(df$var/maxval) - 1)
      coeff_shape <- fitpareto$coefficients
    }
    
    if(model_estimation == "MLE"){
      coeff_shape <- total_weight / sum(df$weights * log(maxval/df$var))
    }
    
    if(model_estimation == "NLS"){
      df$var_norm <- df$var/maxval
      coeff_shape <- coef(gsl_nls(
        fn = cumul_weight ~ var_norm^theta1,
        data = df,
        start = list(theta1 = 3),
        control = list(scale = "levenberg")
      ))
    }
    
    ppareto <- ggplot(df, aes(x = var, y = cumul_weight)) +
      geom_point(shape = 1, color = "#C85C5C", size = 2.0, alpha = 1) + th +
      ylab("Empirical CDF") + xlab("log(val)") +
      geom_abline(intercept = -coeff_shape*log10(maxval), slope = coeff_shape,
                  color = "black", linetype = "dashed", size = 0.9)
    
    ppareto <- ppareto +
      scale_x_log10(limits = c(min(df$var), maxval),
                    breaks = trans_breaks("log10", function(x) 10^x),
                    labels = trans_format("log10", math_format(10^.x))) +
      scale_y_log10(breaks = trans_breaks("log10", function(x) 10^x),
                    labels = trans_format("log10", math_format(10^.x))) +
      annotate("text", label = paste0("\nslope: ", round(coeff_shape, 3)),
               #x = 0, y = 0) +
               x = max(df$var)*0.1, y = 1) +
      ggtitle(title_plot)
    
    ppareto
  }
  
  
  ### Function to compute Pareto tails-- LT
  pareto_shape_thresholds_PSID_LT <- function(var, weights, minq, maxq, steps, run_NLS = TRUE) {
    
    ## candidate cutoffs = quantiles defining the UPPER bound of the lower-tail region
    ## (e.g. probs = 0.05 means "the value below which the bottom 5% of the sample falls")
    quantvalue     <- seq(minq, maxq, steps)
    quantthreshold <- as.numeric(Hmisc::wtd.quantile(var, weights = weights, probs = quantvalue, na.rm = TRUE))
    
    ## sort ascending once
    o   <- order(var)
    var <- var[o]; weights <- weights[o]
    n   <- length(quantvalue)
    
    OLS_estimate <- MLE_estimate <- NLS_estimate <- rep(NA_real_, n)
    mean_residual_OLS <- maxKS_OLS <- meanKS_OLS <- rep(NA_real_, n)
    maxKS_MLE <- meanKS_MLE <- maxKS_NLS <- meanKS_NLS <- rep(NA_real_, n)
    
    for (i in seq_len(n)) {
      
      maxval_test <- quantthreshold[i]
      if (!is.finite(maxval_test) || maxval_test <= 0) next
      
      ## keep only the LOWER tail: everything at or below this cutoff
      id <- which(var <= maxval_test)
      x  <- var[id]; w <- weights[id]
      total_weight <- sum(w)
      if (length(x) < 10) next   # too few points to fit anything meaningful
      
      maxval_test <- max(maxval_test, .001)
      
      ## empirical CDF (NOT CCDF): fraction of weight AT OR BELOW each x
      ## x is sorted ascending, so cumsum naturally hits exactly 1 at the
      ## largest value in the subsample (x = maxval_test) -- no extra
      ## rescaling needed, unlike the upper-tail version
      cumul_weight <- cumsum(w) / total_weight
      
      ## mirrored log-ratio: always >= 0, since x <= maxval_test here
      ## (this keeps every formula below IDENTICAL in form to the upper-tail code)
      if (min(x) > 0) lx <- log(maxval_test / x)
      else            lx <- log(maxval_test / (x + .001))
      
      ## OLS: regress log(CDF) on lx, through the origin
      fitpareto <- stats::lm.fit(matrix(lx, ncol = 1L), log(cumul_weight))
      OLS_estimate[i] <- -unname(fitpareto$coefficients[1])
      
      ## MLE: weighted Hill-type estimator, mirrored
      MLE_estimate[i] <- total_weight / sum(w * lx)
      
      ## KS goodness-of-fit: compare empirical CDF to the fitted power-law CDF
      PX <- cumul_weight   # empirical CDF, already computed above
      err_OLS <- abs((x / maxval_test)^OLS_estimate[i] - PX)
      err_MLE <- abs((x / maxval_test)^MLE_estimate[i] - PX)
      
      maxKS_OLS[i]  <- max(err_OLS);  meanKS_OLS[i]  <- mean(err_OLS)
      maxKS_MLE[i]  <- max(err_MLE);  meanKS_MLE[i]  <- mean(err_MLE)
      mean_residual_OLS[i] <- weighted.mean(abs(fitpareto$residuals), w = w)
      
      if (run_NLS) {
        df_nls <- data.frame(cumul_weight, var_norm = exp(lx))  # var_norm = maxval/x
        model <- gslnls::gsl_nls(
          cumul_weight ~ (1/var_norm)^theta1,
          data = df_nls, start = list(theta1 = 3),
          control = list(scale = "levenberg")
        )
        NLS_estimate[i] <- unname(coef(model)[1])
        err_NLS <- abs((x / maxval_test)^NLS_estimate[i] - PX)
        maxKS_NLS[i]  <- max(err_NLS)
        meanKS_NLS[i] <- mean(err_NLS)
      }
    }
    
    data.frame(
      quantthreshold, quantvalue, OLS_estimate, MLE_estimate, NLS_estimate,
      mean_residual_OLS, maxKS_OLS, meanKS_OLS, maxKS_MLE, meanKS_MLE,
      maxKS_NLS, meanKS_NLS
    )
  }
  
}



####################################
# 2. LOAD DATA (once, all waves)   #
####################################

load("C:/Users/G1SAM03/FRBC Dropbox/Sam Moore/Nico/HFCS_pareto/raw/HFCS_final.RData")
HFCS_raw <- as.data.frame(HFCS)
rm(HFCS)

## ---- run settings ------------------------------------------------------------
waves_to_run <- c(2014, 2017, 2021, 2023)
country_keep <- "DE"
out_root     <- "C:/Users/G1SAM03/FRBC Dropbox/Sam Moore/Nico/HFCS_pareto/output/"

cat("Waves present in data for", country_keep, ":\n")
print(table(HFCS_raw$year[HFCS_raw$sa0100 == country_keep]))


#####################################################################
# run_wave(): sections 2-6 for ONE wave. Every output (eyeball plots,
# zero log, Stata file, Pareto tables/figures, rank correlations) is
# written to <out_root>/wave_<year>/ and every file name carries the
# country code and year, so waves never overwrite each other.
#####################################################################

run_wave <- function(wave_year, HFCS_raw, country_keep, out_root) {

  cat("\n\n##########################################\n",
      "#  WAVE ", wave_year, "\n",
      "##########################################\n", sep = "")

  ####################################
  # 2b. RESTRICT SAMPLE              #
  ####################################

  HFCS <- HFCS_raw %>%
    # keep if sa0100 == country & year == wave
    filter(sa0100 == country_keep, year == wave_year) %>%
    # keep <varlist> (Stata wildcards `x*` become starts_with("x"))
    select(
      sa0100, sa0010, im0100, ra0300, year,
      starts_with("conso_food_home"),
      starts_with("conso_utilities"),
      starts_with("conso_donations"),
      starts_with("rent"),
      starts_with("imputed_rent"),
      starts_with("conso_flow_vehicle"),
      starts_with("conso_flow_art_other_valuable"),
      starts_with("conso_total_final"),
      starts_with("conso_other_goods_services_total"),
      w_hfcs, w_hfcs_wid
    ) %>%
    
    # gen conso_housing* = rent + imputed_rent
    mutate(
      conso_housing         = rent         + imputed_rent,
      conso_housing_adj     = rent_adj     + imputed_rent_adj,
      conso_housing_adj_wid = rent_adj_wid + imputed_rent_adj_wid
    ) %>%
    
    # drop rent* imputed_rent*
    select(-starts_with("rent"), -starts_with("imputed_rent"))

    HFCS$conso_donations_adj <- HFCS$conso_donations_adj_wid <- HFCS$conso_donations

  ## following paper: age restriction: active consumption/saving decisions
  HFCS <- HFCS[HFCS$ra0300 >= 19 & HFCS$ra0300 <= 80, ]

  ## drop households reporting zero food consumption: "We remove observations for which households report not consuming any food."
  HFCS <- HFCS[!(HFCS$conso_food_home == 0), ]

  if (nrow(HFCS) == 0) stop("no observations for ", country_keep, " in ", wave_year, " after sample restrictions")


  ####################################
  # 3. set up loop                   #
  ####################################

  ## ---- paths -------------------------------------------------------------------
  out_dir  <- paste0(out_root, "wave_", wave_year, "/")
  save_dir <- paste0(out_dir, "eyeball_test/")
  corr_dir <- paste0(out_dir, "rank_correlations/")
  dir.create(save_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(corr_dir, recursive = TRUE, showWarnings = FALSE)

  ## ---- sample identifiers (taken from the data, used in all labels) -------------
  HFCS <- as.data.frame(HFCS)
  imps         <- sort(unique(HFCS$im0100))
  waves        <- sort(unique(HFCS$year))
  ref_year     <- max(waves)
  ref_imp      <- min(imps)
  country_code <- unique(HFCS$sa0100)
  country_name <- c(DE = "Germany")[country_code]
  if (is.na(country_name)) country_name <- country_code
  sample_lab   <- paste0(country_name, " (", country_code, "), ", ref_year)   # "Germany (DE), 2021"

  ## ---- adjustment cases (mirrors est_cases in the upper-tail code) -------------
  adj_cases <- data.frame(
    suffix       = c("", "_adj", "_adj_wid"),
    adjustment   = c("None", "Reporting", "Reporting + Representation"),
    adj_short    = c("raw", "adj", "adj_wid"),
    weight_var   = c("w_hfcs", "w_hfcs", "w_hfcs_wid"),
    weight_label = c("HFCS weights", "HFCS weights", "HFCS reweighted (WID)"),
    stringsAsFactors = FALSE
  )

  ## ---- consumption variables available after section 2 -------------------------
  base_spec <- data.frame(
    base  = c("conso_food_home", "conso_utilities", "conso_housing", "conso_donations",
              "conso_flow_vehicle", "conso_flow_art_other_valuable",
              "conso_other_goods_services_total", "conso_total_final"),
    short = c("food_home", "utilities", "housing", "donations",
              "vehicle", "art", "oth_gs", "total"),
    label = c("food at home", "utilities", "housing (rent + imputed rent)", "donations",
              "vehicles (flow)", "art & other valuables (flow)",
              "other goods & services", "total consumption"),
    stringsAsFactors = FALSE
  )

  ## ---- full case list: variable x adjustment -----------------------------------
  est_cases <- merge(base_spec, adj_cases, by = NULL)              # cross join
  est_cases <- est_cases[order(match(est_cases$suffix, adj_cases$suffix),
                               match(est_cases$base, base_spec$base)), ]
  est_cases$type      <- paste0(est_cases$base, est_cases$suffix)   # variable in HFCS
  est_cases$norm_var  <- paste0(est_cases$short, est_cases$suffix, "_norm")
  est_cases$root      <- paste0(est_cases$short, "_", est_cases$adj_short)   # file stub
  est_cases$case_id   <- est_cases$root
  est_cases$full_lab  <- paste0(est_cases$label, " | ", est_cases$adjustment,
                                " | ", est_cases$weight_label)
  rownames(est_cases) <- est_cases$case_id

  stopifnot(all(est_cases$type %in% names(HFCS)),
            all(adj_cases$weight_var %in% names(HFCS)))

  ## ---- normalise each variable by its weighted mean (weight matched to case) ----
  for (k in seq_len(nrow(est_cases))) {
    tv <- est_cases$type[k]; nv <- est_cases$norm_var[k]; wv <- est_cases$weight_var[k]
    HFCS[[tv]] <- as.numeric(HFCS[[tv]])
    HFCS[[nv]] <- HFCS[[tv]] / weighted.mean(HFCS[[tv]], w = HFCS[[wv]], na.rm = TRUE)
  }

  ## ---- bookkeeping tables ------------------------------------------------------
  zero_log <- data.frame(
    case_id = character(), variable = character(), adjustment = character(),
    n_ref = integer(), n_zero = integer(), n_negative = integer(), n_used = integer(),
    share_zero_wtd = numeric(), stringsAsFactors = FALSE
  )

  pareto_summary_LT <- data.frame(
    case_id           = est_cases$case_id,
    type              = est_cases$type,
    base              = est_cases$base,
    label             = est_cases$label,
    adjustment        = est_cases$adjustment,
    weight_label      = est_cases$weight_label,
    median_zeta_MLE   = NA_real_,
    median_quant_opt  = NA_real_,
    median_xmax_opt   = NA_real_,
    n_waves_estimated = NA_integer_,
    n_waves_total     = length(waves),
    stringsAsFactors  = FALSE
  )

  optimal_zeta_LT_list <- setNames(vector("list", nrow(est_cases)), est_cases$case_id)

  #####################################
  # 3a. EYEBALL TEST (reference year) #
  #####################################

  d_ref <- HFCS[HFCS$year == ref_year & HFCS$im0100 == ref_imp, ]   # one implicate for plots

  for (k in seq_len(nrow(est_cases))) {
    
    cs <- est_cases[k, ]
    print(cs$case_id)
    
    var_all     <- d_ref[[cs$norm_var]]
    weights_all <- d_ref[[cs$weight_var]]
    ok          <- is.finite(var_all) & is.finite(weights_all) & weights_all > 0
    var_all     <- var_all[ok]
    weights_all <- weights_all[ok]
    
    n_ref          <- length(var_all)
    n_zero         <- sum(var_all == 0)
    n_neg          <- sum(var_all < 0)
    share_zero_wtd <- sum(weights_all[var_all == 0]) / sum(weights_all)
    
    pos         <- var_all > 0
    var_ref     <- var_all[pos]
    weights_ref <- weights_all[pos]
    
    zero_log <- rbind(zero_log, data.frame(
      case_id = cs$case_id, variable = cs$type, adjustment = cs$adjustment,
      n_ref = n_ref, n_zero = n_zero, n_negative = n_neg, n_used = length(var_ref),
      share_zero_wtd = share_zero_wtd, stringsAsFactors = FALSE))
    
    if (length(var_ref) < 30) {
      message("Skipping ", cs$case_id, ": fewer than 30 positive obs")
      next
    }
    
    zero_note <- sprintf(
      "%s. Adjustment: %s; %s; implicate %d.\n%s zero obs dropped (%.1f%% weighted)%s; %s positive obs used.",
      sample_lab, cs$adjustment, cs$weight_label, ref_imp,
      format(n_zero, big.mark = ","), 100 * share_zero_wtd,
      if (n_neg > 0) sprintf(", %s negative obs dropped", format(n_neg, big.mark = ",")) else "",
      format(length(var_ref), big.mark = ","))
    
    sub_lab <- paste0(cs$adjustment, " | ", cs$weight_label, " | ", sample_lab)
    
    ## Panel 1: whole positive distribution
    p_whole_lt <- eyeball_test_LT(
      var_ref, weights_ref, maxval = max(var_ref), model_estimation = "MLE",
      title_plot = "") +
      labs(title    = paste0("Whole distribution: ", cs$label),
           subtitle = sub_lab,
           caption  = zero_note) +
      theme(plot.title    = element_text(size = 9, face = "bold"),
            plot.subtitle = element_text(size = 7),
            plot.caption  = element_text(hjust = 0, size = 6))
    
    ## Panel 2: bottom 10% of positive values
    xmin_bot10 <- as.numeric(Hmisc::wtd.quantile(var_ref, weights = weights_ref, probs = 0.10))
    
    p_bottom_10 <- eyeball_test_LT(
      var_ref, weights_ref, maxval = xmin_bot10, model_estimation = "MLE",
      title_plot = "") +
      labs(title    = paste0("Bottom 10% of positive values: ", cs$label),
           subtitle = sub_lab,
           caption  = zero_note) +
      theme(plot.title    = element_text(size = 9, face = "bold"),
            plot.subtitle = element_text(size = 7),
            plot.caption  = element_text(hjust = 0, size = 6))
    
    ggsave(paste0(save_dir, cs$root, "_LT_whole_", country_code, "_", ref_year, ".pdf"),
           plot = p_whole_lt, width = 4, height = 3.3, dpi = 300)
    ggsave(paste0(save_dir, cs$root, "_LT_bot10_", country_code, "_", ref_year, ".pdf"),
           plot = p_bottom_10, width = 4, height = 3.3, dpi = 300)
  }

  print(zero_log)
  write.csv(zero_log, paste0(out_dir, "zero_log_", country_code, "_", ref_year, ".csv"), row.names = FALSE)

  #################################
  # 4. SAVE FOR STATA CODE        #
  #################################

  stata_data <- HFCS %>%
    select(sa0100, sa0010, im0100, year, w_hfcs, w_hfcs_wid,
           all_of(unique(est_cases$type)), all_of(unique(est_cases$norm_var))) %>%
    rename_with(~ sub("^conso_flow_art_other_valuable", "conso_art", .x)) %>%
    rename_with(~ sub("^conso_other_goods_services_total", "conso_oth_gs", .x))

  stopifnot(all(nchar(names(stata_data)) <= 32))

  write_dta(stata_data, paste0(out_dir, "stata_hfcs_clean_", country_code, "_", ref_year, ".dta"))

  #################################################
  # 5. LOWER-TAIL PARETO: OPTIMAL CUTOFF, MEDIAN  #
  #################################################

  for (k in seq_len(nrow(est_cases))) {
    
    cs <- est_cases[k, ]
    cat("\n=============================\n", cs$case_id, " (", cs$type, ", ", cs$weight_var, ")\n", sep = "")
    
    rows <- list()
    
    for (yr in waves) {
      for (ii in imps) {
        
        sub <- HFCS[HFCS$year == yr & HFCS$im0100 == ii, ]
        v   <- sub[[cs$norm_var]]
        wt  <- sub[[cs$weight_var]]
        
        base_ok <- is.finite(v) & is.finite(wt) & wt > 0
        n_zero  <- sum(base_ok & v <= 0)
        ok      <- base_ok & v > 0
        v <- v[ok]; wt <- wt[ok]
        
        out <- data.frame(wave = yr, implicate = ii, zeta_MLE = NA_real_, xmax_opt = NA_real_,
                          quant_opt = NA_real_, n_obs = length(v), n_zero = n_zero)
        
        if (length(v) >= 30) {
          scan_res <- tryCatch(
            pareto_shape_thresholds_PSID_LT(var = v, weights = wt,
                                            minq = 0.03, maxq = 0.30, steps = 0.01,
                                            run_NLS = FALSE),
            error = function(e) {
              message("  wave ", yr, " imp ", ii, ": scan failed - ", conditionMessage(e))
              NULL
            })
          
          if (!is.null(scan_res)) {
            valid <- is.finite(scan_res$maxKS_MLE) & is.finite(scan_res$MLE_estimate)
            if (any(valid)) {
              best <- which.min(ifelse(valid, scan_res$maxKS_MLE, Inf))
              out$zeta_MLE  <- scan_res$MLE_estimate[best]
              out$xmax_opt  <- scan_res$quantthreshold[best]
              out$quant_opt <- scan_res$quantvalue[best]
            }
          }
        }
        rows[[length(rows) + 1]] <- out
      }
    }
    
    det <- do.call(rbind, rows)
    
    ## average across implicates within wave
    optimal_zeta_LT <- det %>%
      group_by(wave) %>%
      summarise(zeta_MLE  = mean(zeta_MLE,  na.rm = TRUE),
                xmax_opt  = mean(xmax_opt,  na.rm = TRUE),
                quant_opt = mean(quant_opt, na.rm = TRUE),
                n_obs     = mean(n_obs),
                n_zero    = mean(n_zero),
                .groups   = "drop") %>%
      mutate(across(c(zeta_MLE, xmax_opt, quant_opt), ~ ifelse(is.nan(.x), NA_real_, .x))) %>%
      as.data.frame()
    
    optimal_zeta_LT_list[[cs$case_id]] <- list(by_implicate = det, by_wave = optimal_zeta_LT)
    print(optimal_zeta_LT)
    
    i <- which(pareto_summary_LT$case_id == cs$case_id)
    pareto_summary_LT$median_zeta_MLE[i]   <- median(optimal_zeta_LT$zeta_MLE,  na.rm = TRUE)
    pareto_summary_LT$median_quant_opt[i]  <- median(optimal_zeta_LT$quant_opt, na.rm = TRUE)
    pareto_summary_LT$median_xmax_opt[i]   <- median(optimal_zeta_LT$xmax_opt,  na.rm = TRUE)
    pareto_summary_LT$n_waves_estimated[i] <- sum(!is.na(optimal_zeta_LT$zeta_MLE))
    
    cat(sprintf("Median lower-tail Pareto coefficient (%s): %.3f  |  median optimal cutoff: %.3f (quantile)\n",
                cs$full_lab, pareto_summary_LT$median_zeta_MLE[i], pareto_summary_LT$median_quant_opt[i]))
  }

  ## per-implicate detail to disk
  det_all <- do.call(rbind, lapply(names(optimal_zeta_LT_list), function(cid) {
    d <- optimal_zeta_LT_list[[cid]]$by_implicate
    if (is.null(d)) return(NULL)
    cbind(case_id = cid, est_cases[cid, c("type", "adjustment", "weight_var")], d)
  }))
  write.csv(det_all, paste0(out_dir, "pareto_LT_by_implicate_", country_code, "_", ref_year, ".csv"),
            row.names = FALSE)

  ## ---------------------------------------------------------------------------
  ## Final table
  ## ---------------------------------------------------------------------------
  print(pareto_summary_LT)
  write.csv(pareto_summary_LT, paste0(out_dir, "pareto_LT_summary_", country_code, "_", ref_year, ".csv"),
            row.names = FALSE)

  tab <- pareto_summary_LT %>%
    mutate(adjustment = factor(adjustment, levels = adj_cases$adjustment)) %>%
    arrange(adjustment, median_zeta_MLE) %>%
    select(adjustment, label, weight_label, median_zeta_MLE, median_quant_opt, median_xmax_opt) %>%
    rename(Adjustment = adjustment,
           Variable = label,
           Weights = weight_label,
           `Pareto coefficient` = median_zeta_MLE,
           `Median cut-off (quantile)` = median_quant_opt,
           `Median cut-off (value)` = median_xmax_opt)

  tex_table <- kable(
    tab, format = "latex", booktabs = TRUE, digits = 3,
    align = c("l", "l", "l", "c", "c", "c"),
    caption = paste0("Lower-tail Pareto coefficient estimates by consumption category and adjustment, HFCS ",
                     sample_lab),
    label = paste0("pareto_summary_LT_", country_code, "_", ref_year),
    linesep = "", escape = TRUE
  ) %>%
    kable_styling(latex_options = c("hold_position")) %>%
    collapse_rows(columns = 1, latex_hline = "major", valign = "top")

  tex_table
  writeLines(as.character(tex_table),
             paste0(out_dir, "pareto_LT_summary_", country_code, "_", ref_year, ".tex"))

  ## one summary figure: coefficient by variable, coloured by adjustment
  p_sum <- pareto_summary_LT %>%
    mutate(adjustment = factor(adjustment, levels = adj_cases$adjustment),
           label = factor(label, levels = base_spec$label)) %>%
    ggplot(aes(x = label, y = median_zeta_MLE, colour = adjustment, shape = adjustment)) +
    geom_point(size = 2.5, position = position_dodge(width = 0.5)) +
    labs(x = NULL, y = "Lower-tail Pareto coefficient (MLE)",
         title = paste0("Lower-tail Pareto coefficients by consumption category, HFCS ", sample_lab),
         subtitle = "Optimal cut-off chosen by min max-KS over quantiles 0.03-0.30; averaged across implicates") +
    th + theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.position = "top")
  ggsave(paste0(out_dir, "pareto_LT_summary_", country_code, "_", ref_year, ".pdf"), p_sum,
         width = 8, height = 5)

  #################################################
  # 6. RANK CORRELATIONS                          #
  #################################################
  # if a good has a low Pareto coefficient AND a low rank-rank correlation with other goods,
  # another shock is driving it (it is not just proportional to total spending)

  ## goods to include: all components, not the total
  corr_bases <- setdiff(base_spec$base, "conso_total_final")

  ## weighted Spearman correlation matrix
  spearman_matrix <- function(df, vars, w, drop_zeros = FALSE) {
    k <- length(vars)
    M <- matrix(NA_real_, k, k, dimnames = list(vars, vars))
    for (i in 1:k) for (j in i:k) {
      x <- df[[vars[i]]]; y <- df[[vars[j]]]
      ok <- is.finite(x) & is.finite(y) & is.finite(w) & w > 0
      if (drop_zeros) ok <- ok & x > 0 & y > 0
      r <- if (sum(ok) > 30)
        weightedCorr(x[ok], y[ok], method = "Spearman", weights = w[ok]) else NA_real_
      M[i, j] <- M[j, i] <- r
    }
    diag(M) <- 1
    M[M > 1] <- 1; M[M < -1] <- -1
    M
  }

  avg_corr <- function(M) {
    diag(M) <- NA
    sort(rowMeans(M, na.rm = TRUE))
  }

  plot_corr_heat <- function(M, labs_order, title, subtitle) {
    m <- M
    m[upper.tri(m)] <- NA
    mm <- as.data.frame(as.table(m), stringsAsFactors = FALSE)
    names(mm) <- c("Var1", "Var2", "value")
    mm <- mm[!is.na(mm$value), ]
    mm$Var1 <- factor(mm$Var1, levels = rev(labs_order))
    mm$Var2 <- factor(mm$Var2, levels = rev(labs_order))
    ggplot(mm, aes(Var1, Var2, fill = value)) +
      geom_tile(color = "white") +
      geom_text(aes(label = sprintf("%.2f", value)), size = 3) +
      scale_fill_gradient2(low = "white", high = "steelblue",
                           limits = c(0, 1), oob = scales::squish, na.value = "grey90") +
      labs(x = NULL, y = NULL, fill = "Spearman \u03c1", title = title, subtitle = subtitle) +
      th + theme(axis.text.x = element_text(angle = 45, hjust = 1),
                 plot.title = element_text(size = 9), plot.subtitle = element_text(size = 8))
  }


  rho_list  <- list()
  avg_list  <- list()

  for (a in seq_len(nrow(adj_cases))) {
    
    ac      <- adj_cases[a, ]
    cases_a <- est_cases[est_cases$suffix == ac$suffix & est_cases$base %in% corr_bases, ]
    
    ## order by lower-tail Pareto coefficient (highest -> lowest)
    pc <- pareto_summary_LT$median_zeta_MLE[match(cases_a$case_id, pareto_summary_LT$case_id)]
    o  <- order(-pc)
    cases_a <- cases_a[o, ]; pc <- pc[o]
    
    corr_vars <- cases_a$norm_var
    corr_labs <- paste0(cases_a$label, " (", formatC(pc, format = "f", digits = 2), ")")
    
    ## matrix per implicate, then average across implicates
    mats <- lapply(imps, function(ii) {
      d <- HFCS[HFCS$year == ref_year & HFCS$im0100 == ii, ]
      spearman_matrix(d, corr_vars, d[[ac$weight_var]], drop_zeros = TRUE)
    })
    rho <- Reduce(`+`, lapply(mats, function(m) ifelse(is.na(m), 0, m))) /
      Reduce(`+`, lapply(mats, function(m) !is.na(m)))
    rho[is.nan(rho)] <- NA
    diag(rho) <- 1
    dimnames(rho) <- list(corr_labs, corr_labs)
    rho_list[[ac$adjustment]] <- rho
    
    ## each good's average correlation with the other goods
    ac_avg <- avg_corr(rho)
    avg_list[[ac$adjustment]] <- data.frame(adjustment = ac$adjustment,
                                            weight_label = ac$weight_label,
                                            good = names(ac_avg),
                                            avg_corr = unname(ac_avg),
                                            stringsAsFactors = FALSE)
    cat("\n--- Average correlation with other goods:", ac$adjustment, "---\n")
    print(round(ac_avg, 2))
    
    write.csv(round(rho, 3),
              paste0(corr_dir, "rank_corr_", ac$adj_short, "_", country_code, "_", ref_year, ".csv"))
    
    ## heatmap (lower triangle), ordered by Pareto coefficient
    p_corr <- plot_corr_heat(
      rho, corr_labs,
      title    = paste0("Weighted Spearman rank correlations across goods (positive spending on both), HFCS ",
                        sample_lab),
      subtitle = paste0("Adjustment: ", ac$adjustment, " | ", ac$weight_label,
                        " | averaged over ", length(imps),
                        " implicates | ordered by lower-tail Pareto coefficient (in parentheses)"))
    
    print(p_corr)
    ggsave(paste0(corr_dir, "rank_correlations_", ac$adj_short, "_", country_code, "_", ref_year, ".pdf"),
           p_corr, width = 8, height = 6.5)
  }

  ## combined table of average correlations across adjustments
  avg_corr_tab <- do.call(rbind, avg_list)
  print(avg_corr_tab)
  write.csv(avg_corr_tab,
            paste0(corr_dir, "rank_corr_avg_by_good_", country_code, "_", ref_year, ".csv"),
            row.names = FALSE)

  ## side-by-side heatmaps for the three adjustments in one file
  heat_panels <- lapply(seq_len(nrow(adj_cases)), function(a) {
    ac  <- adj_cases[a, ]
    rho <- rho_list[[ac$adjustment]]
    plot_corr_heat(rho, rownames(rho),
                   title    = paste0(ac$adjustment, " | ", ac$weight_label),
                   subtitle = NULL) +
      theme(legend.position = "none")
  })
  g_heat_all <- ggarrange(plotlist = heat_panels, ncol = 3, nrow = 1)
  g_heat_all <- annotate_figure(
    g_heat_all,
    top = text_grob(paste0("Weighted Spearman rank correlations across goods (positive spending on both), HFCS ",
                           sample_lab, " - averaged over ", length(imps), " implicates"),
                    size = 10))
  ggsave(paste0(corr_dir, "rank_correlations_ALL_adjustments_", country_code, "_", ref_year, ".pdf"),

  ## return the wave's main results so they can be stacked across waves
  invisible(list(summary   = cbind(wave = wave_year, pareto_summary_LT),
                 avg_corr  = cbind(wave = wave_year, avg_corr_tab),
                 zero_log  = cbind(wave = wave_year, zero_log),
                 rho       = rho_list,
                 detail    = optimal_zeta_LT_list))
}


#################################################
# 7. RUN ALL WAVES                              #
#################################################

wave_results <- list()
for (wy in waves_to_run) {
  res <- tryCatch(
    run_wave(wy, HFCS_raw, country_keep, out_root),
    error = function(e) {
      message("WAVE ", wy, " FAILED: ", conditionMessage(e))
      NULL
    })
  if (!is.null(res)) wave_results[[as.character(wy)]] <- res
}

cat("\nWaves completed:", paste(names(wave_results), collapse = ", "), "\n")
failed <- setdiff(as.character(waves_to_run), names(wave_results))
if (length(failed)) cat("Waves FAILED:", paste(failed, collapse = ", "), "\n")

## convenience: stacked versions of the per-wave tables (per-wave files are already written)
if (length(wave_results)) {
  waves_lab <- paste(names(wave_results), collapse = "_")
  write.csv(do.call(rbind, lapply(wave_results, `[[`, "summary")),
            paste0(out_root, "pareto_LT_summary_", country_keep, "_waves_", waves_lab, ".csv"),
            row.names = FALSE)
  write.csv(do.call(rbind, lapply(wave_results, `[[`, "avg_corr")),
            paste0(out_root, "rank_corr_avg_by_good_", country_keep, "_waves_", waves_lab, ".csv"),
            row.names = FALSE)
}
