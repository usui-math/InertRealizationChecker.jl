# Repository invariants

- Read `docs/mathematics.md` before changing cascade cutoffs. A successful finite scan alone must never produce `true`; both the parity tail and the quantity tail require exact certificates. Resource exhaustion is `unknown`, not `false`.
- Preserve paths between cyclic graph components when pruning presentations or checking inclusion. These paths represent nonperiodic points and cannot be discarded on the basis of trace equivalence.
- Marker rules flip each matching center once, simultaneously from the original sequence. Do not infer involutivity from the name or input format: the supplied middle-shift example has a verified involution counterexample.
- Run `julia --project=. test/runtests.jl` after mathematical changes. If saved results change, regenerate the corresponding TOML files in `examples/` and `paper-verification/certificates/`, and keep the README summaries and links in sync.
- Parallel kernels must preserve the first witness, first input error, smallest cutoff, and certificate tie order. Run the full test suite with both `--threads=1` and `--threads=4` after changing these kernels; cross-process API snapshots alone do not exercise the odd-size Boolean kernel checks.
- Trace columns share BigInt values read-only; do not introduce in-place BigInt arithmetic. Boolean products use `Matrix{Bool}` because separate BitMatrix elements can share a writable word.
- Mixing periods must use forward distances. Keep each reachability call's distance array local: reusing the reverse distances can incorrectly classify odd directed cycles as mixing.
