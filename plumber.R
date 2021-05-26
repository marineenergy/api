# plumber.R
if (!require(librarian)){
  install.packages("librarian")
  library(librarian)
}
shelf(
  dplyr, digest, fs, glue, here, highcharter, httr, jsonlite, purrr, rmarkdown, readr, 
  stringr, tibble, tidyr, yaml)
source("/share/github/apps_dev/functions.R")
# TODO: source() as needed /share/github/apps/scripts/db.R,common.R,shiny.R,report.R
# TODO: prefix with pkg:: and skip loading whole library

# paths ----
dir_rpt_pfx <- "/share/user_reports"
url_rpt_pfx <- "https://marineenergy.app/report"
# sym link to share dir_rpt_fx to url_rpt_pfx:
#   ln -s /share/user_reports /share/github/www/report

# TODO: https://rviews.rstudio.com/2019/08/13/plumber-logging/

#* @apiTitle MarineEnergy.app API
#* @apiDescription Application programming interface (API) for the Marine Energy Toolkit at MarineEnergy.app
#* @apiVersion 0.1.9
#* @apiContact Ben Best <ben@ecoquants.com>

# /ferc_docs ----
#' FERC docs in PRIMRE export metadata format
#' @get /ferc_docs
function(){
  
  dir_data <- here("../apps/data")
  docs_csv <- glue("{dir_data}/ferc_docs2.csv")
  
  date_fetched <- file_info(docs_csv) %>% pull(change_time) %>% as.Date()
  
  docs_0 <- read_csv(docs_csv, col_types = cols()) %>% 
    rename(doc_id = doc)
  
  docs <- docs_0 %>% 
    select(doc_id, url, technology) %>% 
    group_by(doc_id) %>% 
    summarize(
      url        = first(na.omit(url)), 
      technology = first(na.omit(technology)), 
      .groups    = "drop_last") %>%  # only 4 of 118 entries with url
    mutate(
      # TODO: doc_id without any special characters or spaces [a-Z_-]
      URI               = glue("https://mhkdr.openei.org/data/{doc_id}"),
      type              = "Document/Report",
      landingPage       = URI,   # TODO: make pages
      sourceURL         = url,
      title             = doc_id,
      description       = "TBD", # TODO: required field for PRIMRE
      author            = map(NA, function(x) list("Maria Carnevale", "Sharon Kramer")), # TODO: add fields
      organization      = "MarineEnergy.app",
      originationDate   = as.Date("2021-11-07"), # TODO: handle date add/modify in future
      spatial           = map(NA, function(x) 
        list( # TODO: required fields lat,lon; default to global
          extent                = "boundingBox",
          boundingCoordinatesNE = c( 90,  180),
          boundingCoordinatesSW = c(-90, -180))),
      technologyType    = str_replace(technology, "Marine Energy.", ""),
      signatureProject  = NA, # TODO: cross-list with Projects
      modifiedDate      = date_fetched)
  
  doc_tags <- docs_0 %>% 
    select(doc_id, receptor, stressor, phase) %>% 
    mutate(
      receptor = str_replace(receptor, fixed('.'), '/'),
      stressor = str_replace(stressor, fixed('.'), '/')) %>% 
    pivot_longer(-doc_id, names_to = "category", values_to = "tag") %>% 
    filter(!is.na(tag)) %>% 
    mutate(
      tag = glue("{str_to_title(category)}/{tag}")) %>% 
    select(-category) %>% 
    group_by(doc_id) %>% 
    nest(tags = c(tag)) %>% 
    mutate(
      tags = map(tags, function(x){ x %>% unlist %>% sort %>% unique}))
  
  docs <- docs %>% 
    left_join(doc_tags, by = "doc_id") %>% 
    select(-doc_id, -url, -technology)
  
  docs
}

