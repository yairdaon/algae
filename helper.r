library( zoo )
source( "plotting.r" )

##########################################################################
## Functions I don't feel OK with and may need revision. Empty, hopefully
##########################################################################

look_ahead_chl <- function( tp )
{
    df <- read.csv( "data/processed_daily_data.csv", header = TRUE )
    chl_df <- data.frame( serial_day = df$serial_day )

    if( tp %% 2 == 0 )
        ts <- df$chl_week
    else
        ts <- df$chl_half
    
    chl_df[paste0("chl_p", tp )] <- half_week_steps( ts, tp )
    
    return( chl_df )
}



##########################################################################
## Functions I feel pretty OK with and don't need revision.
##########################################################################

## Returns a data frame with lags of chlorophyll. Lagged E-1 times.
## Suppose today is Saturday and a measurement was taken. Assuming 3-4
## delay to the next measurement, we know the next measurement will
## take place on either tuesday or wednesday. Consequently, previous
## measurement was also taken on either tuesday or
## wednesday. Substitute e==1, means half_week_steps looks -3 time
## days back. That is a wednesday. Luckily, in the wednesday spot of
## half_chl time series, there is the average of tuesday and
## wednesday! This isn't REALLY an average, though, since we know for
## sure that one of the values (either wednesday or tuesday) is a
## NA. Thus a half week step back gives the value of measurement that
## was (hopefully) taken half a week ago.
multi_lag_chl <- function( E ) 
{
    df <- read.csv( "data/processed_daily_data.csv", header = TRUE )
    lagged_chl <- data.frame( serial_day = df$serial_day )
    lagged_chl["chl_0"] <- df$chl

    half_chl <- df$chl_week
    week_chl <- df$chl_half
    
    ## Predictor at time t-E. Note we take -e (negative!) so we have
    ## the interpretation of a lag of e half weeks, see doc for
    ## methods half_week_steps and lag_days.
    for( e in E )
    {
        ## In case of an integer number of weeks' lag
        if( e %% 2 == 0 )
            lagged_chl[paste0("chl_", e )] <- half_week_steps( week_chl, -e )

        ## In case of an integer + 1/2 number of weeks' lag, see doc
        ## above.
        else
            lagged_chl[paste0("chl_", e )] <- half_week_steps( half_chl, -e )
            
    }
    
    return( lagged_chl )
}

## Returns a time series aligned with the original data frame that has
## a value 6,7 or 8 days ahead (if tp == 2, whichever exists and
## averaged in the unlikely case 6 and 8 exist) or "3.5" days ahead (if
## tp == 1, using either 3 or 4 days ahead, whichever exists).
chl_week_modifier <- function( chl )
    return(
        rollapply(chl,
                  width = 3,
                  align = 'center',
                  FUN = mean,
                  fill = NA,
                  na.rm = TRUE )   
    )

chl_half_modifier <- function( chl )
    return(
        rollapply(chl,
                  width = 2,
                  align = 'right',
                  FUN = mean,
                  fill = NA,
                  na.rm = TRUE )   
    )


## Returns a data frame with lags of time series ts, named var_0,
## var_1 etc. lagged E-1 times.
multi_lag_var <- function( var, E )
{
    df <- read.csv( "data/processed_daily_data.csv", header = TRUE )
    lagged <- data.frame( serial_day = df$serial_day )
    lagged[paste0(var, "_0")] <- df[ ,var ] 
    

    ## Predictor at time t-E. Note we take -e (negative!) so we have
    ## the interpretation of a lag of e half weeks, see doc for
    ## methods half_week_steps and lag_days.
    for( e in 1:E )        
        lagged[paste0(var, "_", e )] <- half_week_steps( ts, -e )
    
    return( lagged )
}

## If tp is even, takes tp/2 week steps. If tp==1 takes a 4 day step
## into the future, if tp==3 takes 11 steps etc. If tp==-1 takes -3
## steps and if tp==-3 it takes -10 steps etc.
##
## half_week_steps(ts, 1)[t] == shift(ts, 4)[t] == ts[t+4],
## half_week_steps(ts, 2)[t] == shift(ts, 7)[t] == ts[t+7],
## half_week_steps(ts,-1)[t] == shift(ts,-3)[t] == ts[t-3],
## half_week_steps(ts,-2)[t] == shift(ts,-7)[t] == ts[t-7],
## etc., wherever the values are defined.
half_week_steps <- function(ts, tp)
    return( shift(ts, ceiling( tp * 3.5 ) ) )

## Averages ts1 (and ts2, if supplied) over the past week
past_week <- function( ts1, ts2 = NA )
{
    mean_1 <- rollapply(ts1,
                        width = 7,
                        align = 'right',
                        FUN = mean,
                        fill = NA,
                        na.rm = TRUE )
 
    if( is.vector( ts2 ) && length(ts1) == length(ts2) ) {
        mean_2 <- rollapply(ts2,
                            width = 7,
                            align = 'right',
                            FUN = mean,
                            fill = NA,
                            na.rm = TRUE )
        return( ( mean_1 + mean_2 ) / 2 )
    }
    
    return( mean_1 )
}

transform <- function( ts, func = "" )
{
    minimum <- min(ts, na.rm = TRUE)
    
    ## If minimum is zero or less ...
    if (  minimum <= 0 && (func == "log" || func == "sqrt") ) {

        ## ... make sure the minimum is zero...
        ts <- ts - minimum
        
        ## ... and make sure the minimum is actually half the second
        ## smallest value (which is guaranteed positive).
        ts[ ts == 0 ]  <- min( ts[ts != 0], na.rm = TRUE )/2
           
    }

    
    ## Transform data according to a given function.
    if( func == "log" )
        ts <- log( ts )
    else if ( func == "sqrt" )
        ts <- sqrt(ts)
    

    ## Mad is media absolte deviation, scaled so that it is a
    ## consistent estimator of the standard deviation
    ts <- ( ts - median(ts, na.rm = TRUE) ) / mad ( ts, na.rm = TRUE )

    ## If you really really want to use mean and std-dev...
    ## ts <- ( ts - mean(ts, na.rm = TRUE) ) / sd( ts, na.rm = TRUE )
    
    return( ts )
}


## For t==1, takes (x_1, x_2, x_3, x_4) to (x_2, x_3, x_4, NA) and for
## t==-1, takes it to (NA, x_1, x_2, x_3). The meaning is that, e.g.
##
## shift(ts, l)[t] == ts[t+l]. 
##
## Thus, l > 0 looks into the future, just like the shift operator known in
## (e.g.) symbolyc dynamics. 
shift <- function( ts, l = 1 )
{
    ## Filler (NA,NA,NA,...) with length |l|. Defined here for
    ## readability.
    fill <- rep(NA, abs(l))
    
    if ( l > 0 ) 
        return( c( ts[(1+l):length(ts)], fill ) ) 
    else if ( l < 0 )
        return( c( fill, ts[1:(length(ts)+l)] ) )
    return( ts )
}

## Take data frame and return only the rows that correspond to the
## serial_days in Hao's dataset.
restrict <- function(df, file_name="data/hao_days.txt" )
{
    restriction   <- scan(file_name) 
    restricted_df <- subset(df, serial_day %in% restriction )
    return( restricted_df )
}
