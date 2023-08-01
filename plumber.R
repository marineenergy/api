# plumber.R
if (!require(librarian)){
  install.packages("librarian")
  library(librarian)
}
shelf(
  dplyr, digest, fs, glue, here, httr, jsonlite, purrr, rmarkdown, readr, 
  stringr, tibble, tidyr, yaml)

#source("/share/github/apps_dev/functions.R")
source("/share/github/apps/scripts/common_2.R")
source("/share/github/apps/scripts/db.R")
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

# /ba_docs ----
#' Biological Assessment document excerpts in PRIMRE export metadata format
#' @get /ba_docs
function(){
  # TODO:
  # - excerpts:
  #   - generate excertps/ba_#.html
  #   - + link to Report interface w/ mention of BA / Documents (FERC) tabs
  # - files:
  #   - mv Google Drive mhk-env/ba/*.gdoc to *.docx to www/files/*.docx;
  #     update ba_docs.ba_doc_url
  # - update date_created,date_modified in Shiny apps/edit
  # - add author (optionally organization) to tbl(con, "ba_docs")
  
  # [Appendix B. PRIMRE Metadata Schema](https://openei.org/wiki/PRIMRE/Developer_Documents#appendB)
  
  # update once
  #   From: Sharon Kramer <skramer@harveyecology.com>
  #   Date: Wed, Apr 26, 2023 at 3:34 PM
  #   Subject: Tagging done?! [for BA not FERC]
  # dbExecute(con, "ALTER TABLE ba_doc_excerpts ADD COLUMN IF NOT EXISTS date_created DATE")
  # dbExecute(con, "ALTER TABLE ba_doc_excerpts ADD COLUMN IF NOT EXISTS date_modified DATE")
  # dbExecute(con, "UPDATE ba_doc_excerpts SET date_created  = '2022-04-26'")
  # dbExecute(con, "UPDATE ba_doc_excerpts SET date_modified = '2022-04-26'")
  
  d_tags <- tbl(con, "ba_doc_excerpt_tags") |> 
    left_join(
      tbl(con, "tags"),
      by = "tag_sql") |> 
    filter(category != "Technology") |> 
    arrange(rowid, tag) |> 
    select(rowid, tag) |> 
    collect() |> 
    group_by(rowid) |> 
    nest(
      tags = tag) |> 
    mutate(
      tags = map(tags, unlist))

  d <- tbl(con, "ba_doc_excerpts") |>
    left_join(
      tbl(con, "ba_docs"),
      by = "ba_doc_file") |> 
    left_join(
      tbl(con, "ba_projects") |> 
        left_join(
          tbl(con, "tags"),
          by = c("tag_technology" = "tag_sql")) |> 
        select(ba_project, tag_tech = tag_nocat),
      by = "ba_project") |> 
    left_join(
      tbl(con, "ba_sites"),
      by = "ba_project") |> 
    collect() |> 
    mutate(
      URI             = glue("https://marineenergy.app/excerpts/ba_{rowid}.html"),
      type            = "Document/Report",
      sourceURL       = ba_doc_url,
      title           = glue("{ba_project}: {ba_doc_file}"),
      description     = excerpt,
      author          = prepared_by,
      organization    = institution,
      originationDate = date_report,
      spatial         = map2(lon, lat, \(x, y){
        list(
          extent = "point",
          coordinates = c(y, x)) }),
      technologyType  = tag_tech) |> 
    left_join(
      d_tags,
      by = "rowid") |> 
    mutate(
      modifiedDate = date_modified) |> 
    select(
      URI, type, sourceURL, title, description, author, organization,
      originationDate, spatial, technologyType, tags,
      modifiedDate)
  
  d
}

