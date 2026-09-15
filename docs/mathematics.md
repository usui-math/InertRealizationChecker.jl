# Mathematical basis of the checker

This document explains why `InertRealizingChecker.jl` can turn finitely many
exact calculations into a statement about every period. It follows the notation
used by the program and by the accompanying paper. The implementation uses no
floating-point arithmetic in a proof certificate.

## Fixed-point shifts and graph presentations

Consider a local map on the binary full shift that flips the center of every
matching compound-marker pattern $u*v$. Matching centers are selected from the
original sequence and are flipped once, simultaneously. Its fixed-point set is
the SFT obtained by forbidding both $u0v$ and $u1v$ for every pattern.
Invertibility of the local map is not needed for this construction.

Let $L$ be the largest forbidden-word length. The initial graph has the words
of length $L-1$ as vertices and appending one symbol as an edge; edges that
contain a forbidden word are removed. Repeatedly removing vertices with zero
in-degree or zero out-degree leaves exactly the part that can occur on a
bi-infinite path. Paths between cyclic components must be retained because they
represent nonperiodic points.

To test $Y\subseteq X$, the checker searches the graph of $Y$ for a path
reading each forbidden word of $X$. Such a path can be extended infinitely in
both directions, and therefore gives an inclusion counterexample. Checking only
periodic points would not prove inclusion.

A nonempty essential graph presents a mixing SFT exactly when it is strongly
connected and the greatest common divisor of its cycle lengths is $1$. The
checker treats the empty shift as non-mixing.

## The all-period cascade criterion

Let $A$ and $B$ be adjacency matrices presenting the parent $X$ and child
$Y$, respectively. Define

$$
F(n)=\operatorname{tr}(A^n)-\operatorname{tr}(B^n),
\qquad
P(n)=\sum_{d\mid n}\mu(n/d)F(d).
$$

Thus $F(n)$ is the difference in points fixed by the $n$-th power of the
shift, and $P(n)$ is the difference in points of least period $n$. Define

$$
D(q)=0\quad(q\text{ odd}),
\qquad
D(2m)=D(m)+P(m),
\qquad
C(n)=P(n)-D(n).
$$

Long's Proposition B.1 states that the periodic points in $X\setminus Y$
form a disjoint union of $2$-cascades if and only if, for every $n\ge1$,

$$
C(n)\ge0,
\qquad
2^{v_2(n)+1}\mid C(n).
$$

When the conditions hold, the number of cascades based at least period $n$ is
$C(n)/(2n)$. The two following sections explain how the checker certifies
these infinitely many conditions with finite exact data.

## Finite certificate for the parity condition

For odd $q$, put

$$
H_0(q)=F(q),
\qquad
H_r(q)=F(2^rq)-2F(2^{r-1}q)\quad(r\ge1).
$$

Substitution of the least-period formula gives

$$
C(2^rq)=\sum_{s\mid q}\mu(s)H_r(q/s).
$$

By Dirichlet inversion, for each fixed $r$, the congruence condition on all
odd $q$ is equivalent to the corresponding congruence condition on $H_r$.

Suppose $A^l$ and $B^l$ are both zero modulo $2$. Then $F(k)$ is
divisible by $2^{\lfloor k/l\rfloor}$. Consequently:

- for $r=0$, odd $q\ge l$ need not be checked; and
- for $r\ge1$, an odd $q$ need not be checked once
  $$
  2^rq\ge l(r+1)
  \quad\text{and}\quad
  2^{r-1}q\ge lr.
  $$

Once these two inequalities hold for $q=1$ at some $r\ge1$, they continue
to hold for larger $r$. Only finitely many pairs $(r,q)$ remain. The checker
computes through the largest period in this finite set and verifies the
divisibility of every $C(n)$ in range. All divisors used by the inversion also
lie in that range. This avoids relying on a boundary interpretation of the
printed checking set in Long's Lemma B.2.

## Finite certificate for the quantity condition

Assume that $A$ is primitive with spectral radius $\rho(A)>1$, and that
$B$ presents a proper subshift, so $\rho(B)<\rho(A)$. For a suitable
positive integer $k$, the checker finds exact rational numbers $a,b,c$ such
that

