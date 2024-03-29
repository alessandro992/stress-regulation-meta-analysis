# Libraries and stuff -----------------------------------------------------

knitr::opts_chunk$set(echo=FALSE, warning = FALSE)
rm(list = ls())

# Assumed default pre-post correlation for within-subjects design, .50.
# Here you can perform the sensitivity analysis to determine the impact of the assumed correlation on the overall effect size estimate.
# E.g., for corr = c(.10, .30, .50, .70, 90).
corr <- 0.5

# No of simulations for the permutation p-curve and 4PSM model
nsim <- 5 # Set to 5 just to make code checking/running fast. For the final paper, it needs to be set to at least 1000 and run overnight.


# Install required R libraries if not installed already
list.of.packages <- c("metafor", "lme4", "ggplot2", "knitr", "psych", "puniform", "kableExtra", "lmerTest", "pwr", "Amelia", "multcomp", "magrittr")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

# Load required libraries
#+ include = FALSE
lapply(list.of.packages, require, quietly = TRUE, warn.conflicts = FALSE, character.only = TRUE)

#' Statistical analysis was carried out in R, version 3.4.3, using packages "metafor", "lme4", "ggplot2", "knitr", "psych", "puniform", "reshape2", "kableExtra", "lmerTest", "pwr", "Amelia".
#'

# Sourcing and data -----------------------------------------------------------------
esData <- readRDS("esData.RDS") # For script testing purposes only, adding some empirical effect size data
source("functions.R")
source("SimulateData.R")
dat <- cbind(data, esData)

# GRIM & GRIMMER Test -----------------------------------------------------

outGrimM1 <- NA
outGrimM2 <- NA
outGrimmerSD1 <- NA
outGrimmerSD2 <- NA
for(i in 1:nrow(dat)){
  outGrimM1[i] <- grimTest(n = dat[i,]$n1, mean = dat[i,]$mean1, items = dat[i,]$items, decimals = 2)
  outGrimM2[i] <- grimTest(n = dat[i,]$n2, mean = dat[i,]$mean2, items = dat[i,]$items, decimals = 2)
  outGrimmerSD1[i] <- grimmerTest(n = dat[i,]$n1, mean = dat[i,]$mean1, SD = dat[i,]$sd1, items = dat[i,]$items, decimals_mean = 2, decimals_SD = 2)
  outGrimmerSD2[i] <- grimmerTest(n = dat[i,]$n2, mean = dat[i,]$mean2, SD = dat[i,]$sd2, items = dat[i,]$items, decimals_mean = 2, decimals_SD = 2)
  
}
dat$outGrimM1 <- outGrimM1
dat$outGrimM2 <- outGrimM2
dat$outGrimmerSD1 <- outGrimmerSD1
dat$outGrimmerSD2 <- outGrimmerSD2
dat$inconsistenciesCount <- rowSums(dat[,c("outGrimM1", "outGrimM2")], na.rm = TRUE)

# Meta-analysis -----------------------------------------------------------

# Subset
dataMind <- dat[dat$strategy == 1 & !is.na(dat$yi),]
dataBio <- dat[dat$strategy == 2 & !is.na(dat$yi),]

#'## Meta-analysis
#'
#'k = number of studies; sqrt in "Variance components" = tau, the standard deviation of true effects; estimate in "Model results" = naive MA estimate
namesObjects <- c("Self-administered mindfulness", "Biofeedback")
levels(dat$strategy) <- namesObjects
dataObjects <- list("Mind" = dataMind, "Bio" = dataBio)

rmaObjects <- setNames(lapply(dataObjects, function(x){rmaCustom(x)}), nm = namesObjects)

# Further results
briefBias <- TRUE # For a more elaborate output from the pub bias tests, set to FALSE
results <- list(NA)
for(i in 1:length(rmaObjects)){
  results[[i]] <- maResults(data = dataObjects[[i]], rmaObject = rmaObjects[[i]], alpha = .05, briefBias = T)
}

results <- setNames(results, nm = namesObjects)
results

# Published vs unpublished studies ----------------------------------------

publishedRMA <- rmaCustom(dat[!is.na(dat$yi) & dat$published == 1,])
unpublishedRMA <- rmaCustom(dat[!is.na(dat$yi) & dat$published == 0,])
pubResults <- maResults(rmaObject = publishedRMA, data = dat[!is.na(dat$yi) & dat$published == 1,], briefBias = T)
unpubResults <- maResults(rmaObject = unpublishedRMA, data = dat[!is.na(dat$yi) & dat$published == 0,], briefBias = T)
pubResults
unpubResults

