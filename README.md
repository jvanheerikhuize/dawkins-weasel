# Dawkins' Weasel

A CLI recreation of Richard Dawkins' Weasel experiment from *The Blind Watchmaker* (1986).

The experiment illustrates the difference between random search and cumulative selection — the core of how evolution actually works. The scripts form a progression: each adds a layer of biological realism on top of the last.

## The experiment

Target phrase: **`METHINKS IT IS LIKE A WEASEL`**

Four strategies, each closer to how evolution actually works:

| Script | Strategy | Biological model | Typical generations |
|---|---|---|---|
| `random_variation.sh` | Pure random search | No selection at all | Never (1 in ~2.4×10³⁹) |
| `cumulative_selection.sh` | Breed → select best → repeat | Asexual clonal selection | ~50–80 |
| `optimised_selection.sh` | True population + tournament selection + uniform crossover | Sexual population genetics | ~300–500 |
| `biological_evolution.sh` | Diploid genomes + meiosis + epistasis | Mendelian diploid evolution | ~600–1000 |

The later scripts take more generations, not because they are worse algorithms, but because they are more honest biology — they model mechanisms that are metabolically costly in real organisms for the same reason.

## Usage

```bash
# Pure random variation — press Ctrl+C to stop
./random_variation.sh

# Cumulative (asexual) selection — watch it converge fast
./cumulative_selection.sh

# Sexual population: tournament selection + uniform crossover
./optimised_selection.sh

# Diploid evolution: meiosis + dominance + epistasis
./biological_evolution.sh
```

No dependencies. Requires only `bash`.

---

## Script 1 — `random_variation.sh`

Pure random search. Every attempt generates a completely independent random string. There is no memory between attempts, no selection, no accumulation of progress. This is what evolution would look like without inheritance — which is to say, it is not evolution at all.

At 28 characters over a 27-symbol alphabet (26 letters + space), the probability of hitting the target in a single attempt is approximately 1 in 2.4 × 10³⁹. At a billion attempts per second, the expected wait is longer than the age of the universe.

---

## Script 2 — `cumulative_selection.sh`

One parent breeds 100 offspring per generation. Each offspring inherits every character unchanged except for a 5% per-character chance of random mutation. The single highest-scoring offspring becomes the next generation's parent. Progress accumulates.

This models **asexual clonal selection**: a single lineage, no recombination, no population. The key insight Dawkins was demonstrating is that selection does not need to be clever or directed — it only needs to keep what works. The correct characters lock in one by one and are never lost, which is why the target is reached in dozens of generations rather than trillions.

### How cumulative selection works

1. Start with a random 28-character string
2. Breed 100 offspring, each with a 5% per-character mutation rate
3. Keep the single offspring closest to the target
4. Repeat until done

---

## Script 3 — `optimised_selection.sh`

Corrects three biological problems with the clonal model, replacing them with mechanisms from population genetics:

### Correction 1 — True population (replaces single immortal parent)

The original script has one parent that only advances when it is beaten. `optimised_selection.sh` maintains **50 individuals** that all evolve simultaneously. Every generation, all 50 are replaced by their offspring. No individual survives by merit of past performance; progress is held statistically across allele frequencies in the population, not locked in a single immortal string.

The key difference: in a real population, evolution acts on *frequency distributions*, not champions.

### Correction 2 — Uniform crossover (replaces single-point crossover)

The previous version of this script used a single random split point, meaning positions 0 and 1 were always inherited together from the same parent — they were as tightly linked as positions 0 and 13. Real meiosis produces multiple crossover events per chromosome; distant positions approach **independent assortment**.

Uniform crossover draws each position independently from parent A or B with equal probability. For a 28-character string this models the dense recombination expected across a short, highly shuffled chromosome. Any combination of the two parents' correct characters can appear in a single offspring — impossible with a single split.

### Correction 3 — Tournament selection (replaces winner-takes-all)

The previous version picked exactly the #1 offspring every generation. Selection was fully deterministic — zero stochasticity. Real natural selection is **probabilistic**: fitter individuals are more likely to reproduce, not guaranteed to.

Tournament selection draws 3 individuals at random; the fittest wins. A weaker individual can win by luck; a stronger one can be passed over. This finite-population stochasticity is **genetic drift**, and it is present in every real population. Tournament size controls selection pressure: size 2 ≈ drift-dominated, size = population ≈ deterministic truncation. Size 3 is the biologically realistic middle.

### What is retained — adaptive μ

