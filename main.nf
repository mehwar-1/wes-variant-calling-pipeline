#!/usr/bin/env nextflow

nextflow.enable.dsl=2

params.reads  = "$projectDir/testdata/sim_R{1,2}.fq.gz"
params.outdir = "results"
params.ref_dir   = "$projectDir/references/chr20_hg38"
params.fasta     = "${params.ref_dir}/Homo_sapiens_assembly38_chr20.fasta"
params.dbsnp     = "${params.ref_dir}/dbsnp_146_hg38_chr20_tso-only.vcf.gz"
params.mills     = "${params.ref_dir}/Mills_and_1000G_gold_standard_indels_hg38_chr20.vcf.gz"

process FASTP {
    container 'quay.io/biocontainers/fastp:0.23.2--h79da9fb_0'
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
    container 'quay.io/biocontainers/fastqc:0.11.9--0'
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
    container 'quay.io/biocontainers/bwa:0.7.17--h5bf99c6_8'
    containerOptions "-v ${params.ref_dir}:${params.ref_dir}"
    cpus 2
    memory '3 GB'
    time '30m'
    tag "$sample_id"

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("${sample_id}.sam")

    script:
    """
    bwa mem -M -t ${task.cpus} -R "@RG\\tID:${sample_id}\\tSM:${sample_id}\\tPL:ILLUMINA\\tLB:${sample_id}" ${params.fasta} ${reads[0]} ${reads[1]} > ${sample_id}.sam
    """
}

process SORT_INDEX {
    container 'quay.io/biocontainers/samtools:1.19.2--h50ea8bc_1'
    cpus 2
    memory '3 GB'
    time '30m'
    tag "$sample_id"
    publishDir "${params.outdir}/aligned", mode: 'copy'

    input:
    tuple val(sample_id), path(sam)

    output:
    tuple val(sample_id), path("${sample_id}.sorted.bam"), path("${sample_id}.sorted.bam.bai")

    script:
    """
    samtools sort -@ ${task.cpus} -o ${sample_id}.sorted.bam ${sam}
    samtools index ${sample_id}.sorted.bam
    """
}

process MARK_DUPLICATES {
    container 'broadinstitute/gatk:4.7.0.0'
    containerOptions "-v ${params.ref_dir}:${params.ref_dir}"
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
    container 'broadinstitute/gatk:4.7.0.0'
    containerOptions "-v ${params.ref_dir}:${params.ref_dir}"
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
    container 'broadinstitute/gatk:4.7.0.0'
    containerOptions "-v ${params.ref_dir}:${params.ref_dir}"
    cpus 2
    memory '3500 MB'
    time '45m'
    tag "$sample_id"
    publishDir "${params.outdir}/variants", mode: 'copy'

    input:
    tuple val(sample_id), path(bam)

    output:
    tuple val(sample_id), path("${sample_id}.vcf.gz"), path("${sample_id}.vcf.gz.tbi")

    script:
    """
    gatk HaplotypeCaller \
        -I ${bam} -R ${params.fasta} \
        -O ${sample_id}.vcf.gz
    """
}

process VARIANT_FILTER {
    container 'broadinstitute/gatk:4.7.0.0'
    containerOptions "-v ${params.ref_dir}:${params.ref_dir}"
    cpus 1
    memory '2 GB'
    time '15m'
    tag "$sample_id"
    publishDir "${params.outdir}/variants_filtered", mode: 'copy'

    input:
    tuple val(sample_id), path(vcf), path(tbi)

    output:
    tuple val(sample_id), path("${sample_id}.filtered.vcf.gz")

    script:
    """
    gatk VariantFiltration \
        -R ${params.fasta} \
        -V ${vcf} \
        --filter-expression "QD < 2.0" --filter-name "QD2" \
        --filter-expression "FS > 60.0" --filter-name "FS60" \
        --filter-expression "MQ < 40.0" --filter-name "MQ40" \
        --filter-expression "SOR > 3.0" --filter-name "SOR3" \
        -O ${sample_id}.filtered.vcf.gz
    """
}

workflow {
    read_pairs_ch = Channel.fromFilePairs(params.reads)

    FASTP(read_pairs_ch)
    FASTQC(FASTP.out.trimmed_reads)
    BWA_ALIGN(FASTP.out.trimmed_reads)
    SORT_INDEX(BWA_ALIGN.out)
    MARK_DUPLICATES(SORT_INDEX.out)
    BQSR(MARK_DUPLICATES.out)
    HAPLOTYPE_CALLER(BQSR.out)
    VARIANT_FILTER(HAPLOTYPE_CALLER.out)
}
