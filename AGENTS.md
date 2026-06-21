# Agent instructions — Dawkins' Weasel

This file provides context for AI coding agents working in this repository.

## What this project is

A CLI recreation of Richard Dawkins' Weasel experiment (*The Blind Watchmaker*, 1986).
Four bash scripts form a progression from pure random search to diploid sexual evolution
with epistasis, each adding a layer of biological realism.

Target phrase: `METHINKS IT IS LIKE A WEASEL` (28 characters, 27-symbol alphabet: A–Z + space)

## Files

| File | Purpose |
|---|---|
| `random_variation.sh` | Pure random search — no memory between attempts, never terminates naturally |
| `cumulative_selection.sh` | Asexual clonal selection — single parent, mutation, keep best offspring |
| `optimised_selection.sh` | Sexual population: 50 individuals, tournament selection, uniform crossover |
| `biological_evolution.sh` | Diploid evolution: two alleles per position, meiosis, dominance, epistasis |
| `README.md` | Public-facing documentation |
| `AGENTS.md` | This file — agent context |
| `LICENSE` | MIT |

## Architecture

All four scripts follow the same **MVP pattern** enforced by naming convention:

- `model_*` — pure logic, no output, mutates `M_*` global state variables
- `view_*` — display only, reads state, never mutates
- `_view_*` — private view helpers (leading underscore)
- `presenter_*` — owns the event loop, calls model then view in sequence

This separation must be preserved in any modifications.

## Algorithm reference

### `random_variation.sh` — `model_generate()`

1. Build a candidate string: 28 characters drawn independently at random
2. Score it: count exact positional matches against the target
3. Track the all-time best for display — **never** fed back into the next attempt

No state carries forward. Each attempt is fully independent by design.

---

### `cumulative_selection.sh` — `model_next_generation()`

Constants: `POPULATION=100`, `MUTATION_RATE=5`

1. **Breed** — produce `POPULATION` offspring from the current single parent; each
   character is inherited unless a random draw falls within `MUTATION_RATE`%, replacing
   it with a random alphabet symbol
2. **Score** — count exact positional matches for each offspring
3. **Select** — keep the single highest-scoring offspring (parent is baseline; it survives
   if no offspring beats it)
4. **Advance** — commit the winner; the next generation always starts from the best so far

---

### `optimised_selection.sh` — `model_next_generation()`

Constants: `POP_SIZE=50`, `TOURNAMENT_SIZE=3`, `BASE_MUT_RATE=5`, `STRESS_MUT_RATE=20`, `STALL_THRESHOLD=15`

Biological corrections over the clonal model:

1. **True population** (`POP_SIZE=50`): all individuals replaced every generation.
   No individual survives by past performance. Progress is held in allele frequencies,
   not in a single immortal string.

2. **Uniform crossover**: each of the 28 positions is drawn independently from parent A or
   B with equal probability (`RANDOM % 2`). Models independent assortment / dense
   recombination across a short chromosome. Contrast with single-point crossover, which
   creates two maximally-linked half-genome blocks.

3. **Tournament selection** (`TOURNAMENT_SIZE=3`): draw 3 random individuals, return the
   fittest. Less-fit individuals can win by luck (genetic drift). Selection pressure is
   controlled by tournament size: 2 ≈ drift-dominated; N ≈ truncation selection.

4. **Adaptive μ** on mean fitness: if `M_MEAN_SCORE` fails to improve for `STALL_THRESHOLD`
   consecutive generations, raise `M_MUT_RATE` to `STRESS_MUT_RATE`. Reset on improvement.
   Stall is measured on the population *mean*, not the champion — a stalled champion while
   the mean rises is convergence, not stalling.

Key state: `M_POP[]`, `M_POP_SCORES[]`, `M_MEAN_SCORE`, `M_PREV_MEAN`.

---

### `biological_evolution.sh` — `model_next_generation()`

Constants: `POP_SIZE=40`, `TOURNAMENT_SIZE=3`, `BASE_MUT_RATE=5`, `STRESS_MUT_RATE=20`,
`STALL_THRESHOLD=25`, `REC_FRACTION=20`, `EPIS_COUNT=4`

Three new mechanisms:

#### 1. Diploid genome + dominance

