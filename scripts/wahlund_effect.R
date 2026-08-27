library(ggplot2)

# allele frequency of A in each deme; both demes are internally in HW
p1 <- 0.8
p2 <- 0.2

# Hardy-Weinberg genotype frequencies for a given allele frequency
hw <- function(p) {
  q <- 1 - p
  AA <- p^2
  Aa <- 2 * p * q
  aa <- q^2
  return(c(AA = AA, Aa = Aa, aa = aa))
}

deme1 <- hw(p1)
deme2 <- hw(p2)

# average the two demes as if sampled together in one pooled collection
pooled_observed <- (deme1 + deme2) / 2

# what HW would predict if the pooled sample were a single random-mating population
p_bar <- (p1 + p2) / 2
pooled_expected <- hw(p_bar)

genotypes <- rbind(deme1, deme2, pooled_observed, pooled_expected)
rownames(genotypes) <- c("Deme 1 (HW)", "Deme 2 (HW)",
                          "Pooled (observed)", "Pooled (HW expected)")

# reshape to long format for ggplot
genotypes_df <- data.frame(
  sample = rep(rownames(genotypes), times = ncol(genotypes)),
  genotype = rep(colnames(genotypes), each = nrow(genotypes)),
  frequency = as.vector(genotypes)
)
genotypes_df$sample <- factor(genotypes_df$sample, levels = rownames(genotypes))
genotypes_df$genotype <- factor(genotypes_df$genotype, levels = c("AA", "Aa", "aa"))

wahlund_fig <- ggplot(genotypes_df, aes(x = sample, y = frequency, fill = genotype)) +
  geom_col(position = "dodge") +
  scale_fill_manual(values = c("#0A2342", "#8FB8DE", "#F15025")) +
  ylim(0, 1) +
  labs(x = NULL, y = "Genotype frequency", fill = NULL) +
  theme_minimal()
# pooled Aa < HW-expected Aa: the Wahlund heterozygote deficit

ggsave("wahlund-effect.png", wahlund_fig, width = 6.5, height = 4, dpi = 300)