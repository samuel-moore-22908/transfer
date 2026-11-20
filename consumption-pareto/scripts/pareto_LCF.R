#################################
# LCF version of pareto_HFCS.R
#
# Applies the HFCS lower-tail Pareto analysis to the UK Living Costs and Food
# Survey (LCF), 2011-2024, England only. Separately for each interview year it:
# 1. Runs the "eyeball test" on the bottom 10% and on the whole distribution
# 2. Finds the optimal lower-tail cut-off (min max-KS) and the MLE Pareto coefficient
# 3. Computes weighted Spearman rank correlations across goods and a heat matrix
# It then stacks the years and takes the median coefficient across years.
#
# Data build (section 2) mirrors create_LCF_consumption.do:
#   - dvhh household file of each UKDS release, read straight from the zips
#   - Jan-Mar 2015 households from the separate 2015q1 file (SN 8210)
#   - England only (gorx 1-9), interviews in 2025 dropped
#   - consumption = p600t (+ housing benefit b230 added back), x 52 -> GBP/year
#   - 12 COICOP divisions p601t..p612t x 52; housing (p604t) gets b230 added back
#
# Differences from the HFCS script (LCF has no implicates and no adjusted variants):
#   - one estimate per year (no averaging over implicates)
#   - one "adjustment" case: published LCF values, annual grossing weight
#   - wave = calendar year of interview (int_year), as in create_LCF_pareto.do
#   - age restriction 19-79: p396p is top-coded at 80 (= "80 or older")
#   - "zero food" restriction uses c_food (01 Food & non-alcoholic drinks)
#################################

## Load libraries (install.packages("") if needed)
library(stats)
library(ggplot2)
library(scales)
library(haven)
library(dplyr)
library(kableExtra)
library(wCorr)
library(ggpubr)
# also used via :: -> Hmisc (wtd.quantile); gslnls only if NLS is switched on

#################################
# 0. SETTINGS                   #
#################################

zip_dir      <- "C:/Users/smoor/Downloads/LCF"               # UKDS Stata zips (as downloaded)
root_dir     <- "C:/Users/smoor/Downloads/LCF_pareto/"
extract_dir  <- paste0(root_dir, "clean/")                    # dvhh files are unzipped here
out_root     <- paste0(root_dir, "output/")

waves_to_run <- 2011:2024        # interview calendar years (2025 interviews are dropped)
age_min      <- 19
age_max      <- 79               # p396p == 80 means 80+, so it is excluded
weeks_per_year <- 52

