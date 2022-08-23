#' ---
#' title: Larraine clips
#' author: varun@ni.eus
#' date: "`r format(Sys.time(), '%Y-%m-%d')`"
#' link-citations: true
#' output: 
#'   html_document:
#'     toc: false
#'     toc_depth: 2
#'     toc_float: false
#'     theme: "flatly"
#'     highlight: "textmate"
#'     css: "css/vignette.css"
#' ---

#+ setup, include=F
knitr::opts_chunk$set(fig.width=6, fig.height=5, echo=F, warning=F, message=F)

#-------------------------------------------------------------------------------
# Global
#-------------------------------------------------------------------------------

# based on view_contintyp.R script (noiz/2019/contintyp/code)

# to render file from terminal:
# R -e 'rmarkdown::render("clip_overview_lana.R")'

rm(list=ls())     # remove previous objects from workspace

library(tidyverse)
library(knitr)
library(DT)

#-------------------------------------------------------------------------------
# Load data
#-------------------------------------------------------------------------------

# "...clips.tsv" files list each clip extracted from those recordings
location_dir <- paste0('../data/media/')

d <- list.files(location_dir, 'clips.tsv$', full.names = T, recursive = T) %>% 
  read_tsv()

#-------------------------------------------------------------------------------
# merge clip and recording info
#-------------------------------------------------------------------------------

# play audio in DT datatable
prewav <- '<audio controls preload="none" type="audio/wav" src="'
postwav <- '" </audio>'

# create html links
esteka <- function(link, txt) {
  paste0('<a href="', link, '">', txt, '</a>')
}

# merge clip and rec info
# add links
dclips <- d %>%
  mutate(cliplink = paste0(clipdir, '/clips/', clipbase, '.wav'),
         cliplink = paste0(prewav, cliplink, postwav),
         # txtgrid = esteka(paste0(clipdir, '/clips/', clipbase, '.TextGrid'),
         #                   clipbase)
         ) %>%
  arrange(start_time)

#-------------------------------------------------------------------------------
# overview of clips; show DT table
#-------------------------------------------------------------------------------

show_clips <- dclips %>%
  select(speaker_id, rec_location, speechact,
         utterance, cliplink, clipbase, comments = oharra)

# documentation of dom options:
# https://datatables.net/reference/option/dom (plfrtip)

show_clips %>% 
  datatable(filter = 'top', rownames = F, escape = F,
            extensions = c('Select', 'SearchPanes'),
            options = list(paging = T,
                           autoWidth = T,
                           scrollX = F,
                           pageLength = 20,
                           dom = 'Plfritip',
                           searchPanes = list(
                             layout = 'columns-3',
                             cascadePanes = T,
                             viewTotal = F
                           ),
                           columnDefs = list(
                             # list(visible = F, targets = c(1:2)),
                             list(searchPanes = list(show = T),
                             targets = c(0, 1, 2)),
                             list(searchPanes = list(show = F),
                             targets = c(5, 6))
                             )))
            
           
