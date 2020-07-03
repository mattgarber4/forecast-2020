library(myUtils)
library(data.table)
library(stringr)
library(dplyr)

setwd("data_acquisition")
id_match <- fread("fb_id_map.csv")



# delete non-single day files
f_list <- list.files("fb_raw")
sapply(paste("fb_raw", f_list[!grepl("yesterday", f_list)], sep = "/"), unlink)

to_state_abbr <- function(s) {
    if (s %in% state.name) {
        return(state.abb[which(state.name == s)])
    } else if (grepl("District of Columbia", s)) {
        return("DC")
    } else {
        return(NA)
    }
}

getDate <- function(zip_file) {
    s <- gsub("\\D", "", zip_file)
    paste(substr(s, 1, 4), substr(s, 5, 6), substr(s, 7, 8), sep = "-")
}

processDay <- function(day_zip, direct) {
    rand <- stringi::stri_rand_strings(1, 50)
    dir <- paste0(tempdir(), "/", rand)
    unzip(paste(direct, day_zip, sep = "/"), junkpaths = F, exdir = dir)
    
    t <- lapply(list.files(paste0(dir, "/regions")), processFile, direct=dir) %>% myBind()
    
    
    print(t$date <- getDate(day_zip))
    return(t[,c("date", "state", "party", "amt")])
    
}

processFile <- function(file, direct) {
    state <- gsub("yesterday_", "", 
                  gsub("\\.csv$", "", 
                       str_extract(file, "yesterday_.*\\.csv"))) %>%
        to_state_abbr()
    t <- suppressWarnings(fread(paste0(direct, "/regions/", file), encoding = "UTF-8"))
    colnames(t) <- c("id", "page", "disc", "amt")
    t$id <- paste0("f", t$id)
    
    t <- merge(t, id_match, by = "id")
    t$amt <- gsub("\\D", "", t$amt) %>% as.numeric()
    
    t <- group_by(t, party) %>% summarize(amt = sum(amt))
    t$state <- state
    if (is.na(state)) {
        return(data.frame(party = character(0), 
                          amt = numeric(0),
                          date = character(0),
                          state = character(0)
                          )
               )
        
    } else {
        t
    }
    
}

processDirectory <- function(directory) {
    dta <- lapply(list.files(directory), processDay, direct = directory) %>% myBind()
    write.csv(dta, row.names = F, file = "fb_ads.csv")
    dta
}

processDirectory("fb_raw")