dir.create(extract_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_root,    recursive = TRUE, showWarnings = FALSE)

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
      coeff_shape <- coef(gslnls::gsl_nls(
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
               x = max(df$var)*0.1, y = 1) +
      ggtitle(title_plot)

    ppareto
  }


  ### Function to compute Pareto tails-- LT
  pareto_shape_thresholds_PSID_LT <- function(var, weights, minq, maxq, steps, run_NLS = TRUE) {

    ## candidate cutoffs = quantiles defining the UPPER bound of the lower-tail region
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
      if (length(x) < 10) next

      maxval_test <- max(maxval_test, .001)

      ## empirical CDF within the tail
      cumul_weight <- cumsum(w) / total_weight

      ## mirrored log-ratio: always >= 0
      if (min(x) > 0) lx <- log(maxval_test / x)
      else            lx <- log(maxval_test / (x + .001))

      ## OLS: regress log(CDF) on lx, through the origin
      fitpareto <- stats::lm.fit(matrix(lx, ncol = 1L), log(cumul_weight))
      OLS_estimate[i] <- -unname(fitpareto$coefficients[1])

      ## MLE: weighted Hill-type estimator, mirrored
      MLE_estimate[i] <- total_weight / sum(w * lx)

      ## KS goodness-of-fit
      PX <- cumul_weight
      err_OLS <- abs((x / maxval_test)^OLS_estimate[i] - PX)
      err_MLE <- abs((x / maxval_test)^MLE_estimate[i] - PX)

      maxKS_OLS[i]  <- max(err_OLS);  meanKS_OLS[i]  <- mean(err_OLS)
      maxKS_MLE[i]  <- max(err_MLE);  meanKS_MLE[i]  <- mean(err_MLE)
      mean_residual_OLS[i] <- weighted.mean(abs(fitpareto$residuals), w = w)

      if (run_NLS) {
        df_nls <- data.frame(cumul_weight, var_norm = exp(lx))
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


##########################################
# 2. BUILD LCF DATA (create_LCF_consumption.do) #
##########################################

## release table: SN, survey year, dvhh file inside the zip
releases <- data.frame(
  sn = c(7272, 7472, 7702, 7992, 8210, 8351, 8459, 8686, 8803, 9022, 9123, 9335, 9468, 9603, 8210),
  survey_year = c(2011:2024, 2015),
  q1_2015 = c(rep(0L, 14), 1L),
  file = c(
    "UKDA-7272-stata/stata/stata9_se/2011_dvhh_ukanon.dta",
    "UKDA-7472-stata/stata/stata11_se/2012_dvhh_ukanon.dta",
    "UKDA-7702-stata/stata/stata11_se/2013_dvhh_ukanon.dta",
    "UKDA-7992-stata/stata/stata11_se/2014_dvhh_ukanon.dta",
    "UKDA-8210-stata/stata/stata11_se/2015-16_dvhh_ukanon.dta",
    "UKDA-8351-stata/stata/stata13_se/2016_17_dvhh_ukanon.dta",
    "UKDA-8459-stata/stata/stata11_se/dvhh_ukanon_2017-18.dta",
    "UKDA-8686-stata/stata/stata13/2018_dvhh_ukanon.dta",
    "UKDA-8803-stata/stata/stata13/lcfs_2019_dvhh_ukanon.dta",
    "UKDA-9022-stata/stata/stata13/lcfs_2020_dvhh_ukanon.dta",
    "UKDA-9123-stata/stata/stata13_se/lcfs_2021_dvhh_ukanon.dta",
    "UKDA-9335-stata/stata/stata13_se/dvhh_ukanon_2022.dta",
    "UKDA-9468-stata/stata/stata13_se/dvhh_ukanon_v2_2023.dta",
    "UKDA-9603-stata/stata/stata13_se/dvhh_uk_anon_v3_2024.dta",
    "UKDA-8210-stata/stata/stata11_se/2015q1_dvhh_ukanon.dta"),
  stringsAsFactors = FALSE
)

divs      <- sprintf("p%dt", 601:612)
div_names <- c("food", "alctob", "clothing", "housing", "furnish", "health", "transport",
               "comms", "recreation", "education", "resthotel", "misc")

read_dvhh <- function(sn, survey_year, q1, file) {
  dest <- file.path(extract_dir, sn, file)
  if (!file.exists(dest)) {
    z <- list.files(zip_dir, pattern = paste0("^", sn, "stata_.*\\.zip$"), full.names = TRUE)
    if (length(z) != 1) stop("expected one zip for SN ", sn, " in ", zip_dir, ", found ", length(z))
    unzip(z, files = file, exdir = file.path(extract_dir, sn))
  }
  d <- read_dta(dest)
  names(d) <- tolower(names(d))
  if (q1 == 1) d <- rename(d, case = case1)
  if (sn == 9603) d <- rename(d, weighta = cal_weight_annual, weightq = cal_weight_quarterly)
  d <- d[, c("case", "weighta", "gorx", "year", "a099", "a049", "p396p", "p600t", divs, "b230")]
  d <- zap_labels(d)
  d$sn <- sn; d$survey_year <- survey_year; d$q1_2015 <- q1
  as.data.frame(d)
}

LCF <- do.call(rbind, lapply(seq_len(nrow(releases)), function(r)
  with(releases[r, ], read_dvhh(sn, survey_year, q1_2015, file))))

LCF <- LCF %>%
  filter(year != 2025) %>%                 # 2025 interviews (2024-25 release): not needed
  filter(gorx >= 1, gorx <= 9) %>%         # England only
  mutate(hhid        = sn * 100000 + case,
         int_year    = year,
         int_quarter = a099,
         wt_annual   = weighta,
         hhsize      = a049,
         age_hrp     = p396p,
         b230        = ifelse(is.na(b230), 0, b230))

## same checks as the do-file
stopifnot(!anyDuplicated(LCF$hhid),
          all(LCF$wt_annual > 0 & !is.na(LCF$wt_annual)),
          with(LCF, all(int_year[survey_year <= 2014] == survey_year[survey_year <= 2014])),
          with(LCF, all(int_year[q1_2015 == 1] == 2015 & int_quarter[q1_2015 == 1] == 1)),
          with(LCF[LCF$survey_year >= 2015 & LCF$q1_2015 == 0, ],
               all(int_year == ifelse(int_quarter == 1, survey_year + 1, survey_year))))

## consumption, GBP/year, housing benefit added back (total and housing)
LCF$cons_annual_pub <- LCF$p600t * weeks_per_year
LCF$hb_annual       <- LCF$b230  * weeks_per_year
LCF$cons_annual     <- (LCF$p600t + LCF$b230) * weeks_per_year
for (j in seq_along(divs)) LCF[[paste0("c_", div_names[j])]] <- LCF[[divs[j]]] * weeks_per_year
LCF$c_housing <- LCF$c_housing + LCF$hb_annual

LCF <- LCF[, c("hhid", "sn", "case", "survey_year", "q1_2015", "int_year", "int_quarter",
               "gorx", "hhsize", "age_hrp", "wt_annual", "cons_annual_pub", "hb_annual",
               "cons_annual", paste0("c_", div_names))]

cat("Households by interview year (England, before sample restrictions):\n")
print(table(LCF$int_year))


#####################################################################
# run_wave(): sections 2b-6 for ONE interview year. All outputs go to
# <out_root>/wave_<year>/ and every file name carries the year.
#####################################################################

## ---- consumption variables (fixed across waves) -------------------------------
base_spec <- data.frame(
  base  = c("c_food", "c_alctob", "c_clothing", "c_housing", "c_furnish", "c_health",
            "c_transport", "c_comms", "c_recreation", "c_education", "c_resthotel",
            "c_misc", "cons_annual"),
  short = c(div_names, "total"),
  label = c("food & non-alcoholic drinks", "alcohol & tobacco", "clothing & footwear",
            "housing, fuel & power (+ housing benefit)", "furnishings & hh equipment",
            "health", "transport", "communication", "recreation & culture", "education",
            "restaurants & hotels", "misc goods & services", "total consumption"),
  stringsAsFactors = FALSE
)
base_spec$norm_var <- paste0(base_spec$short, "_norm")
base_spec$case_id  <- base_spec$short
rownames(base_spec) <- base_spec$case_id

weight_var   <- "wt_annual"
weight_label <- "LCF annual grossing weight"

run_wave <- function(wave_year, LCF) {

  cat("\n\n##########################################\n",
      "#  INTERVIEW YEAR ", wave_year, "\n",
      "##########################################\n", sep = "")

  ####################################
  # 2b. RESTRICT SAMPLE              #
  ####################################

  d <- LCF[LCF$int_year == wave_year, ]

  ## age restriction (HFCS: 19-80; LCF age is top-coded at 80, so 19-79)
  d <- d[d$age_hrp >= age_min & d$age_hrp <= age_max, ]

  ## drop households reporting zero food consumption
  d <- d[!(d$c_food == 0), ]

  if (nrow(d) == 0) stop("no observations in ", wave_year, " after sample restrictions")

  ####################################
  # 3. set up                        #
  ####################################

  out_dir  <- paste0(out_root, "wave_", wave_year, "/")
  save_dir <- paste0(out_dir, "eyeball_test/")
  corr_dir <- paste0(out_dir, "rank_correlations/")
  dir.create(save_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(corr_dir, recursive = TRUE, showWarnings = FALSE)

  tag        <- paste0("ENG_", wave_year)
  sample_lab <- paste0("England, interview year ", wave_year)

  ## normalise each variable by its weighted mean
  for (k in seq_len(nrow(base_spec))) {
    tv <- base_spec$base[k]; nv <- base_spec$norm_var[k]
    d[[nv]] <- d[[tv]] / weighted.mean(d[[tv]], w = d[[weight_var]], na.rm = TRUE)
  }

  zero_log <- data.frame(
    case_id = character(), variable = character(),
    n_ref = integer(), n_zero = integer(), n_negative = integer(), n_used = integer(),
    share_zero_wtd = numeric(), stringsAsFactors = FALSE
  )

  #####################################
  # 3a. EYEBALL TEST                  #
  #####################################

  for (k in seq_len(nrow(base_spec))) {

    cs <- base_spec[k, ]
    print(cs$case_id)

    var_all     <- d[[cs$norm_var]]
    weights_all <- d[[weight_var]]
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
      case_id = cs$case_id, variable = cs$base,
      n_ref = n_ref, n_zero = n_zero, n_negative = n_neg, n_used = length(var_ref),
      share_zero_wtd = share_zero_wtd, stringsAsFactors = FALSE))

    if (length(var_ref) < 30) {
      message("Skipping ", cs$case_id, ": fewer than 30 positive obs")
      next
    }

    zero_note <- sprintf(
      "%s. %s.\n%s zero obs dropped (%.1f%% weighted)%s; %s positive obs used.",
      sample_lab, weight_label,
      format(n_zero, big.mark = ","), 100 * share_zero_wtd,
      if (n_neg > 0) sprintf(", %s negative obs dropped", format(n_neg, big.mark = ",")) else "",
      format(length(var_ref), big.mark = ","))

    sub_lab <- paste0(weight_label, " | ", sample_lab)

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

    ggsave(paste0(save_dir, cs$short, "_LT_whole_", tag, ".pdf"),
           plot = p_whole_lt, width = 4, height = 3.3, dpi = 300)
    ggsave(paste0(save_dir, cs$short, "_LT_bot10_", tag, ".pdf"),
           plot = p_bottom_10, width = 4, height = 3.3, dpi = 300)
  }

  print(zero_log)
  write.csv(zero_log, paste0(out_dir, "zero_log_", tag, ".csv"), row.names = FALSE)

  #################################
  # 4. SAVE FOR STATA CODE        #
  #################################

  write_dta(d, paste0(out_dir, "stata_lcf_clean_", tag, ".dta"))

  #################################################
  # 5. LOWER-TAIL PARETO: OPTIMAL CUTOFF          #
  #################################################

  pareto_LT <- data.frame(
    wave = wave_year, case_id = base_spec$case_id, variable = base_spec$base,
    label = base_spec$label, zeta_MLE = NA_real_, quant_opt = NA_real_,
    xmax_opt = NA_real_, n_obs = NA_integer_, n_zero = NA_integer_,
    stringsAsFactors = FALSE
  )
  scans <- list()

  for (k in seq_len(nrow(base_spec))) {

    cs <- base_spec[k, ]
    v  <- d[[cs$norm_var]]
    wt <- d[[weight_var]]

    base_ok <- is.finite(v) & is.finite(wt) & wt > 0
    pareto_LT$n_zero[k] <- sum(base_ok & v <= 0)
    ok <- base_ok & v > 0
    v <- v[ok]; wt <- wt[ok]
    pareto_LT$n_obs[k] <- length(v)

    if (length(v) >= 30) {
      scan_res <- tryCatch(
        pareto_shape_thresholds_PSID_LT(var = v, weights = wt,
                                        minq = 0.03, maxq = 0.30, steps = 0.01,
                                        run_NLS = FALSE),
        error = function(e) {
          message("  ", cs$case_id, ": scan failed - ", conditionMessage(e))
          NULL
        })

      if (!is.null(scan_res)) {
        scans[[cs$case_id]] <- cbind(wave = wave_year, case_id = cs$case_id, scan_res)
        valid <- is.finite(scan_res$maxKS_MLE) & is.finite(scan_res$MLE_estimate)
        if (any(valid)) {
          best <- which.min(ifelse(valid, scan_res$maxKS_MLE, Inf))
          pareto_LT$zeta_MLE[k]  <- scan_res$MLE_estimate[best]
          pareto_LT$xmax_opt[k]  <- scan_res$quantthreshold[best]
          pareto_LT$quant_opt[k] <- scan_res$quantvalue[best]
        }
      }
    }
    cat(sprintf("%-45s zeta_MLE = %6.3f | cut-off quantile = %.2f\n",
                cs$label, pareto_LT$zeta_MLE[k], pareto_LT$quant_opt[k]))
  }

  ## full scan over candidate cut-offs (replaces the per-implicate file of the HFCS script)
  write.csv(do.call(rbind, scans), paste0(out_dir, "pareto_LT_scan_", tag, ".csv"), row.names = FALSE)
  write.csv(pareto_LT, paste0(out_dir, "pareto_LT_summary_", tag, ".csv"), row.names = FALSE)

  tab <- pareto_LT %>%
    arrange(zeta_MLE) %>%
    select(label, zeta_MLE, quant_opt, xmax_opt, n_obs) %>%
    rename(Variable = label,
           `Pareto coefficient` = zeta_MLE,
           `Cut-off (quantile)` = quant_opt,
           `Cut-off (value, x mean)` = xmax_opt,
           `Positive obs` = n_obs)

  tex_table <- kable(
    tab, format = "latex", booktabs = TRUE, digits = 3,
    align = c("l", "c", "c", "c", "c"),
    caption = paste0("Lower-tail Pareto coefficient estimates by consumption category, LCF ", sample_lab),
    label = paste0("pareto_summary_LT_", tag),
    linesep = "", escape = TRUE
  ) %>%
    kable_styling(latex_options = c("hold_position"))
  writeLines(as.character(tex_table), paste0(out_dir, "pareto_LT_summary_", tag, ".tex"))

  p_sum <- pareto_LT %>%
    mutate(label = factor(label, levels = base_spec$label)) %>%
    ggplot(aes(x = label, y = zeta_MLE)) +
    geom_point(size = 2.5, colour = "#C85C5C") +
    labs(x = NULL, y = "Lower-tail Pareto coefficient (MLE)",
         title = paste0("Lower-tail Pareto coefficients by consumption category, LCF ", sample_lab),
         subtitle = "Optimal cut-off chosen by min max-KS over quantiles 0.03-0.30") +
    th + theme(axis.text.x = element_text(angle = 45, hjust = 1))
  ggsave(paste0(out_dir, "pareto_LT_summary_", tag, ".pdf"), p_sum, width = 8, height = 5)

  #################################################
  # 6. RANK CORRELATIONS                          #
  #################################################

  corr_cases <- base_spec[base_spec$base != "cons_annual", ]
  pc <- pareto_LT$zeta_MLE[match(corr_cases$case_id, pareto_LT$case_id)]
  o  <- order(-pc)
  corr_cases <- corr_cases[o, ]; pc <- pc[o]

  corr_vars <- corr_cases$norm_var
  corr_labs <- paste0(corr_cases$label, " (", formatC(pc, format = "f", digits = 2), ")")

  rho <- spearman_matrix(d, corr_vars, d[[weight_var]], drop_zeros = TRUE)
  dimnames(rho) <- list(corr_labs, corr_labs)

  ac_avg <- avg_corr(rho)
  avg_corr_tab <- data.frame(wave = wave_year, good = names(ac_avg),
                             avg_corr = unname(ac_avg), stringsAsFactors = FALSE)
  cat("\n--- Average correlation with other goods ---\n")
  print(round(ac_avg, 2))

  write.csv(round(rho, 3), paste0(corr_dir, "rank_corr_", tag, ".csv"))
  write.csv(avg_corr_tab, paste0(corr_dir, "rank_corr_avg_by_good_", tag, ".csv"), row.names = FALSE)

  p_corr <- plot_corr_heat(
    rho, corr_labs,
    title    = paste0("Weighted Spearman rank correlations across goods (positive spending on both)\nLCF ",
                      sample_lab),
    subtitle = paste0(weight_label, " | ordered by lower-tail Pareto coefficient (in parentheses)"))
  ggsave(paste0(corr_dir, "rank_correlations_", tag, ".pdf"), p_corr, width = 9, height = 7.5)

  invisible(list(summary = pareto_LT, avg_corr = avg_corr_tab, zero_log = cbind(wave = wave_year, zero_log),
                 rho = rho))
}

## ---- correlation helpers (unchanged from the HFCS script) ----------------------
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


#################################################
# 7. RUN ALL WAVES                              #
#################################################

wave_results <- list()
for (wy in waves_to_run) {
  res <- tryCatch(run_wave(wy, LCF),
                  error = function(e) {
                    message("YEAR ", wy, " FAILED: ", conditionMessage(e))
                    NULL
                  })
  if (!is.null(res)) wave_results[[as.character(wy)]] <- res
}

cat("\nYears completed:", paste(names(wave_results), collapse = ", "), "\n")
failed <- setdiff(as.character(waves_to_run), names(wave_results))
if (length(failed)) cat("Years FAILED:", paste(failed, collapse = ", "), "\n")

#################################################
# 8. ACROSS YEARS: stacked tables and median    #
#################################################

yrs_lab <- paste0(min(as.integer(names(wave_results))), "_", max(as.integer(names(wave_results))))

all_summary <- do.call(rbind, lapply(wave_results, `[[`, "summary"))
write.csv(all_summary, paste0(out_root, "pareto_LT_by_year_ENG_", yrs_lab, ".csv"), row.names = FALSE)
write.csv(do.call(rbind, lapply(wave_results, `[[`, "avg_corr")),
          paste0(out_root, "rank_corr_avg_by_good_by_year_ENG_", yrs_lab, ".csv"), row.names = FALSE)
write.csv(do.call(rbind, lapply(wave_results, `[[`, "zero_log")),
          paste0(out_root, "zero_log_by_year_ENG_", yrs_lab, ".csv"), row.names = FALSE)

## median across years (the HFCS script's "median across sample years")
median_tab <- all_summary %>%
  group_by(case_id, label) %>%
  summarise(median_zeta_MLE   = median(zeta_MLE,  na.rm = TRUE),
            median_quant_opt  = median(quant_opt, na.rm = TRUE),
            median_xmax_opt   = median(xmax_opt,  na.rm = TRUE),
            n_years_estimated = sum(!is.na(zeta_MLE)),
            .groups = "drop") %>%
  arrange(median_zeta_MLE) %>%
  as.data.frame()
print(median_tab)
write.csv(median_tab, paste0(out_root, "pareto_LT_median_ENG_", yrs_lab, ".csv"), row.names = FALSE)

tex_median <- kable(
  median_tab %>% select(label, median_zeta_MLE, median_quant_opt, median_xmax_opt, n_years_estimated) %>%
    rename(Variable = label, `Pareto coefficient` = median_zeta_MLE,
           `Median cut-off (quantile)` = median_quant_opt,
           `Median cut-off (value, x mean)` = median_xmax_opt, Years = n_years_estimated),
  format = "latex", booktabs = TRUE, digits = 3, align = c("l", "c", "c", "c", "c"),
  caption = paste0("Lower-tail Pareto coefficients, median across interview years ",
                   gsub("_", "-", yrs_lab), ", LCF England"),
  label = paste0("pareto_LT_median_ENG_", yrs_lab), linesep = "", escape = TRUE) %>%
  kable_styling(latex_options = c("hold_position"))
writeLines(as.character(tex_median), paste0(out_root, "pareto_LT_median_ENG_", yrs_lab, ".tex"))

## coefficient by year, one panel per category
p_years <- all_summary %>%
  mutate(label = factor(label, levels = base_spec$label)) %>%
  ggplot(aes(x = wave, y = zeta_MLE)) +
  geom_line(colour = "grey60") + geom_point(colour = "#C85C5C", size = 1.8) +
  facet_wrap(~ label, scales = "free_y", ncol = 4) +
  labs(x = "Interview year", y = "Lower-tail Pareto coefficient (MLE)",
       title = "Lower-tail Pareto coefficients by year, LCF England",
       subtitle = "Optimal cut-off chosen by min max-KS over quantiles 0.03-0.30") +
  th + theme(strip.text = element_text(size = 7))
ggsave(paste0(out_root, "pareto_LT_by_year_ENG_", yrs_lab, ".pdf"), p_years, width = 11, height = 8)
