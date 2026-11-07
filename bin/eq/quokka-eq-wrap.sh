#!/bin/bash
# Usage: quokka-eq-wrap.sh <circuit1.qasm> <circuit2.qasm>
# Prints ###runtime, ###memory and ###result:eq|neq|unknown|error
# Gate translation (only for unsupported gates) is not included in the measured time.

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
QUOKKA_DIR="$SCRIPT_DIR/../../simulators/quokka"

CIRC1="$1"
CIRC2="$2"

if [[ ! -f "$CIRC1" || ! -f "$CIRC2" ]]; then
    echo "Usage: $0 <circuit1.qasm> <circuit2.qasm>" >&2
    exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

if ! python3 "$SCRIPT_DIR/helpers/quokka-eq.py" prep "$CIRC1" "$TMP_DIR/c1.qasm" >&2 || \
   ! python3 "$SCRIPT_DIR/helpers/quokka-eq.py" prep "$CIRC2" "$TMP_DIR/c2.qasm" >&2; then
    echo "###runtime:NA"
    echo "###memory:NA"
    echo "###result:error"
    exit 1
fi

OUTPUT=$( QUOKKA_CONFIG=$(realpath "$QUOKKA_DIR/config.json") \
    /usr/bin/time -f "%e %M" -o "$TMP_DIR/time" \
    python3 "$SCRIPT_DIR/helpers/quokka-eq.py" check "$TMP_DIR/c1.qasm" "$TMP_DIR/c2.qasm" 2>&1 )
EXIT_CODE=$?
RUNTIME=$(awk '{print $1}' "$TMP_DIR/time")
MEMORY_KB=$(awk '{print $2}' "$TMP_DIR/time")

RESULT=$(echo "$OUTPUT" | grep -oP '^result:\K\w+')
[[ $EXIT_CODE -ne 0 || -z "$RESULT" ]] && RESULT="error"

echo "###runtime:${RUNTIME:-NA}"
echo "###memory:${MEMORY_KB:-NA}"
echo "###result:$RESULT"

[[ "$RESULT" == "error" ]] && exit 1
exit 0
