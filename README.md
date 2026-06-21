# Dawkins' Weasel

A CLI recreation of Richard Dawkins' Weasel experiment from *The Blind Watchmaker* (1986).

The experiment illustrates the difference between random search and cumulative selection — the core of how evolution actually works.

## The experiment

Target phrase: **`METHINKS IT IS LIKE A WEASEL`**

Three strategies compete to reach it:

| Script | Strategy | Result |
|---|---|---|
| `random_variation.sh` | Pure random search | Effectively never terminates (1 in ~2.4×10³⁹ odds per attempt) |
| `cumulative_selection.sh` | Breed → select → repeat | Converges in ~50–80 generations |
| `optimised_selection.sh` | Gene pool + crossover + adaptive μ | Converges faster; demonstrates sexual recombination and stress-induced mutagenesis |

## Usage

```bash
# Pure random variation — press Ctrl+C to stop
./random_variation.sh

# Cumulative selection — watch it converge
./cumulative_selection.sh

# Optimised: gene pool + crossover + adaptive mutation rate
./optimised_selection.sh
```

No dependencies. Requires only `bash`.

## How cumulative selection works

1. Start with a random 28-character string
2. Breed 100 offspring, each with a 5% per-character mutation rate
3. Keep the offspring closest to the target
4. Repeat until the target is reached

Each generation the best result is kept, so progress accumulates — small improvements are never lost. This is what selection does.

## Example output

```
Target : METHINKS IT IS LIKE A WEASEL
Start  : JQVMUDMLIIEIHPIDJQWGOHIUMNMU

Gen    1 | Score  2/28 | JQVMUDKLIIPIHPIDJQWGOHIUMNMU
Gen    5 | Score  7/28 | JQVMUNKSIIPIISIDJQWBOKIUMNML
Gen   15 | Score 15/28 | MQVOINKSQIP ISRLJKWWQWWEKPEL
Gen   32 | Score 22/28 | METHINKSQIP ISRLJKW K WEASEL
Gen   46 | Score 25/28 | METHINKSQIP ISRLIKE A WEASEL
Gen   60 | Score 28/28 | METHINKS IT IS LIKE A WEASEL

Target reached in 60 generations.
```

## How the optimised script works

`optimised_selection.sh` adds three mechanisms on top of cumulative selection, each grounded in biology:

### 1. Gene pool — standing genetic variation
Instead of one parent, the script keeps the top 5 offspring ever seen (the "pool"). Multiple lineages coexist with different correct characters in different positions. This mirrors how a sexual population maintains genetic diversity rather than bottlenecking through a single individual.

### 2. Two-parent crossover — sexual recombination
Each offspring is bred from two parents drawn at random from the pool. A random split point is chosen: the offspring inherits the left segment from parent A and the right segment from parent B. If parent A has the first half solved and parent B has the second half solved, a single crossover event produces a string that is better than either parent — something sequential mutation alone would take many more generations to achieve. This is the core advantage of sex in evolutionary biology: recombination lets separately-accumulated improvements combine rather than compete.

### 3. Adaptive mutation rate — stress-induced mutagenesis
The mutation rate starts at 5% per character. If the pool's best score fails to improve for 10 consecutive generations, the rate rises to 20%, forcing broader exploration. As soon as improvement is found, it drops back to 5%. This mirrors the SOS response in bacteria: when DNA is damaged or nutrients are scarce, cells express error-prone polymerases (such as Pol IV and Pol V in *E. coli*), temporarily trading replication fidelity for a higher chance of stumbling onto a useful mutation. The response is down-regulated as soon as the stress lifts.

## Further reading

- Dawkins, R. (1986). *The Blind Watchmaker*. W. W. Norton & Company.
- Radman, M. (1975). SOS repair hypothesis. *Basic Life Sciences*, 5A, 355–367. (original SOS response paper)
- Maynard Smith, J. (1978). *The Evolution of Sex*. Cambridge University Press.
