#!/usr/local/bin/Rscript --vanilla

# chmod a+x /share/github/api/scripts/render_yml.R

# arguments
args = commandArgs(trailingOnly=TRUE)
message("args...")
print(args)
if (length(args)!=2) {
  stop("Two argument must be supplied: input_yml, output_file.", call.=FALSE)
} else {
  in_yml   <- args[1]
  out_file <- args[2]
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
out_file <- fs::path_ext_set(in_yml, ".html")
  
m <- read_yaml(in_yml)

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
