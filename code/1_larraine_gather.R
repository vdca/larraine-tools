
#-------------------------------------------------------------------------------
# global
#-------------------------------------------------------------------------------

library(tidyverse)
source('eaf2clips.R')

#-------------------------------------------------------------------------------
# tidy transcribed data
#-------------------------------------------------------------------------------

# directory where the raw audio files and associated ELAN .eaf file are located
rec_dir <- '../data/'

# read annotations in all eaf files.
# function to use: read_eaf()
# more info: check out get_segments() function (in eaf2clips.R script)

eaf_content <- rec_dir %>%
  read_eaf() %>% 
  bind_rows()

# filter, transform, etc...
# then: write tidy annotations into a single tsv file

eaf_content %>% 
  select(-speechact) %>% 
  write_tsv('../data/all_transcriptions.tsv')
