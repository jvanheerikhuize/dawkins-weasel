# Dawkins' Weasel

> *"One of the most striking things about this experiment is not that it works — it is how fast it works."*
> — Richard Dawkins, *The Blind Watchmaker* (1986)

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Shell: bash](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnu-bash&logoColor=white)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)

A terminal recreation of Dawkins' Weasel experiment — four bash scripts that together trace the full arc from random search to diploid sexual evolution with epistasis. No dependencies. Runs in any terminal.

---

## The core idea

How long would it take a monkey randomly typing to produce the line:

```
METHINKS IT IS LIKE A WEASEL
```

At a billion characters per second: longer than the age of the universe. The string is 28 characters over a 27-symbol alphabet. The odds of a single correct attempt are roughly **1 in 10³⁹**.

Now add one rule: keep whatever is closest to the target and breed from it. The experiment reaches the target in **under 100 generations**.

That single rule — cumulative selection — is the engine of all biological evolution.

---

## Quick start

```bash
git clone https://github.com/jvanheerikhuize/dawkins-weasel.git
cd dawkins-weasel

./random_variation.sh        # never terminates — press Ctrl+C
./cumulative_selection.sh    # converges in ~50–80 generations
./optimised_selection.sh     # sexual population, ~300–500 generations
./biological_evolution.sh    # diploid + meiosis + epistasis, ~600–1000 generations
```

Requires only `bash` (version 4+). No other dependencies.

---

## The four scripts

Each script adds a layer of biological realism. The later scripts take more generations — not because they are worse algorithms, but because they model mechanisms that impose real costs in nature.

| Script | Biological model | Converges in |
|---|---|---|
| `random_variation.sh` | No selection | Never (1 in 10³⁹) |
| `cumulative_selection.sh` | Asexual clonal selection | ~50–80 gens |
| `optimised_selection.sh` | Sexual population genetics | ~300–500 gens |
| `biological_evolution.sh` | Diploid Mendelian evolution | ~600–1000 gens |

---

## What you'll see

All four scripts share a rich terminal UI. Each generation displays the current best sequence with per-character colour coding:

```
── Gen   47 ──── best 21  mean 18/28 ──  [μ=5%]
  ● METHINKS IT iS LiKE A WzASEL   21/28
  ● METHINKS IT IS LiKE A WzASEL   20/28
  ● METHiNKS IT IS LiKE A WEASEL   20/28
```

**`biological_evolution.sh`** adds a fourth colour layer that makes Mendelian genetics visible in real time:

| Colour | Meaning |
|---|---|
| **Green** | Correct — dominant position (one allele was enough) |
| **Cyan** | Correct — recessive position (both alleles had to be correct) |
| Yellow | Carrier — one correct allele present but hidden by dominance |
| Red | No correct allele at this position |

Yellow characters are heterozygous carriers: the correct allele exists in the genotype but cannot be expressed. When two carriers mate and produce a homozygous offspring, yellow turns cyan — Mendel's 1-in-4 ratio playing out character by character.

---

## Biological mechanisms

### Script 1 — `random_variation.sh`

Pure random search with no memory between attempts. Demonstrates why evolution *without* selection is not just slow but cosmologically impossible. Press `Ctrl+C` to stop.

### Script 2 — `cumulative_selection.sh`

The core Dawkins experiment. One parent breeds 100 offspring each generation; the fittest offspring becomes the next parent. Correct characters lock in permanently — selection never undoes progress. Reaches the target in dozens of generations.

This is **asexual clonal selection**: a single lineage, no recombination, no population structure.

### Script 3 — `optimised_selection.sh`

Corrects three biological simplifications in the clonal model:

**True population over immortal elite** — 50 individuals evolve together with full generational replacement. No individual survives by merit of past performance; progress is held in allele frequencies across the population, not in a single immortal string.

**Uniform crossover over single split-point** — each position is drawn independently from either parent (50/50), modelling independent assortment. A single split point forces half-genome blocks to always co-inherit, which is unrealistic for a short, recombining chromosome.

**Tournament selection over winner-takes-all** — three random individuals compete; the fittest wins. Less-fit individuals can win by luck; fitter ones can be passed over. This stochasticity is **genetic drift**, present in every finite real population.

### Script 4 — `biological_evolution.sh`

Introduces three mechanisms absent from all prior scripts:

**Diploid genome with dominance** — every individual carries two alleles per position. At *dominant* positions (~80%) one correct allele suffices. At *recessive* positions (~20%) both must be correct. Correct alleles at recessive positions accumulate silently in heterozygotes until two carriers produce a homozygous offspring — Mendelian masking in a terminal.

**Meiosis** — reproduction starts with each parent independently shuffling *its own* two haplotypes into a haploid gamete. Two gametes fuse into the diploid offspring. This is structurally different from all previous scripts: recombination happens inside a single organism before fertilisation, not between two complete parental sequences.

**Epistasis** — synergistic position pairs are fixed at initialisation. Completing both positions of a pair earns a fitness bonus beyond the individual positions. This makes the fitness landscape non-additive: the script sometimes appears to stall because correct characters accumulate in incomplete pairs where the gradient has not yet appeared.

---

## Why the generation counts diverge

`optimised_selection.sh` evaluates roughly the same number of individuals per generation as the clonal script — the extra generations come from probabilistic selection (drift can delay fixation of good alleles) and generational replacement (no individual is immortal).

`biological_evolution.sh` takes longest because **recessive positions require two independent mutation events** — one per allele — plus the Mendelian lottery of two carriers meeting and producing a homozygous offspring. In a population of 40 this can take many generations even once the correct allele is common. This is Haldane's cost of selection made visible.

---

## Architecture

All scripts follow the **MVP pattern** (Model · View · Presenter):

```
model_*       pure logic, no output, mutates M_* global state
view_*        display only, reads state but never mutates
presenter_*   event loop, calls model then view in sequence
```

The separation is enforced by naming convention. Details are documented in [`AGENTS.md`](AGENTS.md).

---

## Further reading

- Dawkins, R. (1986). *The Blind Watchmaker*. W. W. Norton & Company.
- Maynard Smith, J. (1978). *The Evolution of Sex*. Cambridge University Press.
- Wright, S. (1932). The roles of mutation, inbreeding, crossbreeding, and selection in evolution. *Proceedings of the Sixth International Congress of Genetics*, 1, 356–366.
- Haldane, J.B.S. (1957). The cost of natural selection. *Journal of Genetics*, 55, 511–524.
- Kimura, M. (1968). Evolutionary rate at the molecular level. *Nature*, 217, 624–626.
- Radman, M. (1975). SOS repair hypothesis. *Basic Life Sciences*, 5A, 355–367.

---

## License

[MIT](LICENSE) © Jerry van Heerikhuize
