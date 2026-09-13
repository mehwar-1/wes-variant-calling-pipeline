# WES Variant-Calling Pipeline

A Nextflow and Docker rebuild of the whole-exome sequencing analysis from my
MS thesis on host genetic variation in COVID-19 severity. The original work
was done as a manual, script-by-script analysis. This repository turns it
into something someone else could actually run.

## Status: in progress

The pipeline logic below reflects the intended final design, not what is
implemented yet. I am documenting the plan before writing the code, partly
so the scope stays honest as the project develops. See the roadmap for where
things actually stand.

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
more basic variant-calling step feeding into ANNOVAR for annotation. Revisiting
it now, one part of that pipeline is worth changing, not just re-wrapping.

## What is changing, and why

Quality control, alignment and annotation hold up fine as they are. FastQC
and FASTP remain reasonable choices for QC, BWA-MEM is still a standard
aligner, and ANNOVAR still does its job for annotation. None of these need
replacing.

Variant calling is a different matter. The original analysis used a simpler
calling approach without duplicate marking or base quality recalibration
built in as separate, explicit steps. GATK's Best Practices workflow handles
both directly, and HaplotypeCaller's local reassembly around candidate
variant sites gives more reliable calls than the earlier approach did,
particularly for indels. So the calling stage is being rebuilt around GATK,
not carried over unchanged.

| Stage | Tool | Change from thesis version |
|---|---|---|
| Quality control | FastQC, FASTP | Unchanged |
| Alignment | BWA-MEM | Unchanged |
| Alignment processing | SAMtools | Unchanged |
| Duplicate marking | GATK MarkDuplicates | New |
| Base quality recalibration | GATK BQSR | New |
| Variant calling | GATK HaplotypeCaller | Replaces earlier calling step |
| Variant filtering | GATK hard-filtering | New, replaces informal thresholding |
| Annotation | ANNOVAR | Unchanged |

## Roadmap

- [x] Document the original manual pipeline and thesis results
- [x] Identify where the pipeline needs a real methodological update, not
      just a Nextflow wrapper
- [ ] Implement QC, alignment and processing steps in Nextflow
- [ ] Add GATK-based duplicate marking, BQSR, calling and filtering
- [ ] Containerize each step with Docker
- [ ] Add a small public test dataset so the pipeline runs end to end without
      the original patient data
- [ ] Record runtime and resource use for each step

## Why this exists

The scientific question stays the same as the thesis: which host genetic
variants plausibly relate to COVID-19 severity. What changes here is how the
analysis gets done. Re-running the exact original pipeline in Nextflow would
prove I can use a workflow manager. Updating the calling step to GATK while
doing that shows something closer to what the pipeline should have looked
like with a few more years of tooling behind it.

The scientific results referenced above come from the original thesis
analysis. This repository is a software reimplementation of that same
underlying question, not a new set of findings.

## Author

Syeda Mehwar Masooma Shah — MS Molecular Virology, BS Bioinformatics,
COMSATS University Islamabad
