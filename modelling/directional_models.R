source('modelling/predictit/pd_utils.R')

directionalModel <- setRefClass(
    "directionalModel",
    fields = list(params = "list",
                  date = "Date"),
    methods = list(
        predict = function(state) {
            return(list(dir = NULL, conf = NULL))
        }
    )
)

directionalModel$lock(c("params", "date"))

predictitModel <- setRefClass(
    "predictitModel",
    contains = "directionalModel",
    fields = list(
        map = "hash"
    ),
    methods = list(
        initialize = function(date, weight1, weight4, weight7, translateEst, translateConf, conn) {
            map <<- list()
            date <<- date
            params <<- list(weight1 = weight1, 
                            weight4 = weight4, 
                            weight7 = weight7,
                            translateEst = translateEst, 
                            translateConf = translateConf)
            
            df <- predictitWeightedDeltas(date, 
                                          weight1, 
                                          weight4, 
                                          weight7, 
                                          conn)
            df$tot <- (df$delta_dem - df$delta_rep) / 2
            df$conf <- abs(df$delta_dem + df$delta_rep)
            
            for (i in seq_len(nrow(df))) {
                map[[df$state[i]]] <<- list(est = translateEst(df$tot[i]),
                                           conf = translateConf(df$conf[i]))
            }
        },
        
        predict = function(state) {
            return(map[[state]])
        }
    )
)

predictitModel$lock("map")


