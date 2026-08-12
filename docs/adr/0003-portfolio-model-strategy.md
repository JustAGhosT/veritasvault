# ADR-0003 — Portfolio model strategy: the deliverable is a comparison harness

|            |                                                                                                                                                         |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Status** | **Proposed** — requires product and domain sign-off                                                                                                     |
| Date       | 2026-08-12                                                                                                                                              |
| Related    | [ADR-0001](./0001-black-litterman-model-conventions.md), [ADR-0002](./0002-numeric-core-runtime.md), [ADR-0004](./0004-allocation-model-abstraction.md) |
| Specs      | [allocation-models.md](../specs/allocation-models.md), [model-verification.md](../specs/model-verification.md)                                          |

## Context

Three documents of planning have gone into building a Black-Litterman solver
without anyone asking whether a BL solver is the right deliverable. It is worth
asking, because the answer changes what "good" means.

### The mathematics is commodity

The BL posterior is three matrix operations. He & Litterman (1999) is a 20-page
paper. PyPortfolioOpt, Riskfolio-Lib and skfolio all ship working, validated
implementations. Anyone can have a functioning BL engine this afternoon.

So the positioning in `veritasvault-corporate-deck.html` — Black-Litterman as
core IP and commercial wedge — is a **liability rather than an asset**. Any
allocator sophisticated enough to ask for Black-Litterman knows it is 1992
textbook material taught in every quantitative finance programme. Claiming it as
proprietary costs credibility with precisely the audience it is aimed at.

### The deck already contains the defensible version

`veritasvault-investor-overview.html:582`: _Black-Litterman is the language
institutional allocators already speak._ That is the real justification —
**legibility, not differentiation.** BL is table stakes for being taken
seriously, not a moat.

### Which means the build is justified by auditability, not by mathematics

`pip install pyportfolioopt` yields a solver. It does not yield deterministic,
cryptographically signed, versioned, independently reproducible allocations,
which is what `BlackLitterman-Reference.md:22` requires. That is why the
expensive parts of the implementation plan — cross-RID bit-determinism, input
hashing, golden validation against published tables — are the _right_ expensive
parts, and why a thin wrapper around a Python library would not do.

The genuinely defensible work lives in view generation, covariance estimation for
an asset class where it is hard, and the governance wrapper. Never in the
posterior formula.

### BL's prior is weaker in digital assets than in equities

Nothing in the 45 specification documents addresses this, and the corporate deck
has a slide titled _"Black-Litterman, applied to digital assets"_ that needs an
answer.

BL anchors on `Π = λΣw_mkt` — the market-capitalization portfolio as neutral
prior. In digital assets:

- market capitalization is contaminated by locked tokens, low float and wash
  trading, so `w_mkt` is a noisy measurement of a questionable quantity
- the resulting "neutral" book is dominated by one or two assets
- returns are fat-tailed and regime-switching, so the Gaussian prior BL assumes
  is a poorer approximation than in equities
- histories are short and correlations unstable, so Σ is frequently
  ill-conditioned — and BL inverts it

**The single most important consequence: a model whose neutral prior is shaky
should not be the only model.**

### And 1/N is the benchmark nobody has to beat yet

DeMiguel, Garlappi & Uppal (2009) found naive equal weighting frequently beats
optimized portfolios out of sample, because estimation error swamps optimization
gains. `equal-weighting.md` exists in the spec tree, so the thought is in the
building — but as a specification, not as a yardstick. As the implementation plan
stood before this ADR, **nothing in it could have told anyone whether BL was
helping.**

## Decision

**The deliverable is a model comparison harness, not a Black-Litterman engine.**

Black-Litterman remains first and its phases are unchanged — legibility and the
honesty gate both depend on it. What changes is that alternatives become peers in
the architecture rather than distant roadmap items, and the product surface
becomes:

> Here is your allocation under Black-Litterman, Equal Risk Contribution,
> Hierarchical Risk Parity and 1/N, with the differences attributed and each
> model's assumptions stated.

This is more useful to an allocator, much harder to dismiss, genuinely
differentiated in a way the posterior formula never will be, and — decisively —
it makes Black-Litterman **falsifiable**.

### Model roster

Specified in [allocation-models.md](../specs/allocation-models.md). Status column
is honest: everything here is unbuilt.

