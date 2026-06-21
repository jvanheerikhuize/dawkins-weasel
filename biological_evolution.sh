#!/usr/bin/env bash
# biological_evolution.sh — Dawkins' Weasel: diploid genetics with epistasis
# Architecture: MVP (Model · View · Presenter)
#
# Three mechanisms absent from all prior scripts:
#
#   1. Diploid genome + dominance
#      Every individual carries TWO alleles per position (haplotypes A and B).
#      Phenotype — what selection acts on — obeys per-position dominance rules
#      fixed at initialisation.  At dominant positions (~80%) one correct allele
#      suffices to express the correct character.  At recessive positions (~20%)
#      both alleles must be correct.  Beneficial mutations at recessive positions
#      therefore accumulate hidden in heterozygotes, invisible to selection, until
#      two carriers mate and produce a homozygous offspring that reveals them.
#      This is Mendelian genetics: the ratio of carrier × carrier → homozygous
#      correct offspring is exactly 1-in-4, as Mendel's peas predicted.
#
#   2. Meiosis — intra-individual recombination
#      When an individual reproduces it does not pass either haplotype intact.
#      Instead it independently shuffles its own two alleles at each position to
#      form a haploid gamete.  Two such gametes — one from each parent — fuse
#      into the diploid offspring.  This is structurally different from all prior
#      scripts, where crossover swapped segments between two complete parental
#      sequences.  Here recombination happens inside a single organism before
#      the gametes even meet, modelling the independent assortment of alleles
#      during meiosis I.
#
#   3. Epistasis — non-additive fitness interactions
#      EPIS_COUNT position pairs are fixed at initialisation.  When both
#      positions of a pair are phenotypically correct the individual earns a
#      fitness bonus (+1 per complete pair).  Positions in an incomplete pair
#      contribute less per character than they would in isolation, making the
#      landscape rugged: reaching a local plateau requires the "right pairing"
#      before a gradient reappears.  This is why evolution sometimes appears to
#      stall even while correct characters accumulate in the population.

# ─── CONSTANTS ────────────────────────────────────────────────────────────────

