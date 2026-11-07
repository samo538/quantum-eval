#!/usr/bin/env python3
"""Quokka# equivalence check helper.

Usage:
  quokka-eq.py prep  <in.qasm> <out.qasm>       translate to Quokka#'s gate set (if needed)
  quokka-eq.py check <circuit1.qasm> <circuit2.qasm>

`prep` keeps the file as is when all gates are supported, otherwise it
translates it with Qiskit (no optimization) and writes angles as plain numbers.
`check` prints result:eq|neq|unknown|error (QUOKKA_CONFIG must be set).
"""
import re
import shutil
import sys

SUPPORTED = {"id", "h", "x", "y", "z", "s", "sdg", "t", "tdg",
             "cx", "cy", "cz", "swap", "ccx", "rx", "ry", "rz"}
SKIP = ("OPENQASM", "include", "qreg", "creg", "barrier", "measure", "//")


def needs_translation(path):
    for line in open(path):
        s = line.strip()
        if s and not s.startswith(SKIP):
            if re.match(r"[a-z][a-z0-9_]*", s).group(0) not in SUPPORTED:
                return True
    return False


def prep(src, dst):
    if not needs_translation(src):
        shutil.copyfile(src, dst)
        return
    from qiskit import qasm2, transpile
    qc = qasm2.load(src, custom_instructions=qasm2.LEGACY_CUSTOM_INSTRUCTIONS)
    qc = transpile(qc, basis_gates=sorted(SUPPORTED - {"id"}), optimization_level=0)
    lines = ['OPENQASM 2.0;', 'include "qelib1.inc";', f"qreg q[{qc.num_qubits}];"]
    for inst in qc.data:
        name = inst.operation.name
        if name == "barrier":
            continue
        params = ",".join(repr(float(p)) for p in inst.operation.params)
        qubits = ", ".join(f"q[{qc.find_bit(q).index}]" for q in inst.qubits)
        lines.append(f"{name}({params}) {qubits};" if params else f"{name} {qubits};")
    with open(dst, "w") as f:
        f.write("\n".join(lines) + "\n")


def check(c1, c2):
    import quokka_sharp as qk
    res = qk.functionalities.eq(c1, c2, basis="comp", check="cyclic", epsilon=0)
    if res is True or res == "True":
        print("result:eq")
    elif res is False or res == "False":
        print("result:neq")
    elif res in ("TIMEOUT", "MEMOUT"):
        print(f"quokka:{res}")
        print("result:unknown")
    else:
        print(f"quokka:{res}")
        print("result:error")


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ("prep", "check"):
        sys.exit(__doc__)
    (prep if sys.argv[1] == "prep" else check)(sys.argv[2], sys.argv[3])


if __name__ == "__main__":
    main()
