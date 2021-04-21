# run API by sourcing this R script in RStudio
library(plumber)
library(logger)
library(tictoc)

plumber_r <- "/share/github/api/plumber.R"

pr <- pr(plumber_r) %>%
  pr_run(port=8888, host="0.0.0.0")

# Specify how logs are written
log_dir <- "logs"
if (!fs::dir_exists(log_dir)) fs::dir_create(log_dir)
log_appender(appender_tee(tempfile("plumber_", log_dir, "_log.txt")))

convert_empty <- function(string) {
  if (string == "") {
    "-"
  } else {
    string
  }
}

pr$registerHooks(
  list(
    preroute = function() {
      # Start timer for log info
      tictoc::tic()
    },
    postroute = function(req, res) {
      end <- tictoc::toc(quiet = TRUE)
      # Log details about the request and the response
      log_info('{convert_empty(req$REMOTE_ADDR)} "{convert_empty(req$HTTP_USER_AGENT)}" {convert_empty(req$HTTP_HOST)} {convert_empty(req$REQUEST_METHOD)} {convert_empty(req$PATH_INFO)} {convert_empty(res$status)} {round(end$toc - end$tic, digits = getOption("digits", 5))}')
    }
  )
)

pr

## Reference
#  - custom serializer: https://github.com/rstudio/plumber/issues/344#issuecomment-439492586

#r <- plumb("/srv/ws-api/plumber.R")
#r$run(port=8888)
#r$run(port=8888, host="0.0.0.0", swagger = T)

# open in web browser: http://localhost:8888/__swagger__/
# open in web browser: http://api.whalesafe.com
# for more, see https://www.rplumber.io/docs

# To stop on rstudio.marinebon.app in Terminal:
#   ps -eaf | grep api
#   # admin      494   442  0 Feb07 pts/0    00:00:08 /usr/local/lib/R/bin/exec/R --no-save --no-restore --slave --no-restore --file=/srv/ws-api/run_api.R
#   sudo kill -9 494
# To start on rstudio.marinebon.app in Terminal:
#   sudo su root
#   Rscript /share/github/api/run_api.R &
#   exit