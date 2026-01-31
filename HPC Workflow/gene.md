I can't edit the gene_catalog.htm, please upload the md file.

Try to review the coverM code or add the update:

```bash
coverm genome \
  --coupled \
    XX1.fastq.gz \
    XX2.fastq.gz \
  --genome-fasta-directory \
    drep_out/ \
  --genome-fasta-extension fa \
  --discard-unmapped \
  --mapper bwa-mem \
  -t 8 \
  -m mean relative_abundance covered_fraction reads_per_base rpkm tpm \
  -o /CoverM/output_coverm.tsv
 ```