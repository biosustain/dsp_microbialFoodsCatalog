import pandas as pd
from Bio import SeqIO
import matplotlib.pyplot as plt
from collections import Counter
import os


# 1) INPUT FILES


FASTA_FILE = "all_genes.faa"
CLUSTERS_TSV = "mmseqs_clusters.tsv"

# Numbers from your results (used for summary plot)
TOTAL_PREDICTED_GENES = 4_800_000
NON_REDUNDANT_GENES = 2_088_351

# Output directory
OUTDIR = "gene_catalog_plots"
os.makedirs(OUTDIR, exist_ok=True)


# 2) READ FASTA → gene lengths


gene_lengths = []
for record in SeqIO.parse(FASTA_FILE, "fasta"):
    gene_lengths.append(len(record.seq))


# 3) READ MMseqs clusters


clusters = pd.read_csv(
    CLUSTERS_TSV,
    sep="\t",
    header=None,
    names=["representative", "member"]
)

cluster_sizes = clusters.groupby("representative").size()


# 4) PLOTS


#Gene length distribution
plt.figure(figsize=(7,5))
plt.hist(gene_lengths, bins=100, log=True)
plt.xlabel("Protein length (aa)")
plt.ylabel("Count (log scale)")
plt.title("Gene length distribution")
plt.tight_layout()
plt.savefig(f"{OUTDIR}/gene_length_distribution.png")
plt.close()

#Cluster size distribution
plt.figure(figsize=(7,5))
plt.hist(cluster_sizes, bins=100, log=True)
plt.xlabel("Cluster size (# genes)")
plt.ylabel("Count (log scale)")
plt.title("MMseqs2 cluster size distribution")
plt.tight_layout()
plt.savefig(f"{OUTDIR}/cluster_size_distribution.png")
plt.close()

#Redundancy reduction barplot
plt.figure(figsize=(5,5))
plt.bar(
    ["Predicted genes", "Non-redundant genes"],
    [TOTAL_PREDICTED_GENES, NON_REDUNDANT_GENES]
)
plt.ylabel("Number of genes")
plt.title("Gene catalog redundancy reduction")
plt.tight_layout()
plt.savefig(f"{OUTDIR}/redundancy_reduction.png")
plt.close()


# SAVE STATS

with open(f"{OUTDIR}/summary_stats.txt", "w") as f:
    f.write(f"Total predicted genes: {TOTAL_PREDICTED_GENES}\n")
    f.write(f"Non-redundant genes: {NON_REDUNDANT_GENES}\n")
    f.write(f"Redundancy reduction: "
            f"{100 * (1 - NON_REDUNDANT_GENES / TOTAL_PREDICTED_GENES):.2f}%\n")
    f.write(f"Mean gene length: {sum(gene_lengths)/len(gene_lengths):.2f} aa\n")
    f.write(f"Median gene length: {sorted(gene_lengths)[len(gene_lengths)//2]} aa\n")
