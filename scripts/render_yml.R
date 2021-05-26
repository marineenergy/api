#!/usr/local/bin/Rscript --vanilla

# chmod a+x /share/github/api/scripts/render_yml.R

# arguments
args = commandArgs(trailingOnly=TRUE)
message("args...")
print(args)
if (length(args)!=2) {
  stop("Two argument must be supplied: input_yml, output_file.", call.=FALSE)
} else {
  # args <- c(
  #   "/share/user_reports/bdbest@gmail.com/MarineEnergy.app_report-api_4841ccd7_plumber.yml",
  #   "/share/user_reports/bdbest@gmail.com/MarineEnergy.app_report-api_4841ccd7.html")
  # args <- c(
  #   '/share/user_reports/bdbest@gmail.com/MarineEnergy.app_report-api_c8cce9a6_plumber.yml',
  #   '/share/user_reports/bdbest@gmail.com/MarineEnergy.app_report-api_c8cce9a6.html')
  in_yml   <- args[1]
  out_file <- args[2]
}
stopifnot(file.exists(in_yml))
#file.exists(out_file)
#print(args)

# paths
in_rmd <- "/share/github/api/report-v2_template.Rmd"
stopifnot(file.exists(in_rmd))

librarian::shelf(
  dplyr, rmarkdown, yaml)

# metadata
# readLines(in_yml) %>% paste(collapse="\n") %>% cat()
m <- read_yaml(in_yml)

# params for Rmd
p <- m
p$Contents     <- list(value = p$Contents)
p$Interactions <- list(value = p$Interactions)

message("params for Rmd...")
as.yaml(p) %>% cat()

out_fmt <- c(
  "html" = "html_document",
  "pdf"  = "pdf_document",
  "docx" = "word_document")[[m$FileType]]

message("rendering...")
if (!file.exists(out_file))
  render(
    input         = in_rmd,
    output_file   = out_file,
    output_format = out_fmt,
    params        = p)
