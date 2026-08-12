# Model verification

> Companion to [allocation-models.md](./allocation-models.md),
> [ADR-0003](../adr/0003-portfolio-model-strategy.md) and
> [ADR-0004](../adr/0004-allocation-model-abstraction.md).
> **No model is implemented. Nothing here has been run.**

## The question is two questions

"How do we verify a model?" conflates two things that need completely different
evidence, and conflating them is how financial software ships confident nonsense:

|            | Question                                   | Answer type                                                                                                                                |
| ---------- | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| **Tier A** | Does the code compute what the paper says? | Deductive. Exact identities, published tables, differential testing. A model either passes or has a bug.                                   |
| **Tier B** | Is the model any good?                     | Inductive, and much weaker. Statistical evidence over a finite history, subject to noise, regime dependence and the analyst's own choices. |

**Tier A can be settled. Tier B cannot.** A model can be numerically perfect and
empirically useless, and a model that backtests beautifully can be a data-mining
artifact. The two tiers gate different claims and must never be substituted for
one another.

This document is longer on Tier B than Tier A, because Tier A is mostly
mechanical and Tier B is where the danger is.

---

## Tier A — numerical correctness

Six layers, cheapest and strongest first. All run in CI on every commit.

### A1 · Per-model exact invariants

Each model's invariants are specified in
[allocation-models.md](./allocation-models.md): EW.1–3, MC.1–3, MV.1–5, EQ.1–3,
ERC.1–6, MD.1–5, HRP.1–5, MR.1–5, EP.1, plus B1–B5 and T1.12–T1.17 for
Black-Litterman.

These are analytic identities, not sampled comparisons. `MinVar(σ²I) ≡ 1/N` is
either exactly true or the implementation is wrong.

Implemented with `proptest` over generated inputs rather than fixed examples, so
the invariant is asserted across the input space rather than at points someone
chose.

### A2 · The composition identity lattice

