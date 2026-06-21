#!/usr/bin/env bash
# optimised_selection.sh — Dawkins' Weasel: optimised cumulative selection
# Architecture: MVP  (Model · View · Presenter)
#
# Three optimisations over cumulative_selection.sh, each mapping to a real
# mechanism in evolutionary biology:
#
#   1. Gene pool       — keep POOL_SIZE elite parents simultaneously
#                        → standing genetic variation in a sexual population
#
#   2. Two-parent crossover — breed each offspring from two parents at a
#                        random split point
#                        → meiotic recombination / sexual reproduction
#
#   3. Adaptive μ      — raise mutation rate after prolonged stalling
#                        → stress-induced mutagenesis (bacterial SOS response)

# ─── CONSTANTS ────────────────────────────────────────────────────────────────

TARGET="METHINKS IT IS LIKE A WEASEL"
ALPHABET="ABCDEFGHIJKLMNOPQRSTUVWXYZ "
LEN=${#TARGET}
ALPHA_LEN=${#ALPHABET}
POPULATION=100
BASE_MUT_RATE=5         # baseline % chance each character mutates per offspring
STRESS_MUT_RATE=20      # elevated rate triggered by prolonged stalling
STALL_THRESHOLD=10      # consecutive non-improving gens before stress kicks in
POOL_SIZE=5             # elite parents kept across generations
DISPLAY_LOSERS=3        # eliminated offspring shown per generation

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

M_POOL=()             # elite parent strings, sorted best-first
M_POOL_SCORES=()      # their scores
M_GENERATION=0
M_STALL=0
M_MUT_RATE=$BASE_MUT_RATE
M_STRESSED=0
M_PREV_BEST=0
M_LAST_XP=0           # crossover split point used by winning offspring this gen
M_LAST_PA=""          # parent A string for the winning offspring
M_LAST_PB=""          # parent B string for the winning offspring
M_SAMPLE=()           # reservoir sample of losing offspring (for display)
M_SAMPLE_SCORES=()
M_START=$SECONDS

model_score() {
    local s="$1"
    _score=0
    for (( i=0; i<LEN; i++ )); do
        [[ "${s:$i:1}" == "${TARGET:$i:1}" ]] && (( _score++ ))
    done
}

# Insert a string into M_POOL, keeping it sorted descending by score and
# capped at POOL_SIZE. Exact duplicates are rejected to preserve diversity.
model_pool_insert() {
    local str="$1" score=$2
    local n=${#M_POOL[@]}

    for (( i=0; i<n; i++ )); do
        [[ "${M_POOL[$i]}" == "$str" ]] && return
    done

    if (( n < POOL_SIZE )); then
        M_POOL+=("$str")
        M_POOL_SCORES+=($score)
    elif (( score > ${M_POOL_SCORES[$((n-1))]} )); then
        M_POOL[$((n-1))]="$str"
        M_POOL_SCORES[$((n-1))]=$score
    else
        return
    fi

    # Bubble the new entry upward to maintain descending order
    n=${#M_POOL[@]}
    for (( i=n-1; i>0; i-- )); do
        if (( ${M_POOL_SCORES[$i]} > ${M_POOL_SCORES[$((i-1))]} )); then
            local ts="${M_POOL[$i]}"
            local tsc=${M_POOL_SCORES[$i]}
            M_POOL[$i]="${M_POOL[$((i-1))]}"
            M_POOL_SCORES[$i]=${M_POOL_SCORES[$((i-1))]}
            M_POOL[$((i-1))]="$ts"
            M_POOL_SCORES[$((i-1))]=$tsc
        else
            break
        fi
    done
}

model_init() {
    M_POOL=()
    M_POOL_SCORES=()
    local seed=""
    for (( i=0; i<LEN; i++ )); do
        seed+="${ALPHABET:$(( RANDOM % ALPHA_LEN )):1}"
    done
    model_score "$seed"
    M_POOL=("$seed")
    M_POOL_SCORES=($_score)
    M_GENERATION=0
    M_STALL=0
    M_MUT_RATE=$BASE_MUT_RATE
    M_STRESSED=0
    M_PREV_BEST=0
    M_LAST_XP=0
    M_LAST_PA=""
    M_LAST_PB=""
    M_SAMPLE=()
    M_SAMPLE_SCORES=()
    M_START=$SECONDS
}

model_next_generation() {
    # ┌─────────────────────────────────────────────────────────────────────┐
    # │  ALGORITHM: optimised cumulative selection                          │
    # │    Opt 1 — gene pool:    breed from POOL_SIZE elites, not one       │
    # │    Opt 2 — crossover:    two-parent recombination at random split   │
    # │    Opt 3 — adaptive μ:   mutation rate rises when stalling          │
    # └─────────────────────────────────────────────────────────────────────┘

    M_PREV_BEST=${M_POOL_SCORES[0]}

    # Snapshot the pool so all offspring in this generation are bred from the
    # same starting parents — breeding mid-generation would bias later offspring
    # toward a pool that has already absorbed earlier wins.
    local snap=("${M_POOL[@]}")
    local sn=${#snap[@]}

    local best_off="" best_score=-1 best_pa="" best_pb="" best_xp=0
    local disp_pool=() disp_scores=()

    for (( p=0; p<POPULATION; p++ )); do
        # Opt 1 — select two distinct parents from the pool snapshot.
        # A pool of POOL_SIZE means separate evolutionary lineages coexist,
        # each having fixed different beneficial mutations. This standing
        # variation is what makes recombination productive — without it,
        # crossing two identical parents yields nothing new.
        local pa_idx=$(( RANDOM % sn ))
        local pb_idx
        if (( sn > 1 )); then
            pb_idx=$(( RANDOM % (sn - 1) ))
            (( pb_idx >= pa_idx )) && (( pb_idx++ ))
        else
            pb_idx=$pa_idx   # pool not yet diverse: crossover degrades to clone
        fi

        # Opt 2 — two-parent crossover at a uniformly random split point.
        # The offspring inherits positions 0..(xp-1) from parent A and
        # positions xp..(LEN-1) from parent B.
        # This can instantly combine, e.g., the well-evolved left half of
        # one lineage with the well-evolved right half of another — a
        # shortcut that sequential single-parent mutation cannot take.
        local xp=$(( RANDOM % (LEN - 1) + 1 ))
        local child="${snap[$pa_idx]:0:$xp}${snap[$pb_idx]:$xp}"

        # Opt 3 — mutate at the current adaptive rate.
        # Normally this is BASE_MUT_RATE (5%), the same as the baseline script.
        # After STALL_THRESHOLD consecutive non-improving generations the rate
        # rises to STRESS_MUT_RATE (20%), forcing broader exploration.
        # The rate drops back to baseline as soon as improvement is seen.
        local mutated=""
        for (( i=0; i<LEN; i++ )); do
            if (( RANDOM % 100 < M_MUT_RATE )); then
                mutated+="${ALPHABET:$(( RANDOM % ALPHA_LEN )):1}"
            else
                mutated+="${child:$i:1}"
            fi
        done
        child="$mutated"

        model_score "$child"

        if (( _score > best_score )); then
            best_score=$_score
            best_off="$child"
            best_pa="${snap[$pa_idx]}"
            best_pb="${snap[$pb_idx]}"
            best_xp=$xp
        fi

        # Reservoir sample of losers for display
        if (( ${#disp_pool[@]} < DISPLAY_LOSERS )); then
            disp_pool+=("$child")
            disp_scores+=("$_score")
        else
            local ridx=$(( RANDOM % (p + 1) ))
            if (( ridx < DISPLAY_LOSERS )); then
                disp_pool[$ridx]="$child"
                disp_scores[$ridx]=$_score
            fi
        fi
    done

    # Advance: insert the best offspring into the pool.
    # Crucially, existing pool members are NOT discarded — the pool retains its
    # diverse lineages across generations, so recombination stays productive
    # even as the population converges.
    model_pool_insert "$best_off" $best_score

    M_LAST_XP=$best_xp
    M_LAST_PA="$best_pa"
    M_LAST_PB="$best_pb"

    (( M_GENERATION++ ))

    # Adapt mutation rate: stall detection and stress response.
    if (( M_POOL_SCORES[0] > M_PREV_BEST )); then
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

    # Build display sample, excluding current pool members to avoid repeats
    M_SAMPLE=()
    M_SAMPLE_SCORES=()
    for (( s=0; s<${#disp_pool[@]}; s++ )); do
        local in_pool=0
        for pm in "${M_POOL[@]}"; do
            [[ "${disp_pool[$s]}" == "$pm" ]] && in_pool=1 && break
        done
        if (( !in_pool )); then
            M_SAMPLE+=("${disp_pool[$s]}")
            M_SAMPLE_SCORES+=("${disp_scores[$s]}")
        fi
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# VIEW — display only, never mutates state
# ═══════════════════════════════════════════════════════════════════════════════

# Sets _color based on score percentage
_score_color() {
    local pct=$(( $1 * 100 / $2 ))
    if   (( pct >= 90 )); then _color=$GREEN
    elif (( pct >= 60 )); then _color=$CYAN
    elif (( pct >= 30 )); then _color=$YELLOW
    else                       _color=$RED
    fi
}

# Print one string character-by-character: green=match, red=wrong; dimmed variant available
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
    printf "${BOLD}${MAGENTA}  ║     DAWKINS' WEASEL  ·  OPTIMISED SELECTION          ║${RESET}\n"
    printf "${BOLD}${MAGENTA}  ╚══════════════════════════════════════════════════════╝${RESET}\n\n"
    printf "  ${DIM}Target  »${RESET} ${BOLD}${WHITE}%s${RESET}\n" "$TARGET"
    printf "  ${DIM}Start   »${RESET} ${DIM}%s${RESET}\n" "${M_POOL[0]}"
    printf "  ${DIM}Config  »${RESET} ${DIM}%d offspring/gen  ·  pool %d  ·  μ %d%%→%d%% after %d stall gens${RESET}\n" \
        "$POPULATION" "$POOL_SIZE" "$BASE_MUT_RATE" "$STRESS_MUT_RATE" "$STALL_THRESHOLD"
    printf "\n  ${DIM}──────────────────────────────────────────────────────${RESET}\n\n"
}

view_reasoning() {
    printf "\n  ${MAGENTA}▸ %s${RESET}\n\n" "$1"
}

view_generation() {
    _score_color "${M_POOL_SCORES[0]}" "$LEN"
    local col="$_color"

    # ── generation header ─────────────────────────────────────────────────────
    local mu_tag
    if (( M_STRESSED )); then
        mu_tag="${RED}${BOLD}[stress: μ=${M_MUT_RATE}%]${RESET}"
    else
        mu_tag="${DIM}[μ=${M_MUT_RATE}%]${RESET}"
    fi
    printf "  ${DIM}── Gen %4d ──────────────────────────── ${RESET}${col}${BOLD}%2d${RESET}${DIM}/%d ──${RESET}  %b\n" \
        "$M_GENERATION" "${M_POOL_SCORES[0]}" "$LEN" "$mu_tag"

    # ── gene pool ─────────────────────────────────────────────────────────────
    local pn=${#M_POOL[@]}
    for (( i=0; i<pn; i++ )); do
        _score_color "${M_POOL_SCORES[$i]}" "$LEN"
        if (( i == 0 )); then
            printf "  ${BOLD}●${RESET}  "
            _view_string "${M_POOL[$i]}" 0
            printf "   ${_color}${BOLD}%2d${RESET}${DIM}/%d${RESET}\n" "${M_POOL_SCORES[$i]}" "$LEN"
        else
            printf "  ${DIM}●  "
            _view_string "${M_POOL[$i]}" 1
            printf "   ${_color}%2d${RESET}${DIM}/%d${RESET}\n" "${M_POOL_SCORES[$i]}" "$LEN"
        fi
    done
    printf "\n"

    # ── eliminated offspring ──────────────────────────────────────────────────
    for (( s=0; s<${#M_SAMPLE[@]}; s++ )); do
        local sc="${M_SAMPLE_SCORES[$s]}"
        printf "  ${DIM}${RED}✗${RESET}  ${DIM}"
        _view_string "${M_SAMPLE[$s]}" 1
        printf "${RESET}   ${DIM}%2d/%d${RESET}\n" "$sc" "$LEN"
    done

    # ── crossover parents ─────────────────────────────────────────────────────
    if [[ "$M_LAST_PA" != "$M_LAST_PB" ]]; then
        printf "  ${DIM}─ cross ×%-2d ─────────────────────────────────────────────${RESET}\n" "$M_LAST_XP"
        printf "  ${DIM}A  "
        _view_string "$M_LAST_PA" 1
        printf "${RESET}\n"
        printf "  ${DIM}B  "
        _view_string "$M_LAST_PB" 1
        printf "${RESET}\n"
    else
        printf "  ${DIM}─ (pool size 1 — crossover not yet available) ───────────────${RESET}\n"
    fi

    # ── selected ──────────────────────────────────────────────────────────────
    printf "  ${DIM}─ selected ──────────────────────────────────────────────${RESET}\n"
    printf "  ${GREEN}${BOLD}✓${RESET}  "
    _view_string "${M_POOL[0]}" 0
    printf "   ${col}${BOLD}%2d${RESET}${DIM}/%d${RESET}" "${M_POOL_SCORES[0]}" "$LEN"
    if (( M_POOL_SCORES[0] > M_PREV_BEST )); then
        local delta=$(( M_POOL_SCORES[0] - M_PREV_BEST ))
        printf "  ${GREEN}${BOLD}↑ +%d${RESET}" "$delta"
    else
        printf "  ${DIM}[=]${RESET}"
    fi
    printf "\n\n"
}

view_complete() {
    printf "\n"
    printf "  ${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${RESET}\n"
    printf "  ${BOLD}${GREEN}║  ✓  TARGET REACHED                                   ║${RESET}\n"
    printf "  ${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${RESET}\n\n"
    printf "  ${BOLD}${WHITE}%s${RESET}\n\n" "$TARGET"
    printf "  ${DIM}Generations  : %d${RESET}\n" "$M_GENERATION"
    printf "  ${DIM}Population   : %d offspring/gen${RESET}\n" "$POPULATION"
    printf "  ${DIM}Pool size    : %d${RESET}\n" "$POOL_SIZE"
    printf "  ${DIM}Mutation     : %d%% base  ·  %d%% stress${RESET}\n\n" "$BASE_MUT_RATE" "$STRESS_MUT_RATE"
    view_reasoning "Crossover let separate lineages combine gains that sequential mutation would have had to accumulate one at a time."
    view_reasoning "Compare the generation count to cumulative_selection.sh — same population, same baseline mutation rate."
}

# ═══════════════════════════════════════════════════════════════════════════════
# PRESENTER — orchestrates model + view, owns the event loop
# ═══════════════════════════════════════════════════════════════════════════════

presenter_run() {
    model_init
    view_header
    view_reasoning "Pool of $POOL_SIZE elites · two-parent crossover · adaptive μ (rises to ${STRESS_MUT_RATE}% after ${STALL_THRESHOLD} stall gens, resets on improvement)."

    local hit_25=0 hit_50=0 hit_75=0 hit_90=0
    local stress_noted=0

    while [[ "${M_POOL[0]}" != "$TARGET" ]]; do
        model_next_generation
        view_generation

        local pct=$(( M_POOL_SCORES[0] * 100 / LEN ))

        if (( pct >= 25 && !hit_25 )); then
            hit_25=1
            view_reasoning "25% match. The pool now holds distinct variants — crossover is mixing improvements that arose independently in separate lineages."
        fi
        if (( pct >= 50 && !hit_50 )); then
            hit_50=1
            view_reasoning "50% match. Each pool member has locked in different correct characters. A single crossover event can now combine two half-solved strings."
        fi
        if (( pct >= 75 && !hit_75 )); then
            hit_75=1
            view_reasoning "75% match. Pool members are converging — crossover yields diminishing returns as lineages share more correct characters."
        fi
        if (( pct >= 90 && !hit_90 )); then
            hit_90=1
            view_reasoning "90% match. Fine-tuning the last few positions. Mutation is doing most of the work now; the pool members are nearly identical."
        fi

        if (( M_STRESSED && !stress_noted )); then
            stress_noted=1
            view_reasoning "Stalled for $STALL_THRESHOLD generations — μ raised to ${STRESS_MUT_RATE}%. In bacteria, prolonged stress triggers the SOS pathway: error-prone polymerases are expressed, trading accuracy for exploration."
        fi
        if (( !M_STRESSED && stress_noted )); then
            stress_noted=0
            view_reasoning "Improvement found — μ reset to ${BASE_MUT_RATE}%. Stress response deactivated, as in cells that down-regulate error-prone polymerases once the environmental pressure lifts."
        fi
    done

    view_complete
}

presenter_run
