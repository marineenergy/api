# plumber.R
if (!require(librarian)){
  install.packages("librarian")
  library(librarian)
}
shelf(dplyr, digest, fs, glue, here, highcharter, purrr, rmarkdown, readr, stringr, tibble, tidyr)

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
#* FERC docs in PRIMRE export metadata format
#* @get /ferc_docs
function() {
  
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
#* Submit report
#* @param email Email, e.g.: ben@ecoquants.com
#* @param date Date, e.g.: 2021-05-25 14:39:21 UTC 
#* @param title Title, e.g.: Test Report
#* @param ext FileType (one of: html, pdf, docx), e.g.: html
#* @param interactions Interactions as JSON, e.g.: [["Receptor.Fish","Stressor.PhysicalInteraction.Collision"],["Technology.Wave","Receptor.Birds"]]
#* @get /report
#* @html
function(
  req,
  email,
  date,
  title,
  interactions = NA,
  ext       = "html",
  res) {
  # title    = "Test"; receptors = NULL
  
  # paths
  in_rmd      <- "report_test.Rmd"
  dir_reports <- "/share/user_reports"
  url_rpt_pfx <- "https://api.marineenergy.app/report"
  
  dir_rpt_pfx <- "/share/user_reports"
  url_rpt_pfx <- "https://marineenergy.app/report/"
  # sym link:
  #   ln -s /share/user_reports /share/github/www/report
  
  meta <- list(
    Email        = email,
    Date         = date,
    Title        = title,
    FileType     = ext,
    Interactions = fromJSON(interactions))
  browser()

  out_file   <- glue("{dir_out}/me_report_{args_hash}.{ext}")
  out_url    <- glue("{dir_url}/{basename(out_file)}")
  out_format <- c(
    "html" = "html_document",
    "pdf"  = "pdf_document",
    "docx" = "word_document")[[ext]]
  receptors  <- str_split(receptors, "[, ]+") %>% unlist()
  
  # TODO: handle refresh of same input args
  if (!file.exists(out_file))
    render(
      input         = in_rmd, 
      output_file   = out_file, 
      output_format = out_format,
      params = list(
        title     = title,
        receptors = receptors))
  
  stopifnot(file.exists(out_file))
  
  res$status <- 303 # redirect
  res$setHeader("Location", out_url)
  glue::glue(
    "<html>
    <head>
      <meta http-equiv=\"Refresh\" content=\"0; url={out_url}\" />
    </head>
    <body>
    </body>
  </html>")
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