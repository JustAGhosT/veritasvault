# Allocation models — mathematical specification

> **Status: SPECIFICATION ONLY. None of these models is implemented.**
> Companion to [ADR-0003](../adr/0003-portfolio-model-strategy.md) (why a roster)
> and [ADR-0004](../adr/0004-allocation-model-abstraction.md) (how they compose).
> Verification in [model-verification.md](./model-verification.md).

Black-Litterman itself is specified in
[the implementation plan §1](../black-litterman-implementation-plan.md#1-the-mathematical-contract)
and [ADR-0001](../adr/0001-black-litterman-model-conventions.md); it is not
repeated here.

**Notation.** `n` assets; `Σ` the n×n covariance of excess returns; `σ` the
vector of volatilities with `σ_i = √Σ_ii`; `C` the correlation matrix,
`Σ = diag(σ) C diag(σ)`; `μ` expected excess returns; `w` weights; `1` the ones
vector. Every model returns weights summing to 1 unless stated otherwise.

Each section gives the definition, the stage it occupies under ADR-0004, its
input requirements, and **exact invariants** — identities checkable to machine
precision with no reference to a published table. Those invariants are the
primary correctness evidence; see
[model-verification.md Tier A](./model-verification.md#tier-a--numerical-correctness).

---

## 1. Equal weight (1/N)

**Stage:** Allocator · **Requires:** universe only · **Inverts Σ:** no

```
w_i = 1/n
```

**Invariants**

| #    | Property                                                             |
| ---- | -------------------------------------------------------------------- |
| EW.1 | `Σw = 1`, all `w_i > 0`                                              |
| EW.2 | Output is independent of Σ and μ — perturbing either changes nothing |
| EW.3 | Permutation-invariant                                                |

**Why it is in the roster.** DeMiguel, Garlappi & Uppal (2009) found 1/N
frequently beats optimized portfolios out of sample, because estimation error
swamps optimization gains. **This is the benchmark every other model must beat,
and it is the cheapest to implement.** A comparison harness without it is not a
comparison.

_Reference:_ DeMiguel, Garlappi & Uppal (2009), _Optimal Versus Naive
Diversification_, Review of Financial Studies 22(5). Spec: `equal-weighting.md`.

---

## 2. Market-capitalization weight

**Stage:** Allocator · **Requires:** market caps · **Inverts Σ:** no

```
w = m / (1ᵀm)          m = vector of market capitalizations
```

**Invariants**

| #    | Property                                             |
| ---- | ---------------------------------------------------- |
| MC.1 | `Σw = 1`                                             |
| MC.2 | Scale-invariant: `w(cm) = w(m)` for `c > 0`          |
| MC.3 | **`Equilibrium ∘ MVO ≡ MarketCap` exactly** — see §4 |

MC.3 is the composition form of the implementation plan's requirement B3 and is
the single most valuable identity in the suite.

**Caveat for digital assets** ([ADR-0003](../adr/0003-portfolio-model-strategy.md)):
market capitalization is contaminated by locked tokens, low float and wash
trading. This model is the _measurement_ of the market portfolio, and its quality
is bounded by the quality of that measurement — which also bounds Black-Litterman,
since `w_mkt` is BL's prior.

---

## 3. Minimum variance

**Stage:** Allocator · **Requires:** Σ · **Inverts Σ:** yes

```
min  wᵀΣw     s.t.  1ᵀw = 1   (+ constraint set)
```

Closed form with the budget constraint alone:

```
w = Σ⁻¹1 / (1ᵀΣ⁻¹1)
```

Implemented as a Cholesky solve, never an explicit inverse. With inequality
constraints it becomes a Clarabel QP (`P = 2Σ`, `q = 0`).

**Invariants**

| #    | Property                                                                          |
| ---- | --------------------------------------------------------------------------------- |
| MV.1 | **`MinVar(Σ = σ²I) ≡ EqualWeight`** exactly                                       |
| MV.2 | Scale-invariant in Σ: `w(cΣ) = w(Σ)` for `c > 0`                                  |
| MV.3 | `wᵀΣw ≤ vᵀΣv` for every feasible `v` — the defining optimality property           |
| MV.4 | Independent of μ entirely                                                         |
| MV.5 | With no binding inequality constraints, the QP reproduces the closed form to 1e-9 |

_Spec:_ `risk-based-overview.md:27`.

---

## 4. Equilibrium (reverse optimization)

**Stage:** ReturnEstimator · **Requires:** Σ, `w_mkt`, λ · **Inverts Σ:** no

```
Π = λ Σ w_mkt
```

**Invariants**

| #    | Property                                                                                                                                                                              |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| EQ.1 | **`Equilibrium ∘ MVO ≡ MarketCap`** — since `(λΣ)⁻¹(λΣw_mkt) = w_mkt`, exact to machine precision                                                                                     |
| EQ.2 | `λ_implied = (w_mktᵀΠ)/(w_mktᵀΣw_mkt)` returns the input λ exactly ([ADR-0001 §D5](../adr/0001-black-litterman-model-conventions.md#d5--definitions-for-the-undefined-result-fields)) |
| EQ.3 | Linear in `w_mkt` and in λ                                                                                                                                                            |

EQ.1 exercises the entire numeric path — construction, factorization, ordering,
FFI, decimal boundary — against a closed-form answer with no literature
dependency. It is the first test to write and the last one that should ever fail.

---

## 5. Equal Risk Contribution (risk parity)

**Stage:** Allocator · **Requires:** Σ · **Inverts Σ:** **no**

Risk contribution of asset `i`:

```
RC_i = w_i (Σw)_i / √(wᵀΣw)          Σ_i RC_i = √(wᵀΣw)
```

ERC is the long-only portfolio with `RC_i = RC_j` for all `i, j`.

**Do not solve the RC equations by root-finding.** Use the convex log-barrier
formulation (Spinu 2013), which has a unique solution for `w > 0`:

```
min  ½ wᵀΣw − (1/n) Σ_i ln(w_i)      over w > 0,   then normalize w ← w / (1ᵀw)
```

**This requires exponential cones, not a QP.** Clarabel supports them; a pure QP
solver would not have. That capability was an unplanned dividend of the
[ADR-0002](../adr/0002-numeric-core-runtime.md) solver choice. Encode
`t_i ≤ ln w_i` as `(w_i, 1, t_i) ∈ K_exp` and maximize `Σ t_i`.

**Invariants**

| #     | Property                                                                                     |
| ----- | -------------------------------------------------------------------------------------------- |
| ERC.1 | **`ERC(diagonal Σ) ≡ InverseVolatility`**, i.e. `w_i ∝ 1/σ_i` — exact                        |
| ERC.2 | **`ERC(Σ = σ²I) ≡ EqualWeight`** — exact                                                     |
| ERC.3 | Equal correlations _and_ equal volatilities ⇒ 1/N                                            |
| ERC.4 | At the solution, `max_i RC_i − min_i RC_i < 1e-8` — the defining condition, checked directly |
| ERC.5 | Scale-invariant in Σ                                                                         |
| ERC.6 | All `w_i > 0` strictly — the log barrier guarantees an interior solution                     |

ERC.1 is the sharpest test: inverse-volatility is often _mistaken_ for risk
parity, and it is only equal to it when correlations are uniform. A bug that
conflates them passes ERC.2 and fails ERC.1.

_References:_ Maillard, Roncalli & Teïletche (2010), _The Properties of Equally
Weighted Risk Contribution Portfolios_, JPM 36(4); Spinu (2013), _An Algorithm
for Computing Risk Parity Weights_. Spec: `EqualRiskContribution.md`,
`risk-parity-portfolio.md`.

---

## 6. Maximum diversification

**Stage:** Allocator · **Requires:** Σ · **Inverts Σ:** yes

Maximize the diversification ratio:

```
DR(w) = (wᵀσ) / √(wᵀΣw)
```

**Implement via the correlation-matrix reduction, not by optimizing DR
directly.** Substituting `u_i = w_i σ_i` gives `wᵀσ = 1ᵀu` and
`wᵀΣw = uᵀCu`, so maximizing DR is scale-invariant in `u` and reduces to:

```
solve   min uᵀCu  s.t. 1ᵀu = 1        (minimum variance on the CORRELATION matrix)
then    w_i ∝ u_i / σ_i,  normalized
```

Reusing the §3 solver on `C` instead of `Σ`. Deriving it this way removes a
separate non-linear optimization and makes the model a thin wrapper.

**Invariants**

| #    | Property                                                                                            |
| ---- | --------------------------------------------------------------------------------------------------- |
| MD.1 | **`MaxDiv(C = I) ≡ InverseVolatility`** — exact                                                     |
| MD.2 | `MaxDiv(Σ = σ²I) ≡ EqualWeight`                                                                     |
| MD.3 | `DR(w*) ≥ DR(v)` for every feasible `v`                                                             |
| MD.4 | `DR ≥ 1` always, with equality iff the portfolio is a single asset or all correlations are 1        |
| MD.5 | Reduction agrees with direct numerical maximization of DR to 1e-8 (validates the derivation itself) |

_Reference:_ Choueifaty & Coignard (2008), _Toward Maximum Diversification_,
JPM 35(1). Spec: `risk-based-overview.md:49`.

---

## 7. Hierarchical Risk Parity

**Stage:** Allocator · **Requires:** Σ · **Inverts Σ:** **no — this is the point**

The highest-value addition to the roster, and effectively absent from the current
spec tree (one passing mention at `bl-ai-reference.md:134`, as a covariance
technique rather than an allocator).

**Stage 1 — tree clustering.** Correlation distance, then the distance between
distance-vectors:

```
d_ij  = √( ½ (1 − ρ_ij) )
D̄_ij = ‖ d_·i − d_·j ‖₂
```

Hierarchical agglomerative clustering on `D̄` (single linkage in the original).

**Stage 2 — quasi-diagonalization.** Reorder Σ by the linkage tree so correlated
assets are adjacent.

**Stage 3 — recursive bisection.** For a cluster with sub-covariance `V`:

```
w̃      = diag(V)⁻¹ / Σ diag(V)⁻¹           inverse-variance within the cluster
Var(V) = w̃ᵀ V w̃
```

Split the ordered list into halves `L` and `R`, set
`α = 1 − Var(L)/(Var(L) + Var(R))`, scale `L` by `α` and `R` by `1−α`, recurse.

**Invariants**

| #     | Property                                                                                                                                                                       |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| HRP.1 | `Σw = 1`, all `w_i > 0` — long-only by construction, with no constraint imposed                                                                                                |
| HRP.2 | **No matrix inversion anywhere in the algorithm** — assert structurally, e.g. by the absence of any solve/inverse call on the path                                             |
| HRP.3 | **Invariant to the input ordering of assets** — the clustering re-orders internally, so a permuted input must give permuted-identical output                                   |
| HRP.4 | Produces a finite, valid allocation when Σ is singular or `n > T`, where §3, §6 and Black-Litterman all fail                                                                   |
| HRP.5 | `HRP(diagonal Σ)` reduces to inverse-variance weighting — **verify against the reference implementation rather than asserting; the reduction depends on linkage tie-breaking** |

**Linkage tie-breaking must be explicitly defined and documented.** With a
diagonal or near-uniform correlation matrix, distances tie and the clustering
order becomes implementation-dependent. Left unspecified this silently violates
the cross-platform bit-determinism requirement in
[ADR-0002](../adr/0002-numeric-core-runtime.md#cross-platform-bit-determinism-is-a-hard-requirement),
and it will also prevent golden vectors from reproducing. Match SciPy's documented
linkage ordering, since the reference implementations use it.

**Why it matters here.** HRP requires no expected returns and never inverts Σ.
Both properties bite in digital assets: short histories, unstable correlations,
frequent `n > T`, and return forecasts of dubious value. HRP.4 is the property no
other model in this roster has.

_Reference:_ López de Prado (2016), _Building Diversified Portfolios that
Outperform Out of Sample_, JPM 42(4) — includes Python source, so golden vectors
are directly obtainable.

---

## 8. Michaud resampled efficiency

**Stage:** Allocator **decorator** — wraps any allocator ([ADR-0004](../adr/0004-allocation-model-abstraction.md))

```
for b in 1..B:
    draw T observations ~ N(μ, Σ)
    re-estimate μ̂_b, Σ̂_b from the draw
    w_b = Allocator(μ̂_b, Σ̂_b)
w̄ = (1/B) Σ_b w_b
```

**Invariants**

| #    | Property                                                                                                                                                             |
| ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| MR.1 | `Σw̄ = 1` — an average of budget-feasible weights is budget-feasible                                                                                                  |
| MR.2 | Bit-identical output for a fixed seed. **Explicit seed, never a thread RNG**                                                                                         |
| MR.3 | Convergence: results at `B` and `2B` agree within Monte Carlo error                                                                                                  |
| MR.4 | Strictly more diversified than the base allocator — `entropy(w̄) ≥ entropy(w_base)`                                                                                   |
| MR.5 | Convex constraints survive averaging; **non-convex ones do not** — cardinality and minimum-position-size constraints must be re-applied after averaging, or rejected |

MR.5 is a real trap: averaging weight vectors each satisfying "hold at most 10
assets" can produce a portfolio holding all of them.

**Intellectual property: resampled efficiency was patented.** Confirm the current
status before implementing. Flagged, not assessed — this is a legal question, not
a technical one.

_Reference:_ Michaud (1998), _Efficient Asset Management_. Spec:
`MichaudResampling.md`.

---

## 9. Entropy pooling — deferred

**Stage:** ReturnEstimator (strictly, a distribution transformer)

```
p* = argmin_p  KL(p ‖ q)     s.t.  E_p[g(X)] = v,  Σp = 1,  p ≥ 0
```

Views are constraints on the entire distribution rather than on means alone, so
volatility, correlation and tail views become expressible. Solved through the
smooth convex dual in the Lagrange multipliers.

**The invariant that makes it worth specifying now:**

| #    | Property                                                                         |
| ---- | -------------------------------------------------------------------------------- |
| EP.1 | **`EntropyPooling(Gaussian prior, linear mean views) ≡ BlackLitterman`** exactly |

Black-Litterman is the Gaussian-mean special case of entropy pooling. EP.1 is
therefore a validation of _both_ implementations against each other, from
completely independent code paths.

**Deferred, not dropped.** It cuts against the rationale for running BL at all:
entropy pooling is markedly less legible to an allocator, and legibility is
BL's entire justification ([ADR-0003](../adr/0003-portfolio-model-strategy.md)).
It earns its place when views on volatility or tails become a product
requirement — which for digital assets is plausible.

_Reference:_ Meucci (2008), _Fully Flexible Views: Theory and Practice_, Risk
21(10). Mentioned at `black-litterman-views.md:185`.

---

## Composition identity lattice

Every identity below connects two independently implemented paths and is checkable
to machine precision without any published table. Together they are the backbone
of Tier A verification.

| Identity                                                | Tolerance    | Tests      |
| ------------------------------------------------------- | ------------ | ---------- |
| `Equilibrium ∘ MVO ≡ MarketCap`                         | 1e-10        | EQ.1, MC.3 |
| `BlackLitterman(views: ∅) ≡ Equilibrium`                | 1e-12        | plan B1    |
| `MinVar(σ²I) ≡ EqualWeight`                             | 1e-10        | MV.1       |
| `ERC(diagonal Σ) ≡ InverseVolatility`                   | 1e-10        | ERC.1      |
| `ERC(σ²I) ≡ EqualWeight`                                | 1e-10        | ERC.2      |
| `MaxDiv(C = I) ≡ InverseVolatility`                     | 1e-10        | MD.1       |
| `MaxDiv(σ²I) ≡ EqualWeight`                             | 1e-10        | MD.2       |
| `HRP(diagonal Σ) ≡ InverseVariance`                     | verify first | HRP.5      |
| `EntropyPooling(Gaussian, mean views) ≡ BlackLitterman` | 1e-9         | EP.1       |
| `MaxDiv` reduction ≡ direct DR maximization             | 1e-8         | MD.5       |

A bug in any one model surfaces as a broken identity against another. This is
strictly stronger than testing each model in isolation, and it is available only
because [ADR-0004](../adr/0004-allocation-model-abstraction.md) decomposed the
models into composable stages rather than boxing each behind its own entry point.