$$
\begin{aligned}
\min\operatorname{rowsum}(A^k)&\ge a^k,
&\max\operatorname{rowsum}(A^k)&\le c^k,\\
\max\operatorname{rowsum}(B^k)&\le b^k,
&1<a,\quad 1\le b<a,
&c<a^2.
\end{aligned}
$$

The search uses dyadic rational enclosures whose denominator is
$1024\cdot2^{\lceil\log_2k\rceil}$. If the configured search limit is reached
before the growth rates are separated, the result is `unknown`.

Choose $s$ so that every entry of $A^s$ is positive. For $0\le r<k$, let

$$
u_r=\max\operatorname{rowsum}(A^r),\qquad
v_r=\max\operatorname{rowsum}(B^r),\qquad
w_r=\min\operatorname{rowsum}(A^r).
$$

Writing $d_A,d_B$ for the matrix sizes, define

$$
U=d_A\max_{0\le r<k}\frac{u_r}{c^r},\qquad
V=d_B\max_{0\le r<k}\frac{v_r}{b^r},\qquad
L=\frac{d_A}{a^s}\min_{0\le r<k}\frac{w_r}{a^r}.
$$

For an empty child take $V=0$. Row-sum bounds and positivity of $A^s$ give

$$
\operatorname{tr}(A^n)\ge La^n\quad(n\ge s),
$$

and, for every $n\ge0$,

$$
\operatorname{tr}(A^n)\le Uc^n,
\qquad
\operatorname{tr}(B^n)\le Vb^n.
$$

For the lower bound, one uses

$$
\operatorname{tr}(A^sA^{n-s})
\ge \sum_{i,j}(A^{n-s})_{ij}.
$$

Removing all points whose least period is a proper divisor of $n$ gives

$$
P(n)\ge
F(n)-\sum_{\substack{d\mid n\\d<n}}\operatorname{tr}(A^d).
$$

If $n=2^rq$, with $q$ odd, inclusion implies
$0\le P(d)\le F(d)\le\operatorname{tr}(A^d)$, and hence

$$
D(n)=\sum_{j=1}^{r}P(n/2^j)
\le
\sum_{\substack{d\mid n\\d<n}}\operatorname{tr}(A^d).
$$

Every proper divisor is at most $\lfloor n/2\rfloor$, and there are at most
$\lfloor n/2\rfloor$ of them. Therefore, for
$n\ge\max(s,2)$,

$$
\begin{aligned}
C(n)
&\ge F(n)-2\sum_{\substack{d\mid n\\d<n}}\operatorname{tr}(A^d)\\
&\ge La^n-Vb^n-2\lfloor n/2\rfloor Uc^{n/2}\\
&\ge La^n-Vb^n-nUc^{n/2}.
\end{aligned}
$$

Choose a rational $h$ with $\sqrt c\le h<a$. If an integer $M$ satisfies

$$
M\ge\max\left(s,2,\frac{h}{a-h}\right),
\qquad
V(b/a)^M\le L/2,
\qquad
MU(h/a)^M\le L/2,
$$

then the last two left-hand sides are nonincreasing thereafter, and
$C(n)\ge0$ for every $n\ge M$. The checker therefore calculates only the
finite range $1\le n<M$. Equality with zero is allowed at the boundary.

## Reading a certificate

A successful cascade result stores the exact values
$a,b,c,h,k,s,L,U,V,M$, together with the parity cutoff and nilpotence
exponent. The certificate should be read as follows:

1. every period through the recorded finite cutoffs was checked exactly;
2. nilpotence modulo $2$ proves the parity condition beyond its cutoff; and
3. the rational growth bounds prove the quantity condition for every
   $n\ge M$.

The stored `cascade_counts` are useful summary data, but they are not a
substitute for the two tail arguments. Re-running the same input with the same
limits reproduces the certificate deterministically.

## Reference

Nicholas Long, “Fixed point shifts of inert involutions,” *Discrete and
Continuous Dynamical Systems* **25**(4), 1297–1317 (2009), especially
Proposition B.1, Lemma B.2, and Proposition A.2.
[doi:10.3934/dcds.2009.25.1297](https://doi.org/10.3934/dcds.2009.25.1297).
