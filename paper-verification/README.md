# Computational files for the paper

This directory contains the inputs and saved certificates for the Hénon-map
application in *Structure of decomposition by 2-cascades for SFTs and its
application to real Hénon maps*.

The numbered file names correspond to the shifts $Y_1,\ldots,Y_7$ associated
with the numbered parameter regions in the paper. `shift-spade.toml` corresponds
to the region denoted by $\spadesuit$. The latter is retained to document the
reported local-rule and mixing checks, but it is not one of the seven
involutive shifts in the cascade poset.

## Directory layout

```text
paper-verification/
├── inputs/
│   ├── shifts/                 marker patterns for each labeled shift
│   └── cover-relations/        child/parent inputs for the six numbered covers
└── certificates/
    ├── involution/              local-rule involution checks
    ├── mixing/                  graph mixing checks
    ├── finite-order/            the separate order-four check for the spade-labelled shift
    └── cascade-relations/       all-period certificates for the six covers
```

Files under `inputs/` are inputs to the checker. Files under `certificates/` are
saved outputs. In particular, “certificate” here means the exact finite data
used to establish the corresponding claim; it does not mean a digital or
cryptographic certificate.

## Shift labels

| Paper notation | Marker input | Involution certificate | Mixing certificate |
|---|---|---|---|
| $Y_1$ | [`shift-1.toml`](inputs/shifts/shift-1.toml) | [`shift-1.toml`](certificates/involution/shift-1.toml) | [`shift-1.toml`](certificates/mixing/shift-1.toml) |
| $Y_2$ | [`shift-2.toml`](inputs/shifts/shift-2.toml) | [`shift-2.toml`](certificates/involution/shift-2.toml) | [`shift-2.toml`](certificates/mixing/shift-2.toml) |
| $Y_3$ | [`shift-3.toml`](inputs/shifts/shift-3.toml) | [`shift-3.toml`](certificates/involution/shift-3.toml) | [`shift-3.toml`](certificates/mixing/shift-3.toml) |
| $Y_4$ | [`shift-4.toml`](inputs/shifts/shift-4.toml) | [`shift-4.toml`](certificates/involution/shift-4.toml) | [`shift-4.toml`](certificates/mixing/shift-4.toml) |
| $Y_5$ | [`shift-5.toml`](inputs/shifts/shift-5.toml) | [`shift-5.toml`](certificates/involution/shift-5.toml) | [`shift-5.toml`](certificates/mixing/shift-5.toml) |
| $Y_6$ | [`shift-6.toml`](inputs/shifts/shift-6.toml) | [`shift-6.toml`](certificates/involution/shift-6.toml) | [`shift-6.toml`](certificates/mixing/shift-6.toml) |
| $Y_7$ | [`shift-7.toml`](inputs/shifts/shift-7.toml) | [`shift-7.toml`](certificates/involution/shift-7.toml) | [`shift-7.toml`](certificates/mixing/shift-7.toml) |
| $Y_{\spadesuit}$ | [`shift-spade.toml`](inputs/shifts/shift-spade.toml) | [`shift-spade.toml`](certificates/involution/shift-spade.toml) | [`shift-spade.toml`](certificates/mixing/shift-spade.toml) |

The separate finite-order result for $Y_{\spadesuit}$ is
[`certificates/finite-order/shift-spade.toml`](certificates/finite-order/shift-spade.toml).

## Cascade-relation certificates

Each row links the exact checker input to its saved output. The direction
`shift-i-to-shift-j` means $Y_i\lessdot Y_j$: $Y_i$ is the child and $Y_j$
is the parent.

| Cover in the paper | Input | Saved certificate |
|---|---|---|
| $Y_1\lessdot Y_2$ | [`shift-1-to-shift-2.toml`](inputs/cover-relations/shift-1-to-shift-2.toml) | [`shift-1-to-shift-2.toml`](certificates/cascade-relations/shift-1-to-shift-2.toml) |
| $Y_2\lessdot Y_3$ | [`shift-2-to-shift-3.toml`](inputs/cover-relations/shift-2-to-shift-3.toml) | [`shift-2-to-shift-3.toml`](certificates/cascade-relations/shift-2-to-shift-3.toml) |
| $Y_4\lessdot Y_5$ | [`shift-4-to-shift-5.toml`](inputs/cover-relations/shift-4-to-shift-5.toml) | [`shift-4-to-shift-5.toml`](certificates/cascade-relations/shift-4-to-shift-5.toml) |
| $Y_4\lessdot Y_6$ | [`shift-4-to-shift-6.toml`](inputs/cover-relations/shift-4-to-shift-6.toml) | [`shift-4-to-shift-6.toml`](certificates/cascade-relations/shift-4-to-shift-6.toml) |
| $Y_5\lessdot Y_7$ | [`shift-5-to-shift-7.toml`](inputs/cover-relations/shift-5-to-shift-7.toml) | [`shift-5-to-shift-7.toml`](certificates/cascade-relations/shift-5-to-shift-7.toml) |
| $Y_6\lessdot Y_7$ | [`shift-6-to-shift-7.toml`](inputs/cover-relations/shift-6-to-shift-7.toml) | [`shift-6-to-shift-7.toml`](certificates/cascade-relations/shift-6-to-shift-7.toml) |

The two remaining covers in the paper, $Y_3\lessdot\{0,1\}^{\mathbb Z}$ and
$Y_7\lessdot\{0,1\}^{\mathbb Z}$, follow there from the realization theorem
and are therefore not represented by additional cascade-certificate files in
this directory.

## Reproduction commands

Run commands from the repository root. A cascade certificate can be regenerated
as follows:

```sh
julia --project=. bin/check.jl compare \
  paper-verification/inputs/cover-relations/shift-1-to-shift-2.toml \
  reproduced-shift-1-to-shift-2.toml
```

For a labeled shift, run the two independent checks with the same input:

```sh
julia --project=. bin/check.jl involution \
  paper-verification/inputs/shifts/shift-1.toml \
  reproduced-involution-shift-1.toml

julia --project=. bin/check.jl mixing \
  paper-verification/inputs/shifts/shift-1.toml \
  reproduced-mixing-shift-1.toml
```

Replace the label or cover in these examples to reproduce the other files. See
the repository's main [`README.md`](../README.md) for the meaning of result
fields, and [`docs/mathematics.md`](../docs/mathematics.md) for the proof that
the finite cutoffs certify all periods.
