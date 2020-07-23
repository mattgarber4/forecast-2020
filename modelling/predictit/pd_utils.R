library(myUtils)
library(DBI)
library(RPostgres)
library(dplyr)

smoothParty <- function(party, num_days, date_col) {
    sapply(as.Date(date_col), 
           function(d) mean(party[as.Date(date_col) <= d & as.Date(date_col) >= d - num_days + 1])) 
}

# get one day, four day, and seven day changes
selectAtDate <- function(dta, date) {
    dta[dta$date == date, c("state", "dem_smooth", "rep_smooth")]
}

deltas <- function(dta, date) {
    a <- merge(selectAtDate(dta, date), 
               selectAtDate(dta, as.Date(date) - 1), 
               by = 'state',
               suffixes = c('0', '1'))
    b  <- merge(selectAtDate(dta, as.Date(date) - 4),
                selectAtDate(dta, as.Date(date) - 7),
                by = 'state', 
                suffixes = c('4', '7'))
    
    out <- merge(a, b, by = 'state')
    
    out$date <- date
    out$dem_delta1 <- out$dem_smooth0 - out$dem_smooth1
    out$dem_delta4 <- out$dem_smooth0 - out$dem_smooth4
    out$dem_delta7 <- out$dem_smooth0 - out$dem_smooth7
    
    out$rep_delta1 <- out$rep_smooth0 - out$rep_smooth1
    out$rep_delta4 <- out$rep_smooth0 - out$rep_smooth4
    out$rep_delta7 <- out$rep_smooth0 - out$rep_smooth7
    
    return(out[, c("state", "date", "dem_delta1", "dem_delta4", "dem_delta7",
                   "rep_delta1", "rep_delta4", "rep_delta7")])
    
}

getChangesFromDate <- function(conn, date) {
    q <- paste0("select * from getdays('",
                as.Date(date) - 9,
                "', '",
                date,
                "')")
    
    dbGetQuery(conn, q) %>%
        group_by(state) %>% 
        mutate(dem_smooth = smoothParty(dem, 3, date),
               rep_smooth = smoothParty(rep, 3, date)) %>% 
        ungroup() %>% 
        deltas(date)
}
    

# returns the linear combination of the 1 day, 4 day, and 7 day 
# changes in the 3 day trailing average of prices for each party in every state
# using the given weights. Weights must add to 1
predictitWeightedDeltas <- function(date, weight1, weight4, weight7, conn) {
    if (weight1 + weight4 + weight7 != 1) {
        stop("Weights must add to 1")
    }
    
    dta <- getChangesFromDate(conn, date)
    
    return(data.frame(
        state = dta$state,
        dem_delta = round(weight1 * dta$dem_delta1 + weight4 * dta$dem_delta4 + weight7 * dta$dem_delta7, 4), 
        rep_delta = round(weight1 * dta$rep_delta1 + weight4 * dta$rep_delta4 + weight7 * dta$rep_delta7, 4)
    ))
}
