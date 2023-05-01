#!/usr/bin/env Rscript

librarian::shelf(
  fs, logger, plumber, tictoc)

plumber_r <- "/share/github/api/plumber.R"

# setup logging ----
dir_log <- "/home/shiny/api-logs"
if (!dir_exists(dir_log)) dir_create(dir_log)
log_appender(appender_tee(tempfile("plumber_", dir_log, ".txt")))

# * log helper functions -----
# inspiration: https://rviews.rstudio.com/2019/08/13/plumber-logging/
convert_empty <- function(string) {
  if (string == "") {
    "-"
  } else {
    string
  }
}

log_str <- '{convert_empty(req$REMOTE_ADDR)} "{convert_empty(req$HTTP_USER_AGENT)}" {convert_empty(req$HTTP_HOST)} {convert_empty(req$REQUEST_METHOD)} {convert_empty(req$PATH_INFO)} {convert_empty(res$status)} {round(end$toc - end$tic, digits = getOption("digits", 5))}'

log_hooks <- list(
  preroute = function() {
    # Start timer for log info
    tictoc::tic()
  },
  postroute = function(req, res) {
    end <- tictoc::toc(quiet = TRUE)
    log_info(log_str)
  }
)


# run plumber ----
error_handler <- function(req, res, err){
  res$status <- 500
  list(error = err$message)
}

pr <- pr(plumber_r) |> 
  pr_set_error(error_handler) |> 
  pr_hooks(log_hooks) |> 
  pr_run(port=8888, host="0.0.0.0")


# 2023-05-01 bbest update ----
# sudo apt-get update
# sudo apt-get install nodejs npm
#   nodejs is already the newest version (10.19.0~dfsg-3ubuntu1).
#   npm is already the newest version (6.14.4+ds-1ubuntu2)
# implemented logging a la here: https://rviews.rstudio.com/2019/08/13/plumber-logging/
# new commands as root ---
# sudo pm2 start --interpreter="Rscript" /share/github/api/run-api.R
# sudo pm2 list
# sudo pm2 save
# sudo pm2 logs run-api --lines 1000
# sudo pm2 restart run-api


# old commands as shiny ----
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
