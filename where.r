#!/usr/bin/Rscript
library(rEDM)
library(zoo)
source( "helpers/helper.r" )
source( "helpers/plotting.r" )

results <- function( method, variable )
{
    load( paste0("model/runs/", method, "_parameters.Rdata" ) )
    
    ## Get the true values we were trying to predict
    df <- read.csv(filename,
                   header = TRUE,
                   sep = "," )
    df <- lag_every_variable(df, n_lags)
    truth <- df[pred[1]:pred[2], paste0( variable, "_p1" ) ]
    
    predictions <- read.table(paste0("model/runs/", method, "_predictions_", variable, ".csv"),
                              na = "NA",
                              sep =",") 
    
    ## Calculate mean prediction skill per library size
    rhos <- mean_cor( predictions, truth, nrow = n_samp)
    return( list( rhos = rhos, lib_sizes = lib_sizes ) )
}

args <- commandArgs( trailingOnly = TRUE )
if( length(args) > 0 ) {
    
    print("Erase everything and re-download? Press Enter to skip, yes to download." )
    answer <- readLines( "stdin", n=1 )
    
    if( answer == "yes" ) {
        print( "OK. Please insert password.")
        system("rm -f ~/edm/weight-pred/model/runs/*")
        system( "scp -r daon@access.cims.nyu.edu:~/weight-pred/model/runs/ ~/edm/weight-pred/model/" )
    }
}

variable <- "y"
uniform <- results( "uniform",  variable )
exponential <- results( "exp",  variable )
## uniform <- results( uniform,  variable )

x11()
plot(uniform$lib_sizes,
     uniform$rhos,
     xlab = "Library size",
     ylab = "Prediction skill",
     col = "black",
     type = "l",
     ylim = c(0.5,1),
     xlim = c(10,120)
     )
lines(exponential$lib_sizes,
      exponential$rhos, 
      col = "red" )
 

title(paste0("Predicting ", variable) )
legend( x = "topleft",
       legend = c( "uniform", "exp" ), ##, "minvar" ),
       col = c( "black", "red" ), ##, "blue" ),
       lwd = 1)
hold(1)

## libs <- read.table("runs/libraries_x.txt",
##                    header = FALSE,
##                    sep = "\t" )
