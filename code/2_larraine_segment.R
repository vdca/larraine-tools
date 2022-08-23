
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
datadir <- '...'

# run .eaf segmentation at once (for all .eaf files in datadir)
# use segment_eaf() function

"your code"

# write info on all clips to tsv file

"your code"

