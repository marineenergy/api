#!/usr/bin/env Rscript

library(plumber)

plumber_r <- "/share/github/api/plumber.R"

error_handler <- function(req, res, err){
  res$status <- 500
  list(error = err$message)
}

pr(plumber_r) %>%
  pr_set_error(error_handler) %>%
  pr_run(port=8888, host="0.0.0.0")

# sudo -u shiny pm2 restart run-api
# sudo -u shiny pm2 logs run-api --lines 1000
# sudo -u shiny pm2 start --interpreter="Rscript" /share/github/api/run-api.R
# sudo -u shiny pm2 list
# sudo -u shiny pm2 save

# open in web browser: http://api.marineenergy.app
# for more, see https://rplumber.io

# Reference:
#  - https://www.rplumber.io/articles/hosting.html#pm2-1
