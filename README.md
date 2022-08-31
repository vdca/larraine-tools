# Tools in language documentation

Part of the [Basque Summer Tutorial in Language Documentation](https://basquesummertutorial.eus/), Larraine 2022.

- [Set-up](#set-up)
- [Recipes](#recipes)
- [Resources](#resources)

## Set-up

### Installation

To make the most of the sessions, please bring your laptop with the following software installed:
1. [ELAN](https://archive.mpi.nl/tla/elan).
2. [Praat](https://www.fon.hum.uva.nl/praat/).
3. [Audacity](https://www.audacityteam.org/).
4. Optional (advanced):
	1. [R](https://cloud.r-project.org/) + [RStudio Desktop](https://www.rstudio.com/products/rstudio/download/#download) + some R packages ([tidyverse](https://www.tidyverse.org/), [dalejbarr/elan](https://github.com/dalejbarr/elan), [knitr](https://rdocumentation.org/packages/knitr/versions/1.39), [DT](https://rstudio.github.io/DT/)). Installation tips [here](https://r4ds.had.co.nz/introduction.html#prerequisites) and [here](https://www.datacamp.com/tutorial/installing-R-windows-mac-ubuntu).
	2. [ffmpeg](https://ffmpeg.org/).

### Quick check

To check that you have a working version for each program:
- download the sample files under the [data](https://github.com/vdca/larraine-tools/tree/master/data) folder.
- **ELAN:**
	- `File > New` + select the `sample2.mp4` file and/or the `sample2.wav` file.
	- click the play button
	- can you see the video / hear the audio?
- **Praat:**
	- `Open > Read from file...` + select the `sample1.wav` file.
	- click `View & Edit` (menu on the right)
	- click any of the gray bars at the bottom of the new window
	- can you hear the audio?
- **Audacity:**
	- `File > Open` + select the `sample1.wav` file.
	- click the play button
	- can you hear the audio?

## Recipes

This is a summary of the main procedures explained during the course.

### Pipeline

After I do some field-recording, I usually follow this pipeline:
1. Backup SD card.
2. Write metadata in 3 different `.tsv` tables (locations, speakers, recordings).
3. Basic signal processing (channel selection (e.g. stereo to mono), amplitude normalisation, etc.).
4. Utterance-level segmentation in ELAN (usually manually, but sometimes automatic, using silence-detection).
5. Transcription in ELAN.
6. Forced-alignment using [MAUS](https://www.bas.uni-muenchen.de/Bas/BasMAUS.html) (via [emuR](https://github.com/IPS-LMU/emuR); [MFA](https://montreal-forced-aligner.readthedocs.io/en/latest/user_guide/index.html) is an excellent alternative) for word/syllable/phone-level segmentation.
7. Gather all transcribed segments, combine with metadata, and create an html [DataTables](https://datatables.net/) table (via the [DT](https://rstudio.github.io/DT/) package in R) to quickly filter and browse the data.

Your individual research interests will probably require a different workflow. Think about it and write it down!

### Tier preparation

In ELAN, all your segmentations, annotations, transcriptions are contained within tiers (read more about tiers in the [official documentation](https://www.mpi.nl/corpus/html/elan/ch02.html#Sec_Basic_Information_Annotations_tiers_and_linguistic_types)).
Setting up your tier hierarchy requires two steps:
1. defining tier _types_,
2. creating the actual _tiers_.

For illustration purposes, we will create three tier types:
- `utterance_type`: our top-level tier will be of this type; the segments created within this tier will be defined in temporal terms (start and end set in milliseconds).
- `speechact_type`: tiers with this type are not temporally defined, but symbolically linked to an `utterance_type` tier.
- `translation_type`: this type of tier is also symbolically linked to an `utterance_type` tier.

Tier types are defined as follows:
- `Type > Add New Tier Type...`
- `Type Name`: choose a name (e.g. `utterance_type`...)
- `Stereotype`: the temporally-defined top-level type (`utterance_type`) will have a `None` stereotype; the others (`speechact_type`, `translation_type`) will have a `Symbolic Association` stereotype.

There's an additional option which can be useful for tier types like `speechact_type`: controlled vocabularies. If you will be using a closed set of tags within a given tier, this option ensures that you consistently use a tag contained in the set, so you avoid misspellings, etc. Before you choose a controlled vocabulary within the `Add New Tier Type` menu, you need to actually create a controlled vocabulary:
- `Edit > Edit Controlled Vocabularies`
- Give the Controlled Vocabulary (CV) a name.
- Enter the set of possible values one by one.

You are now ready to create the tiers: that's where the segmentation and transcription will be stored.
- `Tier > Add New Tier...`
- Choose a `Tier Name`; for instance, you may want to create three tiers:
    - `orthographic` tier: for the transcription of utterances.
    - `speechact` tier, or `style` tier: for a categorisation of utterances (e.g. declarative, yes/no-question, etc.; or casual, formal, etc.).
    - `translation_eng` tier: for an English translation (or some other language).
- Choose a `Parent Tier`: e.g. the `orthographic` tier will have no parent, but the `translation_eng` tier will have `orthographic` as its parent.
- Choose a `Tier Type`: one of the types you have previously created.

### Segmentation

Manual segmentation:
- `Options > Segmentation Mode`
- Play/pause the recording (using `shift+space` or some other shortcut).
- Define the start and end of each segment using the `enter` key.
- If necessary, manually adjust the segment boundaries using the cursor.

Automatic segmentation:
- `Options > Annotation Mode`
- Go to `Recognizers` tab.
- Choose `Silence Recognizer MPI-PL` (for example).
- Set each of the three parameters depending on your needs; e.g.:
    - silence level = `-30 dB`
    - minimal silence duration = `200 ms`
    - minimal non silence duration = `300 ms`
- Click on `Start`.
- Click on `Create Tier(s)...`.
- Select an existing tier (for instance, the `orthographic` tier), or create a new one.

### Transcription

Once you have defined some segments (manually or automatically), you can go to `Options > Transcription Mode` and start transcribing and/or tagging the segments.

The first time you go to the Transcription Mode, you need to:
- click on the `Configure...` button (left-hand side),
- select the tier types you will be working with (one per column),
- click on `Select tiers...` if you have more than one tier per type.

Afterwards, the procedure is very straightforward:
- click on a cell (each row corresponds to a segment you have previously defined),
- press the `tab` key to listen to the segment,
- type in your transcription,
- or select one of the controlled-vocabulary tags (with the up/down arrows), if available,
- press `enter` to continue with the next segment/row.

For particularly challenging segments, you may want to try one of the following options (on the left-hand side menu):
- `Loop Mode`: it plays the segment in loop (while you work on the transcription).
- `Rate`: it allows you to slow down the playback.

## Resources

All the software mentioned above is open-source, free, and cross-platform; this fosters an extensive community-driven set of resources.
A quick search in the internet will show you a bunch of tutorials, how-tos, scripts, templates, documentation, etc.
Learning from other people's tips and tricks is great, but do remember to write down your own workflow.
A good place to store that kind of notes and reminders are [Zettelkasten](https://en.wikipedia.org/wiki/Zettelkasten)-style documents (which are not confined to a particular research-project, and can be managed with software such as [Obsidian](https://obsidian.md/) or [Zettlr](https://www.zettlr.com/)).

### ELAN
- Official documentation: short manual ([pdf](https://www.mpi.nl/tools/elan/docs/How-to-pages_9.pdf)), full manual ([html](https://www.mpi.nl/tools/elan/docs/manual/index.html), [pdf](https://www.mpi.nl/tools/elan/docs/ELAN_manual.pdf)), how-to guide ([pdf](https://www.mpi.nl/tools/elan/docs/How-to-pages_9.pdf)).
- [Some third-party resources](https://archive.mpi.nl/tla/elan/thirdparty) (tutorials, templates, scripts) listed by the creators of ELAN.
- [Helper tools](https://github.com/CoEDL/elan-helpers) (in Python) by CoEDL.

### Praat
- Official [introduction](https://www.fon.hum.uva.nl/praat/manual/Intro.html).
- Official [manual on scripting](https://www.fon.hum.uva.nl/praat/manual/Scripting.html).
- Some third-party [tutorials](https://www.fon.hum.uva.nl/praat/manualsByOthers.html).
- A [repository of scripts](http://phonetics.linguistics.ucla.edu/facilities/acoustic/praat.html) (UCLA).

### R
- Many-many online courses, tutorials, manuals on a range of topics (some may be closer to linguistics than others).
- Domain-general book (online or paper) by Hadley Wickham, Mine Çetinkaya-Rundel, and Garrett Grolemund: [R for Data Science](https://r4ds.hadley.nz/).
- Book by Bodo Winter: [Statistics for Linguists: An Introduction Using R](https://www.routledge.com/Statistics-for-Linguists-An-Introduction-Using-R/Winter/p/book/9781138056091#).
- Resources by Guilherme D. Garcia: [shorter tutorials](https://guilhermegarcia.github.io/resources.html), and a book ([Data visualization and analysis in second language research](https://guilhermegarcia.github.io/dvaslr.html)).