# /ferc_docs ----
#' FERC document excerpts in PRIMRE export metadata format
#' @get /ferc_docs
function(){

  # [Appendix B. PRIMRE Metadata Schema](https://openei.org/wiki/PRIMRE/Developer_Documents#appendB)
  
  # update once
  #   From: Sharon Kramer <skramer@harveyecology.com>
  #   Date: Wed, Apr 26, 2023 at 3:34 PM
  #   Subject: Tagging done?! [for BA not FERC]
  # dbExecute(con, "ALTER TABLE ferc_docs ADD COLUMN IF NOT EXISTS date_created DATE")
  # dbExecute(con, "ALTER TABLE ferc_docs ADD COLUMN IF NOT EXISTS date_modified DATE")
  # dbExecute(con, "UPDATE ferc_docs SET date_created  = '2022-04-26'")
  # dbExecute(con, "UPDATE ferc_docs SET date_modified = '2022-04-26'")
  # TODO: udpate date_created, date_modified in /edit Shiny app

  d_tags <- tbl(con, "ferc_doc_tags") |> 
    left_join(
      tbl(con, "tags"),
      by = "tag_sql") |> 
    filter(category != "Technology") |> 
    arrange(rowid, tag) |> 
    select(rowid, tag) |> 
    collect() |> 
    group_by(rowid) |> 
    nest(
      tags = tag) |> 
    mutate(
      tags = map(tags, unlist))
  
  d <- tbl(con, "ferc_docs") |>
    collect() |> 
    left_join(
      tbl(con, "projects") |> 
        collect() |> 
        # pull(tag_technology) |> 
        # unique() # "Current.Tidal"    "Wave"             "Current.Riverine"
        left_join(
          tbl(con, "tags") |> 
            filter(category == "Technology") |> 
            collect() |> 
            mutate(
              tag_technology = str_replace(tag_sql, "^Technology.", "")),
          by = "tag_technology") |> 
        select(project, tag_tech = tag_nocat, lon = longitude, lat = latitude),
      by = "project") |> 
    mutate(
      URI             = glue("https://marineenergy.app/excerpts/ferc_{rowid}.html"),
      type            = "Document/Report",
      sourceURL       = prj_doc_attach_url,
      title           = glue("{project}: {prj_document}"),
      description     = detail,
      author          = NA,
      originationDate = date_created,
      spatial         = map2(lon, lat, \(x, y){
        list(
          extent = "point",
          coordinates = c(y, x)) }),
      technologyType  = tag_tech) |> 
    left_join(
      d_tags,
      by = "rowid") |> 
    mutate(
      modifiedDate = date_modified) |> 
    select(
      URI, type, sourceURL, title, description, author,
      originationDate, spatial, technologyType, tags,
      modifiedDate)
  
  d
}

# /report ----
#* Submit parameters to render a report
#* @param email Email, e.g.: ben@ecoquants.com
#* @param date Date, e.g.: 2021-05-25 14:39:21 UTC 
#* @param title Title, e.g.: Test Report
#* @param filetype FileType (one of: html, pdf, docx), e.g.: html
#* @param contents Contents as JSON, e.g.: {"Projects":[true],"Management":[true]}
#* @param interactions Interactions as JSON, e.g.: [["Receptor.Fish","Stressor.PhysicalInteraction.Collision"],["Technology.Wave","Receptor.Birds"]]
#* @get /report
function(
  req,
  email           = "bdbest@gmail.com",
  date            = "2021-05-25 19:11:49 UTC",
  title           = "Test Report",
  filetype        = "html",
  contents        = '{"Projects":[true],"Management":[true]}',
  interactions    = '[["Receptor.Fish","Stressor.PhysicalInteraction.Collision"],["Technology.Wave","Receptor.Birds"]]',
  document_checks = '[]',
  spatial_aoi_wkt = '',
  res) {

  # paths, input
  # in_rmd      <- "report-v2_template.Rmd"
  r_script    <- "/share/github/api/scripts/render_yml.R"
  
  #browser()
  # metadata
  m <- list(
    email           = email,
    date            = date,
    title           = title,
    filetype        = filetype,
    contents        = jsonlite::fromJSON(contents),
    interactions    = jsonlite::fromJSON(interactions, simplifyMatrix=F),
    document_checks = jsonlite::fromJSON(document_checks, simplifyMatrix=F),
    spatial_aoi_wkt = spatial_aoi_wkt)
  
  message("m")
  print(m)
  
  # paths, output
  hsh <- digest::digest(m, algo="crc32") 
  # hsh = "7df59d4c"; email = "ben@ecoquants.com"; m = list(filetype = "html")
  yml <- glue::glue("{dir_rpt_pfx}/{email}/report_{hsh}.yml")
  rpt <- fs::path_ext_set(yml, m$filetype)
  log <- fs::path_ext_set(yml, ".txt")
  url <- stringr::str_replace(rpt, dir_rpt_pfx, url_rpt_pfx)
  
  dir.create(dirname(yml), showWarnings = F)
  yaml::write_yaml(m, yml)
  
  #message(glue("yml exists {file.exists(yml)}: {yml}"))

  if (!file.exists(rpt)){
    # cmd <- glue::glue("{r_script} {yml} > {log} 2>> {log}")
    # r_script="/share/github/api/scripts/render_yml.R"
    # yml="/share/user_reports/ben@ecoquants.com/report_51e8b60a.yml"
    # log="/share/user_reports/ben@ecoquants.com/report_51e8b60a.txt"
    cmd <- glue::glue('r_script={r_script}\n yml={yml}\n log={log}\n $r_script $yml > $log 2>> $log')
    # cat(cmd)
    message(cmd)
    # system(cmd)
    system(cmd, wait = F)
  }
  
  list(
    link   = url,
    status = ifelse(file.exists(rpt), "published", "submitted"),
    params = m)
}

