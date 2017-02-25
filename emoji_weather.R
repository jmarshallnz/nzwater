#' Emoji plot for weather example
#' 

library(png)

ima <- readPNG("emoji_weather.png")

#Set up the plot area
png("emoji_weather_plot.png", width=800, height=110)
par(mar = c(4,1,0,1))
plot(NULL, xlim=c(0,100), ylim=c(0,1), yaxt='n', xaxs='i', type='n', main="", xlab="Percent of the time", ylab="", bty='n')

lim <- par()
rasterImage(ima, lim$usr[1], lim$usr[3], lim$usr[2], lim$usr[4])
dev.off()

