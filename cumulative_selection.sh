#!/usr/bin/env bash
# cumulative_selection.sh — Dawkins' Weasel: cumulative selection
# Architecture: MVP  (Model · View · Presenter)

# ─── CONSTANTS ────────────────────────────────────────────────────────────────

TARGET="METHINKS IT IS LIKE A WEASEL"
ALPHABET="ABCDEFGHIJKLMNOPQRSTUVWXYZ "
LEN=${#TARGET}
ALPHA_LEN=${#ALPHABET}
POPULATION=100
MUTATION_RATE=5      # % chance each character mutates per offspring
DISPLAY_LOSERS=4     # how many eliminated offspring to show per generation

# ─── COLORS ───────────────────────────────────────────────────────────────────

RESET=$'\e[0m'
BOLD=$'\e[1m'
DIM=$'\e[2m'
RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
CYAN=$'\e[36m'
WHITE=$'\e[97m'

# ═══════════════════════════════════════════════════════════════════════════════
# MODEL — pure logic, no output
# ═══════════════════════════════════════════════════════════════════════════════

M_PARENT=""
M_SCORE=0
M_GENERATION=0
M_STALL=0
M_PREV_SCORE=0
M_SAMPLE=()           # reservoir sample of losing offspring (strings)
M_SAMPLE_SCORES=()    # their scores

model_init() {
    M_PARENT=""
    for (( i=0; i<LEN; i++ )); do
        M_PARENT+="${ALPHABET:$(( RANDOM % ALPHA_LEN )):1}"
    done
    M_SCORE=0
    for (( i=0; i<LEN; i++ )); do
        [[ "${M_PARENT:$i:1}" == "${TARGET:$i:1}" ]] && (( M_SCORE++ ))
    done
    M_GENERATION=0
    M_STALL=0
    M_PREV_SCORE=0
    M_SAMPLE=()
    M_SAMPLE_SCORES=()
}

model_score() {
    local s="$1"
    _score=0
    for (( i=0; i<LEN; i++ )); do
        [[ "${s:$i:1}" == "${TARGET:$i:1}" ]] && (( _score++ ))
    done
}

model_next_generation() {
    # ┌─────────────────────────────────────────────────────────────────────┐
    # │  ALGORITHM: cumulative selection (variation + selection per gen)    │
    # └─────────────────────────────────────────────────────────────────────┘

    M_PREV_SCORE=$M_SCORE
    local best="$M_PARENT"
    local best_score=$M_SCORE
    local pool=()
    local pool_scores=()

    # Step 1 — breed POPULATION offspring from the current parent.
    # Each character is inherited unchanged, except when a random draw falls
    # within MUTATION_RATE% — then it is replaced by a random alphabet symbol.
    # Mutations are independent per character and per offspring.
    for (( p=0; p<POPULATION; p++ )); do
        local offspring=""
        for (( i=0; i<LEN; i++ )); do
            if (( RANDOM % 100 < MUTATION_RATE )); then
                offspring+="${ALPHABET:$(( RANDOM % ALPHA_LEN )):1}"
            else
                offspring+="${M_PARENT:$i:1}"
            fi
        done

        # Step 2 — score the offspring: count exact positional matches.
        model_score "$offspring"

        # Step 3 — selection: keep whichever single offspring scores highest.
        # The parent itself is the starting baseline — it survives if no
        # offspring beats it (elitism). Only one string advances; all others
        # are discarded. This is what makes progress cumulative: each winner
        # becomes the parent for the next round, so gains are never lost.
        if (( _score > best_score )); then
            best="$offspring"
            best_score=$_score
        fi

        # Reservoir sampling — maintain a uniformly random sample of losers
        # for display without biasing toward early or late offspring.
        if (( ${#pool[@]} < DISPLAY_LOSERS )); then
            pool+=("$offspring")
            pool_scores+=("$_score")
        else
            local ridx=$(( RANDOM % (p + 1) ))
            if (( ridx < DISPLAY_LOSERS )); then
                pool[$ridx]="$offspring"
                pool_scores[$ridx]=$_score
            fi
        fi
    done

    # Exclude the winner from the loser sample to avoid duplicate display
    M_SAMPLE=()
    M_SAMPLE_SCORES=()
    for (( s=0; s<${#pool[@]}; s++ )); do
        if [[ "${pool[$s]}" != "$best" ]]; then
            M_SAMPLE+=("${pool[$s]}")
            M_SAMPLE_SCORES+=("${pool_scores[$s]}")
        fi
    done

    # Step 4 — advance: the winner becomes the new parent. Progress is
    # preserved unconditionally; the next generation never starts from scratch.
    M_PARENT="$best"
    M_SCORE=$best_score
    (( M_GENERATION++ ))
    if (( M_SCORE > M_PREV_SCORE )); then
        M_STALL=0
    else
        (( M_STALL++ ))
    fi
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

view_header() {
    printf "\n"
    printf "${BOLD}${CYAN}  ╔══════════════════════════════════════════════════════╗${RESET}\n"
    printf "${BOLD}${CYAN}  ║     DAWKINS' WEASEL  ·  CUMULATIVE SELECTION         ║${RESET}\n"
    printf "${BOLD}${CYAN}  ╚══════════════════════════════════════════════════════╝${RESET}\n\n"
    printf "  ${DIM}Target  »${RESET} ${BOLD}${WHITE}%s${RESET}\n" "$TARGET"
    printf "  ${DIM}Start   »${RESET} ${DIM}%s${RESET}\n" "$M_PARENT"
    printf "  ${DIM}Config  »${RESET} ${DIM}%d offspring/gen  ·  %d%% mutation rate${RESET}\n" "$POPULATION" "$MUTATION_RATE"
    printf "\n  ${DIM}──────────────────────────────────────────────────────${RESET}\n\n"
}

view_reasoning() {
    printf "\n  ${CYAN}▸ %s${RESET}\n\n" "$1"
}

# Print one offspring string: correct chars vs wrong chars, dimmed or bold.
_view_string() {
    local str="$1" dimmed=$2
    for (( i=0; i<LEN; i++ )); do
        local ch="${str:$i:1}"
        if [[ "$ch" == "${TARGET:$i:1}" ]]; then
            if (( dimmed )); then
                printf "${RESET}${DIM}%s${DIM}" "$ch"
            else
                printf "${GREEN}${BOLD}%s${RESET}" "$ch"
            fi
        else
            if (( dimmed )); then
                printf "${RED}%s${RESET}${DIM}" "$ch"
            else
                printf "${DIM}${RED}%s${RESET}" "$ch"
            fi
        fi
    done
}

view_generation() {
    _score_color "$M_SCORE" "$LEN"
    local col="$_color"

    # ── generation header ────────────────────────────────────────────────────
    printf "  ${DIM}── Gen %4d ─────────────────────────────────────── ${RESET}${col}${BOLD}%2d${RESET}${DIM}/%d ──${RESET}\n" \
        "$M_GENERATION" "$M_SCORE" "$LEN"

    # ── eliminated offspring (losers) ────────────────────────────────────────
    for (( s=0; s<${#M_SAMPLE[@]}; s++ )); do
        local sc="${M_SAMPLE_SCORES[$s]}"
        _score_color "$sc" "$LEN"
        printf "  ${DIM}${RED}✗${RESET}  ${DIM}"
        _view_string "${M_SAMPLE[$s]}" 1
        printf "${RESET}   ${DIM}%2d/%d${RESET}\n" "$sc" "$LEN"
    done

    # ── divider ──────────────────────────────────────────────────────────────
    printf "  ${DIM}─ selected ──────────────────────────────────────────────${RESET}\n"

    # ── survivor ─────────────────────────────────────────────────────────────
    printf "  ${GREEN}${BOLD}✓${RESET}  "
    _view_string "$M_PARENT" 0
    printf "   ${col}${BOLD}%2d${RESET}${DIM}/%d${RESET}" "$M_SCORE" "$LEN"
    if (( M_SCORE > M_PREV_SCORE )); then
        local delta=$(( M_SCORE - M_PREV_SCORE ))
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
    printf "  ${DIM}Mutation     : %d%% per character${RESET}\n\n" "$MUTATION_RATE"
    view_reasoning "Selection doesn't plan — it just keeps what works. That's enough."
}

# ═══════════════════════════════════════════════════════════════════════════════
# PRESENTER — orchestrates model + view, owns the event loop
# ═══════════════════════════════════════════════════════════════════════════════

presenter_run() {
    model_init
    view_header
    view_reasoning "Starting from a completely random string. Each generation breeds $POPULATION offspring — small random mutations — then discards all but the closest match to the target."

    local hit_25=0 hit_50=0 hit_75=0 hit_90=0
    local stall_noted=0

    while [[ "$M_PARENT" != "$TARGET" ]]; do
        model_next_generation
        view_generation

        local pct=$(( M_SCORE * 100 / LEN ))

        if (( pct >= 25 && hit_25 == 0 )); then
            hit_25=1
            view_reasoning "25% match. Correct characters are locking in — selection pressure keeps them while random mutation continues to probe the rest."
        fi
        if (( pct >= 50 && hit_50 == 0 )); then
            hit_50=1
            view_reasoning "50% match. Half the string is fixed. Pure random search at this same speed would still be at effectively zero."
        fi
        if (( pct >= 75 && hit_75 == 0 )); then
            hit_75=1
            view_reasoning "75% match. The already-correct positions are shielded by selection — only the wrong characters are still drifting toward their target."
        fi
        if (( pct >= 90 && hit_90 == 0 )); then
            hit_90=1
            view_reasoning "90% match. Fine-tuning the last few characters. Notice the rest of the string is now completely stable."
        fi

        if (( M_STALL >= 15 && stall_noted == 0 )); then
            stall_noted=1
            view_reasoning "No improvement for 15 generations — waiting for the right mutation to appear. Selection can only act on variation that actually arises."
        fi
        if (( M_SCORE > M_PREV_SCORE )); then
            stall_noted=0
        fi
    done

    view_complete
}

presenter_run
