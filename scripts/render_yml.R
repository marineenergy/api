#!/usr/local/bin/Rscript --vanilla

# chmod g+x /share/github/api/scripts/render_yml.R

# args ----
args   <- commandArgs(trailingOnly=T)
if (length(args) != 1) {
  stop("Only 1 required argument missing: yml", call.=FALSE)
}
yml <- args[1]
# yml="/share/user_reports/ben@ecoquants.com/report__test.yml"
# yml="/share/user_reports/ben@ecoquants.com/report_88543ffb.yml"
# yml="/share/user_reports/ben@ecoquants.com/report_0522bbdd.yml"
# yml="/share/user_reports/ben@ecoquants.com/report_54759a5a.yml"
stopifnot(file.exists(yml))

setwd("/share/github/api")
template_rmd <- "/share/github/api/_report.Rmd"
source("/share/github/apps_dev/scripts/common.R")
source(here("scripts/report.R"))

message(glue("yml: {yml}"))

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

out_fmt = c(
  html = "html_document",
  pdf  = "pdf_document",
  docx = "word_document")[p$filetype]
fm$output <- fm$output[out_fmt]

message("frontmatter for Rmd... ----")
message(yaml::as.yaml(fm))

write("---", rmd)
write(yaml::as.yaml(fm), rmd, append = T)
write("---", rmd, append = T)
write(lns[idx:length(lns)], rmd, append = T)

# write contents with interactions ----
contents <- names(p$contents)[unlist(p$contents)]

#cntnt = contents[1]
# source(file.path(dir_scripts, "report.R"))

if (length(p$interactions) == 0) {
  # source global.R to get d_docs, d_pubs, ...
  #writeLines('\n```{r}\nsource("/share/github/apps/report-v2/global.R")\n```\n\n', con = rmd) 
  # TODO: return table of all content (do not filter by ixn) WITH the tags like in the app
  r <- lapply(contents, rpt_content_noixns, rmd = rmd)
} else {
  # carry on as originally designed
  r <- lapply(contents, rpt_content, ixns = p$interactions, rmd = rmd)
}

rmarkdown::render(
  input         = rmd,
  output_file   = out)