# /report ----
#* Submit parameters to render a report
#* @param email Email, e.g.: ben@ecoquants.com
#* @param date Date, e.g.: 2021-05-25 14:39:21 UTC 
#* @param title Title, e.g.: Test Report
#* @param ext FileType (one of: html, pdf, docx), e.g.: html
#* @param contents Contents as JSON, e.g.: {"Projects":[true],"Management":[true]}
#* @param interactions Interactions as JSON, e.g.: [["Receptor.Fish","Stressor.PhysicalInteraction.Collision"],["Technology.Wave","Receptor.Birds"]]
#* @get /report
function(
  req,
  email        = "bdbest@gmail.com",
  date         = "2021-05-25 19:11:49 UTC",
  title        = "Test Report",
  ext          = "html",
  contents     = '{"Projects":[true],"Management":[true]}',
  interactions = '[["Receptor.Fish","Stressor.PhysicalInteraction.Collision"],["Technology.Wave","Receptor.Birds"]]',
  res) {

  # paths, input
  in_rmd      <- "report-v2_template.Rmd"
  r_script    <- "/share/github/api/scripts/render_yml.R"
  
  # metadata
  m <- list(
    Email        = email,
    Date         = date,
    Title        = title,
    FileType     = ext,
    Contents     = jsonlite::fromJSON(contents),
    Interactions = jsonlite::fromJSON(interactions))
  
  # paths, output
  hsh <- digest::digest(m, algo="crc32")
  yml <- glue::glue("{dir_rpt_pfx}/{email}/report_{hsh}.yml")
  rpt <- fs::path_ext_set(yml, ext)
  log <- fs::path_ext_set(yml, ".txt")
  url <- stringr::str_replace(rpt, dir_rpt_pfx, url_rpt_pfx)
  
  dir.create(dirname(yml), showWarnings = F)
  yaml::write_yaml(m, yml)

  if (!file.exists(rpt)){
    cmd <- glue::glue("{r_script} {yml} {rpt} > {log} 2>> {log}") # message(cmd)
    system(cmd, wait = F)
  }
  
  list(
    link   = url,
    status = ifelse(file.exists(rpt), "published", "submitted"),
    params = m)
}

# /reports ----
#* Get a user's list of reports, published and submitted
#* @param email Email, e.g.: ben@ecoquants.com
#* @get /user_reports
#* @serializer csv
function(
  req,
  email = "bdbest@gmail.com",
  res) {

  dir_rpts <- glue::glue("{dir_rpt_pfx}/{email}")
  
  d <- tibble(
    yml = list.files(dir_rpts, "\\.yml", full.names = T)) %>% 
    mutate(
      m          = purrr::map(yml, yaml::read_yaml),
      ext        = purrr::map_chr(m, "FileType"),
      title      = purrr::map_chr(m, "Title"),
      date       = purrr::map_chr(m, "Date"),
      contents   = purrr::map_chr(m, function(m) names(m$Contents) %>% paste(collapse=",")),
      n_ixns     = purrr::map_chr(m, function(m) length(m$Interactions)),
      rpt        = fs::path_ext_set(yml, ext),
      rpt_exists = file.exists(rpt),
      status     = ifelse(rpt_exists, "published", "submitted"),
      log        = fs::path_ext_set(yml, ".txt"),
      url        = ifelse(rpt_exists, stringr::str_replace(rpt, dir_rpt_pfx, url_rpt_pfx), NA))
  # TODO: for rpt_exists == F, search for error in log
  
  d %>% 
    select(title, date, status, contents, n_ixns, url)
}

# /delete_report ----
#* Delete a report. Requires a server-supplied token for authorization.
#* @param email Email, e.g.: ben@ecoquants.com
#* @param report 
#* @get /delete_report
#* @serializer csv
function(
  req,
  email  = "bdbest@gmail.com",
  report,
  token,
  res) {
  # report = "report_22b870ca.html"

  pw <- readLines("/share/.password_mhk-env.us")
  token_pw <- digest::digest(c(report, pw), algo="crc32")
  if (token != token_pw)
    return("Sorry, token failed -- not authorized!")
  
  rpt <- glue::glue("{dir_rpt_pfx}/{email}/{report}")
  if (!file.exists(rpt))
    return("Sorry, report not found!")
  
  rpt_files <- list.files(dirname(rpt), fs::path_ext_remove(basename(rpt)), full.names = T)
  file.remove(rpt_files)
  cat("SUCCESS! Report removed.")
}

# / ----
#* redirect to the swagger interface 
#* @get /
#* @serializer html
function(req, res) {
  res$status <- 303 # redirect
  res$setHeader("Location", "./__swagger__/")
  "<html>
  <head>
    <meta http-equiv=\"Refresh\" content=\"0; url=./__swagger__/\" />
  </head>
  <body>
    <p>For documentation on this API, please visit <a href=\"http://api.ships4whales.org/__swagger__/\">http://api.ships4whales.org/__swagger__/</a>.</p>
  </body>
</html>"
}