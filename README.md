# Dawkins' Weasel

A CLI recreation of Richard Dawkins' Weasel experiment from *The Blind Watchmaker* (1986).

The experiment illustrates the difference between random search and cumulative selection — the core of how evolution actually works.

## The experiment

Target phrase: **`METHINKS IT IS LIKE A WEASEL`**

Two strategies compete to reach it:

| Script | Strategy | Result |
|---|---|---|
| `random_variation.sh` | Pure random search | Effectively never terminates (1 in ~2.4×10³⁹ odds per attempt) |
| `cumulative_selection.sh` | Breed → select → repeat | Converges in ~50–80 generations |

## Usage

```bash
# Pure random variation — press Ctrl+C to stop
./random_variation.sh

# Cumulative selection — watch it converge
./cumulative_selection.sh
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

## Further reading

- Dawkins, R. (1986). *The Blind Watchmaker*. W. W. Norton & Company.
