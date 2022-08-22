# varun@ni.eus

#-------------------------------------------------------------------------------
# generate wav clips according to ELAN segmentation
#-------------------------------------------------------------------------------

# use elan R package and ffmpeg commandline program to:
# - read segments from ELAN eaf file
# - extract audio segments from a wav file into smaller utterance-level clips
# - (run MAUS forced-alignment through BAS web services)

#-------------------------------------------------------------------------------
# global
#-------------------------------------------------------------------------------

# rm(list=ls())     # remove previous objects from workspace
library(tidyverse)

# requires elan package
# devtools::install_github("dalejbarr/elan")

#-------------------------------------------------------------------------------
# functions
#-------------------------------------------------------------------------------

# 5 steps:
# (1.1) get_segments(): create tibble with segments from eaf file
# (1.2) get_channels(): which speaker in which stereo channel
# (2) prepare_outputs(): create ffmpeg commands to clip each segment, and csv transcriptions
# (3) create_clips(): loop through all segments in a file and run clipping command
# (4) write_seg_transcription(): write each segment's transcription to a separate csv file
# (5) segmentation_pipeline(): wrap previous functions

# separation ruler
ruler <- function(len = 33) {
  rep('-', len) %>% paste0(collapse = '') %>% paste0('\n', ., '\n')
}

get_segments <- function(datadir, eaffile) {
  
  require(elan)
  
  # debug message
  cat(ruler(), 'read', eaffile, '\n')

  # read all tiers from eaf file
  fulleaf <- efileAnnotations(paste0(datadir, eaffile)) %>% as_tibble()
  
  # remove segments with empty/default annotations
  nonempty <- fulleaf %>% 
    filter(!VALUE %in% c('', 'x'),
           str_detect(VALUE, '^x[0-9]', negate = T))
  
  # select only utt(erance) tier
  utt <- nonempty %>% 
    filter(TIER_ID == 'utt') %>% 
    rename(utterance = VALUE)
  
  # select speech act (sact) tier,
  # this tier has a symbolic association stereotype with parent utt.
  # hence, its annotation_ref corresponds to the utt tier annotation_id.
  sact <- nonempty %>% 
    filter(TIER_ID == 'sact') %>% 
    mutate(ANNOTATION_ID = ANNOTATION_REF) %>% 
    rename(speechact = VALUE) %>% 
    select(ANNOTATION_ID, speechact)
  
  # select comment (comm) tier,
  # this tier has a symbolic association stereotype with parent utt.
  # hence, its annotation_ref corresponds to the utt tier annotation_id.
  comm <- nonempty %>% 
    filter(TIER_ID == 'comm') %>% 
    mutate(ANNOTATION_ID = ANNOTATION_REF) %>% 
    rename(oharra = VALUE) %>% 
    select(ANNOTATION_ID, oharra)
  
  # speaker_id tier
  speakers <- nonempty %>% 
    filter(TIER_ID == 'speaker_id') %>% 
    mutate(ANNOTATION_ID = ANNOTATION_REF) %>% 
    rename(speaker_id = VALUE) %>% 
    select(ANNOTATION_ID, speaker_id)
  
  # merge tiers for all utterance segments
  d <- utt %>% 
    left_join(sact) %>% 
    left_join(speakers) %>% 
    left_join(comm) %>% 
    select(ANNOTATION_ID, t0, t1, utterance, speechact, speaker_id, oharra)
  
  segments <- d %>% 
    mutate(start_time = t0/1000,
           end_time = t1/1000) %>% 
    select(start_time, end_time, speechact, utterance, speaker_id, oharra) %>% 
    add_column(xfile = eaffile, .before = 1)

  return(segments)
  
}

# get list of which speaker in which stereo channel
get_channels <- function() {
  
  # channel info is located in recording db
  recdb <- read_tsv('/media/varun/vaT5/data/audio/rec_db/data/recordings.tsv')
  
  # for each session recording (bylocation/...)
  # match speaker_id to mic channel:
  #   0 = L = lavalier 1
  #   1 = R = lavalier 2
  recdb %>% 
    select(recording_id = new_filename, lavalier1_L, lavalier2_R, speakers) %>% 
    pivot_longer(lavalier1_L:lavalier2_R,
                 names_to = 'channel',
                 values_to = 'speaker_id') %>%
    # filter(!is.na(speaker_id)) %>% 
    mutate(channel = if_else(channel == 'lavalier1_L', 0, 1),
           channel = if_else(is.na(speaker_id), 0, channel)) %>%
    separate_rows(speaker_id) %>%
    separate_rows(speakers) %>% 
    mutate(speaker_id = if_else(is.na(speaker_id), speakers, speaker_id)) %>% 
    select(-speakers) %>% 
    distinct(recording_id, channel, speaker_id)
}

