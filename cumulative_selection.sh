#!/usr/bin/env bash
# cumulative_selection.sh — Dawkins' Weasel: cumulative selection
# Architecture: MVP  (Model · View · Presenter)

# ─── CONSTANTS ────────────────────────────────────────────────────────────────

TARGET="METHINKS IT IS LIKE A WEASEL"
ALPHABET="ABCDEFGHIJKLMNOPQRSTUVWXYZ "
LEN=${#TARGET}
ALPHA_LEN=${#ALPHABET}
POPULATION=100
MUTATION_RATE=5   # % chance each character mutates per offspring

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
M_STALL=0          # generations without score improvement
M_PREV_SCORE=0

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
}

# Sets _score for a given string (uses no global state)
model_score() {
    local s="$1"
    _score=0
    for (( i=0; i<LEN; i++ )); do
        [[ "${s:$i:1}" == "${TARGET:$i:1}" ]] && (( _score++ ))
    done
}

# Breeds POPULATION offspring, selects the best, advances one generation
model_next_generation() {
    M_PREV_SCORE=$M_SCORE
    local best="$M_PARENT"
    local best_score=$M_SCORE

    for (( p=0; p<POPULATION; p++ )); do
        local offspring=""
        for (( i=0; i<LEN; i++ )); do
            if (( RANDOM % 100 < MUTATION_RATE )); then
                offspring+="${ALPHABET:$(( RANDOM % ALPHA_LEN )):1}"
            else
                offspring+="${M_PARENT:$i:1}"
            fi
        done
        model_score "$offspring"
        if (( _score > best_score )); then
            best="$offspring"
            best_score=$_score
        fi
    done

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

view_bar() {
    local score=$1 total=$2 width=28
    local filled=$(( score * width / total ))
    local pct=$(( score * 100 / total ))
    local color
    (( pct <  30 )) && color=$RED
    (( pct >= 30 )) && color=$YELLOW
    (( pct >= 60 )) && color=$CYAN
    (( pct >= 90 )) && color=$GREEN
    printf "${color}"
    for (( i=0; i<filled;           i++ )); do printf "█"; done
    printf "${DIM}"
    for (( i=filled; i<width; i++ )); do printf "░"; done
    printf "${RESET}"
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

view_generation() {
    local pct=$(( M_SCORE * 100 / LEN ))
    local score_color
    (( pct <  30 )) && score_color=$RED
    (( pct >= 30 )) && score_color=$YELLOW
    (( pct >= 60 )) && score_color=$CYAN
    (( pct >= 90 )) && score_color=$GREEN

    printf "  ${DIM}Gen %4d${RESET} │ " "$M_GENERATION"
    view_bar "$M_SCORE" "$LEN"
    printf " ${score_color}${BOLD}%2d${RESET}${DIM}/%d${RESET} │ " "$M_SCORE" "$LEN"

    # Print each character: green+bold if correct, dim+red if wrong
    for (( i=0; i<LEN; i++ )); do
        local ch="${M_PARENT:$i:1}"
        if [[ "$ch" == "${TARGET:$i:1}" ]]; then
            printf "${GREEN}${BOLD}%s${RESET}" "$ch"
        else
            printf "${DIM}${RED}%s${RESET}" "$ch"
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
