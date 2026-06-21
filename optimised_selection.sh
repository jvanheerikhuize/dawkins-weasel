#!/usr/bin/env bash
# optimised_selection.sh — Dawkins' Weasel: population-level evolution
# Architecture: MVP  (Model · View · Presenter)
#
# Three biological corrections over the previous version (same three-mechanism
# frame, each replaced with a more accurate model):
#
#   CORRECTION 1 — Immortal elite pool → True evolving population
#     Before: 5 fixed "champion" strings lived across all generations; only the
#             single best new offspring could enter the pool each generation.
#             This is truncation selection at its extreme — 99 of 100 offspring
#             contributed nothing — and the champions were never replaced, even
#             when the population had long since moved past them.
#     After:  POP_SIZE individuals evolve together; the entire generation is
#             replaced by its offspring (non-overlapping generations, as in
#             annual plants and many insects).  No individual survives by merit
#             of past fitness alone.  Progress is held statistically across
#             allele frequencies, not locked in an immortal lineage.
#
#   CORRECTION 2 — Single-point crossover → Uniform crossover
#     Before: a single random split point forced the two "halves" of the genome
#             to always be co-inherited as intact blocks.  Positions 0 and 1
#             were as tightly linked as positions 0 and 13 — there was no
#             within-block recombination at all.
#     After:  each position is drawn independently from parent A or B with
#             equal probability.  For a 28-character string, this models the
#             dense recombination expected across a short, highly shuffled
#             chromosome — the realistic case for independent loci.  Beneficial
#             mutations that arose in different lineages can now be combined
#             position by position, not only as intact halves.
#
#   CORRECTION 3 — Winner-takes-all → Tournament selection (with drift)
#     Before: exactly one offspring — the highest scorer out of 100 — advanced
#             per generation.  All others contributed zero.  Selection had no
#             stochastic element; it was fully deterministic.
#     After:  parents are chosen by random TOURNAMENT_SIZE-way competition.
#             A less-fit individual can win a tournament by luck; a fitter one
#             can be passed over.  This finite-population stochasticity is
#             genetic drift, present in every real population.  Selection is
#             real but probabilistic, exactly as in nature.
#
#   RETAINED — Adaptive μ (stress-induced mutagenesis)
#     Stall is now measured against population mean fitness rather than the
#     champion's score.  A stalled mean signals a population-wide plateau;
#     a stalled champion while the mean rises is just convergence.

# ─── CONSTANTS ────────────────────────────────────────────────────────────────

