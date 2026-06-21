#!/usr/bin/env bash
# Demonstrates cumulative selection — converges on the target in dozens of generations.
# Each generation breeds POPULATION offspring from the best parent, keeps the closest match.

TARGET="METHINKS IT IS LIKE A WEASEL"
ALPHABET="ABCDEFGHIJKLMNOPQRSTUVWXYZ "
LEN=${#TARGET}
ALPHA_LEN=${#ALPHABET}
POPULATION=100
MUTATION_RATE=5  # % chance each character mutates per generation

# Random initial parent
parent=""
for (( i=0; i<LEN; i++ )); do
    parent+="${ALPHABET:$(( RANDOM % ALPHA_LEN )):1}"
done

# Score parent
parent_score=0
for (( i=0; i<LEN; i++ )); do
    [[ "${parent:$i:1}" == "${TARGET:$i:1}" ]] && (( parent_score++ ))
done

generation=0
echo "Target : $TARGET"
echo "Start  : $parent"
echo ""

while [[ "$parent" != "$TARGET" ]]; do
    best="$parent"
    best_score=$parent_score

    for (( p=0; p<POPULATION; p++ )); do
        # Mutate
        offspring=""
        for (( i=0; i<LEN; i++ )); do
            if (( RANDOM % 100 < MUTATION_RATE )); then
                offspring+="${ALPHABET:$(( RANDOM % ALPHA_LEN )):1}"
            else
                offspring+="${parent:$i:1}"
            fi
        done

        # Score
        s=0
        for (( i=0; i<LEN; i++ )); do
            [[ "${offspring:$i:1}" == "${TARGET:$i:1}" ]] && (( s++ ))
        done

        if (( s > best_score )); then
            best="$offspring"
            best_score=$s
        fi
    done

    parent="$best"
    parent_score=$best_score
    (( generation++ ))

    printf "Gen %4d | Score %2d/%d | %s\n" \
        "$generation" "$parent_score" "$LEN" "$parent"
done

echo ""
echo "Target reached in $generation generations."