The mutation rate starts at 5% per character. If mean population fitness stalls for 15 consecutive generations, it rises to 20%. Stall is now measured on *mean* fitness, not the champion's score — a champion can plateau while the rest of the population is still catching up, which is convergence, not stalling. This models stress-induced mutagenesis (bacterial SOS pathway, error-prone polymerases) at the population level.

---

## Script 4 — `biological_evolution.sh`

Introduces three mechanisms that none of the previous scripts model, derived directly from Mendelian genetics and molecular biology:

### Mechanism 1 — Diploid genome with dominance

Every individual carries **two alleles per position** (a maternal haplotype and a paternal haplotype). What selection acts on — the *phenotype* — is determined by dominance rules fixed at initialisation:

- **Dominant positions** (~80%): one correct allele is enough to express the correct character. A single beneficial mutation is immediately visible to selection.
- **Recessive positions** (~20%): both alleles must be correct. A single correct allele is phenotypically silent — the individual *looks* wrong even though it carries potential.

This creates **diploid masking**: beneficial mutations at recessive positions accumulate in heterozygotes, invisible to selection, until two carriers happen to mate and produce a homozygous offspring. This is Mendelian genetics. The ratio of carrier × carrier → homozygous correct offspring is 1-in-4, exactly as Mendel's peas predicted.

The display uses four colours to make this visible:

| Colour | Meaning |
|---|---|
| **Green bold** | Correct phenotype, dominant position (1 allele sufficed) |
| **Cyan bold** | Correct phenotype, recessive position (both alleles are correct) |
| Yellow | Wrong phenotype — carries one hidden correct recessive allele (carrier) |
| Dim red | Wrong phenotype — no correct allele present |

Yellow characters are the key new signal: they show where the population is silently accumulating potential that selection cannot yet see. When a yellow character suddenly turns cyan, two carriers have met and produced a homozygous offspring.

### Mechanism 2 — Meiosis (intra-individual recombination)

When an individual reproduces it does not pass either of its haplotypes intact. Instead it independently shuffles its *own* two alleles at each position to produce a haploid gamete. Two such gametes — one from each parent — fuse into the diploid offspring.

This is structurally different from all previous scripts, which performed crossover *between* two complete parental sequences. Here recombination happens *inside a single organism* before the gametes even meet, modelling **meiosis I** (independent assortment of homologous chromosomes). Each gamete is a unique haploid sample of the parent's combined allele inventory.

### Mechanism 3 — Epistasis

A set of position pairs is fixed at initialisation. When both positions of a pair are phenotypically correct, the individual earns a **fitness bonus** (+1 per complete pair) on top of the base positional score. Completing half a pair is worth less than completing it.

This makes the fitness landscape **non-additive**: the gradient toward a correct character is steeper when its epistatic partner is already correct. The display shows `(+Nep)` for each individual's current epistasis bonus. The maximum possible score is `LEN + EPIS_COUNT` (28 + 4 = 32 in the default configuration), reached exactly when the phenotype matches the target.

This creates genuine **ridges** in the fitness landscape: the population sometimes appears to stall even while correct characters are accumulating, because the newly correct characters are in incomplete pairs where the bonus gradient has not yet appeared.

---

## Why the later scripts take more generations

`optimised_selection.sh` uses a population of 50 rather than 1, so the raw number of individuals evaluated per generation is comparable. The extra generations come from probabilistic selection (drift can delay fixation) and generational replacement (the best individual can be lost).

`biological_evolution.sh` takes longest because recessive positions require two independent mutation events to fix — one per allele — plus the Mendelian lottery of two carriers mating and producing a homozygous offspring. In a population of 40 this can take many generations even once the correct allele is common. This is **Haldane's cost of selection** made visible in a terminal window.

---

## Further reading

- Dawkins, R. (1986). *The Blind Watchmaker*. W. W. Norton & Company.
- Radman, M. (1975). SOS repair hypothesis. *Basic Life Sciences*, 5A, 355–367.
- Maynard Smith, J. (1978). *The Evolution of Sex*. Cambridge University Press.
- Wright, S. (1932). The roles of mutation, inbreeding, crossbreeding, and selection in evolution. *Proceedings of the Sixth International Congress of Genetics*, 1, 356–366. (fitness landscapes)
- Haldane, J.B.S. (1957). The cost of natural selection. *Journal of Genetics*, 55, 511–524.
- Kimura, M. (1968). Evolutionary rate at the molecular level. *Nature*, 217, 624–626. (neutral theory — relevant to diploid masking and drift)
