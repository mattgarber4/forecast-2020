setwd("ec2")
print(Sys.time())

library(curl)
library(jsonlite)
library(myUtils)
library(DBI)
library(RPostgres)
library(stringr)
library(stringi)
library(data.table)
library(aws.s3)
library(dplyr)


setEnvVarsFromFile('vars.txt')

pad_to_length <- function(str, len, pad_char, front = TRUE) {
  while(sum(nchar(str) < len) > 0) {
    if (front) {
      str[nchar(str) < len] <- paste0(pad_char, str[nchar(str) < len])
    } else {
      str[nchar(str) < len] <- paste0(str[nchar(str) < len], pad_char)
    }
    
  }
  
  str
}

to_state_abbr <- function(s) {
  if (s %in% state.name) {
    return(state.abb[which(state.name == s)])
  } else if (grepl("District of Columbia", s)) {
    return("DC")
  } else {
    return(NA)
  }
}

processDay <- function(day_zip, direct) {
  rand <- stri_rand_strings(1, 50)
  dir <- paste0(tempdir(), "/", rand)
  unzip(paste(direct, day_zip, sep = "/"), junkpaths = F, exdir = dir)
  
  t <- lapply(list.files(paste0(dir, "/regions")), processFile, direct=dir) %>% myBind()
  
  sapply(list.files(dir, recursive = T), unlink)
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

processDirectory <- function(directory, write_csv = TRUE) {
  dta <- lapply(list.files(directory), processDay, direct = directory) %>% myBind()
  if (write_csv) {
    write.csv(dta, row.names = F, file = "fb_ads.csv")
  }
  dta
}

getDate <- function(fname) {
  gsub("[^0-9\\-]", "", fname)
}

## Postgres connection
conn <- dbConnect(Postgres(), 
                  user = Sys.getenv('AWS_RDS_USER'),
                  password = Sys.getenv('AWS_RDS_PASSWORD'),
                  port = 5432, 
                  dbname = Sys.getenv('AWS_RDS_DBNAME'),
                  host = Sys.getenv('AWS_RDS_HOST'),
                  options = '-c search_path=fb')

## found dates in database
dates_in_db <- dbGetQuery(conn, 'select day, month from summary')
dates_in_db$date <- paste('2020', 
                          pad_to_length(dates_in_db$month, 2, '0'), 
                          pad_to_length(dates_in_db$day, 2, '0'), 
                          sep = '-')

## github data repository
repo <- curl_fetch_memory('https://api.github.com/repos/mattgarber4/forecast-2020/contents/data_acquisition/fb_raw')
gh_files <- rawToChar(repo$content) %>% 
  parse_json() %>% 
  sapply(function(li) c(li$name, li$download_url)) %>%
  t() %>%
  data.frame()

colnames(gh_files) <- c('name', 'url')

gh_files$date <- getDate(gh_files$name)


### find all dates that we have in github but not in our database
dates_to_add <- gh_files$date[gh_files$date %!in% dates_in_db$date]

print(dates_to_add)

if (length(dates_to_add) > 0) {
  ## create directory to process this data
  dir <- paste(tempdir(), stri_rand_strings(1, 50), "raw_zip_downloads", sep = '/')
  
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = T)
  }
  
  ## fetch files from github
  sapply(dates_to_add, function(date) {
    url <- gh_files$url[gh_files$date == date]
    fname <- gh_files$name[gh_files$date == date]
    download.file(url, destfile = paste(dir, fname, sep = '/'))
  }) 
  
  ## grab id crosswalk from s3
  id_match <- aws.s3::s3read_using(fread, object = "fb_id_map.csv", 
                                   bucket = 's3://fb-id-map-forecast-2020',
                                   opts = list(region = 'us-east-2'))
  
  ## process all the data in the directory we just created
  t <- processDirectory(dir, write_csv = F)
  
  dbAppendTable(conn, 'spend', t)
  
}

## close connection like the responsible database bois we are
dbDisconnect(conn)
