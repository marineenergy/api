#!/usr/local/bin/Rscript --vanilla

# chmod g+x /share/github/api/scripts/render_yml.R

# args ----
args   <- commandArgs(trailingOnly=T)
if (length(args) != 1) {
  stop("Only 1 required argument missing: yml", call.=FALSE)
}
yml <- args[1]
message(paste("yml:", yml))
# yml="/share/user_reports/ben@ecoquants.com/report_947f20ae.yml"
# yml="/share/user_reports/ben@ecoquants.com/report_adba3571.yml"
stopifnot(file.exists(yml))

message("sourcing")
setwd("/share/github/api")
template_rmd <- "/share/github/api/_report.Rmd"
source("/share/github/apps_dev/scripts/common.R")
source(here("scripts/report.R"))

message('get_gsheet_data("parameters")')
gsheet_params <- get_gsheet_data("parameters") %>% 
  filter(output == "report") %>% select(-output)

# params ----
p <- yaml2params(yml, frontmatter = F)

message("params for Rmd... ----")
message(yaml::as.yaml(p))

# paths ----
rmd <- fs::path_ext_set(yml, ".Rmd")
out <- fs::path_ext_set(yml, glue::glue(".{p$filetype}"))
message(glue::glue("rmd: {rmd}\nout: {out}"))

# write template with params ----
lns <- knitr::knit_expand(template_rmd) %>% strsplit("\n") %>% .[[1]]
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

# write contents, possibly per interaction ----
contents <- names(p$contents)[unlist(p$contents)]

r <- lapply(contents, rpt_content, params = p, gsheet_params, rmd = rmd)

rmarkdown::render(
  input         = rmd,
  output_file   = out, 
  clean = F)