# /user_reports ----
#* Get a user's list of reports, published and submitted
#* @param email Email, e.g.: ben@ecoquants.com
#* @get /user_reports
#* @serializer csv
function(
  req,
  email,
  res) {

  # email = "bdbest@gmail.com"
  dir_rpts <- glue::glue("{dir_rpt_pfx}/{email}")
  
  d <- tibble(
    yml = list.files(dir_rpts, "^report_.*\\.yml", full.names = T)) %>% 
    mutate(
      m          = purrr::map(yml, yaml::read_yaml),
      ext        = purrr::map_chr(m, "filetype"),
      title      = purrr::map_chr(m, "title"),
      date       = purrr::map_chr(m, "date"),
      contents   = purrr::map_chr(m, function(m) 
        names(m$contents)[unlist(m$contents)] %>% 
          stringr::str_to_title() %>% 
          paste(collapse=", ")),
      n_ixns     = purrr::map_int(m, function(m) length(m$interactions)),
      rpt        = purrr::map2_chr(yml, ext, fs::path_ext_set),
      rpt_exists = file.exists(rpt),
      status     = ifelse(rpt_exists, "published", "submitted"),
      log        = fs::path_ext_set(yml, ".txt"),
      url        = stringr::str_replace(rpt, dir_rpt_pfx, url_rpt_pfx)) %>% 
    arrange(desc(date))
  # TODO: for rpt_exists == F, search for error in log

  #message("/user_reports")
  d %>% 
    select(title, date, status, contents, n_ixns, url)
}

# /user_reports_hash_modified ----
#* Get timestap for last modified from user's list of reports, published and submitted
#* @param email Email, e.g.: ben@ecoquants.com
#* @get /user_reports_last_modified
#* @serializer text
function(
  req,
  email,
  res) {
  # email = "bdbest@gmail.com"
  
  dir_rpts <- glue::glue("{dir_rpt_pfx}/{email}")
  
  list.files(dir_rpts, "^report_.*", full.names = T) %>% 
    fs::file_info() %>% 
    # summarize(
    #   last_mod = max(modification_time)) %>% 
    mutate(
      b = basename(path)) %>% 
    select(b, modification_time) %>% 
    digest::digest(algo="crc32")
}

# /delete_report ----
#* Delete a report. Requires a server-supplied token for authorization.
#* @param email Email, e.g.: ben@ecoquants.com
#* @param report 
#* @get /delete_report
#* @serializer text
function(
  req,
  email,
  report,
  token,
  res) {
  # report = "report_22b870ca.html"

  # email = "bdbest@gmail.com"; report = "report_cef7d716.docx"
  # token <- digest::digest(c(report, pw), algo="crc32")
  # # shiny token: 4299c7fb
  # 
  # r <- httr::GET(
  #   "https://api.marineenergy.app/user_reports_last_modified", 
  #   query = list(email=email, report=rpt, token=tkn))
  
  # email = "bdbest@gmail.com"; report = "report_471f1593.html"; token = "aaaae249"
  # email = "ben@ecoquants.com"; report = "report_58fd717d.docx"
  pw <- readLines("/share/.password_mhk-env.us")
  token_pw <- digest::digest(c(report, pw), algo="crc32")
  if (token != token_pw)
    stop("Sorry, token failed -- not authorized!")
  
  yml <- glue::glue("{dir_rpt_pfx}/{email}/{fs::path_ext_set(report, '.yml')}")
  if (!file.exists(yml))
    stop("Sorry, report not found!")
  
  rpt_files <- list.files(dirname(yml), fs::path_ext_remove(basename(yml)), full.names = T)
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
