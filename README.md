# WES Variant-Calling Pipeline

A Nextflow rebuild of the whole-exome sequencing analysis from my MS thesis
on host genetic variation in COVID-19 severity. The original work was a
manual, script-by-script analysis. This repository turns it into something
someone else could actually run, and upgrades the variant-calling stage
while doing it.

## Status: core pipeline working, verified end to end

Reads go in, a VCF with real variant calls comes out. Quality control,
alignment, duplicate marking, base quality recalibration and variant calling
all run successfully, in sequence, through Nextflow. Docker containerization
and the annotation stage are not built yet. See the roadmap below for
exactly what is and is not done.

## Background

The thesis cohort included 58 individuals, six of whom were sequenced by
whole-exome sequencing. Read processing and variant calling on that data
produced an initial call set of 3,418,374 variants. Quality filtering brought
this down to 229,834 high-confidence calls, and functional prioritisation
narrowed it further to 23 deleterious, homozygous SNPs. Three of these, in
ACAT2, TMPRSS2 and TSPAN8, were linked to the SARS-CoV-2 infection pathway
through Gene Ontology analysis.

That analysis used a fairly standard pipeline for the time: FastQC and FASTP
for read QC, BWA for alignment, SAMtools for sorting and deduplication, and a
more basic variant-calling step feeding into ANNOVAR for annotation.
Revisiting it now, one part of that pipeline was worth changing, not just
re-wrapping.

## What changed, and why

Quality control, alignment and duplicate handling hold up fine as they were.
FastQC and FASTP remain reasonable choices for QC, BWA-MEM is still a
standard aligner. None of these needed replacing.

Variant calling was the real gap. The original analysis used a simpler
calling approach, without duplicate marking or base quality recalibration as
separate, explicit steps. GATK's Best Practices workflow handles both
directly, and HaplotypeCaller's local reassembly around candidate variant
sites gives more reliable calls than the earlier approach did, particularly
for indels. The calling stage is rebuilt around GATK now, not carried over
unchanged.

| Stage | Tool | Status |
|---|---|---|
| Quality control | FastQC, FASTP | Implemented, verified |
| Alignment | BWA-MEM | Implemented, verified |
| Duplicate marking | GATK MarkDuplicates | Implemented, verified |
| Base quality recalibration | GATK BQSR | Implemented, verified |
| Variant calling | GATK HaplotypeCaller | Implemented, verified |
| Annotation | ANNOVAR | Not yet built into the Nextflow workflow |
| Containerization | Docker | Not yet built |

## How this was actually tested

Real patient data cannot go anywhere near this repository, so testing used a
small reference genome (chromosome 20 only, from nf-core's own test data
collection, paired with matching, contig-verified known-sites files for
dbSNP and Mills indels) and paired-end reads generated directly from that
same reference with `wgsim`.

Generating reads from the reference itself, rather than sourcing test reads
from elsewhere, was a deliberate choice. Early attempts used generic test
FASTQ files from a different part of the same test-data repository, and they
mapped at a 0% alignment rate, useful information in itself, but not usable
as a pipeline test. Reads simulated directly from the chromosome 20 sequence
align to it by construction, which made it possible to actually exercise
every stage, including base recalibration and variant calling, rather than
stall at alignment.

Two contig-naming issues came up during this process, worth naming plainly:
a first reference and known-sites pairing failed silently on chromosome
naming before any code ran, and a second, found only by comparing the FASTA
header against the VCF's own chromosome column by hand. Both were confirmed
resolved before the pipeline was trusted to run.

## Known limitations

This is a working pipeline, not a finished one. Specifically:

- Coverage in testing was shallow (roughly 2x), enough to confirm the
  pipeline runs correctly end to end, not representative of real diagnostic
  WES depth.
- Variant calls have not been benchmarked against a known-truth set (such as
  Genome in a Bottle). Correctness of the pipeline's logic is demonstrated;
  accuracy of its calls against ground truth is not yet.
- GATK currently runs from a manually activated conda environment. The
  pipeline does not yet declare this dependency itself, which means running
  it correctly still depends on the user remembering to activate the right
  environment first. Fixing this with Nextflow's built-in `conda` directive
  is the next real piece of work.
- Annotation (ANNOVAR) and containerization (Docker) are documented as
  intended but not yet implemented.

## Roadmap

- [x] Document the original manual pipeline and thesis results
- [x] Identify where the pipeline needed a real methodological update, not
      just a Nextflow wrapper
- [x] Implement QC, alignment and processing steps in Nextflow
- [x] Add GATK-based duplicate marking, BQSR and calling
- [x] Verify the pipeline end to end on a correctly matched reference and
      test data
- [ ] Make GATK's environment a declared dependency, not a manual step
- [ ] Add ANNOVAR-based annotation as a Nextflow process
- [ ] Containerize each step with Docker
- [ ] Benchmark variant calls against a known-truth dataset
- [ ] Record runtime and resource use per step on a larger test set

## Why this exists

The scientific question stays the same as the thesis: which host genetic
variants plausibly relate to COVID-19 severity. What changes here is how the
analysis gets done. Rebuilding the pipeline in Nextflow shows I can use a
workflow manager. Rebuilding the calling stage around GATK, and actually
finding and fixing the reference-matching and environment problems that came
with it, shows the harder part: getting a modern bioinformatics pipeline to
run correctly, not just exist on paper.

The scientific results referenced above come from the original thesis
analysis. This repository is a software reimplementation of that same
underlying question, not a new set of findings.

## Author

Syeda Mehwar Masooma Shah — MS Molecular Virology, BS Bioinformatics,
COMSATS University Islamabad