#!/bin/bash
# Wrapper for MEDUSA built from the ACN branch (install: ./install/install.sh medusa-acn).
#
# Usage:
#   medusa-acn-wrap.sh -l mpz|acn4|acn8 [-s] QASM
#
# -l  leaf type (required): mpz  -> MEDUSA_buddy_gmp
#                           acnN -> MEDUSA_buddy_acn_nN
# -s  symbolic loop simulation (--symbolic)

ABSOLUTE_SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "${ABSOLUTE_SCRIPT_PATH}")
MEDUSA_DIR="${SCRIPT_DIR}/../simulators/medusa-acn"

LEAF=""
LOOP_MODE=0

while [[ $# -gt 0 && "$1" == -* ]]; do
    case "$1" in
        -l)
            LEAF="$2"
            shift 2
            ;;
        -s)
            LOOP_MODE=1
            shift
            ;;
        *)
            echo "Unknown flag: $1" >&2
            exit 1
            ;;
    esac
done

case "$LEAF" in
    mpz)
        MEDUSA_EXE="${MEDUSA_DIR}/MEDUSA_buddy_gmp"
        ;;
    acn[0-9]*)
        MEDUSA_EXE="${MEDUSA_DIR}/MEDUSA_buddy_acn_n${LEAF#acn}"
        ;;
    *)
        echo "Invalid or missing -l leaf type. Use: mpz | acn4 | acn8" >&2
        exit 1
        ;;
esac

QASM_FILE="$1"
if [[ -z "$QASM_FILE" ]]; then
    echo "Usage: $0 -l mpz|acn4|acn8 [-s] QASM" >&2
    exit 1
fi

# skip NL file
QASM_BASE=$(basename "$QASM_FILE")
if [[ "$QASM_BASE" == NL_* ]]; then
    echo "###runtime:NA"
    echo "###memory:NA"
    exit 1
fi

if [[ ! -x "$MEDUSA_EXE" ]]; then
    echo "Executable not found or not executable: $MEDUSA_EXE" >&2
    echo "Install with: ./install/install.sh medusa-acn" >&2
    exit 1
fi

# Run in a private temp dir: MEDUSA writes res.dot / res-vars.txt into cwd,
# which would race between parallel pycobench jobs.
QASM_FILE_ABS=$(realpath "$QASM_FILE")
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
cd "$WORK_DIR" || exit 1

if [[ $LOOP_MODE -eq 1 ]]; then
    MEDUSA_OUT=$("$MEDUSA_EXE" -i -s --file "$QASM_FILE_ABS" 2>&1)
else
    MEDUSA_OUT=$("$MEDUSA_EXE" -i --file "$QASM_FILE_ABS" 2>&1)
fi
EXIT_CODE=$?

# Time is printed with %.3g, so allow exponent form (e.g. 1.2e+03)
RUNTIME=$(echo "$MEDUSA_OUT" | grep -oP 'Time=\K[0-9.]+(e[+-]?[0-9]+)?' || true)
MEMORY_KB=$(echo "$MEDUSA_OUT" | grep -oP 'Peak Memory Usage=\K[0-9]+' || true)

echo "###runtime:${RUNTIME:-NA}"
echo "###memory:${MEMORY_KB:-NA}"

if [[ $EXIT_CODE -ne 0 ]]; then
    echo "$MEDUSA_OUT" | tail -n 5 >&2
fi

exit $EXIT_CODE
