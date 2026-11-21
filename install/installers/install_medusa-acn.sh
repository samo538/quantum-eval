#!/bin/bash
# Builds MEDUSA (MoToBuddy backend) from the ACN branch with:
#   MEDUSA_buddy_gmp          algebraic mpz leaves (baseline)
#   MEDUSA_buddy_acn_n<N>     acn leaves, for each N in ACN_NS
set -e
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../common.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../configs/medusa-acn.conf"

log "Installing MEDUSA ACN vs mpz (ref=$REF) into $DIR"

for dep in "${DEPS[@]}"; do
    if ! dpkg -s "$dep" >/dev/null 2>&1; then
        log "Installing $dep"
        sudo apt-get install -y "$dep"
    else
        log "$dep is already installed"
    fi
done

clone_repo "$REPO" "$DIR" "$REF"

cd "$DIR"
log "Initializing MoToBuddy (make init)..."
make init

log "Fetching acn header-only library (make init-acn)..."
make init-acn

JOBS=$(nproc 2>/dev/null || echo 2)

log "Building buddy_gmp (mpz leaves)..."
make -j"$JOBS" buddy_gmp

for n in "${ACN_NS[@]}"; do
    log "Building buddy_acn (ACN_N=$n)..."
    make -j"$JOBS" buddy_acn "ACN_N=$n"
done

write_build_info "$DIR"
echo "acn_sha=$(git -C "$DIR/lib/algebraic-complex-numbers" rev-parse HEAD 2>/dev/null || echo unknown)" >>"$DIR/BUILD_INFO.txt"
echo "ACN_NS=${ACN_NS[*]}" >>"$DIR/BUILD_INFO.txt"

log "MEDUSA ACN install completed: $DIR"
ls -la "$DIR"/MEDUSA_buddy_gmp "$DIR"/MEDUSA_buddy_acn_n* 2>/dev/null || true
