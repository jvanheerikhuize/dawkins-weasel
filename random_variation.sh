#!/usr/bin/env bash
# random_variation.sh — Dawkins' Weasel: pure random search
# Architecture: MVP  (Model · View · Presenter)
# Press Ctrl+C to stop. This will effectively never find the target.

# ─── CONSTANTS ────────────────────────────────────────────────────────────────

TARGET="METHINKS IT IS LIKE A WEASEL"
ALPHABET="ABCDEFGHIJKLMNOPQRSTUVWXYZ "
LEN=${#TARGET}
ALPHA_LEN=${#ALPHABET}

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

M_CANDIDATE=""
M_ATTEMPTS=0
M_BEST=""
M_BEST_SCORE=-1
M_START=$SECONDS

model_init() {
    M_CANDIDATE=""
    M_ATTEMPTS=0
    M_BEST=""
    M_BEST_SCORE=-1
    M_START=$SECONDS
}

model_generate() {
    # ┌─────────────────────────────────────────────────────────────────────┐
    # │  ALGORITHM: pure random search (no memory between attempts)         │
    # └─────────────────────────────────────────────────────────────────────┘

    # Step 1 — generate a candidate by picking each character independently
    # at random. No information from the previous attempt is used; every
    # character slot is a fresh draw from the 27-symbol alphabet.
    M_CANDIDATE=""
    for (( i=0; i<LEN; i++ )); do
        M_CANDIDATE+="${ALPHABET:$(( RANDOM % ALPHA_LEN )):1}"
    done
    (( M_ATTEMPTS++ ))

    # Step 2 — score the candidate: count how many positions match the target
    # exactly. This is the fitness function — 28/28 means we found the target.
    local s=0
    for (( i=0; i<LEN; i++ )); do
        [[ "${M_CANDIDATE:$i:1}" == "${TARGET:$i:1}" ]] && (( s++ ))
    done

    # Step 3 — track the all-time best score for display purposes only.
    # Crucially, this best string is NEVER fed back into the next attempt —
    # that is the key difference from cumulative selection.
    if (( s > M_BEST_SCORE )); then
        M_BEST_SCORE=$s
        M_BEST="$M_CANDIDATE"
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

# Print one string: correct chars in green, wrong chars in red (or dimmed variants)
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

view_bar() {
    local score=$1 total=$2 width=28
    local filled=$(( score * width / total ))
    _score_color "$score" "$total"
    printf "${_color}"
    for (( i=0; i<filled;           i++ )); do printf "█"; done
    printf "${DIM}"
    for (( i=filled; i<width; i++ )); do printf "░"; done
    printf "${RESET}"
}

view_header() {
    printf "\n"
    printf "${BOLD}${RED}  ╔══════════════════════════════════════════════════════╗${RESET}\n"
    printf "${BOLD}${RED}  ║     DAWKINS' WEASEL  ·  PURE RANDOM VARIATION        ║${RESET}\n"
    printf "${BOLD}${RED}  ╚══════════════════════════════════════════════════════╝${RESET}\n\n"
    printf "  ${DIM}Target  »${RESET} ${BOLD}${WHITE}%s${RESET}\n" "$TARGET"
    printf "  ${DIM}Chars   »${RESET} ${DIM}%d  ·  Alphabet %d  ·  Odds ≈ 1 in 27²⁸ ≈ 2.4×10³⁹${RESET}\n" "$LEN" "$ALPHA_LEN"
    printf "\n  ${DIM}──────────────────────────────────────────────────────${RESET}\n\n"
}

view_reasoning() {
    printf "  ${CYAN}▸ %s${RESET}\n\n" "$1"
}

view_progress() {
    local elapsed=$(( SECONDS - M_START ))
    local rate=0
    (( elapsed > 0 )) && rate=$(( M_ATTEMPTS / elapsed ))
    printf "  ${DIM}%13d attempts  ·  %4ds  ·  ~%d/s${RESET}  │  " \
        "$M_ATTEMPTS" "$elapsed" "$rate"
    _view_string "$M_CANDIDATE" 1
    printf "\n"
}

view_best() {
    _score_color "$M_BEST_SCORE" "$LEN"
    printf "\n  ${YELLOW}${BOLD}Best so far »${RESET}  "
    _view_string "$M_BEST" 0
    printf "  "
    view_bar "$M_BEST_SCORE" "$LEN"
    printf "  ${_color}${BOLD}%d/%d${RESET}\n\n" "$M_BEST_SCORE" "$LEN"
}

view_interrupted() {
    local elapsed=$(( SECONDS - M_START ))
    printf "\n\n"
    printf "  ${BOLD}${YELLOW}Stopped after %d attempts in %ds.${RESET}\n\n" "$M_ATTEMPTS" "$elapsed"
    view_best
    view_reasoning "No progress was stored between attempts. Every roll of the dice starts from scratch."
    view_reasoning "Compare this to cumulative_selection.sh — same alphabet, same target, radically different outcome."
}

view_found() {
    local elapsed=$(( SECONDS - M_START ))
    printf "\n\n"
    printf "  ${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${RESET}\n"
    printf "  ${BOLD}${GREEN}║  ✓  FOUND  (astronomically unlikely — congratulations)║${RESET}\n"
    printf "  ${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${RESET}\n\n"
    printf "  ${BOLD}${WHITE}%s${RESET}\n\n" "$TARGET"
    printf "  ${DIM}Attempts : %d${RESET}\n" "$M_ATTEMPTS"
    printf "  ${DIM}Time     : %ds${RESET}\n\n" "$elapsed"
}

# ═══════════════════════════════════════════════════════════════════════════════
# PRESENTER — orchestrates model + view, owns the event loop
# ═══════════════════════════════════════════════════════════════════════════════

_on_interrupt() {
    view_interrupted
    exit 0
}

presenter_run() {
    model_init
    view_header
    view_reasoning "Each attempt generates a fresh random string — no information is carried forward from previous tries."

    trap _on_interrupt INT

    local prev_best=-1
    local did_1m=0 did_10m=0

    while true; do
        model_generate

        if [[ "$M_CANDIDATE" == "$TARGET" ]]; then
            view_found
            break
        fi

        if (( M_ATTEMPTS % 10000 == 0 )); then
            view_progress
        fi

        if (( M_BEST_SCORE > prev_best )); then
            prev_best=$M_BEST_SCORE
            view_best
        fi

        if (( M_ATTEMPTS == 1000000 && did_1m == 0 )); then
            did_1m=1
            view_reasoning "1 million attempts in. Cumulative selection would have found the target several times over by now."
        fi

        if (( M_ATTEMPTS == 10000000 && did_10m == 0 )); then
            did_10m=1
            view_reasoning "10 million attempts. We have covered a negligible fraction of the 2.4×10³⁹ possible strings."
        fi
    done
}

presenter_run
