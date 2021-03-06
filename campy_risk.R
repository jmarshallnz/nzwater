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

#' a plot trying to describe the distribution of risk
#png('risk_by_percentile.png', width=800, height=600)
h <- hist(lots/1000*100, breaks=c(0,0.1,0.2,0.5,1,2,5,10,20,50,100), plot=FALSE)
labs <- paste0(h$breaks[-length(h$breaks)],'-',h$breaks[-1])
barplot(h$counts/reps*100, ylab="Percent of the time", xlab="Risk (percentage of people infected)", names=labs, col='steelblue')
title(main="Percentage of the time NZ rivers/lakes\npresent risk of infection with Campylobacter")
#dev.off()

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

#' An attempt for matching E. coli distributions follows. Using E. coli
#' distributions from
#' 
#' http://www.mfe.govt.nz/sites/default/files/freshwater-microbiology-nov02.pdf
#'
#' Tables A3.7.3 and A3.3.2

ecoli <- data.frame(percentile=seq(5,95,by=5),
                    count=c(4,9,14,32,29,40,51,66,91,110,131,
                            154,191,261,332,461,613,980,1986))

ecoli$risk <- quantile(lots, seq(0.05, 0.95, by=0.05))
# alternate risk from McBride, as above isn't quite right...
ecoli$risk <- c(rep(0,11),1,3,9,18,26,72,131,329)

#' Criteria for blue, green, yellow from:
#' http://www.mfe.govt.nz/fresh-water/freshwater-management-reforms/water-quality-swimming-maps/developing-water-quality
cat = list('#36949B' = data.frame(percentile=c(50, 80, 95), count=c(130, 260, 540)),
           '#7EA948' = data.frame(percentile=c(50,70,90,95), count=c(130,260,540,1000)),
           '#FACB1E' = data.frame(percentile=c(50,66,80,95), count=c(130,260,540,1200)))

compute_risk <- function(count, percentile) {
  #' Compute corresponding risk
  risk = approx(ecoli$count, ecoli$risk, xout = count)$y
  perc = pmax(round(risk / 1000 * 100, 1), 0.1)

  labs = c(paste0("<",perc[1]), paste0(perc[-length(perc)],'-',perc[-1]), paste0(">",perc[length(perc)]))
  
  integrated_risk = c(perc[1]/2,(perc[-length(perc)]+perc[-1])/2,perc[length(perc)])
  return(list(risk=labs, percent=diff(c(0,percentile,100)), irisk=integrated_risk))
}

#png("risk_by_colour.png", width=600, height=600)
par(mfrow=c(3,1), mar=c(5,4,2,2), oma=c(0,0,2,0), cex=1)
#title(main="Percentage of the time NZ rivers/lakes\npresent risk of infection with Campylobacter")
for(i in seq_along(cat)) {
  risk <- compute_risk(cat[[i]]$count, cat[[i]]$percentile)
  avg_risk <- sum(risk$percent * risk$irisk/100)
  if (i == 1) {
    risk$percent = c(risk$percent, NA)
    risk$risk = c(risk$risk, NA)
  }
  barplot(risk$percent, names=risk$risk,
          xlab='Risk (% people infected)',
          ylab='% of time',
          col=names(cat)[i], las=1)
  legend('topright',
         legend=paste0('Risk across all time: ',round(avg_risk,1),'%'),
         bty="n")
  if (i == 1)
    title(main="Percentage of the time NZ rivers/lakes\npresent risk of infection with Campylobacter", outer=TRUE)
}
#dev.off()

#' Alternate stacked bar chart that's more rounded
d <- data.frame(level=c('Excellent', 'Good', 'Fair'),
                colour=c('#36949B', '#7EA948', '#FACB1E'),
                `< 0.1`=c(50,50,50),
                `0.1 - 1`=c(30,20,16),
                `1 - 5`=c(15,20,14),
                `5 - 15`=c(5,6,12),
                `> 15`=c(0,4,8), check.names=FALSE, stringsAsFactors=FALSE)

#' reorder for barplot
d <- d[3:1,]

#' density of lines for risk
dens = c(0,5,15,30,80)

