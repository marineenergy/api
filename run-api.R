#!/usr/bin/env Rscript

library(plumber)

plumber_r <- "/share/github/api/plumber.R"

pr(plumber_r) %>%
  pr_run(port=8888, host="0.0.0.0")

# sudo -u shiny pm2 restart run-api
# sudo -u shiny pm2 logs run-api
# sudo -u shiny pm2 start --interpreter="Rscript" /share/github/api/run-api.R
# sudo -u shiny pm2 list
# sudo -u shiny pm2 save

# open in web browser: http://api.marineenergy.app
# for more, see https://rplumber.io

# Reference:
#  - https://www.rplumber.io/articles/hosting.html#pm2-1
