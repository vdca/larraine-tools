
#-------------------------------------------------------------------------------
# generate wav clips according to ELAN segmentation
#-------------------------------------------------------------------------------

# run pipeline to:
# - parse ELAN .eaf transcription and generate audio clips

#-------------------------------------------------------------------------------
# global
#-------------------------------------------------------------------------------

rm(list=ls())     # remove previous objects from workspace
library(tidyverse)

source('eaf2clips.R')

#-------------------------------------------------------------------------------
# generate clips from elan segments
#-------------------------------------------------------------------------------

# directory where the raw audio files and associated ELAN .eaf file are located
datadir <- '../data/'

# run .eaf segmentation at once (for all .eaf files in datadir)
segment_list <- segment_eaf(datadir,
                            segment_proportion = 1,
                            overwrite_csv = F,
                            overwrite_wav = F,
                            check_existing = T,
                            eaf_pattern = '')

# gather segments in current location in tibble format
segment_df <- segment_list %>% bind_rows()

# write info on all clips in datadir to tsv file
segment_df %>%
  mutate(ortho = str_squish(utterance)) %>% 
  select(speaker_id, rec_location, ortho, translation,
         clipbase, clipdir, recording_id, speechact,
         start_time, end_time, duration) %>% 
  write_tsv(paste0(datadir, 'clips.tsv'))

