#!/usr/bin/env nextflow

nextflow.enable.dsl=2

params.reads  = "$projectDir/testdata/sim_R{1,2}.fq.gz"
params.outdir = "results"
params.ref_dir   = "$projectDir/references/chr20_hg38"
params.fasta     = "${params.ref_dir}/Homo_sapiens_assembly38_chr20.fasta"
params.dbsnp     = "${params.ref_dir}/dbsnp_146_hg38_chr20_tso-only.vcf.gz"
params.mills     = "${params.ref_dir}/Mills_and_1000G_gold_standard_indels_hg38_chr20.vcf.gz"

process FASTP {
    cpus 2
    memory '1 GB'
    time '30m'

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
    cpus 1
    memory '2 GB'
    time '15m'

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
process BWA_ALIGN {
    cpus 2
    memory '3 GB'
    time '30m'
    tag "$sample_id"
    publishDir "${params.outdir}/aligned", mode: 'copy'

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("${sample_id}.sorted.bam"), path("${sample_id}.sorted.bam.bai")

    script:
    """
    bwa mem -t ${task.cpus} -R "@RG\\tID:${sample_id}\\tSM:${sample_id}\\tPL:ILLUMINA\\tLB:${sample_id}" ${params.fasta} ${reads[0]} ${reads[1]} | \
        samtools sort -@ ${task.cpus} -o ${sample_id}.sorted.bam
    samtools index ${sample_id}.sorted.bam
    """
}

process MARK_DUPLICATES {
    cpus 2
    memory '3 GB'
    time '30m'
    tag "$sample_id"
    publishDir "${params.outdir}/dedup", mode: 'copy'

    input:
    tuple val(sample_id), path(bam), path(bai)

    output:
    tuple val(sample_id), path("${sample_id}.dedup.bam"), path("${sample_id}.dedup.bam.bai")

    script:
    """
    gatk MarkDuplicates -I ${bam} -O ${sample_id}.dedup.bam -M ${sample_id}.metrics.txt
    samtools index ${sample_id}.dedup.bam
    """
}

process BQSR {
    cpus 2
    memory '3 GB'
    time '30m'
    tag "$sample_id"
    publishDir "${params.outdir}/bqsr", mode: 'copy'

    input:
    tuple val(sample_id), path(bam), path(bai)

    output:
    tuple val(sample_id), path("${sample_id}.recal.bam")

    script:
    """
    gatk BaseRecalibrator \
        -I ${bam} -R ${params.fasta} \
        --known-sites ${params.dbsnp} \
        --known-sites ${params.mills} \
        -O ${sample_id}.recal.table

    gatk ApplyBQSR \
        -I ${bam} -R ${params.fasta} \
        --bqsr-recal-file ${sample_id}.recal.table \
        -O ${sample_id}.recal.bam
    """
}

process HAPLOTYPE_CALLER {
    cpus 2
    memory '3500 MB'
    time '45m'
    tag "$sample_id"
    publishDir "${params.outdir}/variants", mode: 'copy'

    input:
    tuple val(sample_id), path(bam)

    output:
    path "${sample_id}.vcf.gz"

    script:
    """
    gatk HaplotypeCaller \
        -I ${bam} -R ${params.fasta} \
        -O ${sample_id}.vcf.gz
    """
}

workflow {
    read_pairs_ch = Channel.fromFilePairs(params.reads)

    FASTP(read_pairs_ch)
    FASTQC(FASTP.out.trimmed_reads)
    BWA_ALIGN(FASTP.out.trimmed_reads)
    MARK_DUPLICATES(BWA_ALIGN.out)
    BQSR(MARK_DUPLICATES.out)
    HAPLOTYPE_CALLER(BQSR.out)
}
