#!/usr/bin/env python3
"""Check equivalence of two circuits with MQT QCEC and print the verdict.

Usage: qcec-eq.py <circuit1.qasm> <circuit2.qasm>

Prints eq | neq | unknown (QCEC default settings, single-threaded).
"""
import sys

from mqt import qcec

RESULTS = {
    "equivalent": "eq",
    "equivalent_up_to_global_phase": "eq",
    "not_equivalent": "neq",
    "probably_equivalent": "unknown",
    "probably_not_equivalent": "unknown",
    "no_information": "unknown",
}


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    # single thread, so QCEC competes on the same resources as the other tools
    res = qcec.verify(sys.argv[1], sys.argv[2], parallel=False)
    criterion = str(res.equivalence).split(".")[-1]
    print(f"criterion:{criterion}")
    print(f"result:{RESULTS.get(criterion, 'unknown')}")


if __name__ == "__main__":
    main()