TARGET="METHINKS IT IS LIKE A WEASEL"
ALPHABET="ABCDEFGHIJKLMNOPQRSTUVWXYZ "
LEN=${#TARGET}
ALPHA_LEN=${#ALPHABET}

POP_SIZE=40               # diploid individuals (effective variation ≈ 2× haploid)
TOURNAMENT_SIZE=3
BASE_MUT_RATE=5           # applied independently to each haplotype
STRESS_MUT_RATE=20
STALL_THRESHOLD=25        # recessive positions stall longer; patience needed
REC_FRACTION=20           # % of positions where correct allele is recessive
EPIS_COUNT=4              # number of fitness-interaction pairs
DISPLAY_COUNT=4

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

M_POP_A=()        # haplotype A for each individual
M_POP_B=()        # haplotype B for each individual
M_PHENO=()        # expressed phenotype (what selection sees)
M_SCORE=()        # total fitness (base phenotypic + epistasis bonuses)
M_BASE_SCORE=()   # phenotypic score only (correct positions in phenotype)
M_HET=()          # hidden-carrier count: recessive positions with one correct
                  # allele that cannot be expressed (invisible to selection)
M_DOM=""          # dominance string: '0'=correct-dominant '1'=correct-recessive
EPIS_X=()         # first position index of each epistasis pair
EPIS_Y=()         # second position index
M_GENERATION=0
M_BEST_PHENO=""
M_BEST_SCORE=0
M_MEAN_BASE=0     # mean phenotypic score across population
M_PREV_MEAN_BASE=0
M_STALL=0
M_MUT_RATE=$BASE_MUT_RATE
M_STRESSED=0
M_SAMPLE_A=()
M_SAMPLE_B=()
M_SAMPLE_PHENO=()
M_SAMPLE_SCORES=()
M_SAMPLE_BASE=()
M_SAMPLE_HET=()
M_START=$SECONDS

# Score one diploid individual.
# Reads globals: M_DOM, EPIS_X, EPIS_Y, EPIS_COUNT, TARGET, LEN
# Sets globals:  _pheno, _base_score, _het_count, _score (base + epistasis)
model_score_individual() {
    local ha="$1" hb="$2"
    _pheno=""
    _base_score=0
    _het_count=0
    local i
    for (( i=0; i<LEN; i++ )); do
        local ca="${ha:$i:1}"
        local cb="${hb:$i:1}"
        local tgt="${TARGET:$i:1}"
        local dom="${M_DOM:$i:1}"
        local ph
        if [[ "$ca" == "$tgt" && "$cb" == "$tgt" ]]; then
            # Homozygous correct: always expressed regardless of dominance
            ph="$tgt"
        elif [[ "$ca" == "$tgt" || "$cb" == "$tgt" ]]; then
            # Heterozygous: one allele correct, one wrong
            if [[ "$dom" == "0" ]]; then
                # Correct allele is dominant — phenotype is correct
                ph="$tgt"
            else
                # Correct allele is recessive — phenotype shows the wrong allele.
                # The individual is a "carrier": carries potential invisible to
                # selection.  _het_count records this hidden variation.
                if [[ "$ca" == "$tgt" ]]; then ph="$cb"; else ph="$ca"; fi
                (( _het_count++ ))
            fi
        else
            # Both alleles wrong
            ph="$ca"
        fi
        _pheno+="$ph"
        [[ "$ph" == "$tgt" ]] && (( _base_score++ ))
    done
    # Epistasis: bonus for each pair where both positions are phenotypically correct
    _score=$_base_score
    local e
    for (( e=0; e<EPIS_COUNT; e++ )); do
        if [[ "${_pheno:${EPIS_X[$e]}:1}" == "${TARGET:${EPIS_X[$e]}:1}" && \
              "${_pheno:${EPIS_Y[$e]}:1}" == "${TARGET:${EPIS_Y[$e]}:1}" ]]; then
            (( _score++ ))
        fi
    done
}

# Produce a haploid gamete by recombining an individual's own two haplotypes.
# Each position is drawn independently from haplotype A or B with equal
# probability — modelling uniform independent assortment during meiosis I.
model_make_gamete() {
    local ha="$1" hb="$2"
    _gamete=""
    local i
    for (( i=0; i<LEN; i++ )); do
        if (( RANDOM % 2 == 0 )); then
            _gamete+="${ha:$i:1}"
        else
            _gamete+="${hb:$i:1}"
        fi
    done
}

model_mutate() {
    local s="$1"
    _mutated=""
    local i
    for (( i=0; i<LEN; i++ )); do
        if (( RANDOM % 100 < M_MUT_RATE )); then
            _mutated+="${ALPHABET:$(( RANDOM % ALPHA_LEN )):1}"
        else
            _mutated+="${s:$i:1}"
        fi
    done
}

# Tournament selection on total score (phenotypic + epistasis).
model_tournament() {
    local best_idx=$(( RANDOM % POP_SIZE ))
    local best_sc=${M_SCORE[$best_idx]}
    local t
    for (( t=1; t<TOURNAMENT_SIZE; t++ )); do
        local idx=$(( RANDOM % POP_SIZE ))
        if (( ${M_SCORE[$idx]} > best_sc )); then
            best_idx=$idx
            best_sc=${M_SCORE[$idx]}
        fi
    done
    _tournament_idx=$best_idx
}

model_compute_stats() {
    M_BEST_SCORE=0
    M_BEST_PHENO=""
    local total_base=0
    local i
    for (( i=0; i<POP_SIZE; i++ )); do
        (( total_base += ${M_BASE_SCORE[$i]} ))
        if (( ${M_SCORE[$i]} > M_BEST_SCORE )); then
            M_BEST_SCORE=${M_SCORE[$i]}
            M_BEST_PHENO="${M_PHENO[$i]}"
        fi
    done
    M_MEAN_BASE=$(( total_base / POP_SIZE ))
}

model_init() {
    # Dominance: each position independently recessive with probability REC_FRACTION%
    M_DOM=""
    local i
    for (( i=0; i<LEN; i++ )); do
        if (( RANDOM % 100 < REC_FRACTION )); then
            M_DOM+="1"
        else
            M_DOM+="0"
        fi
    done

    # Epistasis pairs: EPIS_COUNT pairs of distinct positions, no position in two pairs
    EPIS_X=()
    EPIS_Y=()
    local -a used_pos
    for (( i=0; i<LEN; i++ )); do used_pos[$i]=0; done
    local made=0 attempts=0
    while (( made < EPIS_COUNT && attempts < 500 )); do
        local x=$(( RANDOM % LEN ))
        local y=$(( RANDOM % LEN ))
        (( attempts++ ))
        if (( x != y && !used_pos[$x] && !used_pos[$y] )); then
            EPIS_X+=($x)
            EPIS_Y+=($y)
            used_pos[$x]=1
            used_pos[$y]=1
            (( made++ ))
        fi
    done
    EPIS_COUNT=$made

    # Random diploid population
    M_POP_A=()
    M_POP_B=()
    M_PHENO=()
    M_SCORE=()
    M_BASE_SCORE=()
    M_HET=()
    local p
    for (( p=0; p<POP_SIZE; p++ )); do
        local ha="" hb=""
        for (( i=0; i<LEN; i++ )); do
            ha+="${ALPHABET:$(( RANDOM % ALPHA_LEN )):1}"
            hb+="${ALPHABET:$(( RANDOM % ALPHA_LEN )):1}"
        done
        model_score_individual "$ha" "$hb"
        M_POP_A+=("$ha")
        M_POP_B+=("$hb")
        M_PHENO+=("$_pheno")
        M_SCORE+=($_score)
        M_BASE_SCORE+=($_base_score)
        M_HET+=($_het_count)
    done

    model_compute_stats
    M_GENERATION=0
    M_STALL=0
    M_MUT_RATE=$BASE_MUT_RATE
    M_STRESSED=0
    M_PREV_MEAN_BASE=0
    M_START=$SECONDS
}

model_next_generation() {
    # ┌─────────────────────────────────────────────────────────────────────┐
    # │  ALGORITHM: diploid sexual evolution with epistasis                 │
    # │    Step 1 — tournament selection of two parents                     │
    # │    Step 2 — meiosis: each parent shuffles its own haplotypes        │
    # │    Step 3 — gametes fuse; mutation applied to each gamete           │
    # │    Step 4 — score diploid offspring (phenotype + epistasis)         │
    # │    Step 5 — full generational replacement                           │
    # └─────────────────────────────────────────────────────────────────────┘
    M_PREV_MEAN_BASE=$M_MEAN_BASE

    local new_a=() new_b=() new_pheno=() new_score=() new_base=() new_het=()
    local p
    for (( p=0; p<POP_SIZE; p++ )); do
        # Step 1 — two distinct parents via tournament
        model_tournament
        local pa=$_tournament_idx
        local pb=$pa
        local tries=0
        while (( pb == pa && tries < 10 )); do
            model_tournament
            pb=$_tournament_idx
            (( tries++ ))
        done

        # Step 2 — meiosis: intra-individual allele shuffle within each parent.
        # Parent A independently draws from its own haplotype_A or haplotype_B
        # at each position.  Same for parent B.  Two independent gametes result.
        model_make_gamete "${M_POP_A[$pa]}" "${M_POP_B[$pa]}"
        local ga="$_gamete"
        model_make_gamete "${M_POP_A[$pb]}" "${M_POP_B[$pb]}"
        local gb="$_gamete"

        # Step 3 — point mutation applied independently to each gamete.
        # Mutation at this stage affects only one of the offspring's two alleles
        # per position — realistic, since each gamete is already haploid.
        model_mutate "$ga"; ga="$_mutated"
        model_mutate "$gb"; gb="$_mutated"

        # Step 4 — fuse gametes into diploid offspring; compute fitness
        model_score_individual "$ga" "$gb"
        new_a+=("$ga")
        new_b+=("$gb")
        new_pheno+=("$_pheno")
        new_score+=($_score)
        new_base+=($_base_score)
        new_het+=($_het_count)
    done

    # Step 5 — full generational replacement (non-overlapping generations)
    M_POP_A=("${new_a[@]}")
    M_POP_B=("${new_b[@]}")
    M_PHENO=("${new_pheno[@]}")
    M_SCORE=("${new_score[@]}")
    M_BASE_SCORE=("${new_base[@]}")
    M_HET=("${new_het[@]}")

    (( M_GENERATION++ ))
    model_compute_stats

    # Stall on mean phenotypic score.  A rising mean means the correct characters
    # are spreading through the population even if the champion is flat.
    if (( M_MEAN_BASE > M_PREV_MEAN_BASE )); then
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

    # Display sample: top DISPLAY_COUNT individuals by total score
    local -a used
    for (( i=0; i<POP_SIZE; i++ )); do used[$i]=0; done
    M_SAMPLE_A=()
    M_SAMPLE_B=()
    M_SAMPLE_PHENO=()
    M_SAMPLE_SCORES=()
    M_SAMPLE_BASE=()
    M_SAMPLE_HET=()
    local d
    for (( d=0; d<DISPLAY_COUNT; d++ )); do
        local top_idx=0 top_sc=-1
        for (( i=0; i<POP_SIZE; i++ )); do
            if (( !used[$i] && ${M_SCORE[$i]} > top_sc )); then
                top_sc=${M_SCORE[$i]}
                top_idx=$i
            fi
        done
        M_SAMPLE_A+=("${M_POP_A[$top_idx]}")
        M_SAMPLE_B+=("${M_POP_B[$top_idx]}")
        M_SAMPLE_PHENO+=("${M_PHENO[$top_idx]}")
        M_SAMPLE_SCORES+=($top_sc)
        M_SAMPLE_BASE+=(${M_BASE_SCORE[$top_idx]})
        M_SAMPLE_HET+=(${M_HET[$top_idx]})
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

# Print a diploid individual's phenotype with dominance-aware coloring:
#   GREEN bold  — correct phenotype, dominant position (1 allele sufficed)
#   CYAN  bold  — correct phenotype, recessive position (both alleles correct)
#   YELLOW      — wrong phenotype; carries one hidden correct recessive allele
#   DIM RED     — wrong phenotype; no correct allele present
_view_diploid() {
    local pheno="$1" ha="$2" hb="$3" dimmed=$4
    local i
    for (( i=0; i<LEN; i++ )); do
        local ph="${pheno:$i:1}"
        local ca="${ha:$i:1}"
        local cb="${hb:$i:1}"
        local tgt="${TARGET:$i:1}"
        local dom="${M_DOM:$i:1}"
        if [[ "$ph" == "$tgt" ]]; then
            if [[ "$dom" == "0" ]]; then
                if (( dimmed )); then printf "${DIM}${GREEN}%s${RESET}${DIM}" "$ph"
                else printf "${GREEN}${BOLD}%s${RESET}" "$ph"
                fi
            else
                if (( dimmed )); then printf "${DIM}${CYAN}%s${RESET}${DIM}" "$ph"
                else printf "${CYAN}${BOLD}%s${RESET}" "$ph"
                fi
            fi
        elif [[ "$ca" == "$tgt" || "$cb" == "$tgt" ]]; then
            # Carrier: one correct recessive allele hidden in wrong phenotype
            if (( dimmed )); then printf "${DIM}${YELLOW}%s${RESET}${DIM}" "$ph"
            else printf "${YELLOW}%s${RESET}" "$ph"
            fi
        else
            if (( dimmed )); then printf "${DIM}${RED}%s${RESET}${DIM}" "$ph"
            else printf "${DIM}${RED}%s${RESET}" "$ph"
            fi
        fi
    done
}

view_header() {
    local max_score=$(( LEN + EPIS_COUNT ))
    printf "\n"
    printf "${BOLD}${MAGENTA}  ╔══════════════════════════════════════════════════════╗${RESET}\n"
    printf "${BOLD}${MAGENTA}  ║     DAWKINS' WEASEL  ·  DIPLOID EVOLUTION            ║${RESET}\n"
    printf "${BOLD}${MAGENTA}  ╚══════════════════════════════════════════════════════╝${RESET}\n\n"
    printf "  ${DIM}Target   »${RESET} ${BOLD}${WHITE}%s${RESET}\n" "$TARGET"
    printf "  ${DIM}Config   »${RESET} ${DIM}%d diploid individuals · tournament %d · μ %d%%→%d%%${RESET}\n" \
        "$POP_SIZE" "$TOURNAMENT_SIZE" "$BASE_MUT_RATE" "$STRESS_MUT_RATE"
    printf "  ${DIM}Max score»${RESET} ${DIM}%d  (%d phenotype + %d epistasis pairs)${RESET}\n" \
        "$max_score" "$LEN" "$EPIS_COUNT"

    # Dominance map: show which positions are dominant (·) vs recessive (○)
    local rec_count=0 i
    for (( i=0; i<LEN; i++ )); do
        [[ "${M_DOM:$i:1}" == "1" ]] && (( rec_count++ ))
    done
    printf "  ${DIM}Dominance»${RESET} ${GREEN}·${DIM}=dominant(1 allele)  ${CYAN}○${DIM}=recessive(2 alleles):${RESET}\n"
    printf "             "
    for (( i=0; i<LEN; i++ )); do
        if [[ "${M_DOM:$i:1}" == "1" ]]; then
            printf "${CYAN}○${RESET}"
        else
            printf "${GREEN}·${RESET}"
        fi
    done
    printf "  ${DIM}(%d recessive)${RESET}\n" "$rec_count"

    # Epistasis pairs
    printf "  ${DIM}Epistasis»${RESET} ${DIM}position pairs that interact:  "
    for (( e=0; e<EPIS_COUNT; e++ )); do
        printf "(%d↔%d) " "${EPIS_X[$e]}" "${EPIS_Y[$e]}"
    done
    printf "${RESET}\n"
    printf "\n  ${DIM}──────────────────────────────────────────────────────${RESET}\n\n"
}

view_reasoning() {
    printf "\n  ${MAGENTA}▸ %s${RESET}\n\n" "$1"
}

view_generation() {
    local max_score=$(( LEN + EPIS_COUNT ))
    _score_color "$M_BEST_SCORE" "$max_score"
    local col="$_color"

    local mu_tag
    if (( M_STRESSED )); then
        mu_tag="${RED}${BOLD}[stress: μ=${M_MUT_RATE}%]${RESET}"
    else
        mu_tag="${DIM}[μ=${M_MUT_RATE}%]${RESET}"
    fi

    printf "  ${DIM}── Gen %4d ── best ${RESET}${col}${BOLD}%2d${RESET}${DIM}/%d  mean pheno %2d/%d ──${RESET}  %b\n" \
        "$M_GENERATION" "$M_BEST_SCORE" "$max_score" "$M_MEAN_BASE" "$LEN" "$mu_tag"

    local s
    for (( s=0; s<${#M_SAMPLE_PHENO[@]}; s++ )); do
        local sc="${M_SAMPLE_SCORES[$s]}"
        local bs="${M_SAMPLE_BASE[$s]}"
        local ht="${M_SAMPLE_HET[$s]}"
        local epis=$(( sc - bs ))
        _score_color "$sc" "$max_score"
        if (( s == 0 )); then
            printf "  ${BOLD}●${RESET}  "
            _view_diploid "${M_SAMPLE_PHENO[$s]}" "${M_SAMPLE_A[$s]}" "${M_SAMPLE_B[$s]}" 0
            printf "  ${_color}${BOLD}%2d${RESET}${DIM}/%d${RESET}" "$sc" "$max_score"
        else
            printf "  ${DIM}●  "
            _view_diploid "${M_SAMPLE_PHENO[$s]}" "${M_SAMPLE_A[$s]}" "${M_SAMPLE_B[$s]}" 1
            printf "  ${_color}%2d${RESET}${DIM}/%d${RESET}" "$sc" "$max_score"
        fi
        (( epis > 0 )) && printf "${DIM}(+%dep)${RESET}" "$epis"
        (( ht > 0 ))   && printf "${DIM} ⬡%d${RESET}" "$ht"
        printf "\n"
    done
    printf "\n"
}

view_complete() {
    local max_score=$(( LEN + EPIS_COUNT ))
    printf "\n"
    printf "  ${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${RESET}\n"
    printf "  ${BOLD}${GREEN}║  ✓  TARGET REACHED                                   ║${RESET}\n"
    printf "  ${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${RESET}\n\n"
    printf "  ${BOLD}${WHITE}%s${RESET}\n\n" "$TARGET"
    printf "  ${DIM}Generations  : %d${RESET}\n" "$M_GENERATION"
    printf "  ${DIM}Population   : %d diploid individuals${RESET}\n" "$POP_SIZE"
    printf "  ${DIM}Tournament   : size %d${RESET}\n" "$TOURNAMENT_SIZE"
    printf "  ${DIM}Mutation     : %d%% per allele  ·  %d%% stress${RESET}\n" "$BASE_MUT_RATE" "$STRESS_MUT_RATE"
    printf "  ${DIM}Max score    : %d = %d phenotype + %d epistasis${RESET}\n\n" \
        "$max_score" "$LEN" "$EPIS_COUNT"
    view_reasoning "Diploid masking: correct alleles at recessive positions accumulated in heterozygotes, invisible to selection. Only when two carriers mated did a 1-in-4 homozygous offspring emerge — the Mendelian ratio made visible."
    view_reasoning "Meiosis reshuffled alleles within each parent independently before gametes met. The recombination that counted was intra-individual, not inter-individual: each parent contributed a novel haploid sample of its own variation."
    view_reasoning "Epistasis created non-additive gradients. Positions in an incomplete pair produced less fitness per character than orphan positions. The landscape had genuine ridges that had to be crossed, not just a single smooth slope."
}

# ═══════════════════════════════════════════════════════════════════════════════
# PRESENTER — orchestrates model + view, owns the event loop
# ═══════════════════════════════════════════════════════════════════════════════

presenter_run() {
    model_init
    view_header

    local max_score=$(( LEN + EPIS_COUNT ))
    view_reasoning "Diploid population of $POP_SIZE. Color key: ${GREEN}${BOLD}green${RESET}${MAGENTA} = correct (dominant position); ${CYAN}${BOLD}cyan${RESET}${MAGENTA} = correct (recessive, both alleles needed); ${YELLOW}yellow${RESET}${MAGENTA} = carrier (one correct recessive allele hidden); red = no correct allele."

    local hit_25=0 hit_50=0 hit_75=0 hit_90=0
    local stress_noted=0 carrier_noted=0 epis_noted=0

    while [[ "$M_BEST_PHENO" != "$TARGET" ]]; do
        model_next_generation
        view_generation

        local pct=$(( M_MEAN_BASE * 100 / LEN ))

        # Check if any carriers are present in the display sample
        local has_carriers=0
        for ht in "${M_SAMPLE_HET[@]}"; do
            (( ht > 0 )) && has_carriers=1 && break
        done

        if (( has_carriers && !carrier_noted )); then
            carrier_noted=1
            view_reasoning "Yellow characters have appeared: heterozygous carriers at recessive positions. The correct allele is present in the genotype but cannot be expressed — it waits for a second copy. Selection cannot see it; only drift and luck of mating can bring two carriers together."
        fi

        # Check if any epistasis bonus has appeared
        local best_epis=$(( M_BEST_SCORE - M_BEST_SCORE ))
        for (( si=0; si<${#M_SAMPLE_SCORES[@]}; si++ )); do
            local ep=$(( M_SAMPLE_SCORES[si] - M_SAMPLE_BASE[si] ))
            (( ep > best_epis )) && best_epis=$ep
        done
        if (( best_epis > 0 && !epis_noted )); then
            epis_noted=1
            view_reasoning "First epistasis bonus earned. Both positions of a synergistic pair are now phenotypically correct — the fitness gradient just became steeper at those positions. The landscape is not flat: solving the right combinations matters more than solving positions in isolation."
        fi

        if (( pct >= 25 && !hit_25 )); then
            hit_25=1
            view_reasoning "25% mean phenotypic match. Dominant positions are fixing fast — one allele suffices, so selection acts immediately on new mutations. Recessive positions lag behind: their correct alleles are hiding in yellow carriers, accumulating frequency by drift before they can be expressed."
        fi
        if (( pct >= 50 && !hit_50 )); then
            hit_50=1
            view_reasoning "50% mean match. Recessive positions are beginning to fix as carrier frequency grows high enough that homozygous offspring appear at Mendelian rates. When a yellow character suddenly turns cyan, two carriers have finally met."
        fi
        if (( pct >= 75 && !hit_75 )); then
            hit_75=1
            view_reasoning "75% mean match. The population is converging. Meiotic reshuffling within parents is now the key engine: each gamete is a unique haploid sample of its parent's two-allele inventory, producing diploid offspring with novel combinations that neither parent could have passed intact."
        fi
        if (( pct >= 90 && !hit_90 )); then
            hit_90=1
            view_reasoning "90% mean match. The last remaining recessive positions are the bottleneck: the correct allele must be present in both gametes by chance. All other mechanisms have done their work; the final characters are resolved by the Mendelian lottery."
        fi

        if (( M_STRESSED && !stress_noted )); then
            stress_noted=1
            view_reasoning "Mean phenotypic score stalled for $STALL_THRESHOLD generations — μ raised to ${STRESS_MUT_RATE}%. In diploid populations elevated mutation creates more heterozygotes, seeding new carrier lineages. Some will eventually homozygose and break the plateau."
        fi
        if (( !M_STRESSED && stress_noted )); then
            stress_noted=0
            view_reasoning "Mean score improved — μ reset to ${BASE_MUT_RATE}%. The plateau was crossed."
        fi
    done

    view_complete
}

presenter_run
