library(DBI)
library(RPostgres)
source('modelling/predictit/pd_utils.R')

conn <- dbConnect(Postgres(), 
                  user = Sys.getenv("AWS_RDS_USER"),
                  password = Sys.getenv("AWS_RDS_PASSWORD"),
                  host = Sys.getenv("AWS_RDS_HOST"),
                  dbname = Sys.getenv("AWS_RDS_DBNAME"),
                  port = 5432,
                  options = '-c search_path=predictit')

by_date <- lapply(seq(as.Date('2020-07-15'), Sys.Date(), by = 'days'), 
                  predictitWeightedDeltas, 
                  weight1 = .2, weight4 = .3, 
                  weight7 = .5, conn = conn)

mat <- array(data = NA, 
             dim = c(nrow(by_date[[1]]), 2, length(by_date)), 
             dimnames = list(c(by_date[[1]]$state),
                             c("delta_dem", "delta_rep"),
                             as.character(seq(as.Date('2020-07-15'), Sys.Date(), by = 'days'))
                             )
             )

for (i in 1:length(by_date)) {
    mat[, , i] <- as.matrix(by_date[[i]][, -1])
}

plot(as.Date(dimnames(mat)[[3]]), mat[27, 1, ], type = 'l')

s <- seq(as.Date('2020-07-15'), Sys.Date(), by = "days")
df <- by_date[[1]]
df$date <- s[1]
for (i in 2:length(s)) {
    d2 <- by_date[[i]]
    d2$date <- s[i]
    df <- rbind(df, d2)
}


# We want to encode two ideas into this calculation: 
#   1. What direction is the race moving, and by how much?
#   2. How confident are we in this datapoint?
hist(df$delta_dem + df$delta_rep)

# here we see that the weighted deltas sum to around 0 and have a relatively small spread
# we can easily encode the confidence in these measures by how close to perfectly opposite they
# are -- if |delta_dem + delta_rep| is small, then we will assign high confidence. If 
# |delta_dem + delta_rep| is large, then we will apply lower confidence.


hist(df$delta_dem)
hist(df$delta_rep)

# To measure total effect, let's calculate the total weighted shift towards dems (W_d)
# as W_d := (delta_dem - delta_rep) / 2. This represents the average "good news" for dems
# on either side. Similarly, W_r := (delta_rep - delta_dem) / 2 = - W_d

df$delta_tot <- (df$delta_dem - df$delta_rep) / 2

plot_del_total <- function(df) {
    plot(df$date, df$delta_tot)
    abline(lm(df$delta_tot ~ df$date))
    abline(h = 0)
}

plot_del_total(df)

# here we see a very slight overall trend towards democrats with a high degree of uncertainty
# but let's look at a some states

plot_del_total(df[df$state == "FL", ])
plot_del_total(df[df$state == "MI", ])
plot_del_total(df[df$state == "PA", ])
plot_del_total(df[df$state == "NC", ])
plot_del_total(df[df$state == "AZ", ])
plot_del_total(df[df$state == "VA", ])
plot_del_total(df[df$state == "WI", ])
plot_del_total(df[df$state == "CA", ])
plot_del_total(df[df$state == "NY", ])
plot_del_total(df[df$state == "NM", ])
plot_del_total(df[df$state == "USA", ])

# There's not a single consistent pattern here, but all the datapoints move 
# faily smoothly, meaning we shouldn't expect wild swings in short periods of time


df$delta_cor <- abs(df$delta_dem + df$delta_rep)
hist(df$delta_cor)