The [identity lattice](./allocation-models.md#composition-identity-lattice)
connects independently implemented models to each other:
`Equilibrium ∘ MVO ≡ MarketCap`, `ERC(diagonal Σ) ≡ InverseVolatility`,
`EntropyPooling(Gaussian, mean views) ≡ BlackLitterman`, and six more.

**This is the strongest layer against independent bugs, and it is nearly free.**
A bug in one model surfaces as a broken identity against another, so the models
cross-check each other. It exists only because
[ADR-0004](../adr/0004-allocation-model-abstraction.md) decomposed models into
composable stages; a design where each model is a black box behind its own entry
point cannot express any of it.

**But it is blind to shared errors, and an earlier draft of this document
overstated it by calling it simply "the strongest layer".** Every identity
compares two paths that run through the _same_ `AssetUniverse` ordering, the same
`Covariance` constructor and the same Cholesky wrapper. If the ordering
projection is wrong, `Equilibrium ∘ MVO ≡ MarketCap` still passes — both sides
are wrong identically. The lattice tests that the models agree, not that they are
right.

**A3 and A4 are therefore not optional and the lattice cannot substitute for
them.** Published tables and independent implementations are the only layers that
catch a defect in shared infrastructure, because they were computed by code that
shares none of it.

`ERC.1` deserves specific mention: inverse-volatility weighting is routinely
_mistaken_ for risk parity, and equals it only under uniform correlations. An
implementation that conflates the two passes the easy test (ERC.2) and fails
ERC.1.

### A3 · Golden vectors from published sources

| Model               | Source                                                                  |
| ------------------- | ----------------------------------------------------------------------- |
| Black-Litterman     | He & Litterman (1999) 7-country example; Idzorek (2005) 8-asset example |
| HRP                 | López de Prado (2016) — the paper includes Python source                |
| ERC                 | Maillard, Roncalli & Teïletche (2010) worked examples                   |
| Max diversification | Choueifaty & Coignard (2008)                                            |

The five rules from the implementation plan §7 T2 apply to every golden vector
here, not only to Black-Litterman's:

1. Provenance in the fixture header — paper, year, table, page.
2. **Tolerances in the printed unit.** Published tables give one or two decimals
   in percent. The correct assertion is ±0.05% absolute on returns and ±0.1% on
   weights, not a relative 1e-9. A too-tight tolerance fails for reasons that are
   not bugs, and the reflex response is to loosen it until green — which destroys
   the test.
3. **Nothing is frozen until two independent derivations agree** — the printed
   table _and_ an independent implementation.
4. **Disagreement is a finding, not a nuisance.** Investigate and document before
   freezing. Never adjust the implementation to match a single printed table.
5. Conventions stated in the header. Most reproduction failures in this
   literature are convention mismatches, not arithmetic errors.

### A4 · Differential testing against reference implementations

Seeded pseudo-random problems — `n ∈ [3,30]`, `Σ = AAᵀ + εI` — compared against
Riskfolio-Lib, skfolio and PyPortfolioOpt offline, with inputs and reference
outputs committed as fixtures so CI needs no Python. Max absolute deviation
< 1e-9.

Catches the failure class golden vectors cannot: a bug that is correct on the
literature's specific shapes and wrong elsewhere.

### A5 · Conditioning and failure modes

Per the implementation plan §7 T4, extended across the roster. **The important
addition is that models must fail differently and correctly:** given a singular Σ,
minimum variance and Black-Litterman must fail loudly, while **HRP must succeed**
(HRP.4). A test asserting that all models fail together would be asserting the
wrong thing.

### A6 · Determinism

Cross-RID bit-identity per
[ADR-0002](../adr/0002-numeric-core-runtime.md#cross-platform-bit-determinism-is-a-hard-requirement),
with two model-specific hazards:

- **HRP linkage tie-breaking** — ties are common with near-uniform correlations,
  and unspecified tie-breaking is non-deterministic (HRP.5).
- **Michaud seeding** — an implicit RNG breaks determinism on the first run
  (MR.2).

### Tier A exit

A model is **correct** when A1–A6 pass on `main`. That is a binary, defensible
state, and it is the only thing a `correctness:` claim in `docs/CLAIMS.md` may
assert.

---

## Tier B — model validity

### What can go wrong, and it usually does

| Hazard                   | How it manifests here                                                                                                            |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| **Backtest overfitting** | Seven models on one history: the best in-sample Sharpe is biased upward by selection alone, even if all seven are worthless      |
| **Data snooping**        | Every tuning decision — rebalance frequency, estimation window, τ, universe — is a free parameter searched against the same data |
| **Look-ahead bias**      | Using a covariance estimated over a window that includes the rebalance date                                                      |
| **Survivorship bias**    | Acute in digital assets. A universe of tokens that still exist in 2026 is a universe selected on survival                        |
| **Ignoring costs**       | 1/N looks excellent until monthly rebalancing is costed; BL's tilts are real trades                                              |
| **Regime dependence**    | A single aggregate Sharpe over a period containing one bull market says almost nothing                                           |

**The comparison harness makes all of these worse, not better.** Producing a
ranking is precisely the activity that manufactures authoritative-looking results
out of estimation noise. A comparison harness with a weak Tier B protocol is more
dangerous than no comparison at all —
[ADR-0003](../adr/0003-portfolio-model-strategy.md) records this as the risk it
creates.

### Protocol

**B1 · Pre-register before running — including the thresholds.** Model roster,
universe construction rules, estimation window, rebalance frequency, transaction
cost model, the metrics to be reported, **and the decision rule for each metric**
— all fixed and committed to git _before_ the first backtest, with the commit
hash recorded in the results.

The threshold half is easy to omit and fatal to omit. **A measurement with no
pre-committed decision rule is not a measurement; it is a number that gets
rationalized after the fact**, which is precisely the behaviour the rest of this
protocol exists to prevent. "Report the deflated Sharpe" without "and we require
DSR > x" leaves the judgement exactly where the bias is.

Every threshold is a judgement call and none of the values below is derivable
from first principles — which is the reason to fix them in advance rather than
after seeing the data:

| Metric                     | Pre-committed rule (illustrative — set these deliberately)  |
| -------------------------- | ----------------------------------------------------------- |
| Deflated Sharpe (B5)       | DSR > 0 at 95%, with the trial count stated                 |
| PBO (B10)                  | < 0.5, else the selection process is worse than a coin flip |
| CPCV distribution (B9)     | 25th-percentile path still beats 1/N net of costs           |
| Stability elasticity (B13) | BL's elasticity < MVO's, else BL's central claim fails      |
| View calibration (B14)     | Brier score beats a constant-base-rate forecast             |
| Capacity (B13)             | stated as an AUM figure, not a pass/fail                    |

This is the single most effective measure against p-hacking and it costs nothing.
Any deviation from the pre-registration is reported as a deviation, in the
results, with its reason.

**B2 · Walk-forward only.** The estimation window strictly precedes each
rebalance date. No in-sample fitting, ever. Sketched already at
`black-litterman-validation.md:200`.

**B3 · Universe must include the dead.** Delisted, depegged and abandoned assets
stay in the universe until the date they became untradeable. Omitting them is the
difference between a real result and a flattering one, and in digital assets that
difference is very large.

**B4 · Costs and turnover are part of the metric, not a footnote.** Report
gross and net side by side. A model whose advantage disappears after costs does
not have an advantage.

**B5 · Adjust for the number of trials.** Report the **deflated Sharpe ratio**
(Bailey & López de Prado 2014) alongside the raw one, with the trial count stated
— where trials means every model _and_ every parameter variant examined, not just
the ones reported.

**B6 · Report differences with uncertainty, never point estimates.** Bootstrap
confidence intervals on Sharpe _differences_ between models. Two models 0.1
Sharpe apart over three years are indistinguishable, and presenting them as
ranked is a false statement dressed as a table.

**B7 · Report the whole roster, always.** Never publish only the winner. This is
enforced structurally: the harness emits all pipelines or none.

**B8 · Split by regime.** Report by volatility regime and market direction
alongside the aggregate. A model that wins on average by winning enormously in
one quarter is a different proposition from one that wins consistently, and the
aggregate hides which you have.

---

## Tier B, extended — approaches beyond the backtest

B1–B8 above are the discipline for _when you backtest_. But a walk-forward
backtest is one path through one history, and the industry default of reporting
its Sharpe as though it were an estimate with no variance is the original sin of
this field.

Nine further approaches follow. The useful way to rank them is not by cost or
rigour but by **how hard they are to game** — because the failure mode here is
never an honest analyst reading a number wrong, it is a well-meaning analyst
iterating until the number looks good.

| #     | Approach                                | Gaming resistance               | Needs forward data?     | Cost                       |
| ----- | --------------------------------------- | ------------------------------- | ----------------------- | -------------------------- |
| B16   | Shadow mode / paper trading             | **maximum**                     | yes — quarters          | low compute, high patience |
| B13   | Stability, capacity, implementability   | **very high**                   | **no**                  | very low                   |
| B14   | Calibration testing                     | high, and accumulates           | partial                 | low                        |
| B11   | Synthetic data with known ground truth  | high                            | **no**                  | medium                     |
| B12   | Cross-universe validation               | high                            | no (uses other markets) | medium                     |
| B15   | Reality Check / SPA                     | high — it _corrects_ for gaming | yes                     | low                        |
| B9    | Combinatorially purged cross-validation | medium                          | yes                     | high compute               |
| B10   | Probability of backtest overfitting     | medium                          | yes                     | low, given B9              |
| B17   | Ablation                                | medium                          | either                  | low                        |
| B1–B8 | Single walk-forward backtest            | **lowest**                      | yes                     | medium                     |

**The recommendation that falls out: start at the top, not the bottom.** B11,
B13 and B14 require no forward data at all, so they can run in CI from the day
the models exist — long before any backtest is credible. They belong in Phases
5b and 6b, not in a later research phase.

### B9 · Combinatorially purged cross-validation

Partition the history into `N` blocks, hold out `k` at a time, train on the rest.
This yields `C(N,k)` backtest paths instead of one, and therefore a **distribution
of Sharpe ratios** rather than a point.

Two corrections are mandatory, not optional:

- **Purge** — drop training observations whose estimation window overlaps the
  test blocks. This bites here specifically because covariance is estimated over a
  trailing window, so a naive split leaks future data into the estimator.
- **Embargo** — leave a gap after each test block, because serial correlation
  carries information across the boundary.

Report the distribution. A model whose median path beats 1/N but whose 25th
percentile does not has told you something a single path never would.

_Reference:_ López de Prado, _Advances in Financial Machine Learning_ (2018), ch. 7 & 12.

### B10 · Probability of backtest overfitting

CSCV yields **PBO** — an explicit estimate of the probability that the
configuration selected as best in sample lands below median out of sample.

Crucially, **PBO is reported for the harness as a whole, not per model**, because
the harness _is_ the selection process. Comparing seven models and reporting the
winner is exactly the activity PBO measures the damage of.

_Reference:_ Bailey, Borwein, López de Prado & Zhu (2016), _The Probability of
Backtest Overfitting_, Journal of Computational Finance 20(4).

### B11 · Synthetic data with known ground truth

**The approach that bridges Tier A and Tier B, and the one most under-used.**

Generate returns from a _known_ `(μ, Σ)`. The optimal portfolio is then known
analytically, so the question stops being "did it make money" and becomes
**"does the model recover the known optimum, and how quickly as T grows?"** That
is a deductive question with an exact answer, and no amount of iterating can
p-hack it, because fresh data is free and unlimited.

What to generate:

| Scenario              | Tests                                                          |
| --------------------- | -------------------------------------------------------------- |
| Gaussian, `T ≫ n`     | baseline recovery; every model should converge                 |
| Gaussian, `T ≈ n`     | estimation-error sensitivity — **the entire reason BL exists** |
| `T < n`               | only HRP should survive (HRP.4); the rest must fail loudly     |
| Student-t returns     | robustness to the fat tails BL's Gaussian prior assumes away   |
| Regime-switching      | do models detect or smear the break?                           |
| Correlation → 1 shock | crisis behaviour, constructed rather than hoped for            |

**Reproduce the DeMiguel result as a test.** At realistic `n` and `T`, naive 1/N
should beat mean-variance optimization. If the harness does not show that, the
harness is wrong — this is a known empirical regularity being used as a fixture.

Resample real history with the **stationary block bootstrap** (Politis & Romano 1994) where preserving actual autocorrelation and tail structure matters more
than knowing ground truth.

### B12 · Cross-universe validation — more markets, not more time

History is finite; markets are not. Run the identical roster on equities, FX,
commodities and separate crypto sub-sectors.

This is **genuinely independent data** rather than the same history resampled,
which is what makes it stronger than B9. A model that works on one universe and
nowhere else has told you it was fitted to that universe. Overfitting four
unrelated markets simultaneously is very hard.

It also directly tests the [ADR-0003](../adr/0003-portfolio-model-strategy.md)
concern that BL's market-cap prior is weaker in digital assets than in equities:
if BL's edge over 1/N is materially smaller in crypto than in equities, that
concern is confirmed empirically rather than argued.

### B13 · Stability, capacity and implementability — no forward data required

**The highest value-per-unit-risk in this document**, because none of it requires
forward data and therefore none of it can be data-snooped. Partly specified
already at `black-litterman-validation.md:73-172` and `:352`.

**Stability.** Perturb Σ by a small relative amount and measure the weight
response:

```
elasticity = ‖Δw‖₁ / (‖ΔΣ‖_F / ‖Σ‖_F)
```

A model whose allocation swings on a 1% covariance perturbation is unusable
regardless of its backtest Sharpe. **This tests Black-Litterman's actual claim.**
BL's entire pitch — `black-litterman-overview.md:35` — is that it is more stable
than mean-variance optimization and produces less extreme weights. A Sharpe
ranking does not evaluate that claim at all; an elasticity comparison against MVO
evaluates exactly it, in minutes, with no history required.

**Capacity.** At what AUM does market impact consume the edge? In digital assets,
with thin books outside the majors, this is frequently decisive and almost always
omitted. A strategy with a 2.0 Sharpe and $5m capacity is a different product
from the same Sharpe at $500m.

**Implementability.** Turnover, Herfindahl concentration, maximum position,
number of holdings, and the count of positions below minimum tradeable size —
already listed at `black-litterman-validation.md:352` and never wired to anything.

### B14 · Calibration rather than performance

Black-Litterman is a _Bayesian_ model that emits a posterior distribution, and
almost nobody ever checks whether that distribution is calibrated. Two tests, and
the second is the most product-relevant thing in this document.

**Posterior predictive coverage.** If the model states a 90% interval, do 90% of
realizations fall inside it? Report a reliability diagram over rebalance dates.
Systematic under-coverage means the posterior is overconfident, which propagates
directly into position sizing.

**View calibration — the one that matters most here.** Do views submitted at 80%
confidence come true 80% of the time? Track per view, per author, per source;
report reliability diagrams and Brier scores.

This is the test that can invalidate everything upstream of it: **if analysts'
stated confidence is miscalibrated, the Ω calibration in
[ADR-0001 §D1](../adr/0001-black-litterman-model-conventions.md#d1--view-uncertainty-ω-calibration)
is wrong no matter how numerically perfect the solver is.** A flawless Tier A and
a badly calibrated view pipeline produce confident, precise, wrong allocations.

It also closes a loop the specs already anticipate: measured historical accuracy
feeds Ω through the `Explicit` calibration method — exactly the "historical
method" at `black-litterman-model.md:165` and the accuracy assessment at
`confidence-calibration.md:41`. Neither is currently connected to anything.

And unlike a backtest, calibration evidence **accumulates continuously in
production** without a research exercise.

_References:_ Brier (1950); Gneiting, Balabdaoui & Raftery (2007),
_Probabilistic Forecasts, Calibration and Sharpness_, JRSS-B 69(2).

### B15 · Formal multiple-testing tests

Deflated Sharpe (B5) adjusts a single reported statistic. **White's Reality Check**
and **Hansen's SPA test** answer the sharper question directly: _does any model in
this roster beat the benchmark, once the number of models tried is accounted for?_

Given B7 already requires reporting the whole roster, the roster is exactly the
input these tests need. The benchmark is 1/N.

_References:_ White (2000), _A Reality Check for Data Snooping_, Econometrica
68(5); Hansen (2005), _A Test for Superior Predictive Ability_, JBES 23(4).

### B16 · Shadow mode — the only truly out-of-sample test

Run the harness live against real market data with no capital deployed. Record
every allocation, timestamped and signed.

**This is where the audit infrastructure already in the plan pays off in an
unexpected way.** `InputHash` + `EngineVersion` + signature
([§3.4](../black-litterman-implementation-plan.md#34-exact-dto-diff)) make a
shadow-mode record **tamper-evident**: the allocation, the exact input that
produced it, and the exact engine version are bound together cryptographically
before the outcome is known. A shadow record cannot be quietly revised, a model
version cannot be swapped in retroactively, and a losing period cannot be dropped.

It is slow — meaningful evidence takes quarters — and it is the only approach on
this list that cannot be gamed at all. **Start it the day Phase 6b ships**, so
that by the time anyone wants to make a performance claim, real out-of-sample
evidence already exists rather than being a year away.

### B17 · Ablation — which component is actually contributing?

Remove one component at a time and measure the delta: views, shrinkage,
constraints, the confidence weighting.

The sharpest of these has an uncomfortable edge: **if removing views changes the
allocation materially less than the noise floor, Black-Litterman is an expensive
way to compute equilibrium returns.** That question deserves an answer before the
product is built around views, and it is cheap to ask — it reuses the
leave-one-out machinery from [ADR-0001 §D5](../adr/0001-black-litterman-model-conventions.md#d5--definitions-for-the-undefined-result-fields)
with no new mathematics.

---

### What Tier B can and cannot establish

**It cannot establish that a model will work.** It can only fail to reject a
model over one finite history under one set of choices. Every result is
conditional on the pre-registered protocol, and stating that conditionality is
part of reporting the result.

Useful framing — **what would falsify each model?**

| Model             | Falsified by                                                                                                                            |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Black-Litterman   | Posterior allocations that do not beat their own equilibrium prior net of costs — BL failing to add value over the input it starts from |
| ERC / risk parity | Realized risk contributions diverging materially from equal out of sample                                                               |
| HRP               | Underperforming inverse-variance weighting, its own degenerate case                                                                     |
| Michaud           | Not improving out-of-sample stability over the base allocator it wraps                                                                  |
| 1/N               | Being beaten, net of costs, with statistical significance — **which is the bar for the entire product**                                 |

Each falsification test is more informative than a Sharpe ranking, because each
targets the specific claim the model makes rather than a generic performance
number.

### Tier B exit

Graduated, because the approaches differ enormously in strength:

| Claim state   | Requires                                                                                                                                                                                               |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `unevaluated` | default                                                                                                                                                                                                |
| `stable`      | B13 only — stability, capacity and implementability, no forward data. **Available from Phase 5b**, and sufficient to say "allocations are stable under input perturbation", which is BL's actual claim |
| `recovers`    | B11 — known-ground-truth recovery, including the DeMiguel 1/N regularity reproduced                                                                                                                    |
| `calibrated`  | B14 — posterior coverage and view reliability over a stated sample                                                                                                                                     |
| `evaluated`   | B1–B8 full backtest protocol + B9/B10 (CPCV distribution and PBO) + B12 cross-universe                                                                                                                 |
| `consistent`  | all of the above **and** B15 (SPA against 1/N) **and** ≥ 4 quarters of B16 shadow mode in which **live behaviour matched the backtest's stated expectations**                                          |

**A single backtest never gates any of these.** `stable`, `recovers` and
`calibrated` need no forward data at all, so they are reachable long before any
backtest is credible — which is the point of the ordering.

**There is deliberately no `strong` state, and no state asserting that one model
outperforms another.** An earlier draft had one, gated on four quarters of shadow
mode; [M1](#m1--the-sample-sizes-available-cannot-support-the-performance-claims-anyone-wants)
shows that twelve monthly observations cannot distinguish a Sharpe of 1.0 from
one of 0.5, and that doing so with confidence takes over a decade of data this
product will never have. The top state is therefore `consistent` — live behaviour
did not contradict what the backtest predicted — which is answerable at realistic
sample sizes. "This model beats that one" is not, and the ledger has no way to
say it.

---

---

## Measuring the measurement

The document to this point asserts that a suite of tests establishes correctness.
That assertion deserves the same scepticism it applies to everything else. Six
weaknesses, in descending order of how much they matter.

### M1 · The sample sizes available cannot support the performance claims anyone wants

This is the most uncomfortable item here and no protocol fixes it.

The standard error of a Sharpe estimate is approximately `√((1 + SR²/2)/T)`. For
an annualized Sharpe near 1.0 measured on monthly data:

| Observations    | SE of annualized Sharpe | 95% interval around a true SR of 1.0 |
| --------------- | ----------------------- | ------------------------------------ |
| 12 (1 year)     | ≈ 1.0                   | roughly [−1.0, 3.0]                  |
| 36 (3 years)    | ≈ 0.6                   | roughly [−0.2, 2.2]                  |
| ~200 (17 years) | ≈ 0.25                  | roughly [0.5, 1.5]                   |

**Distinguishing a Sharpe of 1.0 from 0.5 with confidence takes on the order of a
decade and a half of monthly data.** Digital assets do not have that history, and
neither will this product.

Paired comparison is meaningfully better — two allocation models over the same
universe share most of their market exposure, so the _difference_ has far lower
variance than either level, and relative claims need perhaps three to five times
fewer observations than absolute ones. But that still means **years, not
quarters.**

Consequences, stated rather than buried:

- **The `strong` claim state as originally defined was wrong.** Gating it on
  "≥ 4 quarters of shadow mode" gated a strong claim on evidence that cannot
  support one. Twelve monthly observations distinguish essentially nothing.
- Performance _ranking_ between models should probably never be claimed at all on
  this product's realistic data. The comparison harness is valuable for showing
  an allocator _how the models differ and why_, not for declaring a winner.
- The claim states that survive scrutiny are the ones measurable at realistic
  sample sizes: **`stable`, `recovers`, `calibrated`.** Those are real, defensible
  and reachable. The top state is renamed `consistent` — live behaviour did not
  contradict the backtest's stated expectations, which is answerable — replacing
  any state that asserted one model beats another, which is not.

If this reads as deflating, it is the correct amount of deflating. The
alternative is a ranking table built out of noise.

### M2 · Mutation testing — does the suite actually catch bugs?

The whole framework rests on the assumption that these tests would fail if the
code were wrong. That is testable, and largely untested in practice.

Seed known faults and require the suite to catch every one:

| Mutation                                     | Must be caught by                     |
| -------------------------------------------- | ------------------------------------- |
| Transpose P in the view matrix               | T2 golden vectors; T1.9 permutation   |
| Swap Σ and Σ_p in the optimizer              | T2; the 1/(1+τ) invariant T1.15       |
| Use `model.md:161`'s withdrawn Ω formula     | T1.3 (B2, 100% confidence)            |
| Sign flip on `Q − PΠ`                        | T1.6 (view agreeing with equilibrium) |
| Drop the τ factor from Ω                     | T1.12 τ-invariance                    |
| Off-by-one in the `AssetUniverse` projection | T1.9; A3 golden vectors               |
| Skip PSD repair                              | T4.4                                  |
| Inverse-variance in place of ERC             | ERC.1                                 |
| Single- vs average-linkage in HRP            | HRP golden vectors                    |
| Round weights without renormalizing          | T6.2                                  |

**Any mutation that survives the suite is a hole in the suite, and the fix is a
new test, not a shrug.** Run as a scheduled job rather than per-commit; the
mutation set is committed alongside the tests and grows whenever a real bug is
found in production — every genuine defect becomes a permanent mutation.

This is the direct answer to "is the measurement strong": a suite that has never
been shown to fail on a known-bad implementation is decoration.

### M3 · The audit claim — the actual differentiator — is unmeasured

[ADR-0003](../adr/0003-portfolio-model-strategy.md) concludes that the defensible
value is auditability, not mathematics. Everything above measures the mathematics.

**T5.8 proves determinism across three platforms _today_. It proves nothing about
the same platform a year from now**, after a compiler upgrade, a dependency bump
or a refactor — which is exactly the span an audit covers.

Add a **reproduction drill**, run quarterly:

1. Take a signed result at least six months old.
2. Rebuild the engine at the `EngineVersion` git sha it records.
3. Replay the input identified by its `InputHash`.
4. Assert bit-identical output.

A failure means the audit trail does not actually work, however green the rest of
CI is. This is the only test that measures the claim the product is being sold
on, and it is cheap.

### M4 · Tolerances are conventions, not derivations

Constants of 1e-8, 1e-9, 1e-10 and 1e-12 are scattered through these specs. They
came from convention.

A defensible tolerance derives from conditioning: the achievable accuracy of a
Cholesky solve is roughly `κ(Σ) · ε_machine`. For a fixture with κ = 10⁶ that is
about 1e-10 — which happens to match, but by luck rather than reasoning. On an
ill-conditioned fixture a fixed 1e-10 is unmeetable; on a trivially conditioned
one it is vacuously loose and would pass a genuinely broken implementation.

**Derive each tolerance from the fixture's own condition number** —
`tol = max(c · κ(Σ) · ε, floor)` with `c` stated — and record κ in the fixture
header alongside the citation. Golden vectors from published tables keep their
absolute printed-unit tolerances (A3 rule 2); this applies to the analytic
identities, where machine precision is the only limit.

### M5 · Claims have no expiry

A claim verified once stays verified forever in the ledger. A `performance`
assessment from two years ago, in a different volatility regime, is not current
evidence of anything.

Add `verified_at` per axis and a staleness rule that **automatically demotes**:
`correctness` never expires while its tests stay green in CI; `calibrated`
expires after two quarters without a refresh; `performance` expires after four.
An expired axis reverts to its default and `claims-gate` fails if a deck still
asserts it.

### M6 · A framework that is too slow to run measures nothing

CPCV is `C(N,k)` full backtests. If the complete Tier B suite takes a week, it
will be run once, before a board meeting, and never again — at which point it is
theatre.

Budget it explicitly: Tier A under five minutes per commit; the no-forward-data
Tier B set (B11, B13, B17) under an hour nightly; the full backtest tier
quarterly. **If a layer cannot meet its budget, reduce its scope deliberately and
`log()` what was dropped** rather than letting it quietly stop running.

---

## How this binds to claims

`docs/CLAIMS.md` carries three independent axes per
[ADR-0003](../adr/0003-portfolio-model-strategy.md#consequence-claims-need-three-axes-not-one):

| Axis          | Gated by                                   | Default       |
| ------------- | ------------------------------------------ | ------------- |
| `correctness` | Tier A on `main`                           | `unbuilt`     |
| `novelty`     | a written, reviewed defensibility argument | `commodity`   |
| `performance` | the full Tier B protocol                   | `unevaluated` |

The `claims-gate` CI job fails when a claim's state exceeds its evidence, and
when a deck line drops a qualifier the ledger still requires.

**The three axes are independent and it is normal for them to disagree.** The
expected steady state for Black-Litterman is
`correctness: verified, novelty: commodity, performance: unevaluated` — and that
is a perfectly good position to be in. It says: this is implemented correctly,
it is not proprietary, and we have not yet earned the right to claim it performs.
All three are defensible statements. What is not defensible is quietly promoting
any one of them on the evidence of another.
