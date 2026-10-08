#!/bin/bash
# Sets up the reference genome, known-sites files, exome target intervals,
# and test reads used by this pipeline. Run this once before your first
# `nextflow run main.nf`.

set -e
command -v samtools >/dev/null || { echo "ERROR: samtools not found"; exit 1; }
command -v wgsim >/dev/null || { echo "ERROR: wgsim not found"; exit 1; }

echo "Downloading chr20 reference bundle and target intervals from nf-core/test-datasets..."
mkdir -p references
rm -rf /tmp/test-datasets-tmp
git clone --depth 1 --single-branch --branch sarek \
    https://github.com/nf-core/test-datasets.git /tmp/test-datasets-tmp
cp -r /tmp/test-datasets-tmp/reference/chr20_hg38 references/
cp /tmp/test-datasets-tmp/testdata/umi-dna/tso/tso500_chr20_hg38.bed references/chr20_hg38/
rm -rf /tmp/test-datasets-tmp
echo "Reference bundle ready in ./references/chr20_hg38"
echo "Exome target intervals (TSO500 panel, chr20) ready in ./references/chr20_hg38"

echo "Extracting target-region sequence from the reference (needed so simulated reads actually land inside the exome panel, not spread across the whole chromosome)..."
while read -r chr start end; do
    samtools faidx references/chr20_hg38/Homo_sapiens_assembly38_chr20.fasta "${chr}:$((start+1))-${end}"
done < references/chr20_hg38/tso500_chr20_hg38.bed > references/chr20_hg38/target_regions.fa
echo "Target-region sequence ready: references/chr20_hg38/target_regions.fa"

echo "Generating simulated paired-end test reads from the target regions..."
mkdir -p testdata
wgsim -S 42 -1 150 -2 150 -N 50000 -e 0.01 -r 0.001 \
    references/chr20_hg38/target_regions.fa \
    testdata/sim_R1.fq testdata/sim_R2.fq
gzip -f testdata/sim_R1.fq testdata/sim_R2.fq
echo "Test reads ready in ./testdata/"

echo "Setup complete. Run: nextflow run main.nf"