# Sensitivity analysis excluding effects from non-randomized designs -------
rmaRnd <- setNames(lapply(dataObjects, function(x){rmaCustom(x[x$researchDesign == 1,])}), nm = namesObjects)
rndResults <- list(NA)
for(i in 1:length(rmaRnd)){
  rndResults[[i]] <- maResults(rmaObject = rmaRnd[[i]], data = dataObjects[[i]][dataObjects[[i]]$researchDesign == 1,], briefBias = T)
}
rndResults <- setNames(rndResults, nm = namesObjects)
rndResults

# Sensitivity analysis excluding effects based on inconsistent means or SDs -------

rmaRnd <- setNames(lapply(dataObjects, function(x){rmaCustom(x[x$inconsistenciesCount == 0,])}), nm = namesObjects)
rndResults <- list(NA)
for(i in 1:length(rmaRnd)){
  rndResults[[i]] <- maResults(rmaObject = rmaRnd[[i]], data = dataObjects[[i]][dataObjects[[i]]$inconsistenciesCount == 0,], briefBias = T)
}
rndResults <- setNames(rndResults, nm = namesObjects)
rndResults

# Sensitivity analysis excluding effects based on a high risk of bias -------------

# Probably need to edit to comply with that is given in the ms: "Following RoB 2 recommendations a study was categorized overall as a high risk of bias if one of two conditions are met: 
# A) The study scores a  high risk of bias in at least one domain or B) the study is evaluated as having some concerns for more than one domain. 
# A study was judged as having “some concern” whether it raised some concerns in at least one domain. 
# Finally a study was assessed as having a low risk of bias if it was judged as having a low risk of bias in all of the five domains. 

excludeRisk <- 3 # Exclude studies having a risk of bias of at least x
rmaRoB <- setNames(lapply(dataObjects, function(x){rmaCustom(x[x$overallRiskOfBias < excludeRisk,])}), nm = namesObjects)
RoBResults <- list(NA)
for(i in 1:length(rmaRnd)){
  RoBResults[[i]] <- maResults(rmaObject = rmaRnd[[i]], data = dataObjects[[i]][dataObjects[[i]]$overallRiskOfBias < excludeRisk,], briefBias = T)
}
RoBResults <- setNames(RoBResults, nm = namesObjects)
RoBResults

# Moderator analysis for strategies ---------------------------------------
# The other moderator analyses will follow the same analytic pipeline

# Comparison of categories after controlling for prognostic factors w.r.t. the effect sizes
rmaCompare <- robust.rma.mv(rma.mv(yi = yi, V = vi, mods = ~factor(strategy), data = dat[!is.na(dat$yi),], method = "REML", random = ~ 1|study/result), cluster = dat[!is.na(dat$yi),]$study)
rmaCompare

# Defining the null model for moderator analyses
rmaNull <- robust.rma.mv(rma.mv(yi = yi, V = vi, mods = researchDesign + typePopulation + typeComparisonGroup + published + overallRiskOfBias - 1, struct="DIAG", data = dat[!is.na(dat$yi),], method = "ML", random = ~ factor(strategy) | result), cluster = dat[!is.na(dat$yi),]$study)

# Strategies
# Comparison of categories of strategies after controlling for prognostic factors w.r.t. the effect sizes
# What moderator/meta-regression analyses shall we conduct is a substantial question to discuss.
rmaCat <- robust.rma.mv(rma.mv(yi = yi, V = vi, mods = ~factor(strategy) + researchDesign + typePopulation + typeComparisonGroup + published + overallRiskOfBias - 1,struct="DIAG", data = dat[!is.na(dat$yi),], method = "ML", random = ~ factor(strategy) | result), cluster = dat[!is.na(dat$yi),]$study)
rmaCat

# Likelihood ratio test for the differences between categories
# Omnibus test
anova(rmaNull, rmaCat)

# Contrasts 
# p-values adjusted using Holm's method
summary(glht(rmaCat, linfct=cbind(contrMat(c("Self-administered mindfulness" = 1, "Biofeedback" = 1), type="Tukey"), 0, 0, 0, 0, 0)), test=adjusted("holm"))

# Components
# Comparison of components after controlling for prognostic factors w.r.t. the effect sizes
rmaComp <- robust.rma.mv(rma.mv(yi = yi, V = vi, mods = ~factor(typeStressComponent) + researchDesign + typePopulation + typeComparisonGroup + published + overallRiskOfBias - 1, struct="DIAG", data = dat[!is.na(dat$yi),], method = "ML", random = ~ factor(strategy) | result), cluster = dat[!is.na(dat$yi),]$study)
rmaComp

# Likelihood ratio test for the differences between categories
# Omnibus test
anova(rmaNull, rmaComp)

# Contrasts 
# p-values adjusted using Holm's method
summary(glht(rmaComp, linfct=cbind(contrMat(c("AFloAneV" = 1, "AFhiAneV" = 1, "AFloApoV" = 1, "AFhiApoV" = 1, "cognitiveComp" = 1, "physiologicalComp" = 1), type="Tukey"), 0, 0, 0, 0, 0)), test=adjusted("holm"))
