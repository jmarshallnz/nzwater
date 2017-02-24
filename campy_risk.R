#' Script for attempting to reproduce NIWA work on *Campylobacter* infection risk from
#' freshwater swimming, as presented in table A3.7.3 (first column on the right labeled A)
#' from the November 2002 report "Pathogen Occurrence and Human Health Risk Assessment Analysis"
#' by McBride et. al, available here:
#' 
#' http://www.mfe.govt.nz/sites/default/files/freshwater-microbiology-nov02.pdf
#' 
#' This is the table that is then aligned against the percentile distribution of
#' E. coli to derive cut-offs and infer numbers of people that would be sick as
#' a result.
#'
#' It uses a Monte-Carlo approach of first sampling the duration of swim and likely
#' ingestion of water to attain volume of freshwater ingested, then combines this
#' from data on the concentration of *Campylobacter jejuni* in water from a study
#' in late 90's or so to get number of *Campylobacter jejuni* the person has
#' ingested. This is then fed into the dose-response curve to assess their
#' probability of infection, and we then sample whether people become infected
#' from a bernoulli.
#' 
#' Distributions are PERT's for duration of swim and volume of water ingested,
#' A geometric and uniform combination for *Campylobacter jejuni* concentration,
#' A dose-response model (deterministic) and the Bernoulli.
#' 
source('rpert.R')

#' PERT parameters for duration of swim (hours) and volume (ml) ingested per hour
duration <- list(min = 0.25, max=2, mode=0.5)
volume <- list(min = 10, max=100, mode=50)
#' Geometric to determine bins for *Campylobacter jejuni* counts
which_bin <- 0.42531
#' Bins for *Campylobacter jejuni* counts
breaks <- c(0,0.3,1.2,4.2,28.8,110,2000)
bins <- data.frame(bin=0:5, min=breaks[-length(breaks)], max=breaks[-1])
#' Dose-response for *Campylobacter jejuni*
dose_response <- function(dose, alpha=0.145, N50=896) {
  1 - (1 + dose/N50 * (2^(1/alpha)-1))^(-alpha)
}

#' Do the sampling for n people swimming at the same river
sample <- function(n) {
  #' ingested volume per-person
  dur <- rpert(n=n, x.min = duration$min, x.max = duration$max, x.mode = duration$mode)
  rate <- rpert(n=n, x.min = volume$min, x.max = volume$max, x.mode = volume$mode)
  vol <- dur * rate
  #' a **single** sample of the river/beach water Campylobacter jejuni counts
  bin    <- match(pmin(rgeom(n = 1, prob = which_bin), max(bins$bin)), bins$bin)
  counts <- runif(n = 1, min = bins$min[bin], max = bins$max[bin])
  #' bugs ingested
  bugs <- vol * counts / 100
  #' dose-response
  inf <- dose_response(bugs)
  #' whether they're actually infected
  rbinom(n, 1, inf)
}

#' Sample lots of times to see how often people get sick, if 1000 people go to
#' a river or beach
reps <- 10000
lots <- replicate(reps, sum(sample(1000)))

#' compute percentiles
knitr::kable(round(quantile(lots, seq(0, 1, by=0.025))))

#' Note if instead we want what would happen to `n` people visiting different sites,
#' you'd change the `n=1` in the `bin` and `count` lines above to `n` instead. This
#' basically drops down to the distribution of the mean of the above though.

#' To get E.coli from this, what was done is that the *E. coli* percentile distribution
#' as sampled in NZ waters was laid side-by-side with this, under the assumption that
#' *E. coli* levels correlate reasonably well with *Campylobacter jejuni* levels at
#' higher concentrations, and presumably it is at higher correlations where the higher
#' risks occur. Then, acceptable risks were defined (e.g. 0.1%, 1%, 5%), and using the
#' above the corresponding percentiles were found. The *E. coli* levels corresponding
#' to those percentiles was then what was used as the limits.
#' 
#' How you work backwards from *E. coli* levels to risk is a bit of an unknown...
#' 
#' Presumably, if you're 95% less than 540 cfu/100ml, then you're less than what was the
#' 80-th percentile 95% of the time, so would expect fewer than the 80th percentile of
#' cases (24) 95% of the time. This doesn't mean risk would be less than 2.4% though,
#' but it does mean for 95% of the time your risk would be at most 2.4%. We don't know
#' about the last 5% and that is where risk is known to be more than 2.4%, and perhaps
#' much more given the skewness of the distribution.