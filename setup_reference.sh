#!/bin/bash
# Sets up the reference genome, known-sites files, and test reads used by
# this pipeline. Run this once before your first `nextflow run main.nf`.

set -e

echo "Downloading chr20 reference bundle from nf-core/test-datasets..."
mkdir -p references
git clone --single-branch --branch sarek \
    https://github.com/nf-core/test-datasets.git /tmp/test-datasets-tmp
cp -r /tmp/test-datasets-tmp/reference/chr20_hg38 references/
rm -rf /tmp/test-datasets-tmp
echo "Reference bundle ready in ./references/chr20_hg38"

echo "Generating simulated paired-end test reads from the reference..."
mkdir -p testdata
wgsim -1 150 -2 150 -N 50000 -e 0.01 -r 0.001 \
    references/chr20_hg38/Homo_sapiens_assembly38_chr20.fasta \
    testdata/sim_R1.fq testdata/sim_R2.fq
gzip -f testdata/sim_R1.fq testdata/sim_R2.fq
echo "Test reads ready in ./testdata/"

echo "Setup complete. Run: nextflow run main.nf"