TARGET="METHINKS IT IS LIKE A WEASEL"
ALPHABET="ABCDEFGHIJKLMNOPQRSTUVWXYZ "
LEN=${#TARGET}
ALPHA_LEN=${#ALPHABET}

POP_SIZE=50               # true evolving population
TOURNAMENT_SIZE=3         # individuals competing per parent-selection event
BASE_MUT_RATE=5           # baseline % mutation per position per offspring
STRESS_MUT_RATE=20        # elevated rate after prolonged mean-fitness stall
STALL_THRESHOLD=15        # consecutive non-improving gens before stress
DISPLAY_COUNT=5           # individuals shown from population per generation

# ─── COLORS ───────────────────────────────────────────────────────────────────

RESET=$'\e[0m'
BOLD=$'\e[1m'
DIM=$'\e[2m'
RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
CYAN=$'\e[36m'
MAGENTA=$'\e[35m'
WHITE=$'\e[97m'

# ═══════════════════════════════════════════════════════════════════════════════
# MODEL — pure logic, no output
# ═══════════════════════════════════════════════════════════════════════════════

M_POP=()              # current population strings
M_POP_SCORES=()       # fitness scores (index-aligned with M_POP)
M_GENERATION=0
M_BEST=""             # fittest individual in current generation
M_BEST_SCORE=0
M_MEAN_SCORE=0        # mean population fitness
M_PREV_MEAN=0         # mean score of previous generation (stall detection)
M_STALL=0
M_MUT_RATE=$BASE_MUT_RATE
M_STRESSED=0
M_SAMPLE=()           # top-DISPLAY_COUNT individuals for display
M_SAMPLE_SCORES=()
M_START=$SECONDS

model_score() {
    local s="$1"
    _score=0
    for (( i=0; i<LEN; i++ )); do
        [[ "${s:$i:1}" == "${TARGET:$i:1}" ]] && (( _score++ ))
    done
}

# Tournament selection: draw TOURNAMENT_SIZE individuals uniformly at random
# from the current population and return the index of the fittest.
# The probabilistic nature is deliberate — a weaker individual can win by the
# luck of who they happen to compete against.  Tournament size controls
# selection pressure: size 2 ≈ weak, drift-dominated; size = POP_SIZE ≈
# deterministic truncation.  Size 3 sits in the biologically realistic middle.
model_tournament() {
    local best_idx=$(( RANDOM % POP_SIZE ))
    local best_sc=${M_POP_SCORES[$best_idx]}
    for (( t=1; t<TOURNAMENT_SIZE; t++ )); do
        local idx=$(( RANDOM % POP_SIZE ))
        if (( ${M_POP_SCORES[$idx]} > best_sc )); then
            best_idx=$idx
            best_sc=${M_POP_SCORES[$idx]}
        fi
    done
    _tournament_idx=$best_idx
}

model_compute_stats() {
    M_BEST_SCORE=0
    M_BEST=""
    local total=0
    for (( i=0; i<POP_SIZE; i++ )); do
        local sc=${M_POP_SCORES[$i]}
        (( total += sc ))
        if (( sc > M_BEST_SCORE )); then
            M_BEST_SCORE=$sc
            M_BEST="${M_POP[$i]}"
        fi
    done
    M_MEAN_SCORE=$(( total / POP_SIZE ))
}

model_init() {
    M_POP=()
    M_POP_SCORES=()
    for (( p=0; p<POP_SIZE; p++ )); do
        local ind=""
        for (( i=0; i<LEN; i++ )); do
            ind+="${ALPHABET:$(( RANDOM % ALPHA_LEN )):1}"
        done
        model_score "$ind"
        M_POP+=("$ind")
        M_POP_SCORES+=($_score)
    done
    model_compute_stats
    M_GENERATION=0
    M_STALL=0
    M_MUT_RATE=$BASE_MUT_RATE
    M_STRESSED=0
    M_PREV_MEAN=0
    M_START=$SECONDS
}

model_next_generation() {
    # ┌─────────────────────────────────────────────────────────────────────┐
    # │  ALGORITHM: population-level evolution                              │
    # │    Fix 1 — true population:   POP_SIZE individuals, full turnover  │
    # │    Fix 2 — uniform crossover: each position independently from A/B │
    # │    Fix 3 — tournament select: probabilistic selection + drift       │
    # └─────────────────────────────────────────────────────────────────────┘

    M_PREV_MEAN=$M_MEAN_SCORE

    local new_pop=()
    local new_scores=()

    for (( p=0; p<POP_SIZE; p++ )); do
        # Fix 3 — select parent A via tournament.
        model_tournament
        local pa_idx=$_tournament_idx

        # Select parent B; re-draw until a distinct individual is chosen.
        # Mating with an identical individual makes crossover equivalent to
        # cloning — it contributes nothing beyond what mutation alone provides.
        local pb_idx=$pa_idx
        local tries=0
        while (( pb_idx == pa_idx && tries < 10 )); do
            model_tournament
            pb_idx=$_tournament_idx
            (( tries++ ))
        done

        # Fix 2 — uniform crossover: each of the LEN positions is drawn
        # independently from parent A or B with equal probability.
        # Unlike a single split point (which locks two large always-co-inherited
        # blocks), uniform crossover can produce any combination of the two
        # parents' correct characters in a single offspring — the equivalent of
        # dense, evenly spaced crossover events along the chromosome.
        local child=""
        for (( i=0; i<LEN; i++ )); do
            if (( RANDOM % 2 == 0 )); then
                child+="${M_POP[$pa_idx]:$i:1}"
            else
                child+="${M_POP[$pb_idx]:$i:1}"
            fi
        done

        # Point mutation at the current adaptive rate.
        local mutated=""
        for (( i=0; i<LEN; i++ )); do
            if (( RANDOM % 100 < M_MUT_RATE )); then
                mutated+="${ALPHABET:$(( RANDOM % ALPHA_LEN )):1}"
            else
                mutated+="${child:$i:1}"
            fi
        done

        model_score "$mutated"
        new_pop+=("$mutated")
        new_scores+=($_score)
    done

    # Fix 1 — full generational replacement.  No individual survives to the
    # next generation by merit of past performance — only through offspring.
    # Progress is preserved because fit parents were more likely to win
    # tournaments and so more likely to have offspring in this new generation;
    # correct characters propagate via allele frequency, not individual
    # immortality.
    M_POP=("${new_pop[@]}")
    M_POP_SCORES=("${new_scores[@]}")

    (( M_GENERATION++ ))
    model_compute_stats

    # Stall detection on population mean, not the champion.
    # A champion can plateau while the rest of the population catches up —
    # that is convergence, not stalling.  A stalled mean signals the whole
    # population is on a plateau and broader exploration is needed.
    if (( M_MEAN_SCORE > M_PREV_MEAN )); then
        M_STALL=0
        M_STRESSED=0
        M_MUT_RATE=$BASE_MUT_RATE
    else
        (( M_STALL++ ))
        if (( M_STALL >= STALL_THRESHOLD )); then
            M_STRESSED=1
            M_MUT_RATE=$STRESS_MUT_RATE
        fi
    fi

    # Build display sample: top DISPLAY_COUNT individuals by fitness.
    local -a used
    for (( i=0; i<POP_SIZE; i++ )); do used[$i]=0; done

    M_SAMPLE=()
    M_SAMPLE_SCORES=()
    for (( d=0; d<DISPLAY_COUNT; d++ )); do
        local top_idx=0 top_sc=-1
        for (( i=0; i<POP_SIZE; i++ )); do
            if (( !used[$i] && ${M_POP_SCORES[$i]} > top_sc )); then
                top_sc=${M_POP_SCORES[$i]}
                top_idx=$i
            fi
        done
        M_SAMPLE+=("${M_POP[$top_idx]}")
        M_SAMPLE_SCORES+=($top_sc)
        used[$top_idx]=1
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# VIEW — display only, never mutates state
# ═══════════════════════════════════════════════════════════════════════════════

_score_color() {
    local pct=$(( $1 * 100 / $2 ))
    if   (( pct >= 90 )); then _color=$GREEN
    elif (( pct >= 60 )); then _color=$CYAN
    elif (( pct >= 30 )); then _color=$YELLOW
    else                       _color=$RED
    fi
}

_view_string() {
    local str="$1" dimmed=$2
    for (( i=0; i<LEN; i++ )); do
        local ch="${str:$i:1}"
        if [[ "$ch" == "${TARGET:$i:1}" ]]; then
            if (( dimmed )); then printf "${RESET}${DIM}%s${DIM}" "$ch"
            else             printf "${GREEN}${BOLD}%s${RESET}" "$ch"
            fi
        else
            if (( dimmed )); then printf "${RED}%s${RESET}${DIM}" "$ch"
            else             printf "${DIM}${RED}%s${RESET}" "$ch"
            fi
        fi
    done
}

view_header() {
    printf "\n"
    printf "${BOLD}${MAGENTA}  ╔══════════════════════════════════════════════════════╗${RESET}\n"
    printf "${BOLD}${MAGENTA}  ║     DAWKINS' WEASEL  ·  POPULATION EVOLUTION         ║${RESET}\n"
    printf "${BOLD}${MAGENTA}  ╚══════════════════════════════════════════════════════╝${RESET}\n\n"
    printf "  ${DIM}Target  »${RESET} ${BOLD}${WHITE}%s${RESET}\n" "$TARGET"
    printf "  ${DIM}Config  »${RESET} ${DIM}%d individuals · tournament %d · μ %d%%→%d%% after %d stall gens${RESET}\n" \
        "$POP_SIZE" "$TOURNAMENT_SIZE" "$BASE_MUT_RATE" "$STRESS_MUT_RATE" "$STALL_THRESHOLD"
    printf "\n  ${DIM}──────────────────────────────────────────────────────${RESET}\n\n"
}

view_reasoning() {
    printf "\n  ${MAGENTA}▸ %s${RESET}\n\n" "$1"
}

view_generation() {
    _score_color "$M_BEST_SCORE" "$LEN"
    local col="$_color"

    local mu_tag
    if (( M_STRESSED )); then
        mu_tag="${RED}${BOLD}[stress: μ=${M_MUT_RATE}%]${RESET}"
    else
        mu_tag="${DIM}[μ=${M_MUT_RATE}%]${RESET}"
    fi

    # ── generation header ─────────────────────────────────────────────────────
    printf "  ${DIM}── Gen %4d ──── best ${RESET}${col}${BOLD}%2d${RESET}${DIM}  mean %2d/%d ──${RESET}  %b\n" \
        "$M_GENERATION" "$M_BEST_SCORE" "$M_MEAN_SCORE" "$LEN" "$mu_tag"

    # ── top individuals in current population ─────────────────────────────────
    for (( s=0; s<${#M_SAMPLE[@]}; s++ )); do
        local sc="${M_SAMPLE_SCORES[$s]}"
        _score_color "$sc" "$LEN"
        if (( s == 0 )); then
            printf "  ${BOLD}●${RESET}  "
            _view_string "${M_SAMPLE[$s]}" 0
            printf "   ${_color}${BOLD}%2d${RESET}${DIM}/%d${RESET}\n" "$sc" "$LEN"
        else
            printf "  ${DIM}●  "
            _view_string "${M_SAMPLE[$s]}" 1
            printf "   ${_color}%2d${RESET}${DIM}/%d${RESET}\n" "$sc" "$LEN"
        fi
    done
    printf "\n"
}

view_complete() {
    printf "\n"
    printf "  ${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${RESET}\n"
    printf "  ${BOLD}${GREEN}║  ✓  TARGET REACHED                                   ║${RESET}\n"
    printf "  ${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${RESET}\n\n"
    printf "  ${BOLD}${WHITE}%s${RESET}\n\n" "$TARGET"
    printf "  ${DIM}Generations  : %d${RESET}\n" "$M_GENERATION"
    printf "  ${DIM}Population   : %d individuals${RESET}\n" "$POP_SIZE"
    printf "  ${DIM}Tournament   : size %d (probabilistic selection + drift)${RESET}\n" "$TOURNAMENT_SIZE"
    printf "  ${DIM}Mutation     : %d%% base  ·  %d%% stress${RESET}\n\n" "$BASE_MUT_RATE" "$STRESS_MUT_RATE"
    view_reasoning "Selection was probabilistic throughout: fit individuals were more likely to reproduce, but not guaranteed. Progress accumulated in the population's allele frequencies, not in a single immortal champion."
    view_reasoning "Uniform crossover allowed beneficial mutations that fixed in different lineages to be combined position by position — any combination the two parents could assemble in one offspring, not just swapped halves."
}

# ═══════════════════════════════════════════════════════════════════════════════
# PRESENTER — orchestrates model + view, owns the event loop
# ═══════════════════════════════════════════════════════════════════════════════

presenter_run() {
    model_init
    view_header
    view_reasoning "A true population of $POP_SIZE individuals. Each generation every individual competes via tournament selection, reproduces through uniform crossover, and the old generation is fully replaced. No individual is guaranteed to survive — only genotypes that spread through the population endure."

    local hit_25=0 hit_50=0 hit_75=0 hit_90=0
    local stress_noted=0

    while [[ "$M_BEST" != "$TARGET" ]]; do
        model_next_generation
        view_generation

        local pct=$(( M_BEST_SCORE * 100 / LEN ))

        if (( pct >= 25 && !hit_25 )); then
            hit_25=1
            view_reasoning "25% match. Selection is shifting allele frequencies — correct characters appear in more individuals each generation, not just the best. It is the population, not any one organism, that is evolving."
        fi
        if (( pct >= 50 && !hit_50 )); then
            hit_50=1
            view_reasoning "50% match. Mean fitness trails best fitness — the population still carries diversity. Uniform crossover is assembling partial solutions that arose independently in different lineages."
        fi
        if (( pct >= 75 && !hit_75 )); then
            hit_75=1
            view_reasoning "75% match. Population diversity is narrowing as most lineages converge on the same correct characters. Recombination yields diminishing returns; point mutation is now the primary source of new variation."
        fi
        if (( pct >= 90 && !hit_90 )); then
            hit_90=1
            view_reasoning "90% match. Near fixation — the correct characters have spread to nearly every individual. Mean and best fitness are converging. The final positions are resolved by mutation alone."
        fi

        if (( M_STRESSED && !stress_noted )); then
            stress_noted=1
            view_reasoning "Mean fitness stalled for $STALL_THRESHOLD generations — μ raised to ${STRESS_MUT_RATE}%. The population is on a fitness plateau. As in bacteria under antibiotic pressure, elevated mutagenesis trades short-term accuracy for broader exploration of the landscape."
        fi
        if (( !M_STRESSED && stress_noted )); then
            stress_noted=0
            view_reasoning "Mean fitness improved — μ reset to ${BASE_MUT_RATE}%. The population has found a new gradient; elevated mutagenesis is no longer needed."
        fi
    done

    view_complete
}

presenter_run