| Model                        | Needs μ?   | Needs Σ? | Inverts Σ? | Phase    | Spec today                                                   |
| ---------------------------- | ---------- | -------- | ---------- | -------- | ------------------------------------------------------------ |
| Equal weight (1/N)           | no         | no       | no         | 5a       | `equal-weighting.md`                                         |
| Market-cap weight            | no         | no       | no         | 5a       | BL prior                                                     |
| Equilibrium (reverse-opt)    | —          | yes      | no         | 2        | `black-litterman-model.md`                                   |
| Black-Litterman              | produces μ | yes      | yes        | 2–3      | 45 documents                                                 |
| Mean-variance (MVO)          | yes        | yes      | yes        | 3        | `MarkowitzModel.md`                                          |
| Minimum variance             | no         | yes      | yes        | 5b       | `risk-based-overview.md:27`                                  |
| Equal Risk Contribution      | no         | yes      | no†        | 5b       | `EqualRiskContribution.md`                                   |
| Maximum diversification      | no         | yes      | yes        | 5b       | `risk-based-overview.md:49`                                  |
| **Hierarchical Risk Parity** | no         | yes      | **no**     | 5b       | **absent** — one passing mention at `bl-ai-reference.md:134` |
| Michaud resampling           | wraps      | wraps    | wraps      | 6b       | `MichaudResampling.md`                                       |
| **Entropy pooling**          | produces μ | yes      | yes        | deferred | **absent** — footnote at `black-litterman-views.md:185`      |

† ERC is solved as a convex log-barrier problem, not by inverting Σ.

**HRP is the most valuable addition and is effectively absent from the spec
tree.** It never inverts the covariance matrix — decisive when Σ is
ill-conditioned or when n > T, which is the normal condition for digital assets.
It requires no expected returns at all. It is also the cheapest model on the list
to build: clustering plus recursive bisection, no solver.

**Entropy pooling** strictly generalizes BL — views as constraints on the entire
distribution, posterior by minimum KL divergence — and handles fat tails and
views on volatility and correlation rather than means alone. It is deferred
rather than dropped because it cuts against the very rationale for running BL: it
is markedly less legible to an allocator, and legibility is the reason BL is here.

### This is cheap, because the architecture already accommodates it

- The crate is already `vv-portfolio-core` with BL as a module ([ADR-0002](./0002-numeric-core-runtime.md))
- 1/N and market-cap are trivial
- Minimum variance and maximum diversification reuse the Clarabel QP already
  scheduled for Phase 5
- **ERC needs Clarabel's exponential cones, which a pure QP solver would not have
  provided** — an unplanned dividend of that choice
- HRP needs no solver at all
- The leave-one-out attribution machinery in [ADR-0001 §D5](./0001-black-litterman-model-conventions.md#d5--definitions-for-the-undefined-result-fields)
  generalizes from view-versus-view to model-versus-model with no new mathematics

## Consequence: claims need three axes, not one

The honesty gate in the implementation plan catches overclaiming _completion_. It
does not catch overclaiming _novelty_ — and a claim can be entirely true and
still damage credibility. Nor does it distinguish "we implemented this correctly"
from "this works well", which are separated by a large evidentiary gap.

`docs/CLAIMS.md` therefore carries **three independent states per claim**:

| Axis            | Question                                   | Gated by                                                                                                                            |
| --------------- | ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| **Correctness** | Does the code compute what the paper says? | [Tier A](../specs/model-verification.md#tier-a--numerical-correctness) — invariants, golden vectors, cross-model identities         |
| **Novelty**     | Is this actually differentiated?           | a written defensibility argument, reviewed. Default is **`commodity`**                                                              |
| **Performance** | Does it work better than the alternatives? | [Tier B](../specs/model-verification.md#tier-b--model-validity) — pre-registered walk-forward protocol. **Never a single backtest** |

Applied to what exists today:

```yaml
- claim: black-litterman-allocation
  correctness: unbuilt
  novelty: commodity # 1992, textbook, three OSS implementations
  performance: unevaluated
- claim: ml-enhanced-covariance
  correctness: unbuilt
  novelty: plausible # needs a defensibility argument before any claim
  performance: unevaluated
- claim: audited-reproducible-allocation
  correctness: unbuilt
  novelty: defensible # deterministic, signed, versioned — this is the real one
  performance: not-applicable
```

**The `novelty: commodity` marking on Black-Litterman is the point of this
table.** It does not stop the product from running BL or from saying so. It stops
the decks from calling it IP.

## Consequences

**Positive.** BL becomes falsifiable. The comparison surface is more defensible
than any single model. The abstraction work ([ADR-0004](./0004-allocation-model-abstraction.md))
is required anyway for Phase 9 to slot in. HRP directly addresses the
ill-conditioned-Σ problem that is BL's weakest point in this asset class.

**Negative.** Scope grows: six additional models, plus a verification protocol
that is more demanding than a test suite. Phase 5 splits into 5a and 5b.
Comparison invites the question "so which one do I use?", which is a product
question this ADR does not answer.

**Risk this ADR creates.** A comparison harness with a weak verification protocol
is _worse_ than no comparison — it manufactures authoritative-looking rankings out
of estimation noise. [model-verification.md](../specs/model-verification.md)
Tier B exists specifically to prevent that, and it is the harder half of the
work.

## Sign-off required

- [ ] The deliverable is a comparison harness, not a BL engine
- [ ] Model roster and phasing, including HRP as a first-class model
- [ ] **`novelty: commodity` on Black-Litterman, and the deck edits that follow**
- [ ] Entropy pooling deferred rather than dropped
