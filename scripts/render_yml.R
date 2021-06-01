#!/usr/local/bin/Rscript --vanilla

# chmod g+x /share/github/api/scripts/render_yml.R

# yml="/share/user_reports/ben@ecoquants.com/report_51e8b60a.yml"

# args ----
args   <- commandArgs(trailingOnly=T)
if (length(args) != 1) {
  stop("Only 1 required argument missing: yml", call.=FALSE)
}
yml <- args[1]
stopifnot(file.exists(yml))

message("yml: {yml}")

setwd("/share/github/api")
template_rmd <- "/share/github/api/_report.Rmd"
source("/share/github/apps_dev/scripts/common.R")
source(file.path(dir_scripts, "report.R"))

# librarian::shelf(
#   dplyr, fs, rmarkdown, yaml)

# params ----
p <- yaml2params(yml, frontmatter = F)

message("params for Rmd... ----")
message(yaml::as.yaml(p))

# paths ----
rmd <- fs::path_ext_set(yml, ".Rmd")
out <- fs::path_ext_set(yml, glue::glue(".{p$filetype}"))
message(glue::glue("rmd: {rmd}\nout: {out}"))

# write template with params ----
lns <- readLines(template_rmd)
fm  <- rmarkdown::yaml_front_matter(template_rmd)
idx <- lns %>% 
  grepl(pattern = "---") %>% 
  which() %>% 
  .[2] + 1
fm$params <- yaml2params(yml, frontmatter = T)

write("---", rmd)
write(yaml::as.yaml(fm), rmd, append = T)
write("---", rmd, append = T)
write(lns[idx:length(lns)], rmd, append = T)

# write contents with interactions ----
contents <- names(p$contents)[unlist(p$contents)]

#cntnt = contents[1]
r <- lapply(contents, rpt_content, ixns = p$interactions, rmd = rmd)

# rpt_content(contents[1], T)
#knitr::knit_expand('_cntnt.Rmd')

# message("rendering...")
# if (!file.exists(out))
rmarkdown::render(
  input         = rmd,
  output_file   = out)
    # output_format = c(
    #   "html" = "html_document",
    #   "pdf"  = "pdf_document",
    #   "docx" = "word_document")[[p$filetype]])
