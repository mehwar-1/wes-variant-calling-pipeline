#!/usr/bin/env nextflow

nextflow.enable.dsl=2

params.reads  = "/home/mehwar1/test-datasets/testdata/dummy/normal/dummy_n_R{1,2}_xxx.fastq.gz"
params.outdir = "results"

process FASTP {
    tag "$sample_id"
    publishDir "${params.outdir}/fastp", mode: 'copy'

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("${sample_id}_trimmed_{1,2}.fastq.gz"), emit: trimmed_reads
    path "${sample_id}_fastp.json"
    path "${sample_id}_fastp.html"

    script:
    """
    fastp \
        -i ${reads[0]} -I ${reads[1]} \
        -o ${sample_id}_trimmed_1.fastq.gz -O ${sample_id}_trimmed_2.fastq.gz \
        --json ${sample_id}_fastp.json \
        --html ${sample_id}_fastp.html
    """
}

process FASTQC {
    tag "$sample_id"
    publishDir "${params.outdir}/fastqc", mode: 'copy'

    input:
    tuple val(sample_id), path(reads)

    output:
    path "*_fastqc.{zip,html}"

    script:
    """
    fastqc ${reads}
    """
}

workflow {
    read_pairs_ch = Channel.fromFilePairs(params.reads)

    FASTP(read_pairs_ch)
    FASTQC(FASTP.out.trimmed_reads)
}