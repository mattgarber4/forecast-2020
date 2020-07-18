library(myUtils)
library(DBI)
library(RPostgres)
setwd("data_acquisition/past_returns")

d <- rio::import("pres12.xlsx")

d$year <- '2012'
d$type <- 'pres'

cleanData <- function(path, type) {
    d1 <- rio::import(path)
    d1$Rating <- NULL
    d1$Code <- NULL
    d1$PVI <- NULL
    d1$state <- ifelse(tolower(d1$Loc) %in% tolower(state.name),
                       state.abb[match(tolower(d1$Loc), tolower(state.name))],
                       d1$Loc)
    d1$Loc <- NULL
    
    d1$type <- type
    
    colnames(d1) <- tolower(gsub("_Pct", "", colnames(d1)))
    colnames(d1) <- gsub('gop', 'rep', colnames(d1))
    
    if (sum(d1$dem > 1) > 0) {
        d1$dem <- d1$dem / 100
        d1$rep <- d1$rep / 100
    }
    
    d1
}






d <- rbind(d, cleanData("pres.xlsx", "pres")) %>% 
    rbind(cleanData("sen.xlsx", "sen")) %>%
    rbind(cleanData("gov.xlsx", "gov"))


conn <- dbConnect(Postgres(), 
                  user = Sys.getenv('AWS_RDS_USER'),
                  password = Sys.getenv('AWS_RDS_PASSWORD'),
                  port = 5432, 
                  dbname = Sys.getenv('AWS_RDS_DBNAME'),
                  host = Sys.getenv('AWS_RDS_HOST'),
                  options = '-c search_path=returns')

dbWriteTable(conn, 'returns', d)
dbDisconnect(conn)
