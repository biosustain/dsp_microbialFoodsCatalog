# =========================
# LIBRARIES
# =========================
library(tidyverse)
library(vegan)3
library(scales)

# =========================
# INPUT FILES
# =========================
files <- c(
  "ο1_drep_mag_abundance.tsv",
  "ο2_drep_mag_abundance.tsv",
  "ο3_drep_mag_abundance.tsv",
  "ο4_drep_mag_abundance.tsv"
)

# =========================
# OUTPUT DIRECTORIES
# =========================
dir.create("diversity_results", showWarnings = FALSE)
dir.create("diversity_results/tables", showWarnings = FALSE)
dir.create("diversity_results/plots", showWarnings = FALSE)

# =========================
# READ CoverM FILES
# =========================
read_coverm <- function(path){
  df <- readr::read_tsv(path, show_col_types = FALSE)
  
  ra_col <- grep("Relative Abundance \\(%\\)", names(df), value = TRUE)[1]
  if (is.na(ra_col)) stop("No Relative Abundance (%) column in: ", path)
  
  sample <- stringr::str_replace(
    tools::file_path_sans_ext(basename(path)),
    "_mag_abundance$", ""
  )
  
  df %>%
    transmute(
      sample = sample,
      genome = Genome,
      relative_abundance = as.numeric(.data[[ra_col]])
    ) %>%
    filter(genome != "unmapped") %>%
    mutate(relative_abundance = replace_na(relative_abundance, 0))
}

df <- purrr::map_dfr(files, read_coverm)

write_tsv(df, "diversity_results/tables/relative_abundance_long.tsv")

# =========================
# ALPHA DIVERSITY
# =========================
alpha_df <- df %>%
  group_by(sample) %>%
  summarise(
    richness = sum(relative_abundance > 0),
    shannon  = vegan::diversity(relative_abundance, index = "shannon"),
    .groups = "drop"
  )

write_tsv(alpha_df, "diversity_results/tables/alpha_diversity.tsv")

# Alpha plots
p_rich <- ggplot(alpha_df, aes(sample, richness)) +
  geom_col(fill = "#4DAF4A") +
  coord_flip() +
  theme_minimal(base_size = 14) +
  labs(
    title = "Alpha diversity: Richness",
    x = "Sample",
    y = "Number of MAGs"
  )

p_shan <- ggplot(alpha_df, aes(sample, shannon)) +
  geom_col(fill = "#377EB8") +
  coord_flip() +
  theme_minimal(base_size = 14) +
  labs(
    title = "Alpha diversity: Shannon index",
    x = "Sample",
    y = "Shannon diversity"
  )

ggsave("diversity_results/plots/alpha_richness.png", p_rich, width = 7, height = 4, dpi = 300)
ggsave("diversity_results/plots/alpha_shannon.png",  p_shan, width = 7, height = 4, dpi = 300)

# =========================
# BETA DIVERSITY (Bray–Curtis + PCoA)
# =========================
mat <- df %>%
  pivot_wider(
    names_from = genome,
    values_from = relative_abundance,
    values_fill = 0
  ) %>%
  column_to_rownames("sample")

beta_bc <- vegan::vegdist(mat, method = "bray")

write.table(
  as.matrix(beta_bc),
  "diversity_results/tables/beta_braycurtis_matrix.tsv",
  sep = "\t",
  quote = FALSE
)

pcoa <- cmdscale(beta_bc, eig = TRUE, k = 2)

pcoa_df <- tibble(
  sample = rownames(pcoa$points),
  PC1 = pcoa$points[,1],
  PC2 = pcoa$points[,2]
)

p_beta <- ggplot(pcoa_df, aes(PC1, PC2, label = sample)) +
  geom_point(size = 4, color = "#E41A1C") +
  geom_text(vjust = -0.8, size = 4) +
  theme_minimal(base_size = 14) +
  labs(
    title = "Beta diversity: PCoA (Bray–Curtis)",
    x = "PC1",
    y = "PC2"
  )

ggsave("diversity_results/plots/beta_PCoA_braycurtis.png", p_beta, width = 6, height = 5, dpi = 300)
# =========================
# COMMUNITY COMPOSITION (Top 10 + Other)
#   - force "Other" to be grey
# =========================
# =========================
# COMMUNITY COMPOSITION (Top 10 + Other)  ✅ Other always present + grey
# =========================
topN <- 10

top_genomes <- df %>%
  group_by(genome) %>%
  summarise(total = sum(relative_abundance), .groups = "drop") %>%
  arrange(desc(total)) %>%
  slice_head(n = topN) %>%
  pull(genome)

comp_df <- df %>%
  mutate(group = if_else(genome %in% top_genomes, genome, "Other")) %>%
  group_by(sample, group) %>%
  summarise(relative_abundance = sum(relative_abundance), .groups = "drop") %>%
  group_by(sample) %>%
  mutate(percent = 100 * relative_abundance / sum(relative_abundance)) %>%
  ungroup()

# 🔥 ensure "Other" exists in EVERY sample (even if 0)
all_samples <- sort(unique(comp_df$sample))
comp_df <- comp_df %>%
  complete(sample = all_samples,
           group = c(top_genomes, "Other"),
           fill = list(relative_abundance = 0, percent = 0)) %>%
  mutate(group = factor(group, levels = c(top_genomes, "Other")))

# colors: topN palette + grey for Other
library(RColorBrewer)
pal <- brewer.pal(max(3, min(length(top_genomes), 12)), "Set3")
if (length(top_genomes) > length(pal)) pal <- rep(pal, length.out = length(top_genomes))
mag_colors <- c(setNames(pal[seq_along(top_genomes)], top_genomes),
                "Other" = "grey40")

p_comp <- ggplot(comp_df, aes(sample, percent, fill = group)) +
  geom_col(width = 0.8) +
  coord_flip() +
  scale_y_continuous(
    limits = c(0, 100),
    breaks = seq(0, 100, 20),
    labels = scales::label_percent(scale = 1)
  ) +
  scale_fill_manual(values = mag_colors, drop = FALSE) +
  theme_minimal(base_size = 14) +
  labs(
    title = "Community composition (Top 10 MAGs + Other)",
    x = "Sample",
    y = "Relative abundance (%)",
    fill = "MAG"
  )

ggsave("diversity_results/plots/composition_top10.png",
       p_comp, width = 10, height = 5.5, dpi = 300)
# =========================
# README
# =========================
writeLines(
  c(
    "Alpha diversity: richness and Shannon per sample",
    "Beta diversity: Bray–Curtis distance + PCoA",
    "Community composition: Top 10 MAGs + Other (Other = grey)",
    "All tables are in diversity_results/tables",
    "All figures are in diversity_results/plots"
  ),
  "diversity_results/README.txt"
)

message("DONE ✅ All results saved in folder: diversity_results/")

