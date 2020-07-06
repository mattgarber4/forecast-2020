library(rvest)
library(myUtils)
library(RSelenium)

# extracts data from market line from predictit
getLine <- function(line) {
    party <- html_nodes(line, css="span.market-contract-horizontal-v2__title-text") %>% html_text()
    party <- substr(trimws(party), 1, 1)
    
    price <- html_nodes(line, css="span.market-contract-horizontal-v2__current-price-display") %>% html_text()
    
    price <- gsub("\\D", "", price) %>% as.numeric()
    
    data.frame(party = party, price = price)
}

# collects data from all market lines
getMarketPrices <- function(html) {
    lines <- html_nodes(html, css="div.market-contract-horizontal-v2")
    lapply(lines, getLine) %>% myBind()
}

# collects data from state with given market id
getMarketData <- function(remdr, id, time = 1, state) {
    # set max wait time to 10 seconds -- assume there is a separate error if 
    # process takes longer
    if (time >= 10) {
        return(data.frame(
            party = NA,
            price = NA,
            state = state,
            time = Sys.time()
        ))
    }
    
    # url to use
    url <- paste0("https://www.predictit.org/markets/detail/", id)
    remdr$navigate(url)
    
    # let remote browser catch up
    Sys.sleep(time)
    
    # try collectiong data
    tryCatch({
        el <- remdr$findElement(using = "css selector", "body")
        ht <- el$getElementAttribute("innerHTML")[[1]] %>% read_html()
        prices <- getMarketPrices(ht)
        prices$state <- state
        prices$time <- Sys.time()
        prices
        },
        
        # catch all errors by attempting the same call with greater delay
        error = function(e) {
            print("handling assumed delay error")
            getMarketData(remdr, id, time + 1, state)
        })
}


# states and market ids
id_map <- read.csv("data_acquisition/predictit_codes.csv")

remdr <- newRemDr()
remdr$open(silent = T)


# collect all data
res <- mapply(getMarketData, 
              id = id_map$id, 
              state = id_map$state, 
              MoreArgs = list(remdr = remdr),
              SIMPLIFY = F
              ) %>% myBind()

remdr$close()

# write to file
write.csv(res, 
          file = paste0("data_acquisition/predictit/predictit-", gsub("\\s|:", "", Sys.time()), ".csv"),
          row.names = F)
