# ADR-0004 — Allocation model abstraction

|            |                                                                                            |
| ---------- | ------------------------------------------------------------------------------------------ |
| **Status** | **Proposed**                                                                               |
| Date       | 2026-08-12                                                                                 |
| Related    | [ADR-0002](./0002-numeric-core-runtime.md), [ADR-0003](./0003-portfolio-model-strategy.md) |
| Spec       | [allocation-models.md](../specs/allocation-models.md)                                      |

## Context

[ADR-0003](./0003-portfolio-model-strategy.md) makes alternative allocation
models peers rather than roadmap items. That only works if the abstraction is
right. Get it wrong and every model becomes a special case with its own entry
point, the comparison harness becomes a switch statement, and Phase 9 cannot slot
in without surgery.

## The obvious abstraction is wrong

```rust
trait AllocationModel {
    fn allocate(&self, input: BlackLittermanInputDto) -> Weights;   // ✗
}
```

This fails immediately. The models need radically different inputs: BL needs Σ,
`w_mkt`, λ, τ and views; HRP needs only Σ; 1/N needs only the asset count. A
single input type means every model receives fields it ignores, and **a caller
who configures BL views and then runs HRP gets silence rather than an error** —
the views simply have no effect and the result looks plausible.

## The decomposition that works

**The key observation: Black-Litterman is not an allocation model. It is a return
estimator.**

This is not a design opinion, it is what the specification already says.
`black-litterman-model.md` separates _§Posterior Distribution_ from _§Optimal
Portfolio Weights_, and E4 (`w* = (λΣ)⁻¹μ_BL`) is nothing but mean-variance
optimization applied to `μ_BL`. BL produces expected returns; something else
turns them into weights.

Once that is seen, three orthogonal stages fall out:

```
  returns history  ──▶ ┌──────────────────────┐
                       │ CovarianceEstimator  │ ──▶  Σ
                       └──────────────────────┘
                          sample · Ledoit-Wolf · ML (Phase 9)

  market data ────────▶ ┌──────────────────────┐
  + views               │   ReturnEstimator    │ ──▶  μ   (optional)
                        └──────────────────────┘
                          equilibrium · Black-Litterman · historical · entropy pooling

  μ? + Σ? + constraints ▶ ┌──────────────────────┐
                          │      Allocator       │ ──▶  w
                          └──────────────────────┘
                            MVO · MinVar · ERC · MaxDiv · HRP · 1/N · market-cap
```

Why this is the right cut:

- **BL composes with any allocator.** Running BL posterior returns through an ERC
  allocator is a real and interesting thing to do; under the naive abstraction it
  is not expressible.
- **HRP and 1/N simply declare they need no μ.** They are not special cases, they
  are allocators with weaker requirements.
- **Phase 9 slots into stage 1 without touching anything else.** The ML shrinkage
  estimator is another `CovarianceEstimator`. This is the abstraction earning its
  keep before it is built.
- **Michaud is not a model at all** — it is a decorator over an allocator. That
  falls out for free rather than needing a special case.

## Design

### Make the asset universe a type, not a convention

The implementation plan §3.1 identifies the sharpest hazard in the contract: the
covariance matrix is positional while the market weights and equilibrium returns
are dictionaries, so correctness depends on an ordering agreement that nothing
enforces. A dictionary reorder is invisible; a covariance reorder is
catastrophic.

**Do not defend this with a test. Make it unrepresentable.**

```rust
pub struct AssetUniverse { ids: Vec<AssetId>, index: HashMap<AssetId, usize> }

// Constructible ONLY through the universe, which fixes the ordering.
pub struct Weights          { universe: Arc<AssetUniverse>, v: DVector<f64> }
pub struct ExpectedReturns  { universe: Arc<AssetUniverse>, v: DVector<f64> }
pub struct Covariance       { universe: Arc<AssetUniverse>, m: DMatrix<f64> }

impl AssetUniverse {
    pub fn vector_from(&self, map: &HashMap<AssetId, f64>) -> Result<DVector<f64>>;
    // errors on any missing asset or unknown key — never defaults to zero
}

impl Covariance {
    /// The ONLY constructor. Symmetry, PSD and conditioning are established here,
    /// once, so nothing downstream can receive an unvalidated matrix.
    pub fn new(u: Arc<AssetUniverse>, m: DMatrix<f64>) -> Result<(Self, PsdReport)>;
}
```

