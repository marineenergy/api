# reports-v2 functions

librarian::shelf(dplyr, purrr)

get_rowids_with_ixn <- function(db_tbl, ixn, categories = NULL){
  # db_tbl = "tethys_mgt_tags"; ixn = c("Receptor.Fish", "Stressor.PhysicalInteraction.Collision")
  # db_tbl = "mc_spatial_tags"; ixn = values$ixns %>% unlist()
  # ixn = list(c(""Receptor.Birds","Stressor.HabitatChange"))
  
  #browser()
  
  # subset interactions by categories available to content type
  if (!is.null(categories)){
    ixn_categories <- str_extract(ixn, "^[A-z]+")
    ixn <- ixn[ixn_categories %in% categories]
  }
  
  if (length(ixn) > 0){
    sql <- glue("SELECT rowid FROM {db_tbl} WHERE tag_sql ~ '{ixn}.*'") %>% 
      paste(collapse = "\nINTERSECT\n")
  } else {
    sql <- glue("SELECT DISTINCT rowid FROM {db_tbl}")
  }
  DBI::dbGetQuery(con, sql) %>% 
    pull(rowid)
}

get_tbl_ixn <- function(db_tbl, ixn){
  rowids <- get_rowids_with_ixn(glue("{db_tbl}_tags"), ixn)
  
  tbl(con, db_tbl) %>%
    filter(rowid %in% !!rowids) %>% 
    select(-rowid) %>% 
    collect()
}

rpt_content <- function(content, params, gsheet_params, rmd){
  # content = "projects" # content = "management" # content = "documents"
  # gsheet_params <- get_gsheet_data("parameters") %>% 
  #   filter(output == "report") %>% select(-output)
  
  ixns = params$interactions
  
  g_p       <- filter(gsheet_params, content == tolower(!!content))
  rmd_pfx   <- filter(g_p, variable == "rmd_pfx") %>% pull(value)
  rmd_ixn   <- filter(g_p, variable == "rmd_ixn") %>% pull(value)
  rmd_noixn <- filter(g_p, variable == "rmd_noixn") %>% pull(value)
  
  if (!is_empty(rmd_pfx)){
    stopifnot(file.exists(rmd_pfx))
    
    readLines(rmd_pfx) %>% 
      write(rmd, append = T)
  }
  
  if (is_empty(rmd_ixn) | is_empty(ixns)){
    stopifnot(file.exists(rmd_noixn))
    
    readLines(rmd_noixn) %>% 
      write(rmd, append = T)
    
    return(T)
  }
  
  if (is_empty(rmd_pfx)){
    glue('\n# {stringr::str_to_title(content)}\n\n`r rpt_content_description("{content}")`\n\n', .trim = F) %>% 
      write(rmd, append = T)
  }
  
  stopifnot(file.exists(rmd_ixn))
  rmd_ixns <- lapply(
    1:length(ixns), 
    function(i_ixn){ 
      knitr::knit_expand(rmd_ixn) })
  rmd_ixns %>% 
    unlist() %>% 
    write(rmd, append = T)
  
  T
}

rpt_content_description <- function(content){
  # content <- "management" # content <- "projects"
  gsheet_params %>% 
    filter(
      content == !!content,
      variable == "description_md") %>% 
    pull(value) %>% 
    md2html()
}

rpt_tbl <- function(d, cntnt, caption_md=""){
  
  is_df   <- T
  is_html <- knitr::is_html_output()
  
  if (cntnt == "literature" & is_html){
    # tethys_lit
    d <- d %>%
      mutate(
        Title = map2_chr(
          title, uri,
          function(x, y)
            glue("<a href={y} target='_blank'>{x}</a>"))) %>%
      select(Title) %>%
      arrange(Title)
  }
  
  if (cntnt == "literature" & !is_html){
    is_df <- F
    
    d <- d %>%
      mutate(
        li_title = glue("1. [{title}]({uri})")) %>%
      pull(li_title) %>% 
      paste(collapse = "\n")
  }
  
  if (cntnt == "management" & !is_html){
    #tbl(con, "tethys_mgt") %>% collect() %>% names() %>% paste(collapse = '`,\n = `') %>% cat()
    
    # d <- tbl(con, "tethys_mgt") %>% 
    #   collect() %>% 
    #   slice(1:3)
    d <- d %>% 
      mutate(
        Parameters = glue(
          "
          Technology: {Technology}; Category: {`Management Measure Category`}; 
          Phase: {`Phase of Project`}; 
          Stressor: {Stressor}; 
          Receptor: {Receptor} -- {`Specific Receptor`}")) %>% 
      select(
        Parameters, 
        Interaction, 
        Measure = `Specific Management Measures`, 
        Implications = `Implications of Measure`)
    # d %>% 
    #   knitr::kable(format="html", caption=caption_md)
  }
  
  if (is_html){
    caption_html <- htmltools::HTML(markdown::markdownToHTML(
      text = caption_md,
      fragment.only = T))
    
    d %>% 
      DT::datatable(
        caption = caption_html,
        escape = F)
  } else {
    if (is_df){
      #d, caption = caption_md, format = "simple")

      # TODO: get nice table output in docx
      #   https://stackoverflow.com/questions/47704329/how-to-format-kable-table-when-knit-from-rmd-to-word-with-bookdown
      # d %>% 
      #   kableExtra::kbl(booktabs = T, caption = caption_md) %>% 
      #   kableExtra::kable_styling(full_width = T, latex_options = "striped") %>% 
      #   kableExtra::column_spec(1:4, width = rep("1.5in", 4))
      # library(huxtable)
      
      glue("{caption_md}:\n\n", .trim=F) %>% cat()
      
      # install.packages(c("huxtable", "flextable"))
      h <- d %>% 
        huxtable::as_hux() %>%
        # huxtable::set_caption(caption_md) %>% 
        huxtable::theme_basic() %>% 
        huxtable::map_background_color(
          huxtable::by_rows("grey95", "grey80")) %>%
        # set_tb_padding(2)
        # set_width(0.8) %>% 
        # set_font_size(8) %>% 
        # set_lr_padding(2) %>% 
        huxtable::set_col_width(rep(1/ncol(d), ncol(d))) # %>% 
        # set_position("left")
      huxtable::width(h) <- 1
      huxtable::wrap(h) <- TRUE
      h
    } else {
      glue("{caption_md}:\n\n", .trim=F) %>% cat()
      cat(d)
    }
  }
}

# yaml to params for Rmd
yaml2params <- function(yml, frontmatter=F){
  p <- yaml::read_yaml(yml)
  if (frontmatter){
    # directly writing into frontmatter of Rmd requires extra `value` for list objects
    p$contents        <- list(value = p$contents)
    p$interactions    <- list(value = p$interactions)
    p$document_checks <- list(value = p$document_checks)
  }
  p
}
