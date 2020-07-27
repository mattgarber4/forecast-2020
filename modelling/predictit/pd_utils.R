library(tidyr)
library(magrittr)

# calculates the coefficients for price at given day through price nine days before
# to calculate the linear combination of the 1 day, 4 day, and 7 day deltas in 
# the three day average with the given weights, which must add to 1
weightParser <- function(w1, w2, w3) {
    if (abs(w1 + w2 + w3 - 1) > .00001) {
        stop("weights must add to 1")
    }
    c(1, w2 + w3, w2 + w3, -1 * c(w1, rep(w2, 3), rep(w3, 3))) / 3
}

fixDate <- function(d, date, idx, dist) {
    sub <- d[idx, 1 + which(abs(as.Date(colnames(d)[-1]) - as.Date(date)) < dist + 1)]
    return(apply(sub, 1, function(v) mean(v, na.rm = T)))
}

# fix for missing data
imputePrices <- function(d) {
    for (date in colnames(d)[-1]) {
        dist <- 2
        while ((NA %in% d[, date] || NaN %in% d[, date]) && dist < 10) {
            idx <- which(is.na(d[, date]))
            d[idx, date] <- fixDate(d, date, idx, dist)
            dist <- dist + 1
        }
    }
    
    d
}

onePartyWeightedDeltas <- function(dta, party, wgts) {
    # look at this party
    d <- dta[, c("state", "date", party)]
    d <- spread(d, key = date, value = which(colnames(d) == party))
    
    if (nrow(d) != 57) {
        stop("Should be 57 rows -- missing data")
    }
    
    if (ncol(d) != 11) {
        stop("Should be 10 dates -- missing data")
    }
    
    # ensure columns in correct order and impute missing prices
    d <- d[, order(colnames(d), decreasing = T)] %>% imputePrices()
    
    # apply weights to each row and sum and round
    return(data.frame(state = d$state, 
                      delta = apply(wgts * t(as.matrix(d[, -1])), 2, sum) %>% round(4)))
}

# returns the linear combination of the 1 day, 4 day, and 7 day 
# changes in the 3 day trailing average of prices for each party in every state
# using the given weights. Weights must add to 1. Previously, I had a bunch of 
# reshaping, but here I did a little algebra to speed things up
predictitWeightedDeltas <- function(date, weight1, weight4, weight7, conn) {
    wgts <- weightParser(weight1, weight4, weight7)
    
    q <- paste0("select * from getdays('",
                as.Date(date) - 9,
                "', '",
                date,
                "')")
    
    dta <- dbGetQuery(conn, q)
    
    merge(onePartyWeightedDeltas(dta, "dem", wgts), 
          onePartyWeightedDeltas(dta, "rep", wgts), 
          by = "state", 
          suffixes = c("_dem", "_rep"))
    
}
