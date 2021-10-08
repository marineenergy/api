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
# sudo -u shiny pm2 stop run-api
# sudo -u shiny pm2 start run-api
# sudo -u shiny pm2 logs run-api --lines 1000
# sudo -u shiny pm2 start --interpreter="Rscript" /share/github/api/run-api.R
# sudo -u shiny pm2 list
# sudo -u shiny pm2 save

# open in web browser: http://api.marineenergy.app
# for more, see https://rplumber.io

# Reference for setup:
#  - https://www.rplumber.io/articles/hosting.html#pm2-1
# # Install pm2
# sudo apt-get update
# sudo apt-get install nodejs npm
# sudo npm install -g pm2
# sudo pm2 startup
# # introduce api.marineenergy.org service
# sudo -u shiny pm2 start --interpreter="Rscript" --image-name="run-api" /share/github/api/run-api.R
# sudo -u shiny pm2 save
# # TODO: get service to auto restart on boot, probably only as user root (vs user shiny)