#' draw the plot
#png('stacked_risk_by_colour.png', width=800, height=450)
b <- barplot(t(d[,-(1:2)]), horiz=TRUE, names=d$level, las=1, col='black', density=dens, plot=FALSE)
alpha <- function(col, alpha=0.5) { rgb(t(col2rgb(col)/255), alpha=alpha) }
source('legendxx.R')
par(mfrow=c(1,1), mar=c(4,6,4,2), cex=1.5)
plot(NULL, axes=FALSE, xlim=c(0,130), xaxs='i', xaxt='n', ylim=c(0,max(b)+min(b)), yaxs='i', yaxt='n', xlab="", ylab="")
rect(xl=c(0,0,0),yb=b-0.5,xr=rep(100,3),yt=b+0.5, col=alpha(d$colour, 0.7), border=NA)
barplot(t(d[,-(1:2)]), horiz=TRUE, names=d$level, las=1, col='black', density=dens, add=TRUE, xaxt='n')
axis(1, at=seq(0,100,by=20))
legend(105,3.38,legend=names(d[,-(1:2)]), density=dens, bty='n', box.cex = c(2,1.8), y.intersp = 2)
text(110,3.40, "Risk (%)", cex=1.2, adj=c(0,0))
mtext('Percentage of time', side=1, line=3, at=50, cex=1.5)
mtext('Percentage of the time NZ rivers/lakes', cex=1.8, line=2.1, font=2)
mtext(expression(paste(bold('present risk of infection with '), bolditalic(Campylobacter))), cex=1.8, line=0.6, font=2)
#dev.off()

#' estimate of total risk contribution of each class.
#' this uses the midpoint of each category, where we have it, i.e.
#' it assumes linearly increasing risk, which is not right, but
#' probably close-enough for a first guess. For the last category
#' where we don't have an upper bound on risk, we assume it's the
#' maximal risk of 25, slightly more conservative than the results
#' from McBride et. al.
risk_cat <- c(0,0.1,1,5,15,25)
avg_risk <- (risk_cat[-1] + risk_cat[-length(risk_cat)])/2

# I think we're after river percentile vs risk percentile
prop_risk <- rbind(rep(0,3),apply(d[,3:7],1,function(x) {z = x * avg_risk; z/sum(z)*100 }))
risk_perc <- rbind(rep(0,3), apply(d[,3:7], 1, cumsum))

#png('risk_percentiles.png', width=800, height=600)
par(cex=1.5)
plot(prop_risk ~ risk_perc, type='n', xaxs='i', yaxs='i', xlab="Percentage of time", ylab="Percentage of infections")
for (i in 1:3)
  lines(risk_perc[,i], prop_risk[,i], col=d$colour[i], lwd=2)
title("Most infections occur in the 20% of time that\nrivers are most contaminated")
#dev.off()

# and for the old 'A' and 'B' regulations

old <- data.frame(level=c('A', 'B'),
                colour=c('white', 'white'),
#                `< 0.1`=c(0,0),
                `< 1`=c(95,0),
                `1 - 5`=c(5,95),
                `> 5`=c(0,5), check.names=FALSE, stringsAsFactors=FALSE)


#' reorder for barplot
d <- old[2:1,]

#' density of lines for risk
dens = c(5,15,30)

#' draw the plot
png('old_risk_by_colour.png', width=800, height=350)
b <- barplot(t(d[,-(1:2)]), horiz=TRUE, names=d$level, las=1, col='black', density=dens, plot=FALSE)
alpha <- function(col, alpha=0.5) { rgb(t(col2rgb(col)/255), alpha=alpha) }
source('legendxx.R')
par(mfrow=c(1,1), mar=c(4,6,4,2), cex=1.5)
plot(NULL, axes=FALSE, xlim=c(0,130), xaxs='i', xaxt='n', ylim=c(0,max(b)+min(b)), yaxs='i', yaxt='n', xlab="", ylab="")
rect(xl=c(0,0,0),yb=b-0.5,xr=rep(100,3),yt=b+0.5, col=alpha(d$colour, 0.7), border=NA)
barplot(t(d[,-(1:2)]), horiz=TRUE, names=d$level, las=1, col='black', density=dens, add=TRUE, xaxt='n')
axis(1, at=seq(0,100,by=20))
legend(105,2.25,legend=names(d[,-(1:2)]), density=dens, bty='n', box.cex = c(2,1.8), y.intersp = 2)
text(110,2.28, "Risk (%)", cex=1.2, adj=c(0,0))
mtext('Percentage of time', side=1, line=3, at=50, cex=1.5)
mtext('Percentage of the time NZ rivers/lakes', cex=1.8, line=2.1, font=2)
mtext(expression(paste(bold('present risk of infection with '), bolditalic(Campylobacter))), cex=1.8, line=0.6, font=2)
dev.off()
