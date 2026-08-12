# Black-Litterman Allocation Engine — Implementation Plan

> **Status: PLAN ONLY. No solver exists. Nothing in this document may be cited as
> evidence that the engine is built.** See [§9 Honesty gate](#9-honesty-gate--when-claims-may-change)
> for the exact conditions under which product and investor claims may change.

|                     |                                                                                                                   |
| ------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Revision            | 2 — 2026-08-12 (numeric core moved to Rust; ADR-0001 decisions folded in)                                         |
| Scope               | Classical Black-Litterman solver, wired through CQRS → API → frontend                                             |
| Explicitly deferred | ML shrinkage covariance estimator (Phase 9)                                                                       |
| Model conventions   | [ADR-0001](./adr/0001-black-litterman-model-conventions.md) — **proposed, needs sign-off**                        |
| Runtime             | [ADR-0002](./adr/0002-numeric-core-runtime.md) — Rust core, P/Invoke                                              |
| Model strategy      | [ADR-0003](./adr/0003-portfolio-model-strategy.md) — **the deliverable is a comparison harness, not a BL engine** |
| Abstraction         | [ADR-0004](./adr/0004-allocation-model-abstraction.md) — **must be accepted before Phase 1**                      |
| Model specs         | [allocation-models.md](./specs/allocation-models.md) · [model-verification.md](./specs/model-verification.md)     |
| Verified baseline   | `dotnet build vv.Platform.sln` → succeeded, 0 errors, 1 warning; cargo/rustc 1.97.1 present                       |

---

## 0. What exists today

**Specification** — 45 documents, all `status: draft`, `version: 0.1.0`, across
`Asset/portfolio-management/black-litterman/` (classical) and
`AI/black-litterman-ai/` (ML-enhanced), plus a near-duplicate pair of
`AI/FinancialModels/` and `AI/financial-models/` trees (see [§11](#11-housekeeping)).

**Contracts** — `src/vv.Application/DTOs/Portfolio/BlackLittermanModels.cs`, 82 lines.

**Computation** — none. `git grep -il blacklitterman -- src` returns three DTO
files and the docs. No solver, no handler, no service, no interface, no test.

**Frontend** — `JustAGhosT/vv-landing`, `components/corporate/model-results.tsx`,
renders `data/models/results.json` behind the comment _"In a real application,
this would be an API call."_ That repo is not checked out locally; Phase 8 is
planned from description, not from reading its source.

---

## 1. The mathematical contract

### 1.1 Notation

| Symbol  | Shape         | Meaning                                       | DTO source                                     |
| ------- | ------------- | --------------------------------------------- | ---------------------------------------------- |
| n, k    | scalar        | asset count, view count                       | `Assets.Count`, `Views.Count`                  |
| Σ       | n×n           | covariance of **excess** returns              | `CovarianceMatrix`                             |
| w_mkt   | n×1           | market-cap weights                            | `MarketCapitalizationWeights`                  |
| λ, τ    | scalar        | risk aversion, prior uncertainty              | `RiskAversionCoefficient`, `ConfidenceInPrior` |
| Π       | n×1           | implied equilibrium excess returns            | derived, or `EquilibriumReturns`               |
| P, Q, Ω | k×n, k×1, k×k | view matrix, values, uncertainty              | `Views[]`                                      |
| μ_BL    | n×1           | posterior expected returns                    | `PosteriorExpectedReturns`                     |
| M, Σ_p  | n×n           | posterior covariance of the mean / of returns | — / `PosteriorCovariance`                      |
| w\*     | n×1           | optimal weights                               | `OptimalWeights`                               |

### 1.2 The five equations

**(E1) Reverse optimization** — `black-litterman-model.md:46`

```
Π = λ Σ w_mkt
```

**(E2) Posterior mean, precision form** — `black-litterman-model.md:125-126`

```
M    = [ (τΣ)⁻¹ + PᵀΩ⁻¹P ]⁻¹
μ_BL = M [ (τΣ)⁻¹ Π + PᵀΩ⁻¹ Q ]
```

**(E3) Posterior mean, covariance form** — `black-litterman-model.md:130`

```
μ_BL = Π + τΣPᵀ [ τPΣPᵀ + Ω ]⁻¹ (Q − PΠ)
```

**E3 is the production path** — it inverts k×k (k ≤ ~5) rather than two n×n, and
is well-posed at Ω = 0 where E2 is not. **E2 is implemented anyway and asserted
to agree to 1e-10**: two independent derivations of the same quantity is the
cheapest strong correctness signal available here.

**(E4) Optimal weights** — `black-litterman-model.md:172`

```
w* = (λ R)⁻¹ μ_BL          R ∈ { Σ (default), Σ_p }   — ADR-0001 §D2
```

**(E5) Ω calibration** — four methods, ADR-0001 §D1. Default
`Ω = diag(P(τΣ)Pᵀ)`.

### 1.3 Behavioural contract

`black-litterman-validation.md:31-52` and `black-litterman-model.md:191-195`:

| #   | Requirement                             | Spec ref         |
| --- | --------------------------------------- | ---------------- |
| B1  | No views ⇒ μ_BL = Π exactly             | validation.md:31 |
| B2  | 100% confidence ⇒ Pμ_BL = Q exactly     | validation.md:36 |
| B3  | Π through the optimizer ⇒ w\* = w_mkt   | validation.md:41 |
| B4  | Zero confidence ⇒ μ_BL → Π              | model.md:195     |
| B5  | Scaling w_mkt by k leaves w\* unchanged | validation.md:52 |

B3 is the highest-value test in the suite: E1 and E4 are exact inverses under the
default risk matrix, so `w* = (λΣ)⁻¹(λΣw_mkt) = w_mkt` must hold to machine
precision. It exercises the whole path — construction, factorization, ordering,
FFI, decimal boundary — against a closed-form answer with no literature
dependency.

### 1.4 Four additional exact invariants

Derived while resolving ADR-0001 §D1 and §D2. Each is exact, cheap, and
independent of any published table:

```
1.  μ_BL is invariant to τ          under ProportionalToPrior and ConfidenceScaled
2.  M ∝ τ                            (linearly)
3.  Σ_p = (1 + τ)Σ                   when k = 0
4.  w* = w_mkt / (1 + τ)             when k = 0 and R = Σ_p
```

(1) holds because Ω ∝ τ under both default calibrations, so τ cancels in E3.
It does **not** hold under `Explicit` Ω. These become tests T1.12–T1.15.

---

## 2. Model conventions — resolved

All six blocking questions from revision 1 are decided in
**[ADR-0001](./adr/0001-black-litterman-model-conventions.md)**, which carries
the full reasoning. Summary:

| #   | Question                                                                                                                                                    | Decision                                                                                                                                                                    |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| D1  | Three conflicting Ω formulas                                                                                                                                | four named methods; default `ProportionalToPrior`; `model.md:161` **withdrawn** (contradicts B2); c=0 drops the view row, c=1 gives Ω=0                                     |
| D2  | `PosteriorCovariance` undefined; Σ vs Σ_p in E4                                                                                                             | return `Σ_p = Σ + M`; optimizer risk matrix explicit, **default Σ** (B3 exact)                                                                                              |
| D3  | Units undeclared                                                                                                                                            | required `ReturnBasis` enum; **no automatic conversion**; excess-return space throughout; `RiskFreeRate` is reporting-only                                                  |
| D4  | Π both input and derived                                                                                                                                    | supplied wins; derived otherwise; divergence > 10% warns; source always in diagnostics                                                                                      |
| D5  | **six** undefined result fields — `TiltMagnitude`, `ImpactScore`, `ImpliedConfidenceLevel`, `ImpliedRiskAversion`, `ReturnContribution`, `RiskContribution` | leave-one-out definitions, same optimizer and constraints as the main solve; **scores are non-additive**; `ImpliedRiskAversion` doubles as a self-consistency check (T1.17) |
| D6  | Numerical policy unstated                                                                                                                                   | E3 production / E2 cross-check; Cholesky-solve never inverse; **relative** eigenvalue floor (spec's absolute 1e-6 rejected as scale-dependent); κ warn 1e10 / reject 1e14   |

Errata pointers are in place in `black-litterman-model.md` (two),
`black-litterman-views.md`, and `black-litterman-implementation.md`, so nobody
implements the withdrawn formula from the spec tree.

**D2's default is the one to argue about in review.** It is structured as a
flipped default plus a golden re-baseline, not a rewrite.

---

## 3. DTO assessment and exact diff

**Verdict: sufficient as a wire contract, insufficient as a computation
contract.** All changes are additive except one enum tightening.

### 3.1 `CovarianceMatrix` as `List<List<decimal>>`

**Keep it on the wire. Never compute on it.** As JSON it is correct and
idiomatic. As a compute type it carries no shape, symmetry, or PSD invariant —
and, most sharply, **no binding to asset identity**. Correctness depends on
positional agreement with `Assets`, while `MarketCapitalizationWeights` and
`EquilibriumReturns` are _dictionaries_. Mixing positional and keyed
representations of the same asset set in one DTO is the sharpest edge in this
contract: a dictionary reorder is invisible, a covariance reorder is
catastrophic. Hence T1.9.

The fix is a validated mapping seam, not a new wire type. `Assets` is canonical
ordering; every dictionary is projected onto it; any key not in `Assets`, or any
asset missing from a dictionary, is a validation failure — never a default-to-zero.

### 3.2 `decimal` / `double` boundary

**`double` (Rust `f64`) inside, `decimal` at the wire, one tested seam in C#.**

The case for `decimal` is exact base-10 arithmetic on money, and it does not
apply: every input here is a statistical estimate carrying perhaps two
significant figures. `double` gives 15–16 — six orders of magnitude more
precision than the data contains. Under ADR-0002 the point is moot for the core
(Rust computes in `f64`), but the C# boundary rules still bind:

1. **Inbound** `decimal → double`: direct cast. ~1e-17 relative error, ~14 orders
   below input noise.
2. **Outbound** `double → decimal`: `Math.Round(x, 10, MidpointRounding.ToEven)`.
   Fixed scale, deterministic, machine-independent.
3. **Renormalize weights after rounding.** Rounding n weights independently does
   not preserve `Σw = 1`; the result would render as `0.9999999999`. Renormalize,
   then assert `sum == 1.0m` exactly.
4. **Guard before converting**: `double.IsFinite(x)` and `|x| < 7.9e28`. A
   non-finite value throws a typed domain exception naming the quantity — it
   never becomes a decimal.
5. **Never round-trip mid-computation.** One conversion in, one out.

### 3.3 Field-level gaps

| #   | Issue                                                                                  | Fix                                                                                                                                            |
| --- | -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | No `ReturnBasis`                                                                       | add (D3)                                                                                                                                       |
| 2   | No Ω calibration selector                                                              | add (D1)                                                                                                                                       |
| 3   | `Confidence` semantics undefined; c=0 and c=1 break naive formulas                     | define + endpoint handling (D1)                                                                                                                |
| 4   | τ unguarded — τ=0 makes (τΣ)⁻¹ undefined                                               | validator: τ ∈ (0, 1]                                                                                                                          |
| 5   | λ unguarded — λ=0 makes (λΣ)⁻¹ undefined                                               | validator: λ > 0                                                                                                                               |
| 6   | `ViewType` derivable from `AssetWeights`, can contradict it                            | `AssetWeights` authoritative; validate Absolute ⇒ one nonzero, Relative ⇒ weights sum to 0                                                     |
| 7   | Π both input and derived                                                               | precedence + diagnostic (D4)                                                                                                                   |
| 8   | No per-view Ω override                                                                 | add `ViewVariance`                                                                                                                             |
| 9   | No result diagnostics                                                                  | add `BlackLittermanDiagnosticsDto` — `BlackLitterman-Reference.md:22` requires auditable I/O, and a result with no provenance is not auditable |
| 10  | `PortfolioMetricsDto` non-nullable metrics that BL cannot compute                      | make nullable — see below                                                                                                                      |
| 11  | No `AsOf` / `CurrencyCode`                                                             | add                                                                                                                                            |
| 12  | `ConstraintDto.Type` is a bare `string`                                                | enum                                                                                                                                           |
| 13  | **No returns-history input ⇒ the covariance estimator is unreachable through the API** | add `ReturnHistory` + `CovarianceEstimationMethod` — see below                                                                                 |

**On gap 13 — a hole in revision 2 of this plan, not just in the DTO.** The input
accepts a finished `CovarianceMatrix` and nothing else. But
[§5](#5-minimum-viable-solver) puts a `CovarianceEstimator` trait with sample and
Ledoit–Wolf implementations in Phase 4, and an estimator needs _returns history_
to estimate from. **As written, Phase 4 ships code that no API caller can
reach** — and, more seriously, the same gap means the Phase 9 ML estimator could
never be exercised through the product either, while
`veritasvault-investor-overview.html:346` sells "ML-enhanced covariance
estimation" as a product capability.

Fix: accept either a covariance matrix or a returns history, mutually exclusive,
validated. The alternative — declaring covariance estimation permanently
upstream and deleting the trait from Phase 4 — is a legitimate scope cut, but it
must then be stated plainly, because it makes the deck's covariance claim
unbuildable on this endpoint.

**On gap 10** — `MaxDrawdown` and `ValueAtRisk` need a return history and are not
derivable from BL inputs. As non-nullable `decimal` they reach the UI as `0`, and
a displayed max drawdown of 0.00% is indistinguishable from a real answer. The
engine computes only what the inputs support: `ExpectedReturn = w*ᵀμ_BL`,
`Volatility = √(w*ᵀΣw*)`, `SharpeRatio = ExpectedReturn / Volatility` (μ is
excess — no rf term), `AssetAllocation = w*`.

### 3.4 Exact DTO diff

**Safe to make now, and only now.** Verified: `PortfolioMetricsDto`,
`BlackLittermanConstraintDto`, `InvestorViewDto` and `ViewImpactDto` have **no
references anywhere outside their own declaration file**. The window closes the
moment the API ships — which is why the DTO changes land in Phase 1, not Phase 7.

```csharp
// ── New enums ────────────────────────────────────────────────────────────────
// Unspecified = 0 is deliberate: a missing JSON field deserializes to it and is
// rejected loudly, rather than silently defaulting to a real value. This is the
// D3 failure mode, eliminated structurally.
public enum ReturnBasis { Unspecified = 0, Daily, Weekly, Monthly, Quarterly, Annual }

// These two DO have intended defaults, so default(T) is the intended value.
public enum OmegaCalibrationMethod { ProportionalToPrior = 0, ConfidenceScaled, IdzorekTilt, Explicit }
public enum RiskMatrixChoice { PriorCovariance = 0, PosteriorCovariance }
public enum ConstraintType { Unspecified = 0, Budget, Box, Group, Turnover }
public enum CovarianceEstimationMethod { NotApplicable = 0, Sample, LedoitWolfShrinkage, MlShrinkage /* Phase 9 */ }

// ── BlackLittermanInputDto: additive ─────────────────────────────────────────
public required ReturnBasis ReturnBasis { get; set; }                  // D3
public OmegaCalibrationMethod OmegaCalibration { get; set; }           // D1, default = ProportionalToPrior
public RiskMatrixChoice OptimizerRiskMatrix { get; set; }              // D2, default = PriorCovariance
public DateTime? AsOf { get; set; }
public string? CurrencyCode { get; set; }
public decimal MinimumTradeSize { get; set; }                          // D5, default 0 = report all

// Gap 13 — supply EITHER CovarianceMatrix OR ReturnHistory + a method, never both.
// Outer list is one row per period, inner is ordered by Assets. Validator enforces
// the exclusion, rectangularity, and that periods >= assets + 1 for a sample estimate.
public List<List<decimal>>? ReturnHistory { get; set; }
public CovarianceEstimationMethod CovarianceEstimation { get; set; }   // default NotApplicable

// ── InvestorViewDto: additive ────────────────────────────────────────────────
public decimal? ViewVariance { get; set; }   // explicit Ω_ii; overrides Confidence

// ── BlackLittermanConstraintDto: tightening ──────────────────────────────────
- public required string Type { get; set; }
+ public required ConstraintType Type { get; set; }

// ── PortfolioMetricsDto: nullability ─────────────────────────────────────────
- public decimal MaxDrawdown { get; set; }
- public decimal ValueAtRisk { get; set; }
+ public decimal? MaxDrawdown { get; set; }    // not derivable from BL inputs
+ public decimal? ValueAtRisk { get; set; }    // not derivable from BL inputs

// ── BlackLittermanResultDto: additive ────────────────────────────────────────
public required BlackLittermanDiagnosticsDto Diagnostics { get; set; }
public ReturnBasis ReturnBasis { get; set; }   // echoed from input

// ── New ──────────────────────────────────────────────────────────────────────
public class BlackLittermanDiagnosticsDto
{
    public required string SolverStatus { get; set; }              // Optimal | Infeasible | ...
    public required string EquilibriumSource { get; set; }          // Supplied | Derived   (D4)
    public required string OmegaCalibrationUsed { get; set; }
    public required string OptimizerRiskMatrixUsed { get; set; }    // D2 — which R was used
    public required string CovarianceSource { get; set; }           // Supplied | Estimated:<method>  (gap 13)
    public decimal CovarianceConditionNumber { get; set; }
    public bool PsdRepairApplied { get; set; }
    public int EigenvaluesClipped { get; set; }
    public List<string> ViewsDroppedZeroConfidence { get; set; } = new();   // D1
    public List<string> BindingConstraintIds { get; set; } = new();
    public decimal? KktResidual { get; set; }
    public List<DiagnosticWarningDto> Warnings { get; set; } = new();
    public required string EngineVersion { get; set; }              // vv-portfolio-core semver + git sha
    public int AbiVersion { get; set; }
    public int SchemaVersion { get; set; }                          // payload schema, versioned independently of the ABI
    public required string InputHash { get; set; }                  // SHA-256 of the canonical solver input — see §6.1
    public long ComputeTimeMs { get; set; }
}

public class DiagnosticWarningDto
{
    public required string Code { get; set; }
    public required string Message { get; set; }
    public string? Field { get; set; }
}
```

`BlackLittermanConstraintDto` is otherwise well-formed:
`AssetWeights` + `LowerBound`/`UpperBound` is exactly the general linear
constraint `L ≤ aᵀw ≤ U`, of which box, budget, sector and group constraints are
all special cases. No further change needed.

---

## 4. Numerics — Rust core

Full reasoning in **[ADR-0002](./adr/0002-numeric-core-runtime.md)**. The short
version: .NET has no maintained QP solver (Accord archived at 3.8.0, OR-Tools is
LP, alglib is GPL), so the C# route required hand-rolling Goldfarb–Idnani; the
differential-test oracle was going to be another language regardless; and the
Phase 9 specs are TensorFlow. Rust removes the first problem outright.

Verified on crates.io 2026-08-12; local toolchain cargo/rustc 1.97.1:

| Crate                  | Version | Licence        | Role                                               |
| ---------------------- | ------- | -------------- | -------------------------------------------------- |
| `nalgebra`             | 0.35.0  | Apache-2.0     | Cholesky, symmetric eigendecomposition, SVD        |
| `clarabel`             | 0.11.1  | Apache-2.0     | interior-point conic solver — the QP               |
| `serde` / `serde_json` | —       | MIT/Apache-2.0 | FFI payload                                        |
| `schemars`             | —       | MIT            | JSON Schema emission for C# type generation (§6.1) |
| `osqp`                 | 1.0.1   | Apache-2.0     | **dev-only** QP cross-check (T7.8)                 |

**All permissive-licensed.** On the .NET side the only mature QP option was GPL;
that constraint disappears here.

**`osqp` is a dev-dependency behind a cargo feature (`--features qp-crosscheck`),
never shipped.** Running two independent QP solvers and asserting they agree is
the same logic as the E2/E3 cross-check, applied to the part of the pipeline with
no closed-form oracle. Two constraints on how it is wired: it must not enter the
production dependency graph (it would otherwise widen the audited surface for no
runtime benefit), and it runs on **one** CI platform rather than all three,
because the crate wraps the OSQP C library and would drag a C toolchain into
every runner. _Confirm the C-binding detail in the Clarabel API spike; the
feature-gating is correct either way._

**Never form an explicit inverse.** Every `⁻¹` above is a `Cholesky::solve`.
Faster, more accurate, and Cholesky _failing_ is the positive-definiteness check.

Constraint handling is staged so each stage has a closed-form oracle:

- **Stage 1** — unconstrained, `w* = (λR)⁻¹μ` by Cholesky solve. **Required for
  the literature golden vectors, which are unconstrained.**
- **Stage 2** — budget only (`Σw = 1`), closed form via Lagrange multiplier.
- **Stage 3** — general inequalities via Clarabel, checked against stages 1 and 2
  wherever constraints are slack.

QP mapping: `max wᵀμ − (λ/2)wᵀΣw` ⟺ `min ½wᵀ(λΣ)w − μᵀw`, so `P = λΣ`, `q = −μ`;
budget → `ZeroCone`; `L ≤ Aw ≤ U` → two `NonnegativeCone` blocks.
**A spike must confirm Clarabel 0.11's Rust API surface before Phase 5 commits** —
version and licence are verified, API ergonomics are not.

---

## 5. Minimum viable solver

**In scope:** E1 → E5 → E3 → E4, constraint stages 1–3, and the D5 attribution —
built on the ADR-0004 three-stage abstraction from the start, with Black-Litterman
occupying the `ReturnEstimator` stage rather than being the whole pipeline.

**Also in scope from [ADR-0003](./adr/0003-portfolio-model-strategy.md)** (Phases
5a, 5b, 6b — specified in [allocation-models.md](./specs/allocation-models.md)):
1/N, market-cap, minimum variance, ERC, maximum diversification, HRP, and the
Michaud decorator. These are not scope creep — without at least 1/N and HRP,
**nothing in this plan can tell you whether Black-Litterman is helping.**

**Deferred, each with an interface seam now:**

| Deferred                                      | Seam                        |
| --------------------------------------------- | --------------------------- |
| ML shrinkage covariance estimator (Phase 9)   | `CovarianceEstimator` trait |
| Factor-space BL (`implementation.md:384-411`) | —                           |
| Backtesting engine (`validation.md:200`)      | —                           |
| Sensitivity analyzer (`validation.md:73-172`) | —                           |
| Entropy pooling, robust BL, dynamic BL        | —                           |

The MVP ships two classical estimators behind the trait: sample covariance and
Ledoit–Wolf shrinkage (`covariance-estimation-methods.md:45`). **Ledoit–Wolf must
be hand-written in Rust** — no crate supplies it, where sklearn would have. This
is acceptable: a closed-form estimator is a very different proposition from a QP
solver, and it is validated against sklearn output captured as a fixture.

---

## 6. Wiring

```
crates/vv-portfolio-core/          pure Rust — BL math, optimizer, attribution. No FFI.
crates/vv-portfolio-ffi/           cdylib — C ABI shim: serde + panic containment only.
src/vv.Analytics/           C# LibraryImport bindings, SafeHandle, IBlackLittermanEngine
src/vv.Application/         command, handler, validator, DTO mapper
src/vv.Api/                 controller
```

### 6.1 FFI surface

```c
int32_t vv_bl_solve(const uint8_t* req, size_t req_len, uint8_t** out, size_t* out_len);
void    vv_bl_free(uint8_t* ptr, size_t len);
int32_t vv_bl_abi_version(void);
```

Three rules that decide whether this works (full rationale in ADR-0002 §FFI):

1. **One crossing per request, JSON payload.** The _entire_ solve happens
   Rust-side including the `2k+1` attribution solves — attribution must use the
   same optimizer and constraints as the main solve, so a per-solve crossing
   would be both slow and incoherent.
2. **Rust allocates, Rust frees.** C# wraps the pointer in a `SafeHandle` so
   release survives exceptions. **Never `Marshal.FreeHGlobal` on Rust memory** —
   different allocator, immediate heap corruption.
3. **`catch_unwind` at every entry point.** Unwinding across FFI is UB.
   `panic = "abort"` is rejected — it would kill the API process on bad input.

C# side uses `[LibraryImport]` (source-generated, .NET 7+), not `[DllImport]`.

**Payload types are generated, not mirrored by hand.** Two hand-maintained
definitions of the same wire format drift silently — and the drift surfaces as
wrong numbers, not as a compile error, because JSON deserialization fills
missing fields with defaults.

The pipeline is `schemars` on the Rust types → JSON Schema → C# generation
(NJsonSchema / NSwag), run in CI with a check that the committed C# matches
what the current Rust would generate.

_Correction to an earlier suggestion in this plan's review: `typeshare` is not
the right tool here — it targets TypeScript, Swift, Kotlin and Go, and C# is not
among its first-class outputs._ The JSON Schema route is the workable one, and it
pays a second dividend: the same schema validates actual responses in the API
contract tests (T8), so a shape regression fails loudly at the boundary.

The payload carries **`schema_version` independently of `vv_bl_abi_version`**.
They change for different reasons — the ABI changes when the C function
signatures change, the schema when a field is added — and conflating them forces
a needless ABI bump for every additive field.

**Input hashing.** `InputHash` is the SHA-256 of **the request bytes the FFI
received**, hashed before parsing. This is deliberately not a hash of the HTTP
request body: it binds the signed result to precisely the input the solver
consumed, with no dependence on C#-side re-serialization or on a JSON
canonicalization scheme. Documented on the field as "hash of the canonical solver
input, not of the HTTP request". Together with `EngineVersion` (semver + git sha)
this makes a result independently reproducible, which is what
`BlackLitterman-Reference.md:22` actually needs from an audit trail.

### 6.2 CQRS layer

The existing pattern is `record …Command : IRequest<TResult>` →
`…CommandHandler` with constructor-injected service + `ILogger`, both
null-guarded. `DependencyInjection.AddApplication()` already registers MediatR
and FluentValidation by assembly scan and wires `ValidationBehavior` +
`LoggingBehavior`. **A validator dropped in `Validators/` is enforced
automatically — no wiring needed.**

```
Commands/RunBlackLittermanAllocationCommand.cs
Handlers/RunBlackLittermanAllocationCommandHandler.cs
Validators/BlackLittermanInputDtoValidator.cs      every §3.3 guard
Mapping/BlackLittermanDtoMapper.cs                 the single decimal ⇄ double seam
```

One line in `DependencyInjection.cs`:
`services.AddScoped<IBlackLittermanEngine, RustBlackLittermanEngine>();`

### 6.3 API

Matching `MarketDataController`'s shape:

```
POST /api/portfolioallocation/black-litterman   → 200 BlackLittermanResultDto
                                                  400 validation failure
                                                  422 numerically infeasible
```

422 is deliberate and distinct from 400: a singular covariance or an infeasible
constraint set is a well-formed request the solver cannot answer. It is reported
as such, never as a silently repaired answer.

### 6.4 Build and distribution

The real cost of ADR-0002, and the largest new infrastructure in this plan:

1. Cross-compile `win-x64`, `linux-x64`, `osx-arm64` (plus `linux-musl-x64` if
   anything deploys to Alpine — glibc/musl is not interchangeable and fails at
   load time).
2. Package as NuGet with `runtimes/{rid}/native/` layout so `dotnet publish`
   selects correctly. **Do not start with loose files copied to output** —
   retrofitting is worse.
3. CI: build on three runners, pack, publish to an internal feed.
4. Pin `rust-toolchain.toml`; commit `Cargo.lock`.
5. `vv_bl_abi_version` checked at startup so a mismatched binary is refused
   rather than misread.

### 6.5 Frontend cutover (`vv-landing`, separate repo, separate PR)

1. Typed API client + zod validation on the response. Shape drift must fail
   loudly — a `decimal` serialized as a JSON string is a realistic failure mode.
2. Replace the direct `results.json` import with a fetch, and delete the
   _"In a real application…"_ comment in the same commit that removes the
   behaviour it describes.
3. Real loading and error states.
4. **The fixture stays reachable only behind an explicit `NEXT_PUBLIC_USE_FIXTURE`
   flag, never as a silent fallback on error.** A silent fallback reproduces
   today's problem with better camouflage: plausible numbers with no indication
   the engine failed.
5. CI check that fails if the fixture is imported outside the flagged path.

---

## 7. Test strategy

Financial computation. A test asserting the solver returned _something_ is worse
than no test — it converts "unverified" into a green check mark.

Most tiers now run as `cargo test` in `vv-portfolio-core`: fast, no .NET, no DI, no HTTP.
`proptest` covers the invariants across generated inputs rather than hand-picked
cases.

### T1 — Invariants and properties (`cargo test` + `proptest`)

| #     | Test                                                                                  | Tolerance |
| ----- | ------------------------------------------------------------------------------------- | --------- |
| T1.1  | B1: no views ⇒ μ_BL = Π                                                               | 1e-12     |
| T1.2  | **B3: w\* from Π equals w_mkt** (exact inverse round-trip)                            | 1e-10     |
| T1.3  | B2: c→1 ⇒ Pμ_BL = Q                                                                   | 1e-9      |
| T1.4  | B4: c→0 ⇒ μ_BL → Π                                                                    | monotone  |
| T1.5  | B5: w_mkt scaled by k ⇒ w\* unchanged after normalization                             | 1e-10     |
| T1.6  | Q = PΠ ⇒ μ_BL = Π at **every** confidence                                             | 1e-10     |
| T1.7  | **E2 and E3 agree**                                                                   | 1e-10     |
| T1.8  | Σ_p symmetric and PSD (min eigenvalue ≥ −1e-12)                                       | —         |
| T1.9  | **Permutation equivariance**: reorder `Assets` ⇒ results permute identically          | exact     |
| T1.10 | Determinism: identical input ⇒ byte-identical result                                  | exact     |
| T1.11 | Blending monotonicity: c₁<c₂ ⇒ μ_BL(c₂) strictly closer to Q                          | —         |
| T1.12 | **μ_BL invariant to τ** under both default Ω methods                                  | 1e-12     |
| T1.13 | **M ∝ τ** linearly                                                                    | 1e-12     |
| T1.14 | **Σ_p = (1+τ)Σ** when k=0                                                             | 1e-12     |
| T1.15 | **w\* = w_mkt/(1+τ)** when k=0 and R=Σ_p                                              | 1e-10     |
| T1.16 | μ_BL **does** vary with τ under `Explicit` Ω (negative control for T1.12)             | —         |
| T1.17 | **`ImpliedRiskAversion` returns the input λ exactly** when Π is derived (ADR-0001 D5) | 1e-12     |

T1.9 is the direct test for §3.1's positional/keyed hazard — the defect class
most likely to ship undetected. T1.16 exists so T1.12 cannot pass vacuously.

### T2 — Golden vectors from the literature

**The load-bearing tier.** Sources named in the spec's own reference list
(`BlackLitterman-Reference.md:38-41`): Black & Litterman (1992), Idzorek (2005),
Meucci (2010), Walters (2014).

| #    | Source                                                  | Reproduces            |
| ---- | ------------------------------------------------------- | --------------------- |
| T2.1 | He & Litterman (1999), 7-country example, δ=2.5, τ=0.05 | Π from E1             |
| T2.2 | same, single relative view                              | μ_BL, w\*             |
| T2.3 | same, two-view case                                     | μ_BL, w\*             |
| T2.4 | Idzorek (2005) 8-asset example                          | Π, μ_BL, w\*          |
| T2.5 | Idzorek confidence/tilt method                          | implied confidence, Ω |

Five mandatory rules:

1. **Every fixture carries provenance in its header** — paper, year, table, page.
   A golden vector without a citation is a number someone made up.
2. **Tolerances stated in the printed unit.** These tables print to one or two
   decimals in percent, so the correct assertion is ±0.05% absolute on returns and
   ±0.1% absolute on weights — _not_ a relative 1e-9. A too-tight tolerance fails
   for reasons that are not bugs, and the reflex fix is to loosen it until green,
   which destroys the test's value. Set it right once, with a comment saying why.
3. **No golden vector is frozen until two independent derivations agree** — the
   printed table _and_ an independent implementation (numpy/PyPortfolioOpt script
   in `tests/reference/`, its output committed so CI needs no Python).
4. **Disagreement is a finding, not a nuisance.** Investigate and write it up
   before freezing. The Rust is never adjusted to match a single printed table.
5. **State the conventions each fixture assumes** — τ, δ vs λ, Ω method, and
   whether weights use Σ or Σ_p (ADR-0001 §D2). Most reproduction failures in this
   model are convention mismatches, not arithmetic errors.

T2.5 is partly self-validating: under `IdzorekTilt`, `ImpliedConfidenceLevel`
should return approximately the `Confidence` that was input (ADR-0001 §D5).

### T3 — Differential testing

Seeded pseudo-random problems: n ∈ [3,30], k ∈ [0,5], Σ = AAᵀ + εI (guaranteed
PD), τ ∈ [0.01,0.1], λ ∈ [1,10]. ~1000 cases against numpy/PyPortfolioOpt offline;
inputs and reference outputs committed as fixtures. Max absolute deviation < 1e-9
on μ_BL and w\*.

Catches the class of error the golden vectors cannot — a bug correct on the
literature's specific shapes and wrong elsewhere.

### T4 — Conditioning and failure modes

| #     | Scenario                                        | Required behaviour                                                   |
| ----- | ----------------------------------------------- | -------------------------------------------------------------------- |
| T4.1  | Σ singular (two identical assets)               | typed error naming the problem — **never a silent pseudo-inverse**   |
| T4.2  | κ(Σ) > 1e10                                     | succeed + warn, condition number reported                            |
| T4.3  | Σ non-symmetric on input                        | rejected at validation                                               |
| T4.4  | Σ symmetric but indefinite                      | relative eigenvalue clipping, `PsdRepairApplied` set                 |
| T4.5  | c = 0 and c = 1 exactly                         | defined behaviour per D1; no division by zero                        |
| T4.6  | τ = 0, λ = 0, λ < 0                             | rejected at validation                                               |
| T4.7  | Contradictory views ("A>B" and "B>A")           | solve **and warn** — the math is well-posed; the user should be told |
| T4.8  | Duplicate view rows ⇒ P rank-deficient          | handled via E3 (k×k stays invertible when Ω ≻ 0)                     |
| T4.9  | **No NaN or Inf ever crosses the FFI boundary** | asserted on every T1–T3 case                                         |
| T4.10 | n=1, k=0 degenerate                             | defined behaviour                                                    |

### T5 — FFI boundary (new under ADR-0002)

| #    | Test                                                                                                                     |
| ---- | ------------------------------------------------------------------------------------------------------------------------ |
| T5.1 | Round-trip: C# request → Rust → C# result, no precision loss                                                             |
| T5.2 | **Soak: 10⁵ solves, no leak** (RSS flat, handle count flat)                                                              |
| T5.3 | A Rust panic surfaces as an error code, does not unwind into .NET                                                        |
| T5.4 | Null / zero-length / malformed-JSON payload handled cleanly                                                              |
| T5.5 | ABI version mismatch refused at startup, not misread                                                                     |
| T5.6 | `cargo miri` clean on `vv-portfolio-core`                                                                                |
| T5.7 | `SafeHandle` releases on the exception path                                                                              |
| T5.8 | **Cross-RID determinism**: golden fixtures produce byte-identical canonicalized JSON on win-x64, linux-x64 and osx-arm64 |
| T5.9 | Resolved `nalgebra` feature set contains no BLAS/LAPACK backend                                                          |

T5.8 and T5.9 are not hygiene. `BlackLitterman-Reference.md:22` requires model
inputs and outputs to be cryptographically signed; a one-ULP difference between a
developer machine and a production container breaks signature verification and
voids the audit trail. See [ADR-0002 §Cross-platform bit-determinism](./adr/0002-numeric-core-runtime.md#cross-platform-bit-determinism-is-a-hard-requirement).

### T6 — Decimal boundary (C#)

| #    | Test                                                                     |
| ---- | ------------------------------------------------------------------------ |
| T6.1 | `decimal → double → decimal` round-trip within the declared 1e-10 scale  |
| T6.2 | Weights sum to **exactly** `1.0m` after rounding and renormalization     |
| T6.3 | Non-finite double ⇒ typed exception, never a decimal                     |
| T6.4 | `\|x\| > 7.9e28` ⇒ typed exception, never `OverflowException` from depth |
| T6.5 | Rounding is `ToEven` and machine-independent                             |

### T7 — Constraints and QP

| #    | Test                                                                                                         |
| ---- | ------------------------------------------------------------------------------------------------------------ |
| T7.1 | Slack constraints ⇒ QP result equals stage-1 analytic solution (1e-9)                                        |
| T7.2 | Budget-only ⇒ QP equals stage-2 closed form (1e-9)                                                           |
| T7.3 | KKT residual < 1e-8 on every solved problem                                                                  |
| T7.4 | Box constraints honoured to the exact bound                                                                  |
| T7.5 | Group constraint `L ≤ aᵀw ≤ U` honoured                                                                      |
| T7.6 | Infeasible set ⇒ explicit failure, **not** a projected approximation                                         |
| T7.7 | Long-only + budget ⇒ all weights ≥ 0, sum to 1                                                               |
| T7.8 | **Clarabel and OSQP agree to 1e-8** on every constrained solve (`--features qp-crosscheck`, one CI platform) |

### T8 — Application and API contract

| #    | Test                                                                    | Project                |
| ---- | ----------------------------------------------------------------------- | ---------------------- |
| T8.1 | Handler maps DTO → payload → DTO with no precision loss                 | `vv.Application.Tests` |
| T8.2 | Validator rejects every §3.3 blocking case with a specific message      | `vv.Application.Tests` |
| T8.3 | **He–Litterman fixture POSTed over HTTP reproduces the golden numbers** | `vv.Api.Tests`         |
| T8.4 | Singular Σ ⇒ 422, not 500                                               | `vv.Api.Tests`         |
| T8.5 | Malformed input ⇒ 400 with field-level detail                           | `vv.Api.Tests`         |
| T8.6 | Missing `ReturnBasis` in JSON ⇒ 400 (not a silent `Daily` default)      | `vv.Api.Tests`         |

T8.3 is not redundant with T2. It is the only test covering JSON serialization of
`decimal`, dictionary ordering across the wire, and model binding — the layer
where a numerically perfect engine still delivers wrong numbers to the UI.

### T9 — Meta-verification: does the suite actually catch bugs?

Everything above assumes these tests would fail if the code were wrong. That
assumption is itself testable. See
[model-verification.md M2](./specs/model-verification.md#m2--mutation-testing--does-the-suite-actually-catch-bugs).

| #    | Test                                                                                                                                                                                                                                                                         | Cadence                   |
| ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| T9.1 | **Mutation suite**: every seeded fault (transposed P, swapped Σ/Σ_p, withdrawn Ω formula, dropped τ, sign flip on `Q−PΠ`, `AssetUniverse` off-by-one, skipped PSD repair, inverse-vol in place of ERC, wrong HRP linkage, unrenormalized rounding) is caught by a named test | scheduled, not per-commit |
| T9.2 | **Reproduction drill**: a signed result ≥ 6 months old, rebuilt at its recorded `EngineVersion` sha and replayed from its `InputHash`, produces byte-identical output                                                                                                        | quarterly                 |

**A mutation that survives is a hole in the suite, and the fix is a new test.**
Every genuine defect found in production becomes a permanent mutation.

T9.2 measures the claim the product is actually sold on. T5.8 proves determinism
across three platforms _today_; it proves nothing about the same platform after a
compiler upgrade or a dependency bump — which is exactly the span an audit
covers.

### Coverage

`vv-portfolio-core` holds a higher bar than the repo default — ≥95% line coverage
(`cargo llvm-cov`) — with the explicit note that **coverage is a floor, not
evidence of numerical correctness.** T2 and T3 are the evidence, and T9.1 is the
evidence that T2 and T3 work.

**Analytic-identity tolerances are derived, not chosen.** `tol = max(c·κ(Σ)·ε, floor)`
with κ recorded in each fixture header, per
[M4](./specs/model-verification.md#m4--tolerances-are-conventions-not-derivations).
A fixed constant is unmeetable on an ill-conditioned fixture and vacuously loose
on a trivial one. Golden vectors from published tables keep their absolute
printed-unit tolerances.

---

## 8. Sequenced build order

Each phase has a binary exit criterion. No numbered phase starts before the
previous exits — **Phase 0b is the deliberate exception**: it is independent
housekeeping and gating solver work on it would be make-work.

| Phase  | Work                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Exit criterion                                                                                                                                                                                                                                                                                              |
| ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **0**  | Ratify [ADR-0001](./adr/0001-black-litterman-model-conventions.md) (model conventions), [ADR-0003](./adr/0003-portfolio-model-strategy.md) (comparison harness + `novelty: commodity` on BL) and **[ADR-0004](./adr/0004-allocation-model-abstraction.md) — which must be accepted before Phase 1, because retrofitting the three-stage split after BL is built means rewriting BL**. **No code.**                                                                                                                                                                                                                                           | Sign-off on D1 (Ω default + withdrawal of `model.md:161`), D2 (Σ vs Σ_p — _the one to argue about_), D3, D5; on the model roster; and on the abstraction                                                                                                                                                    |
| **0b** | **Housekeeping** ([§11](#11-housekeeping)) — H1 triage of the stale `vv.Application.Tests`, H2 dedupe of the case-variant doc trees. **Neither blocks solver work; run them in parallel.** H1 must land before Phase 7, H2 whenever convenient                                                                                                                                                                                                                                                                                                                                                                                               | H1: `vv.Application.Tests` compiles and runs in CI. H2: one `financial-models` tree, no broken inbound links                                                                                                                                                                                                |
| **1**  | `crates/vv-portfolio-core` + `vv-portfolio-ffi` skeleton; **the ADR-0004 three-stage traits and the `AssetUniverse`/`Covariance` newtypes**; `src/vv.Analytics` bindings; DTO diff (§3.4); validator; decimal seam; **`schemars` → C# type generation**; CI build matrix + NuGet packaging; **`claims-gate` seeded with `docs/CLAIMS.md`**                                                                                                                                                                                                                                                                                                   | `dotnet build` green on all RIDs; **T5 and T6 pass** (incl. T5.8 cross-RID determinism); T4.3/T4.6 pass; generated C# matches committed C#; `claims-gate` green; **a pipeline with a mismatched `requires()` is rejected before execution, not silently ignored**                                           |
| **2**  | E1 + E3 + E2, view-matrix builder, Ω `ProportionalToPrior` + `ConfidenceScaled`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | T1.1, T1.6, T1.7, T1.12–T1.14, T1.16, T2.1 pass                                                                                                                                                                                                                                                             |
| **3**  | Stage-1 unconstrained weights; posterior covariance                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | **T1 complete, T2.1–T2.3 pass, T3 passes** ⇐ _[honesty gate](#9-honesty-gate--when-claims-may-change)_                                                                                                                                                                                                      |
| **4**  | `IdzorekTilt` (Brent root-find) + `Explicit` Ω; `CovarianceEstimator` trait + sample + Ledoit–Wolf                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | T2.4, T2.5 pass; Ledoit–Wolf matches sklearn fixture                                                                                                                                                                                                                                                        |
| **5**  | Clarabel API spike → stage-2 budget closed form → stage-3 QP                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | T7 complete                                                                                                                                                                                                                                                                                                 |
| **5a** | **Benchmark allocators**: 1/N, market-cap ([ADR-0003](./adr/0003-portfolio-model-strategy.md))                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | EW._, MC._ and the `Equilibrium ∘ MVO ≡ MarketCap` identity pass                                                                                                                                                                                                                                            |
| **5b** | **Risk-based allocators**: minimum variance, ERC (Clarabel exponential cones), maximum diversification, **HRP**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | MV._, ERC._, MD._, HRP._ pass; [identity lattice](./specs/allocation-models.md#composition-identity-lattice) green; HRP linkage tie-break documented and deterministic                                                                                                                                      |
| **6**  | Attribution (D5), tilt magnitude, implied confidence, trade recommendations, computable metrics, diagnostics block                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | Attribution non-additivity documented in the API contract; `MaxDrawdown`/`VaR` null, not 0                                                                                                                                                                                                                  |
| **6b** | **Comparison harness** — `Vec<Pipeline>` over one context; model-vs-model attribution reusing the D5 machinery. Michaud decorator. **Tier B approaches needing no forward data: [B13](./specs/model-verification.md#b13--stability-capacity-and-implementability--no-forward-data-required) stability/capacity, [B11](./specs/model-verification.md#b11--synthetic-data-with-known-ground-truth) synthetic ground truth, [B17](./specs/model-verification.md#b17--ablation--which-component-is-actually-contributing) ablation. Start [B16](./specs/model-verification.md#b16--shadow-mode--the-only-truly-out-of-sample-test) shadow mode** | All pipelines emitted or none (B7); Michaud seeded and bit-deterministic (MR.2); non-convex constraints rejected under averaging (MR.5); **BL's stability elasticity measured against MVO — its actual claim**; DeMiguel 1/N regularity reproduced on synthetic data; shadow-mode recording live and signed |
| **7**  | MediatR command + handler + DI + controller + OpenAPI                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | T8 complete                                                                                                                                                                                                                                                                                                 |
| **8**  | `vv-landing` cutover (separate repo, separate PR)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Fixture reachable only behind the flag; CI check enforces it                                                                                                                                                                                                                                                |
| **9**  | _Deferred_ — ML shrinkage covariance. Needs its own spike: `ort` (ONNX) is **release-candidate only** on crates.io as of 2026-08-12                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | Out of scope for this plan                                                                                                                                                                                                                                                                                  |

**Phase 0 is not overhead.** Five of its six decisions change the numbers.
Building first and deciding later means the golden vectors get chosen to match
whatever was built — which is how a model passes its own tests and fails against
the literature.

**Reviewer note for Phases 2–5:** these PRs need a reviewer who can check the
mathematics, not only the code. A conventional review will pass a correct-looking
implementation of the wrong equation.

---

## 9. Honesty gate — when claims may change

The decks currently state this correctly.
`veritasvault-corporate-deck.html:240` marks Black-Litterman allocation
`Roadmap`; line 278 says roadmap items _including the Black-Litterman engine
itself_ are unbuilt. **That stays accurate until the conditions below are met.**

| Milestone                                         | Claim it licenses                                                                                                                    | Claim it does **not** license                                |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------ |
| Phase 3 exit: T1 + T2.1–T2.3 + T3 green on `main` | "Classical Black-Litterman posterior returns and unconstrained optimal weights, numerically validated against He & Litterman (1999)" | anything about constraints, ML covariance, or production use |
| Phase 5 exit                                      | adds constrained allocation                                                                                                          | —                                                            |
| Phase 7 exit                                      | adds "exposed via API"                                                                                                               | —                                                            |
| Phase 8 exit                                      | adds "live in the product"                                                                                                           | —                                                            |
| Phase 9                                           | **only then** may "ML-enhanced covariance estimation" (`veritasvault-investor-overview.html:346`, `:1035`) move off Roadmap          | —                                                            |

1. **Passing tests written by the same session that wrote the solver is not
   validation.** The gate is specifically T2 (external literature) and T3
   (independent implementation) — evidence from outside the codebase.
2. **A green CI run on a branch is not the gate.** It is green on `main`.
3. **"ML-enhanced covariance estimation" is Phase 9.** Shipping classical BL does
   not license that claim; the two are separate sentences in the investor
   overview for good reason.

### The gate is mechanical, not a promise

A prose commitment not to overstate decays the moment someone edits a deck in a
hurry before a meeting. Encode it instead.

`docs/CLAIMS.md` holds a machine-readable claim ledger — one row per external
capability claim, each carrying the deck file and line it appears in, its current
state (`roadmap` | `live`), and the test IDs that gate promotion:

Each claim carries **three independent axes**, because the gate above catches
overclaiming _completion_ but not overclaiming _novelty_ — and a claim can be
entirely true and still cost credibility. See
[ADR-0003](./adr/0003-portfolio-model-strategy.md#consequence-claims-need-three-axes-not-one).

```yaml
- claim: black-litterman-allocation
  appears_in: [docs/investor/veritasvault-corporate-deck.html:240]
  correctness: unbuilt # gated by T1.*, T2.1-T2.3, T3
  novelty: commodity # 1992, textbook, three OSS implementations
  performance: unevaluated # gated by the Tier B protocol
- claim: ml-enhanced-covariance
  appears_in: [docs/investor/veritasvault-investor-overview.html:346]
  correctness: unbuilt # gated by phase-9; no test exists yet
  novelty: plausible # needs a written defensibility argument
  performance: unevaluated
- claim: audited-reproducible-allocation
  correctness: unbuilt # gated by T5.8, T5.9, InputHash
  novelty: defensible # deterministic, signed, versioned — the real one
  performance: not-applicable
```

| Axis          | Gated by                                                                                                       | Default       |
| ------------- | -------------------------------------------------------------------------------------------------------------- | ------------- |
| `correctness` | [Tier A](./specs/model-verification.md#tier-a--numerical-correctness) green on `main`                          | `unbuilt`     |
| `novelty`     | a written, reviewed defensibility argument                                                                     | `commodity`   |
| `performance` | the full [Tier B](./specs/model-verification.md#tier-b--model-validity) protocol — **never a single backtest** | `unevaluated` |

CI job `claims-gate` fails when either half of the contract is broken:

- a claim's state exceeds its evidence — `correctness: verified` without green
  gating tests, or `performance: consistent` without the pre-registration commit,
  full-roster results, deflated Sharpe and bootstrap intervals — **or**
- a deck line no longer carries the qualifier the ledger still requires.

The second direction is the one that matters. It catches the actual failure mode
— a deck edited before a meeting without the ledger being touched — rather than
the theoretical one.

**The axes are independent and normally disagree.** The expected steady state for
Black-Litterman is `correctness: verified, novelty: commodity, performance:
unevaluated`, and that is a perfectly good place to be: implemented correctly,
not proprietary, not yet entitled to a performance claim. All three are
defensible. Quietly promoting one on the evidence of another is not.

---

## 10. Decisions summary

| Decision              | Choice                                                                   | Rationale                                                                                                           |
| --------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------- |
| Numeric runtime       | **Rust core, P/Invoke** ([ADR-0002](./adr/0002-numeric-core-runtime.md)) | .NET has no maintained QP solver; avoids owning Goldfarb–Idnani; all deps permissive-licensed                       |
| Linear algebra        | `nalgebra` 0.35.0                                                        | mature, documented; speed irrelevant at n ≤ 50                                                                      |
| QP                    | `clarabel` 0.11.1                                                        | Rust-native reference implementation; Python/Julia are wrappers over it                                             |
| Numeric type          | `f64` in core, `decimal` at wire                                         | inputs are estimates with ~2 significant figures; `double` gives 15–16                                              |
| Posterior formula     | E3 in production, E2 as cross-check                                      | inverts k×k not n×n; well-posed at Ω=0; disagreement is a bug signal                                                |
| Inversion             | `Cholesky::solve`, never explicit inverse                                | faster, more accurate, and failure _is_ the PSD check                                                               |
| FFI shape             | one JSON call per solve                                                  | payload ~20 KB; avoids manual struct marshalling, the bug class that corrupts silently                              |
| Ω default             | `ProportionalToPrior`, 3 alternatives behind a selector                  | spec is self-contradictory (D1); this form reproduces the literature                                                |
| Optimizer risk matrix | Σ by default, Σ_p available                                              | B3 exact under Σ; **most likely decision to be overturned**                                                         |
| Covariance wire type  | keep `List<List<decimal>>` + validator + mapper                          | fine as JSON, unusable for compute; `Assets` is canonical ordering                                                  |
| ML shrinkage          | Phase 9, behind `CovarianceEstimator`                                    | classical Ledoit–Wolf is enough to ship                                                                             |
| QP cross-check        | `osqp` dev-only, feature-gated, one CI platform                          | two independent solvers agreeing, where no closed-form oracle exists                                                |
| FFI type maintenance  | `schemars` → JSON Schema → C# codegen                                    | hand-mirrored types drift silently and surface as wrong numbers, not compile errors; `typeshare` does not target C# |
| Versioning            | `schema_version` separate from `abi_version`                             | they change for different reasons; conflating forces needless ABI bumps                                             |
| Audit binding         | `InputHash` (SHA-256 of FFI request bytes) + `EngineVersion`             | makes a signed result independently reproducible, per `BlackLitterman-Reference.md:22`                              |
| Determinism           | pure-Rust path pinned, proven cross-RID in CI                            | signing requirement makes bit-identical output a correctness constraint                                             |
| Honesty gate          | mechanical `claims-gate` CI job over `docs/CLAIMS.md`                    | a prose commitment decays; a build failure does not                                                                 |

---

## 11. Housekeeping

Two findings from the codebase survey. Both land in Phase 0b, before solver work.

### H1 — `tests/vv.Application.Tests` is stale, not merely unwired

It has two source files, **no `.csproj`, and no solution entry** — so it does not
run today. Adding a csproj would **not** fix it, because both files reference a
source shape that no longer exists:

- `Services/Decorators/ValidationMarketDataServiceDecoratorTests.cs` imports
  `vv.Application.Services.Decorators` and uses `IMarketDataService<T>`.
  Verified: the decorator lives in `vv.Api.Services.Decorators`
  ([ValidationMarketDataServiceDecorator.cs:10](src/vv.Api/Services/Decorators/ValidationMarketDataServiceDecorator.cs:10)),
  the generic interface is declared in `src/vv.Api/Services/MarketDataService.cs`,
  and `vv.Application`'s `IMarketDataService` is **non-generic**
  ([IMarketDataService.cs:10](src/vv.Application/Services/IMarketDataService.cs:10)).
- `Services/MarketDataServiceTests.cs` constructs `MarketDataService(repository, validator)`;
  the actual constructor is `MarketDataService(IMarketDataRepository, ILogger<MarketDataService>)`
  ([MarketDataService.cs:19](src/vv.Application/Services/MarketDataService.cs:19)).

Work: move the decorator test to `vv.Api.Tests` and fix its usings; rewrite the
service test against the current constructor; then add the csproj and the
solution entry. **This must be done before Phase 7** or the new handler and
validator tests will silently not execute either.

### H2 — Case-variant duplicate doc trees

`git ls-files` returns **19 tracked paths** across
`AI/FinancialModels/` and `AI/financial-models/` — nine filenames duplicated,
plus `financial-models/` holding both `portfolio-optimization.md` and
`PortfolioOptimization.md`.

**All nine cross-tree pairs are byte-identical** (verified by comparing git blob
hashes, which is independent of what the working tree happens to contain). So
deduplication is lossless — no merge required.

On a case-insensitive filesystem only one of each pair can exist in the working
tree, so edits to the "wrong" path are silently lost and the pair drifts apart.
The trees are identical _today_; that is not stable.

Procedure:

1. Scan inbound links first — `git grep -l "FinancialModels"` — including the
   appendix of this document and `Crosscutting/` references.
2. Keep `financial-models/` (kebab-case matches the dominant convention in
   `Domains/AI/`: `financial-ai/`, `black-litterman-ai/`, `time-series/`).
3. Check whether `financial-models/portfolio-optimization.md` and
   `financial-models/PortfolioOptimization.md` are also identical — **not yet
   verified**; only the cross-tree pairs were compared.
4. `git rm --cached` the exact `FinancialModels/` paths, fix links, commit.

Verified with:

```bash
git ls-files "src/vv.Domain/Docs/Domains/AI/FinancialModels/" "src/vv.Domain/Docs/Domains/AI/financial-models/"
```

---

## Appendix — spec documents consulted

Classical tree (`Asset/portfolio-management/black-litterman/`): `index.md`,
`black-litterman-overview.md`, `black-litterman-model.md`,
`black-litterman-views.md`, `black-litterman-implementation.md`,
`black-litterman-validation.md`.

AI tree: `bl-ai-overview.md`, `bl-ai-components.md`, `bl-ai-implementation.md`,
`bl-ai-reference.md`, the covariance/ML-shrinkage subtree (Phase 9 scope),
`BlackLitterman-Overview.md`, `BlackLitterman-Implementation.md`,
`BlackLitterman-Reference.md`, `covariance-estimation-methods.md`,
`covariance-estimation-reference.md`.

Contracts: `Crosscutting/Contracts/domain-interfaces.md` — declares
`GetBlackLittermanParametersAsync` and `IPortfolioOptimizationService`, neither
implemented.
