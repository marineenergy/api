# plumber.R
if (!require(librarian)){
  install.packages("librarian")
  library(librarian)
}
shelf(
  dplyr, digest, fs, glue, here, highcharter, httr, purrr, rmarkdown, readr, 
  stringr, tibble, tidyr, yaml)
source("/share/github/apps_dev/functions.R")

# TODO: https://rviews.rstudio.com/2019/08/13/plumber-logging/

# /highchart ----
#' Plot the iris dataset using interactive chart
#' 
#' @param spec Species to filter
#'
#' @get /highchart
#' @serializer htmlwidget
function(spec){
  library(highcharter)
  
  myData <- iris
  title <- "All Species"
  
  # Filter if the species was specified
  if (!missing(spec)){
    title <- paste0("Only the '", spec, "' Species")
    myData <- subset(iris, Species == spec)
  }
  
  hchart(myData, "scatter", hcaes(x = Sepal.Length, y = Petal.Length, group = Species)) %>%
    hc_title(text = title)
}

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

# /echo ----
#* Echo back the input
#* @param msg The message to echo
#* @get /echo
function(msg="") {
  list(msg = paste0("The message is: '", msg, "'"))
}

# /plot ----
#* Plot a histogram
#* @serializer png
#* @get /plot
function() {
  rand <- rnorm(100)
  hist(rand)
}

# /report ----
#* Submit report parameters for publishing
#* @param email Email, e.g.: ben@ecoquants.com
#* @param date Date, e.g.: 2021-05-25 14:39:21 UTC 
#* @param title Title, e.g.: Test Report
#* @param ext FileType (one of: html, pdf, docx), e.g.: html
#* @param contents Contents as JSON, e.g.: {"Projects":[true],"Management":[true]}
#* @param interactions Interactions as JSON, e.g.: [["Receptor.Fish","Stressor.PhysicalInteraction.Collision"],["Technology.Wave","Receptor.Birds"]]
#* @get /report
function(
  req,
  email,
  date,
  title,
  ext = "html",
  content = NA,
  interactions = NA,
  res) {

  # paths
  in_rmd      <- "report-v2_template.Rmd"
  r_script    <- "/share/github/api/scripts/render_yml.R"
  dir_rpt_pfx <- "/share/user_reports"
  url_rpt_pfx <- "https://marineenergy.app/report/"
  # sym link to share dir_rpt_fx to url_rpt_pfx:
  #   ln -s /share/user_reports /share/github/www/report
  
  # metadata
  m <- list(
    Email        = email,
    Date         = date,
    Title        = title,
    FileType     = ext,
    Content      = fromJSON(content),
    Interactions = fromJSON(interactions))
  # ext = m$FileType; email = m$Email
  
  hash <- digest(m, algo="crc32")
  yml <- glue("{dir_rpt_pfx}/{email}/MarineEnergy.app_report-api_{hash}_plumber.yml")
  dir.create(dirname(yml), showWarnings = F)
  write_yaml(m, yml)

  out_file <- glue("{dir_rpt_pfx}/{email}/MarineEnergy.app_report-api_{hash}.{ext}")

  browser()
  if (!file.exists(out_file)){
    message(glue("{yml} -> {out_file}"))
    # /share/user_reports/bdbest@gmail.com/MarineEnergy.app_report-api_c8cce9a6_plumber.yml 
    #   /share/user_reports/bdbest@gmail.com/MarineEnergy.app_report-api_c8cce9a6.html
    system2("Rscript", "--vanilla", r_script, yml, out_file, wait = F)  
  }
  
  list(
    url    = glue("{url_rpt_pfx}/{basename(out_file)}"),
    status = ifelse(file.exists(out_file), "published", "submitted"),
    params = m)
}

# /sum ----
#* Return the sum of two numbers
#* @param a The first number to add
#* @param b The second number to add
#* @post /sum
function(a, b) {
  as.numeric(a) + as.numeric(b)
}

# / ----
#* redirect to the swagger interface 
#* @get /
#* @html
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