Parse, don't validate. The PSD repair and conditioning checks from
[ADR-0001 §D6](./0001-black-litterman-model-conventions.md#d6--numerical-policy)
happen at construction, and every function downstream takes a `Covariance` rather
than a `DMatrix<f64>` — so "did anyone check this matrix?" stops being a question
anyone can ask. Test T1.9 (permutation equivariance) becomes belt-and-braces
rather than the primary defence.

### Declare requirements, and validate the pipeline before running it

```rust
pub struct InputRequirements {
    pub expected_returns: Requirement,     // Required | Optional | Unused
    pub covariance:       Requirement,
    pub market_weights:   Requirement,
    pub views:            Requirement,
    pub return_history:   Requirement,
}

pub trait Allocator {
    fn id(&self) -> ModelId;
    fn requires(&self) -> InputRequirements;
    fn allocate(&self, ctx: &AllocationContext) -> Result<Allocation>;
}
```

`requires()` is what turns the failure mode above into a real error. The harness
checks a pipeline before executing it and reports:

> `HRP` declares `expected_returns: Unused`. The configured `BlackLitterman`
> return estimator will have no effect on the allocation. Either choose an
> allocator that consumes expected returns, or remove the views.

Silently ignoring configured inputs is how a product ships a screen full of views
that change nothing.

### The three traits

```rust
pub trait CovarianceEstimator {
    fn id(&self) -> ModelId;
    fn estimate(&self, returns: &ReturnPanel) -> Result<(Covariance, EstimatorDiagnostics)>;
}

pub trait ReturnEstimator {
    fn id(&self) -> ModelId;
    fn requires(&self) -> InputRequirements;
    fn estimate(&self, ctx: &MarketContext) -> Result<(ExpectedReturns, ReturnDiagnostics)>;
}

pub trait Allocator { /* as above */ }
```

Every stage returns diagnostics alongside its result, because
`BlackLitterman-Reference.md:22` requires an audit trail and a value with no
provenance is not auditable. Diagnostics compose up the pipeline into the single
`BlackLittermanDiagnosticsDto` the API returns.

### Michaud is a decorator

```rust
pub struct ResampledAllocator<A: Allocator> {
    inner: A,
    draws: usize,
    seed:  u64,     // explicit — never thread_rng; bit-determinism is a hard requirement
}

impl<A: Allocator> Allocator for ResampledAllocator<A> {
    fn requires(&self) -> InputRequirements { self.inner.requires() }
    fn allocate(&self, ctx: &AllocationContext) -> Result<Allocation> { /* average over draws */ }
}
```

Resampled efficiency applies to _any_ allocator, not only mean-variance. Under
the naive abstraction this would have been a second copy of every model.

The explicit `seed` is not incidental: [ADR-0002](./0002-numeric-core-runtime.md#cross-platform-bit-determinism-is-a-hard-requirement)
makes bit-identical output across platforms a correctness constraint, and a
sampling model with an implicit RNG violates it on the first run.

### Pipeline and comparison

```rust
pub struct Pipeline {
    pub covariance: Box<dyn CovarianceEstimator>,
    pub returns:    Option<Box<dyn ReturnEstimator>>,   // None for HRP, ERC, 1/N
    pub allocator:  Box<dyn Allocator>,
    pub constraints: ConstraintSet,
}

pub struct Comparison { pub pipelines: Vec<Pipeline> }
```

The comparison harness of [ADR-0003](./0003-portfolio-model-strategy.md) is a
`Vec<Pipeline>` evaluated against one `MarketContext`. It needs no new
mathematics — and the model-versus-model attribution reuses the leave-one-out
machinery from ADR-0001 §D5 unchanged.

## Evidence the abstraction is correct

Good abstractions make true statements expressible. Under this decomposition, the
implementation plan's behavioural requirements stop being assertions about one
model and become **composition laws across independent code paths**:

| Plan requirement                           | Becomes                                                       |
| ------------------------------------------ | ------------------------------------------------------------- |
| B3: Π through the optimizer ⇒ `w* = w_mkt` | `Equilibrium ∘ MVO ≡ MarketCapAllocator`                      |
| B1: no views ⇒ `μ_BL = Π`                  | `BlackLitterman(views: ∅) ≡ Equilibrium`                      |
| —                                          | `ERC(diagonal Σ) ≡ InverseVolatility`                         |
| —                                          | `HRP(diagonal Σ) ≡ InverseVariance`                           |
| —                                          | `MinVar(Σ = σ²I) ≡ EqualWeight`                               |
| —                                          | `EntropyPooling(Gaussian prior, mean views) ≡ BlackLitterman` |

Each is an exact identity between two independently implemented paths, checkable
to machine precision, requiring no published table. That lattice of identities is
the backbone of [Tier A verification](../specs/model-verification.md#tier-a--numerical-correctness) —
and it only exists because the models were decomposed rather than boxed.

## Rejected alternatives

| Option                                                         | Why not                                                                                                                                               |
| -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| One `AllocationModel` trait with a fat input                   | Every model ignores most fields; misconfiguration is silent; Michaud duplicates every model; Phase 9 needs surgery                                    |
| Model-specific entry points (`vv_bl_solve`, `vv_hrp_solve`, …) | Comparison becomes a switch statement; no shared validation; the FFI surface grows without bound                                                      |
| Generic type parameters instead of trait objects               | A heterogeneous `Vec<Pipeline>` is the core use case; monomorphization buys nothing at n ≤ 50 and costs the ability to configure pipelines at runtime |
| Raw `DMatrix<f64>` throughout                                  | Reintroduces the ordering hazard the plan identifies as sharpest, and makes "has this been PSD-checked?" a permanent open question                    |

## Consequences

**Positive.** Phase 9 slots into stage 1 untouched. Michaud is free. The ordering
hazard becomes structurally impossible rather than test-defended. Six exact
composition identities appear that no single-model design would have exposed.

**Negative.** More types than a direct implementation, and `Arc<AssetUniverse>`
threading through every value is visible ceremony. The three-stage split must be
established in Phase 1 — retrofitting it after BL is built means rewriting BL.

**This ADR must be accepted before Phase 1 begins**, for that last reason.
