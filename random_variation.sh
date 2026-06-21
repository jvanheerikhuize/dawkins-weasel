#!/usr/bin/env bash
# Demonstrates pure random search — essentially never finds the target.
# Press Ctrl+C to stop.

TARGET="METHINKS IT IS LIKE A WEASEL"
ALPHABET="ABCDEFGHIJKLMNOPQRSTUVWXYZ "
LEN=${#TARGET}
ALPHA_LEN=${#ALPHABET}

attempts=0
start=$SECONDS

echo "Target : $TARGET"
echo "Length : $LEN characters | Alphabet size : $ALPHA_LEN"
echo "Odds   : ~1 in 27^28 ≈ 2.4 × 10^39 per attempt"
echo "Searching... (Ctrl+C to stop)"
echo ""

while true; do
    candidate=""
    for (( i=0; i<LEN; i++ )); do
        candidate+="${ALPHABET:$(( RANDOM % ALPHA_LEN )):1}"
    done

    (( attempts++ ))

    if [[ "$candidate" == "$TARGET" ]]; then
        printf "\nFound after %d attempts in %ds!\n" "$attempts" "$(( SECONDS - start ))"
        echo "$candidate"
        break
    fi

    if (( attempts % 10000 == 0 )); then
        printf "%12d attempts | %4ds elapsed | %s\n" \
            "$attempts" "$(( SECONDS - start ))" "$candidate"
    fi
done