Each individual has two haplotype strings (`M_POP_A[]`, `M_POP_B[]`). Phenotype is
computed per-position by `model_score_individual()` using `M_DOM` (a 28-char string of
`0`/`1` flags set at `model_init()`):

- `dom=0` (dominant): `alleles_a[i] == TARGET[i]` OR `alleles_b[i] == TARGET[i]` → correct phenotype
- `dom=1` (recessive): BOTH alleles must equal `TARGET[i]` → correct phenotype;
  otherwise the non-target allele is expressed and `_het_count` is incremented

`_het_count` counts positions where one correct recessive allele is present but
unexpressed — the "hidden carrier" signal shown as yellow in the display.

#### 2. Meiosis — `model_make_gamete(ha, hb)`

Produces a haploid gamete by drawing each position independently from `ha` or `hb`
(`RANDOM % 2`). Called *per parent*, not per pair — each parent shuffles its own two
haplotypes before contributing a gamete. Two gametes fuse into the diploid offspring.

Order: `make_gamete(pa_A, pa_B)` → `gamete_a`; `make_gamete(pb_A, pb_B)` → `gamete_b`;
mutate both independently; score `(gamete_a, gamete_b)` as the new diploid.

#### 3. Epistasis

`EPIS_X[]` and `EPIS_Y[]` hold the position indices of `EPIS_COUNT` pairs (no position
in two pairs). After computing the base phenotypic score, `model_score_individual()`
adds +1 for each pair where both positions are phenotypically correct:

```bash
_score=$_base_score
for (( e=0; e<EPIS_COUNT; e++ )); do
    if [[ "${_pheno:${EPIS_X[$e]}:1}" == "${TARGET:${EPIS_X[$e]}:1}" && \
          "${_pheno:${EPIS_Y[$e]}:1}" == "${TARGET:${EPIS_Y[$e]}:1}" ]]; then
        (( _score++ ))
    fi
done
```

Maximum score = `LEN + EPIS_COUNT` = 32. At termination (phenotype == TARGET) all
epistasis bonuses are earned, so the final score always equals the maximum.

Key state: `M_POP_A[]`, `M_POP_B[]`, `M_PHENO[]`, `M_SCORE[]`, `M_BASE_SCORE[]`,
`M_HET[]`, `M_DOM`, `EPIS_X[]`, `EPIS_Y[]`.

## Display colour coding (`biological_evolution.sh`)

| Colour | Condition |
|---|---|
| Green bold | `phenotype[i] == TARGET[i]` and `M_DOM[i] == 0` (dominant correct) |
| Cyan bold | `phenotype[i] == TARGET[i]` and `M_DOM[i] == 1` (recessive correct) |
| Yellow | `phenotype[i] != TARGET[i]` but one allele == TARGET[i] (hidden carrier) |
| Dim red | Neither allele == TARGET[i] |

## Key constants across all scripts

| Constant | Default | Script | Effect |
|---|---|---|---|
| `TARGET` | `METHINKS IT IS LIKE A WEASEL` | all | Target phrase |
| `ALPHABET` | `A–Z + space` | all | 27-symbol character set |
| `POPULATION` | 100 | cumulative | Offspring per generation |
| `MUTATION_RATE` | 5 | cumulative | % mutation per character |
| `POP_SIZE` | 50 / 40 | optimised / biological | True population size |
| `TOURNAMENT_SIZE` | 3 | optimised, biological | Selection tournament width |
| `BASE_MUT_RATE` | 5 | optimised, biological | Baseline % mutation per allele |
| `STRESS_MUT_RATE` | 20 | optimised, biological | Elevated mutation under stall |
| `STALL_THRESHOLD` | 15 / 25 | optimised / biological | Generations before stress |
| `REC_FRACTION` | 20 | biological | % of positions that are recessive |
| `EPIS_COUNT` | 4 | biological | Number of epistasis pairs |
| `DISPLAY_COUNT` | 4–5 | optimised, biological | Individuals shown per generation |

## What to avoid

- Do not mix display logic into `model_*` functions or state mutation into `view_*` functions
- Do not add external dependencies — zero-dependency simplicity is a design goal
- Do not persist state between attempts in `random_variation.sh` — that turns it into
  cumulative selection and defeats the demonstration
- Do not change `M_DOM` or `EPIS_X/Y` mid-run — they are fixed at `model_init()` and
  the display and scoring logic both depend on them being constant across generations
