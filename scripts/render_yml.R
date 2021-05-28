#!/usr/local/bin/Rscript --vanilla

# chmod a+x /share/github/api/scripts/render_yml.R

# rndr=/share/github/api/scripts/render_yml.R
# yml=/share/user_reports/bdbest@gmail.com/report_8953190e.yml
# $rndr $yml
# pandoc: /share/user_reports/bdbest@gmail.com/report_8953190e.tex: openFile: permission denied (Permission denied)
# -rw-rw-r-- 1 root  root    2994 May 28 19:27 report_8953190e.tex
# -rw-rw-r-- 1 root  root    3680 May 28 19:27 report_8953190e.txt
# sudo chmod 775 *
# sudo chgrp staff *
# TODO: run plumber API as user shiny

# arguments
args = commandArgs(trailingOnly=TRUE)
message("args...")
print(args)
if (!length(args) %in% 1:2) {
  stop("One to two arguments must be supplied: input_yml, output_file.", call.=FALSE)
} else {
  in_yml <- args[1]
}

stopifnot(file.exists(in_yml))

# paths
in_rmd <- "/share/github/api/report-v2_template.Rmd"
stopifnot(file.exists(in_rmd))

librarian::shelf(
  dplyr, rmarkdown, yaml)

# metadata
# readLines(in_yml) %>% paste(collapse="\n") %>% cat()
# in_yml   <- "/share/user_reports/bdbest@gmail.com/report_c917e20c.yml"

m <- read_yaml(in_yml)

if (length(args) == 2){
  out_file <- args[2]
} else {
  out_file <- fs::path_ext_set(in_yml, glue::glue(".{m$filetype}"))
}

# params for Rmd
p <- m
p$contents     <- list(value = p$contents)
p$interactions <- list(value = p$interactions)

message("params for Rmd...")
as.yaml(p) %>% cat()

out_fmt <- c(
  "html" = "html_document",
  "pdf"  = "pdf_document",
  "docx" = "word_document")[[m$filetype]]

message("rendering...")
if (!file.exists(out_file))
  render(
    input         = in_rmd,
    output_file   = out_file,
    output_format = out_fmt,
    params        = p)
