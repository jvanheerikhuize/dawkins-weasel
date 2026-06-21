# Agent instructions — Dawkins' Weasel

This file provides context for AI coding agents working in this repository.

## What this project is

A CLI recreation of Richard Dawkins' Weasel experiment (*The Blind Watchmaker*, 1986).
Two bash scripts demonstrate why cumulative selection converges on a target in tens of
generations while pure random search is effectively impossible.

Target phrase: `METHINKS IT IS LIKE A WEASEL` (28 characters, alphabet of 26 letters + space)

## Files

| File | Purpose |
|---|---|
| `random_variation.sh` | Pure random search — generates a fresh string each attempt, never carries information forward |
| `cumulative_selection.sh` | Cumulative selection — breeds, scores, and selects each generation; progress is never discarded |
| `optimised_selection.sh` | Optimised cumulative selection — adds gene pool, two-parent crossover, and adaptive mutation rate |
| `README.md` | User-facing documentation |
| `LICENSE` | MIT |

## Architecture

Both scripts follow the same **MVP pattern** (Model · View · Presenter), enforced by
naming convention. Functions are prefixed:

- `model_*` — pure logic, no output, mutates `M_*` global state variables
- `view_*` — display only, reads state but never mutates it
- `_view_*` / `_score_color` — private view helpers (leading underscore)
- `presenter_*` — owns the event loop, calls model then view in sequence

This separation is intentional and should be preserved in any changes.

## Algorithms

### `optimised_selection.sh` — `model_next_generation()` (three optimisations)

1. **Gene pool** (`POOL_SIZE=5` elites kept simultaneously): multiple lineages coexist across generations, providing the standing variation that makes recombination productive. Maps to genetic diversity in a sexual population.

2. **Two-parent crossover**: each offspring inherits positions `0..(xp-1)` from parent A and `xp..(LEN-1)` from parent B, where `xp` is a random split. When pool members have evolved different correct characters, a single crossover can combine two half-solved strings. Maps to meiotic recombination.

3. **Adaptive mutation rate**: baseline is `BASE_MUT_RATE` (5%). After `STALL_THRESHOLD` (10) consecutive non-improving generations, rate rises to `STRESS_MUT_RATE` (20%) to force broader exploration, then resets when improvement is found. Maps to the bacterial SOS response — error-prone polymerases are expressed under stress and repressed when the cell recovers.

### `random_variation.sh` — `model_generate()`

1. Build a candidate string by picking each of the 28 characters independently at random
2. Score it: count exact positional matches against the target
3. Track the all-time best score for display — this is **never** fed back into the next attempt

No state carries forward between attempts. Each roll is fully independent.

### `cumulative_selection.sh` — `model_next_generation()`

1. **Breed**: produce `POPULATION` (default 100) offspring from the current parent; each
   character is inherited as-is unless a random draw falls within `MUTATION_RATE`% (default 5%),
   in which case it is replaced with a random alphabet symbol
2. **Score**: count exact positional matches for each offspring
3. **Select**: keep the single highest-scoring offspring as the new parent (the parent itself
   is the baseline — it survives if no offspring beats it)
4. **Advance**: commit the winner; the next generation always starts from the best result so far

Progress is cumulative and irreversible. This is the key structural difference from random search.

## Running the scripts

```bash
./random_variation.sh        # press Ctrl+C to stop — it will never terminate naturally
./cumulative_selection.sh    # converges in ~50–80 generations
./optimised_selection.sh     # converges faster via crossover + adaptive mutation
```

No dependencies beyond `bash`. Scripts are already marked executable.

## Key constants (top of each script)

| Constant | Default | Script(s) | Effect |
|---|---|---|---|
| `TARGET` | `METHINKS IT IS LIKE A WEASEL` | all | The phrase to reach |
| `ALPHABET` | `A–Z + space` | all | Symbol set (27 characters) |
| `POPULATION` | 100 | cumulative, optimised | Offspring per generation |
| `MUTATION_RATE` | 5 | cumulative | % chance each character mutates |
| `BASE_MUT_RATE` | 5 | optimised | Baseline % mutation rate |
| `STRESS_MUT_RATE` | 20 | optimised | Elevated rate during stalling |
| `STALL_THRESHOLD` | 10 | optimised | Gens without improvement before stress |
| `POOL_SIZE` | 5 | optimised | Elite parents kept simultaneously |
| `DISPLAY_LOSERS` | 3–4 | cumulative, optimised | Eliminated offspring shown per gen |

## What to avoid

- Do not mix display logic into `model_*` functions or state mutation into `view_*` functions
- Do not add external dependencies — the project's value is its zero-dependency simplicity
- Do not persist state between attempts in `random_variation.sh` — that would turn it into cumulative selection and defeat the demonstration
