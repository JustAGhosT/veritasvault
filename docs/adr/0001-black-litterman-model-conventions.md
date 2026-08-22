# ADR-0001 — Black-Litterman model conventions

|            |                                                                                             |
| ---------- | ------------------------------------------------------------------------------------------- |
| **Status** | **Proposed — requires domain sign-off before Phase 1 begins**                               |
| Date       | 2026-08-12                                                                                  |
| Supersedes | conflicting statements in four spec documents (see [§7](#7-spec-errata-issued-by-this-adr)) |
| Related    | [Implementation plan](../black-litterman-implementation-plan.md)                            |

## Context

The Black-Litterman specification is 45 documents deep and mathematically
detailed, but it is **self-contradictory in three places and silent in three
more**. Every one of these gaps changes the numbers a solver produces. A solver
built before they are settled would produce plausible output that cannot be
validated against the literature, and the golden vectors would end up chosen to
match whatever was built.

This ADR resolves all six. Decisions D1, D2 and D3 are modelling judgements and
are the ones a domain reviewer should scrutinise; D4, D5 and D6 are engineering
policy.

**Nothing here is implemented.** This document exists so that Phase 1 starts
from a decided contract.

---

## D1 — View uncertainty (Ω) calibration

### Problem

Four formulas appear across the specs for the same quantity, giving four
different answers:

| Source                                  | Formula                          | Ω at c=1           | Ω at c=0 |
| --------------------------------------- | -------------------------------- | ------------------ | -------- |
| `black-litterman-model.md:158`          | Ω = diag(P(τΣ)Pᵀ)                | n/a (no c)         | n/a      |
| `black-litterman-model.md:161`          | Ω_ii = (1/c_i)(PΣPᵀ)\_ii         | **(PΣPᵀ)\_ii ≠ 0** | ÷0       |
| `black-litterman-views.md:148`          | Ω_ii = (PΣPᵀ)\_ii·(1−c_i)/c_i    | 0                  | ÷0       |
| `black-litterman-implementation.md:226` | Ω_ii = (P(τΣ)Pᵀ)\_ii·(1−c_i)/c_i | 0                  | ÷0       |

`black-litterman-model.md:161` is **provably wrong against the spec's own
validation requirements**: at c=1 it leaves Ω non-zero, so the view does not
bind and `Pμ_BL ≠ Q`, contradicting the sanity check at
`black-litterman-validation.md:36`.

### Decision

Implement four named methods behind an explicit `OmegaCalibration` selector.
Default `ProportionalToPrior`.

**1. `ProportionalToPrior` (default)**

```
Ω = diag( P (τΣ) Pᵀ )
```

He & Litterman's original. Carries no confidence input — every view is held at
the uncertainty the prior itself implies for that combination of assets. This is
the default because it is the form the published golden vectors are computed
under; changing the default would make the literature reproduction fail for a
reason that is not a bug.

**2. `ConfidenceScaled`**

```
Ω_ii = ( P (τΣ) Pᵀ )_ii · (1 − c_i) / c_i        c_i ∈ (0, 1]
```

`black-litterman-implementation.md:226` is adopted as the confidence-bearing
form. It satisfies both required limits: c→1 gives Ω→0 (view binds exactly,
requirement B2) and c→0 gives Ω→∞ (equilibrium prevails, requirement B4).

Endpoint handling — **not** clamping to ε:

- **c_i = 0 ⇒ drop the view's row from P and Q entirely.** This is exactly
  equivalent to the Ω→∞ limit and is numerically clean, where clamping is
  neither. A view with zero confidence is a view the user has switched off.
- **c_i = 1 ⇒ Ω_ii = 0**, which is well-posed in E3 and undefined in E2
  (Ω⁻¹). See D6: E3 is the production path partly for this reason.
- All views at c=0 ⇒ k=0 ⇒ μ_BL = Π. Consistent with B1.

**3. `IdzorekTilt`** (Phase 4)

Idzorek's confidence method: c_i is the fraction of the way from the prior
weights to the 100%-confidence weights that view i should actually move the
portfolio.

```
w₁₀₀,ᵢ  = optimal weights with view i at Ω_ii = 0, others unchanged
w_target,ᵢ = w_mkt + c_i · (w₁₀₀,ᵢ − w_mkt)
solve for Ω_ii  such that  w(Ω_ii) = w_target,ᵢ
```

**Implement by 1-D root-finding (Brent on log Ω_ii), not by Idzorek's printed
closed-form approximation.** The weight displacement is monotone in Ω_ii, so
bracketing convergence is guaranteed. This choice matters for two reasons: the
closed form is an approximation whose errata are part of why Walters (2014) is in
the spec's own reference list, and root-finding is **self-validating** — the test
is simply whether the resulting weights hit the target tilt, with no dependence
on a printed table.

**4. `Explicit`**

Caller supplies `InvestorViewDto.ViewVariance` per view. Escape hatch, and the
only method that permits a full non-diagonal Ω later. Required for backtests that
calibrate Ω from historical forecast error (`black-litterman-views.md:131`).

### Consequence worth knowing: τ cancels

Under both `ProportionalToPrior` and `ConfidenceScaled`, Ω is proportional to τ.
Substituting into E3:

```
τΣPᵀ [ τPΣPᵀ + τK ]⁻¹ (Q − PΠ)  =  ΣPᵀ [ PΣPᵀ + K ]⁻¹ (Q − PΠ)
```

where `K = diag(PΣPᵀ)` or `diag((PΣPᵀ)_ii(1−c)/c)`. **τ cancels exactly, so
μ_BL is invariant to τ under both default methods.** τ still scales the
posterior covariance: `M = τ[Σ⁻¹ + Pᵀ(K)⁻¹P]⁻¹`, so `M ∝ τ`.

Two consequences:

- τ is close to a nuisance parameter in this design. The team should not spend
  calibration effort on it, and a test that varies τ and expects μ_BL to move
  would be asserting the wrong thing.
- Under `Explicit`, Ω does **not** scale with τ and this cancellation does not
  hold. τ matters there.

Both facts become tests (T1.12).

### Rejected

`black-litterman-model.md:161` — contradicts requirement B2. Issued as errata.

---

## D2 — Posterior covariance, and the optimizer's risk matrix

### Problem

`BlackLittermanResultDto.PosteriorCovariance` exists. No spec document defines
it; `BlackLitterman-Overview.md:42` names it and stops. Two conventions are in
circulation and they differ by Σ, which is not a small correction.

Separately, E4 (`black-litterman-model.md:172`) computes weights with **Σ**,
while the He & Litterman derivation that the golden vectors come from uses the
posterior. These are different portfolios.

### Decision

**Return `Σ_p = Σ + M`** as `PosteriorCovariance`, where
`M = [(τΣ)⁻¹ + PᵀΩ⁻¹P]⁻¹`.

M alone is the covariance of the _estimate of the mean_; Σ + M is the covariance
of _returns_, which is what the field name and its consumer (a risk display) mean.

**Optimizer risk matrix is an explicit option, defaulting to Σ** (`RiskMatrixChoice.PriorCovariance`),
with `PosteriorCovariance` available for literature reproduction. The resolved
choice is echoed in the result diagnostics.

### Rationale, and the trade-off a reviewer should weigh

The default follows E4 as written, and it is the only choice under which
requirement B3 holds **exactly**:

```
w* = (λΣ)⁻¹ Π = (λΣ)⁻¹ (λ Σ w_mkt) = w_mkt        exact, to machine precision
```

That exactness is worth a lot — B3 is the cheapest strong correctness test in
the suite, and it degrades under Σ_p. In the no-view case M = τΣ, so
Σ_p = (1+τ)Σ and:

```
w* = (λΣ_p)⁻¹ Π = w_mkt / (1 + τ)
```

Under Σ_p, B3 holds only up to that scale factor — exactly after budget
normalization. This is the familiar result that unconstrained BL weights come out
scaled by 1/(1+τ) against the market book.

**This is the decision in this ADR most likely to be overturned, and it is a
genuine modelling judgement.** The Bayesian-consistent argument favours Σ_p: if
you are uncertain about μ, that uncertainty belongs in the risk term. The
argument for Σ is that it is what the spec says, what most practitioner
implementations do, and what makes B3 exact. Because the choice is exposed as an
option and echoed in diagnostics, flipping the default later is a one-line change
plus a golden-vector re-baseline — not a rewrite.

**Every golden-vector fixture states which convention it assumes in its header.**
Most failures to reproduce this model are convention mismatches, not arithmetic
errors.

---

## D3 — Units and return basis

### Problem

`black-litterman-implementation.md:109-120` annualizes — monthly excess returns,
`cov × 12`. Nothing in `BlackLittermanInputDto` declares the frequency or
annualization state of `CovarianceMatrix`, `EquilibriumReturns`,
`RiskFreeRate`, or the views' `ExpectedReturn`.

A monthly Σ combined with annual views produces a wrong answer with no error, no
warning, and an entirely plausible shape. **This is the single most likely source
of a silently incorrect production result.**

### Decision

Add one required field:

```csharp
public enum ReturnBasis { Daily, Weekly, Monthly, Quarterly, Annual }
```

Meaning: _every rate and every covariance entry in this payload is expressed per
this period._ A single enum rather than a frequency plus an `IsAnnualized` flag,
because two fields admit contradictory combinations and one does not.

Rules:

1. `ReturnBasis` is **required**. There is no default — a default here is a
   silent assumption, which is the failure mode being eliminated.
2. **The engine does not convert.** It computes in the declared basis and echoes
   it on the result. Automatic conversion invites a compounding error that is
   invisible at the boundary.
3. `RiskFreeRate` and every view's `ExpectedReturn` are on the same basis. The
   validator cannot verify this — it is a documented caller contract, reinforced
   by a plausibility warning (see D6).

### Excess vs. total return, and what `RiskFreeRate` is for

**The engine works entirely in excess-return space.** Π, Q, and μ_BL are all
excess returns; Σ is the covariance of excess returns. This is consistent
throughout the specs.

`RiskFreeRate` therefore has no role in the core computation. It is used only to
report total expected return alongside excess (`total = excess + rf`) in the
result metrics. Documented as such, so nobody later "fixes" the Sharpe ratio by
subtracting it twice — with excess returns, `Sharpe = wᵀμ / √(wᵀΣw)` is already
correct with no rf term.

---

## D4 — Equilibrium returns: input or derived

### Problem

`EquilibriumReturns` is an input field, but E1 derives Π from λ, Σ and w_mkt.
When both are present and disagree, behaviour is undefined.

### Decision

1. `EquilibriumReturns` non-empty ⇒ **use it verbatim**, skip E1.
2. Empty ⇒ derive via `Π = λΣw_mkt`.
3. When both are available, compute E1 anyway and compare. If
   `‖Π_supplied − Π_derived‖₂ / ‖Π_derived‖₂ > 0.10`, emit a diagnostic warning.
   Do not fail — a caller may legitimately supply a Π from a different model —
   but a caller passing a stale vector should find out.
4. `Diagnostics.EquilibriumSource ∈ { Supplied, Derived }`, always populated.

Rationale: silent precedence is the problem. Explicit precedence plus a
divergence warning keeps both use cases open while making the choice visible in
the audit record that `BlackLitterman-Reference.md:22` requires.

---

## D5 — Definitions for the undefined result fields

### Problem

`TiltMagnitude`, `ViewImpactDto.ImpactScore`, `ImpliedConfidenceLevel`,
`ImpliedRiskAversion`, `ReturnContribution` and `RiskContribution` appear in the
result DTO. **None of the six is defined anywhere in the 45 specification
documents** — verified by
grepping both trees for `tilt`, `implied confidence`, `view impact` and
`attribution`. They are UI-shaped fields invented ahead of the mathematics.
Without definitions the engine emits a number for each and the number means
nothing.

### Decision

All attribution is **leave-one-out**, computed with the _same optimizer and the
same constraints_ as the main solve. Attribution computed under a different
constraint set is incoherent with the portfolio it claims to explain.

Notation: `w*` = final weights; `w₍₋ᵢ₎` = weights with view i removed;
`w₁₀₀,ᵢ` = weights with view i at Ω_ii = 0 and all others unchanged;
`Δᵢ = w* − w₍₋ᵢ₎`; `dᵢ = Q_i − P_iΠ` (how much more bullish view i is than
equilibrium on its asset combination).

**`TiltMagnitude`**

```
TiltMagnitude = ‖ w* − w_mkt ‖₁
```

Sum of absolute weight deviations from the neutral book. Note for the UI: this is
**twice** one-way turnover when both books are fully invested. Label it
"total absolute tilt", not "turnover".

**`ViewImpactDto.ImpactScore` ∈ [−1, 1]**

```
ImpactScoreᵢ = sign( dᵢ · (P_i Δᵢ) ) · ‖Δᵢ‖₁ / max(‖w* − w_mkt‖₁, ε)     clamped to [−1,1]
```

Magnitude is view i's share of the total tilt. Sign is positive when the
portfolio moved _in the direction the view argued for_ and negative when the
view was overruled by the other views and the constraints — which is genuinely
informative and is the case a user most wants surfaced.

**These scores do not sum to 1.** Views interact; leave-one-out effects are not
additive. This must be stated in the API documentation, because the obvious UI
for a set of scores is a pie chart and a pie chart here would be a lie.

**`ImpliedConfidenceLevel`** — keyed by **`ViewId`** (the key set is unstated in
the DTO; this fixes it):

```
ImpliedConfidenceᵢ = ‖ w* − w₍₋ᵢ₎ ‖₁ / max(‖ w₁₀₀,ᵢ − w₍₋ᵢ₎ ‖₁, ε)     clamped to [0,1]
```

Idzorek's implied confidence, generalized to multiple views: the tilt view i
actually achieved as a fraction of the tilt it would achieve at full confidence.
Under `IdzorekTilt` this should return approximately the `Confidence` that was
input — **which makes it a self-consistency test** (T2.5).

**`ReturnContribution` / `RiskContribution`**

```
ReturnContributionᵢ = w*ᵀ μ_BL      − w₍₋ᵢ₎ᵀ μ₍₋ᵢ₎
RiskContributionᵢ   = √(w*ᵀ Σ w*)   − √(w₍₋ᵢ₎ᵀ Σ w₍₋ᵢ₎)
```

Deltas, not shares. Also non-additive; documented as such.

**`ImpliedRiskAversion`** — _missed in the first pass of this ADR; it is a sixth
undefined result field, not a fifth._

```
λ_implied = ( w_mktᵀ Π ) / ( w_mktᵀ Σ w_mkt )
```

This is not an invention: it is exactly the spec's own calibration formula
`λ = (E(R_m) − r_f) / σ_m²` (`black-litterman-model.md:138`) expressed in
quantities the engine already holds — `w_mktᵀΠ` **is** the market excess return
and `w_mktᵀΣw_mkt` **is** the market variance.

It has a useful dual role:

- When Π is **derived** (E1), it returns the input λ _exactly_, since
  `w_mktᵀ(λΣw_mkt) / w_mktᵀΣw_mkt = λ`. That makes it a free self-consistency
  check on the whole equilibrium path — test T1.17.
- When Π is **supplied** (D4), it reports what λ the caller's equilibrium vector
  actually implies, which is precisely the diagnostic a caller passing an
  external Π wants.

**`TradeRecommendations`**

```
TradeRecommendation[a] = w*[a] − CurrentHoldings[a]     where |·| ≥ MinimumTradeSize
```

If `CurrentHoldings` is empty, `TradeRecommendations` is **empty** and a
diagnostic says why. Emitting `w*` as if it were a trade list would imply a full
liquidate-and-rebuild that the caller never described.

### Cost

`2k + 1` solves total (k for leave-one-out, k for the 100%-confidence variants,
1 for the main solve). k is typically 1–5. Negligible, including with the QP in
the loop.

---

## D6 — Numerical policy

### Decision

**Production posterior path is E3** (the covariance form,
`black-litterman-model.md:130`):

```
μ_BL = Π + τΣPᵀ [ τPΣPᵀ + Ω ]⁻¹ (Q − PΠ)
```

It inverts a k×k matrix (k ≤ ~5) rather than two n×n matrices, and it is
well-posed at Ω = 0, which E2 is not. **E2 is implemented anyway and asserted to
agree to 1e-10** — two independent derivations of the same quantity is the
cheapest strong correctness signal available on this problem.

**Never form an explicit inverse.** Every `⁻¹` in this ADR is implemented as
`Cholesky.Solve`. It is faster, more accurate, and Cholesky _failing_ is the
positive-definiteness check.

**PSD repair.** `black-litterman-implementation.md:367` proposes clipping
eigenvalues at an absolute `1e-6`. This is rejected as scale-dependent: for daily
return covariances, variances are order 1e-4 and an absolute 1e-6 floor is a
material distortion rather than a repair. Use a **relative** floor:

```
λᵢ ← max( λᵢ , 1e-10 · λ_max )
```

Reject outright if `λ_min < −1e-8 · λ_max` — that is not a rounding artifact but
a genuinely indefinite input, and repairing it silently would be fabricating a
covariance the caller did not supply. Set `Diagnostics.PsdRepairApplied` whenever
any eigenvalue is clipped.

**Conditioning.** Warn at `κ(Σ) > 1e10`; reject at `κ(Σ) > 1e14`. Condition
number is always reported in diagnostics.

**Thresholds are configurable but have defined defaults.** The defaults above are
policy, not physics; they are named constants, not literals scattered through the
solver.

**Plausibility warnings** (diagnostics only, never failures) — these catch the
D3 unit error, which no validator can detect structurally:

- any `|Π_i| > 1.0` on an `Annual` basis, or `> 0.2` on `Monthly`
- any diagonal `Σ_ii` implying annualized volatility `> 300%`
- `Σ` diagonal spanning more than 6 orders of magnitude

**decimal/double boundary** — full rules in the implementation plan §3.2.
Summary: `double` inside, `decimal` at the wire, one conversion seam, outbound
rounding at scale 10 with `MidpointRounding.ToEven`, weights renormalized after
rounding so they sum to exactly `1.0m`, and `double.IsFinite` guards so no
non-finite value is ever converted.

---

## 7. Spec errata issued by this ADR

Pointer notes are added in place to the affected documents. No spec content is
deleted — the errata note names this ADR and states what supersedes what.

| Document                            | Location                                          | Errata                                               |
| ----------------------------------- | ------------------------------------------------- | ---------------------------------------------------- |
| `black-litterman-model.md`          | §Parameter Calibration → View Uncertainty (~:153) | option 2 is withdrawn — contradicts validation.md:36 |
| `black-litterman-model.md`          | §Optimal Portfolio Weights (~:168)                | risk matrix is an explicit choice; see D2            |
| `black-litterman-views.md`          | §Confidence Scaling (~:139)                       | superseded by D1 `ConfidenceScaled` (τ included)     |
| `black-litterman-implementation.md` | `calibrate_omega` (~:204)                         | adopted as canonical; endpoint handling added        |
| `black-litterman-implementation.md` | `ensure_positive_definite` (~:365)                | absolute eigenvalue floor replaced by relative       |

---

## Consequences

**Positive.** Phase 1 starts from a decided contract. Four new exact invariants
fall out of the analysis and become tests: τ-invariance of μ_BL under both
default Ω methods, `M ∝ τ`, `Σ_p = (1+τ)Σ` with no views, and
`w* = w_mkt/(1+τ)` under the Σ_p risk matrix with no views. Each is exact and
cheap, and none depends on any literature table.

**Negative.** Three input fields are added and `BlackLittermanConstraintDto.Type`
changes from `string` to an enum. This is safe **only because nothing consumes
these DTOs yet** — verified: `PortfolioMetricsDto`, `BlackLittermanConstraintDto`,
`InvestorViewDto` and `ViewImpactDto` have no references outside their own
declaration file. **That window closes the moment the API ships**, which is an
argument for landing the DTO changes early rather than after Phase 7.

**Open.** D2's default is the decision most likely to be revisited; it is
deliberately structured as a flipped default plus a golden re-baseline rather
than a rewrite.

## Sign-off required

- [ ] Ω default and the withdrawal of `model.md:161` (D1)
- [ ] `Σ` vs `Σ_p` as the optimizer risk matrix (D2) — _the one to argue about_
- [ ] Excess-return space and `RiskFreeRate`'s reporting-only role (D3)
- [ ] Attribution definitions, and that the scores are non-additive (D5)
