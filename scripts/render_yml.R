#!/usr/bin/env Rscript

# arguments
args = commandArgs(trailingOnly=TRUE)
if (length(args)==2) {
  stop("Two argument must be supplied: input_yml, output_file.", call.=FALSE)
} else if (length(args)==1) {
  # args <- c(
  #   "/share/user_reports/bdbest@gmail.com/MarineEnergy.app_report-api_4841ccd7_plumber.yml",
  #   "/share/user_reports/bdbest@gmail.com/MarineEnergy.app_report-api_4841ccd7.html")
  in_yml   <- args[1]
  out_file <- args[2]
}
stopifnot(file.exists(in_yml))
#print(args)

# paths
in_rmd <- "/share/github/api/report-v2_template.Rmd"

librarian::shelf(
  rmarkdown, yaml)

# metadata
# readLines(in_yml) %>% paste(collapse="\n") %>% cat()
m <- read_yaml(in_yml)

# params for Rmd
p <- m
p$Content      <- list(value = p$Content)
p$Interactions <- list(value = p$Interactions)
# as.yaml(p) %>% cat()

out_fmt <- c(
  "html" = "html_document",
  "pdf"  = "pdf_document",
  "docx" = "word_document")[[m$FileType]]

if (!file.exists(out_file))
  render(
    input         = in_rmd,
    output_file   = out_file,
    output_format = out_fmt,
    params        = p)
