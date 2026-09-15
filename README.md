# InertRealizingChecker.jl

`InertRealizingChecker.jl` is a Julia package for exact, computer-assisted
verification of cascade relations between fixed-point shifts of binary compound
marker maps. It accompanies the paper *Structure of decomposition by 2-cascades
for SFTs and its application to real Hénon maps*.

The repository contains:

- the Julia library and command-line interface;
- the inputs and certificates used for the paper's Hénon-map application; and
- a self-contained description of the finite mathematical verification.

All proof-relevant calculations use integer or rational arithmetic. A successful
finite scan by itself is not reported as a proof: `status = "true"` is returned
only when the program has also certified the parity and quantity tails.

## Requirements

- Julia 1.10 or later
- no non-standard-library dependencies

The repository was tested with Julia 1.12.7.

## Reproducing the paper computations

Run the commands below from the repository root. For example, the certificate
for the cover relation $Y_1\lessdot Y_2$ is reproduced by

```sh
julia --project=. bin/check.jl compare \
  paper-verification/inputs/cover-relations/shift-1-to-shift-2.toml \
  reproduced.toml
```

The expected output is
[`paper-verification/certificates/cascade-relations/shift-1-to-shift-2.toml`](paper-verification/certificates/cascade-relations/shift-1-to-shift-2.toml).
Commands for every certificate, together with the correspondence between file
names and the notation in the paper, are listed in
[`paper-verification/README.md`](paper-verification/README.md).

To run the test suite:

```sh
julia --project=. test/runtests.jl
```

## Command-line interface

```text
julia --project=. bin/check.jl compare INPUT [OUTPUT]
julia --project=. bin/check.jl mixing INPUT [OUTPUT]
julia --project=. bin/check.jl involution INPUT [OUTPUT]
```

If `OUTPUT` is supplied, the same TOML result printed to the terminal is also
written to that file. Exit code `0` means that the computation completed,
including a mathematically undecided result; exit code `2` indicates invalid
input or an execution error. Read the result's `status` field to distinguish
`true`, `false`, and `unknown`.

A comparison input has the form

```toml
[child]
patterns = ["0*10", "10*111"]

[parent]
patterns = ["0*10", "110*1110"]
```

For `mixing` and `involution`, replace `[child]` and `[parent]` with a single
`[shift]` table.

## Marker notation

In a pattern such as `0*10`, `*` marks the coordinate whose binary symbol is
flipped when the left and right contexts are `0` and `10`. The symbols `∗` and
`□` are accepted as alternatives to `*`.

All matching centers are determined from the original sequence and flipped
simultaneously. A center matched by more than one pattern is flipped only once.
The empty pattern list is the identity map, while `["*"]` flips every symbol.
Patterns with an empty left or right context are allowed.

The input describes a marker **map**; the program does not assume that the map
is an automorphism. A successful involution check proves that the local map is
an automorphism whose inverse is itself.

## What `compare` proves

For fixed-point shifts $Y$ (child) and $X$ (parent), `compare` checks the
strict cascade relation

$$
Y <_{\mathrm{cas}} X
\quad\Longleftrightarrow\quad
Y\subsetneq X
\text{ and }
\operatorname{Per}(X)\setminus\operatorname{Per}(Y)
\text{ is a disjoint union of }2\text{-cascades}.
$$

The result statuses mean:

| `status` | Meaning |
|---|---|
| `true` | The relation is proved for all periods by a finite computation with tail certificates. |
| `false` | Equality, failed inclusion, or a violation at a specific period was found. |
| `unknown` | The input lies outside the sufficient hypotheses or a resource limit was reached. |

When `status = "true"`, `certificate` records exact rational growth bounds and
finite cutoffs. `checked_periods` is the largest period computed directly, and
`cascade_counts` gives the number of cascades based at each of the first (at
most) 32 periods. An inclusion counterexample records finite left and right
cycles joined by a word, so it represents a genuine bi-infinite point rather
than merely a failed finite-word test.

The checker establishes a relation between fixed-point shifts. It does not
construct an inert involution on the parent shift. Any realization conclusion
using shift equivalence is a separate application of Long's theorem.

See [`docs/mathematics.md`](docs/mathematics.md) for the definitions, finite
parity reduction, quantity bounds, and exact-certificate argument.

## Julia API

```julia
using InertRealizingChecker

parent_map = MarkerMap(["0*10"])
child_map = MarkerMap(["0*10", "110*1110"])
parent = fixed_shift(parent_map)
child = fixed_shift(child_map)

check_involution(child_map)
check_finite_order(child_map, 5)
check_mixing(parent)
check_inclusion(child, parent)
check_cascade(child, parent)
counts = periodic_counts(child, parent, 100)
```

Arguments to comparison functions are always ordered `(child, parent)`.
`check_finite_order(marker_map, n)` searches in increasing order for the least
$k$ with $1\le k\le n$ and $\phi^k=\mathrm{id}$. A `false` result means
only that no such order was found within the inclusive bound; it does not prove
infinite order. The check exhausts the complete dependency window rather than
sampling periodic sequences.

`FixedShift` values should normally be created with `fixed_shift`.
`fixed_shift` and `periodic_counts` throw `ResourceLimit` when a configured
limit is exceeded. The CLI and the high-level checks instead encode resource
exhaustion as `status = "unknown"`.

Unreduced cylinder pairs can be generated by specifying the head and tail
lengths (the head includes the current symbol):

```julia
pairs = cylinder_pairs(["0□10", "110□1110"], 4, 4)
map = MarkerMap(pairs)
```

## Resource limits

The defaults are:

```toml
[limits]
max_states = 1024
max_period = 10000
max_power = 256
max_window = 24
```

All values must be positive integers. Limits can be supplied through the input
TOML or as, for example, `Limits(max_period=20000)` in Julia. Exceeding a limit
never counts as a negative mathematical result.

## Parallel execution

The implementation uses Julia's standard `Threads` support. Select the thread
count when starting Julia:

```sh
julia --threads=4 --project=. bin/check.jl compare INPUT
julia --threads=4 --project=. test/runtests.jl
```

Exact arithmetic, resource-limit behavior, witness ordering, and certificate
selection are deterministic across thread counts. The scripts and raw data used
for performance measurements are retained in [`benchmark/`](benchmark/); they
are not part of the paper's proof certificates.

## Reference

Nicholas Long, “Fixed point shifts of inert involutions,” *Discrete and
Continuous Dynamical Systems* **25**(4), 1297–1317 (2009).
[doi:10.3934/dcds.2009.25.1297](https://doi.org/10.3934/dcds.2009.25.1297).