# convert segment onset/offset to samples (instead of seconds)
# in order to comply with BPF specification (chunk preparation):
# https://clarin.phonetik.uni-muenchen.de/BASWebServices/interface/ChunkPreparation
# overwrite = 'y' / 'n' (whether ffmpeg will overwrite output files);
# last 3 lines of ffcmd normalize loudness and rewrite the clip.
prepare_outputs <- function(datadir, segments, eaffile, overwrite_wav = 'n') {
  
  recording_id <- str_replace(eaffile, '\\.eaf$', '')
  wavfile <- paste0(recording_id, '.wav')
  # clip_rootdir <- str_replace(datadir, 'bylocation.*', 'byspeaker')
  clip_rootdir <- datadir %>% str_sub(1, -2)
  
  channels <- get_channels()
  
  segment_df <- segments %>% 
    arrange(start_time) %>%      # arranged by default, but just in case
    separate(start_time, into = c('sec', 'ms'), remove = F, fill = 'right') %>% 
    mutate(ms = if_else(is.na(ms), '0', ms),
           clipbase = paste(recording_id, sec, ms, sep = '_'),
           # speaker_location = str_sub(speaker_id, 1, 3),
           rec_location = str_sub(recording_id, 10, 12),
           recording_id = recording_id,
           eafdir = datadir,
           duration = end_time - start_time) %>% 
    select(-sec, -ms) %>% 
    left_join(channels) %>% 
    mutate(channel = if_else(is.na(channel), 0, channel)) %>% 
    mutate(clipdir = paste(clip_rootdir, sep = '/'),
           ffcmd = paste0("ffmpeg -loglevel warning -", overwrite_wav, " -i ",
                          datadir, wavfile,
                          " -map_channel 0.0.", channel,
                          " -ss ", start_time, " -to ", end_time,
                          " ", clipdir, '/clips/', clipbase, '.wav; ',
                          "ffmpeg-normalize ", clipdir, '/clips/', clipbase, '.wav',
                          ' -of ', clipdir, '/clips/', 
                          " -nt rms -t -23 -ext wav -f")) %>% 
    arrange(clipbase)
  return(segment_df)
}

# create sub-dirs for BAS-services input and output
preparedirs <- function(segment_df) {
  
  # directories needed within each recording-clip folder 
  # subsubdirs <- c('BAS_input', 'BAS_output', 'textgrids', 'clips')
  subsubdirs <- c('clips')
  
  # define directories for each speaker
  clip_subdirs <- segment_df %>% 
    distinct(clipdir) %>% 
    expand(clipdir, subsubdirs) %>% 
    mutate(clip_subdirs = paste(clipdir, subsubdirs, sep = '/')) %>% 
    pull(clip_subdirs)
  
  # create dirs if needed
  walk(clip_subdirs, ~ dir.create(.x, recursive = T, showWarnings = F))
}

# run ffmpeg command to split wav file
create_clips <- function(ffcmds) {
  for (cmd in ffcmds) {
    cat('\n Run ffmpeg command: \n ', cmd, '\n')
    system(cmd)
  }
}

# use tuneR package to get the actual number of samples in each clip.
# this is important for MAUS. substract 1 sample, because count starts at 0.
get_n_samples <- function(datadir, wfile) {
  wfile <- paste0(datadir, '/clips/', wfile, '.wav')
  w <- tuneR::readWave(wfile)
  n_samples <- length(w) - 1
  return(n_samples)
}

# write transcription to file if file does not already exist; otherwise do nothing
write_if <- function(x, path, overwrite_csv = F) {
  if (file.exists(path)) {
    cat('\n file exists:', path, '\n')
    if (overwrite_csv == T) {
      cat('\n -----> overwrite \n')
      write_lines(x, path)
    }
  } else {
    cat('\n write ----->', path, '\n')
    write_lines(x, path)
  }
}

# write transcriptions to separate files.
# pmap cannot access columns by name.
# it can by position for n arguments: ..1, ..2, ..3, ..n
# or by position with only 2 arguments: .x, .y
# or by name creating a function explicitly:
# pmap(a, function(utterance, start_time, ...) paste(utterance, start_time)).
# see: https://stackoverflow.com/a/41871497
write_seg_transcription <- function(segment_df, overwrite_csv = F) {
  
  seg_transcription <- segment_df %>% 
    mutate(n_samples = map2_dbl(clipdir, clipbase, ~ get_n_samples(.x, .y)),
           maus_format = paste(0, n_samples, utterance, sep = ';'),
           # maus_csv_file = str_replace(clipname, 'wav$', 'csv'),
           maus_csv_file = paste0(clipdir, '/BAS_input/', clipbase, '.csv'))
  
  seg_transcription %>% 
    select(maus_format, maus_csv_file) %>%
    pmap(~ write_if(.x, .y, overwrite_csv))
}

