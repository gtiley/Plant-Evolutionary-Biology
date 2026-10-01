set.seed(1234)

# Parameters you can change directly.
N <- 100
p0 <- 0.1
n_generations <- 1000
n_replicates <- 100

# Start with an empty plot and draw trajectories one at a time.
plot(
  NA,
  xlim = c(1, n_generations),
  ylim = c(0, 1),
  xlab = "Generations",
  ylab = expression(p(A[1]))
)

# Store the final frequency from each replicate so we can inspect the outcome.
final_freqs <- numeric(n_replicates)

# Repeat the Wright–Fisher process many times.
for (replicate in seq_len(n_replicates)) {
  # Start each replicate at the same initial allele frequency.
  p <- p0
  freq <- numeric(n_generations)

  # Each generation is a binomial sample of 2N gene copies.
  for (generation in seq_len(n_generations)) {
    A1 <- rbinom(1, size = 2 * N, prob = p)
    p <- A1 / (2 * N)
    freq[generation] <- p
  }

  # Add this replicate's trajectory to the existing plot.
  if (freq[length(freq)] == 0) {
    lines(freq, col = "#BA3B46")
  }
  
  if (freq[length(freq)] > 0) {
    lines(freq, col = "#1C5D99")
  }

  # Save the final allele frequency for this replicate.
  final_freqs[replicate] <- freq[n_generations]
}

# Print a small summary table of the final frequencies.
final_p <- data.frame(
  replicate = seq_len(n_replicates),
  final_frequency = final_freqs
)