# wrap previous functions
segmentation_pipeline <- function(datadir,
                                  eaffile,
                                  segment_proportion = 1,
                                  overwrite_csv = F,
                                  overwrite_wav = F,
                                  check_existing = T) {
  
  # read segments from eaf file
  segments <- get_segments(datadir, eaffile) %>% 
    slice_head(prop = segment_proportion)
  
  # lehen: only segments with speechact feature (for ffmpeg segmentation)
  # orain: sact-ik ez bada, 'libre' ezarri
  segments <- segments %>% 
    # -> deal with missing sact (fill or filter)
    mutate(speechact = if_else(is.na(speechact), 'libre', speechact)) %>%
    # filter(!is.na(speechact)) %>% 
    # -> deal with missing speaker_id (fill or filter)
    # mutate(speaker_id = if_else(is.na(speaker_id), speaker_ref, speaker_id)) %>% 
    # filter(!is.na(speaker_id)) %>% 
    select(-xfile)
  
  # convert T/F to ffmpeg y/n syntax
  if (overwrite_wav == T) {
    overwrite_wav <- 'y'
  } else {
    overwrite_wav <- 'n'
  }
  
  # add some output-file information
  segment_df <- prepare_outputs(datadir, segments, eaffile, overwrite_wav)
  full_segment_df <- segment_df
  
  # list all existing wav clips in speaker directories
  existing_clips <- segment_df %>% 
    distinct(clipdir) %>% 
    mutate(clipdir = paste0(clipdir, '/clips')) %>% 
    map(., list.files) %>% 
    unlist() %>% 
    str_replace('.wav$', '')
  
  # filter out existing clips
  if (check_existing == T) {
    segment_df <- segment_df %>% 
      filter(!clipbase %in% existing_clips)
  } else {segment_df <- segment_df}
  
  # create subdirectories for each speechact category,
  # with special dirs for BAS input/output
  preparedirs(segment_df)
  
  # split wav files into segments
  create_clips(segment_df$ffcmd)
  
  # write segment transcription in BPF format (for MAUS pipeline)
  # cat('\n\n Write segment transcriptions into individual files:', '\n')
  # write_seg_transcription(segment_df, overwrite_csv)
  
  cat('\n\n Finished segmenting', eaffile, '\n')
  return(full_segment_df)
}

# run segmentation for all .eaf files in a dir
segment_eaf <- function(datadir, segment_proportion = 1,
                        overwrite_csv = F, overwrite_wav = F,
                        check_existing = T, eaf_pattern = '') {
  
  # add ELAN .eaf extension to filter pattern.
  # by deafult, all eaf files in directory get processed.
  eaf_pattern <- paste0(eaf_pattern, '\\.eaf$')
  
  # get all .eaf files in datadir
  eaffiles <- list.files(datadir, pattern = eaf_pattern, recursive = T)
  
  # error handling:
  # wrap segmentation_pipeline() function so that the map() function doesn't break
  # https://www.r-bloggers.com/2020/08/handling-errors-using-purrrs-possibly-and-safely/
  possible_segmentation <- possibly(.f = segmentation_pipeline, otherwise = NULL)
  
  # run segmentation pipeline for each .eaf file
  segment_df <- map(eaffiles,
                    ~ possible_segmentation(datadir, .x,
                                            segment_proportion,
                                            overwrite_csv,
                                            overwrite_wav,
                                            check_existing))
  return(segment_df)
}

# run segmentation for all .eaf files in a dir
read_eaf <- function(datadir, eaf_pattern = '') {
  
  # add ELAN .eaf extension to filter pattern.
  # by deafult, all eaf files in directory get processed.
  eaf_pattern <- paste0(eaf_pattern, '\\.eaf$')
  
  # get all .eaf files in datadir
  eaffiles <- list.files(datadir, pattern = eaf_pattern, recursive = T)
  
  # better error handling
  possible_read <- possibly(.f = get_segments, otherwise = NULL, quiet = T)
  
  # read annotations in each .eaf file
  segment_df <- map(eaffiles,
                    ~ possible_read(datadir, .x))
  
  names(segment_df) <- eaffiles
  
  return(segment_df)
}

#' segment_eaf()
#'   segmentation_pipeline()
#'     get_segments()
#'     prepare_outputs()
#'     preparedirs()
#'     create_clips()
#'     write_seg_transcription()

