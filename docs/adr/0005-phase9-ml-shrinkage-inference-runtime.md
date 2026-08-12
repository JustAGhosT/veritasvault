---
document_type: architecture
classification: internal
status: review
version: 0.1.0
last_updated: '2026-08-12'
applies_to:
- Core
reviewers:
- '@tech-lead'
priority: p1
next_review: '2026-11-12'
---

# ADR-0005 — Phase 9 ML shrinkage inference: hand-written forward pass in Rust

| | |
|---|---|
| **Status** | **Proposed** — spike result. Phase 9 remains deferred and unimplemented. |
| Date | 2026-08-12 |
| Decision by | Repository owner, this session |
| Supersedes | Nothing. Resolves the Phase 9 spike that [ADR-0002](./0002-numeric-core-runtime.md) left open |
| Related | [ADR-0001](./0001-black-litterman-model-conventions.md), [ADR-0002](./0002-numeric-core-runtime.md), [ADR-0003](./0003-portfolio-model-strategy.md), [ADR-0004](./0004-allocation-model-abstraction.md), [Implementation plan](../black-litterman-implementation-plan.md) |

## Provenance and scope — read first

Two things about the state of this repository, stated up front because they change how this
document should be read.

1. **ADR-0001 through ADR-0004, the implementation plan and `docs/specs/` are not committed to
   any branch.** They exist as untracked files in a sibling worktree
   (`.claude/worktrees/youthful-hopper-bc5107`); `git log --all` finds no commit that ever
   added them. This ADR was written against that uncommitted text, so **its relative links
   dangle until those files land**, and it should be reviewed alongside them.

   That worktree was still being written while this ADR was drafted — ADR-0003, ADR-0004 and
   `docs/specs/` all appeared mid-session, and the plan was modified 79 seconds before this
   note was written. Two consequences: this ADR was renumbered from 0003 to **0005** after
   ADR-0003 (portfolio model strategy) and ADR-0004 (allocation model abstraction) claimed
   those numbers, and the amendments in §9 are recorded rather than applied, because editing
   an actively-modified file from a different branch would race that session's work. ADR-0003
   and ADR-0004 were read by targeted search rather than in full; §8 and §9.3 depend on them,
   so both should be re-checked against their final text.
2. **Nothing in the Black-Litterman engine is implemented.** There is no `crates/` directory,
   no `Cargo.toml` anywhere in the repository, and no solver. The only Black-Litterman code
   that exists is `src/vv.Application/DTOs/Portfolio/BlackLittermanModels.cs`. This spike
   produces a recommendation and changes none of that. The investor decks are correct that
   ML-enhanced covariance estimation is roadmap, not product.

Scope: this ADR decides how a *trained* ML shrinkage model is evaluated at inference time
inside the Rust numeric core. It does not decide training, and it does not authorise Phase 9
to begin — see [Blocking prerequisites](#6-blocking-prerequisites-surfaced-by-this-spike).

## 1. Architecture summary: confirmed in outline, materially understated in detail

The spike brief summarised the model as 2–3 dense hidden layers, 128–256 units,
LeakyReLU(α=0.2), batch normalization, L2 regularization, sigmoid output constrained to
[0,1], optional softmax for multi-target weighting; an ensemble of several such models plus a
2–3 layer meta-learner; distillation optional.

Against `ml-shrinkage-training-architecture-network.md` that is **accurate**. Against the
covariance subtree as a whole it is **not**, because the subtree contains two mutually
inconsistent network specifications and the brief matches only the smaller one.

### 1.1 Two conflicting specs

| | `ml-shrinkage-training-architecture-network.md` | `shrinkage/bl-ai-shrinkage-model.md` |
|---|---|---|
| Activation | LeakyReLU(α=0.2) | **ELU** |
| Hidden layers | 128 / 64 / 32 | 128 / 64 extractor, then **2 residual blocks** @ 64, then heads |
| Attention | "Optional self-attention for feature importance" (§2, Layer 3) | **Self-attention layer, 2 heads, dim 32, plus regime embedding** — structural, not optional (§3, §4) |
| Output heads | One output layer, `num_targets` units | **Three target-specific heads** (identity / constant-correlation / single-factor), each Dense32 → Dense16 → Sigmoid |
| BatchNorm placement | Prose says "Applied post-activation" (§2); the PyTorch and TensorFlow code both do Dense → BN → activation | BatchNorm **first**, before the first Dense |
| Auxiliary outputs | Uncertainty estimates, target weights | Plus condition estimate, expected estimation error, **regime classification probabilities** |
| Hyperparameter table | None | §5: residual blocks 2–4 (default 2), attention heads 1–4 (default 2), attention dim 16–64 (default 32) |

Both files are `status: draft`, `version: 0.1.0`, `last_updated: 2025-05-31`. Neither
references the other, and neither is marked as superseding. There is no basis in the
documents for choosing one.

This is a spec defect of exactly the kind ADR-0001 catalogued as D1 (three conflicting Ω
formulas) and it needs the same treatment: pick one, record the choice, mark the other
withdrawn. It is **not** an implementation decision and it is not resolved here.

Note also that the docs mix frameworks incoherently — `network.md` gives both a PyTorch and a
TensorFlow implementation, the loss specs are TensorFlow, and `training-process.md` is
PyTorch. ADR-0002's claim that "Phase 9 is already written in another language" is right in
substance; it is written in *two*, interchangeably.

### 1.2 Both variants are still deterministic feed-forward graphs

Taking the richer of the two, the inference ops are: matmul, bias add, ELU (or LeakyReLU),
batch-norm (foldable — see §4.1), residual add, scaled dot-product attention (matmul, scale,
softmax, matmul), sigmoid, softmax, concat. Nothing recurrent, nothing data-dependent in
control flow, nothing stochastic.

So the brief's central claim survives: this is a small deterministic forward pass. The
estimate of "roughly 60 lines of Rust" is low — attention, two residual blocks, three heads
and ensemble aggregation put it closer to **150–250 lines** — but the difference does not
change the conclusion.

One observation worth recording because it suggests the spec is aspirational rather than
worked through: self-attention is specified over a **flat feature vector**, i.e. a sequence of
length one. Scaled dot-product attention over a single token reduces to a value projection
with a softmax of a single element, which is identically 1. As specified, the attention layer
is a no-op dressed as a mechanism. Whoever resolves §1.1 should decide whether attention was
meant to operate over per-asset or per-feature-group tokens, or whether it should be dropped.

### 1.3 Uncertainty quantification — the finding that decides the ADR

The brief asked specifically whether uncertainty quantification needs anything beyond a
deterministic forward pass, because that would change the answer. It does, for two of the
three approaches the spec offers. `ml-shrinkage-training-architecture-uncertainty.md` §2
presents them as alternatives, and they are **not equivalent** under a signing requirement:

1. **Bayesian neural networks** (`BayesianLinear`, lines 66–105). `forward()` draws
   `torch.randn_like(self.weight_mu)` **at inference** and forms
   `weight = mu + exp(log_sigma) * eps`; the spec calls for "Monte Carlo sampling for
   posterior predictions" (line 63). Stochastic at inference. **Incompatible with a signed
   audit trail.**
2. **Monte Carlo dropout** (lines 172–207). `predict_with_uncertainty` calls `self.train()`
   explicitly to *enable dropout during inference* (line 192) and averages 50 stochastic
   passes. Stochastic at inference. **Also incompatible.**
3. **Deep ensembles** (lines 132–161). Each member runs under `.eval()` and
   `torch.no_grad()`; the output is the mean and variance across members. **Fully
   deterministic** — N deterministic forward passes plus two reductions.

The remaining machinery in that document is deterministic: variance prediction heads for
heteroscedastic aleatoric uncertainty (§4), temperature scaling (a scalar divide), isotonic
regression (a monotone lookup table — note this is an sklearn artifact, not a network layer,
and would not come across in an ONNX graph export), quantile regression heads, and mixture
density network *parameters* (sampling from the resulting mixture would not be).

**Conclusion: uncertainty quantification does not require stochastic inference, but two of
the three specified routes do.** Phase 9 must therefore select **deep ensembles plus a
variance head**, and prohibit Bayesian layers and MC dropout on the signed path.

This constraint binds under **every** runtime option, which is why it is the most important
result of the spike. An ONNX export of a Bayesian layer (`RandomNormalLike`) or of a
training-mode `Dropout` node is no more reproducible than the PyTorch original. The
determinism question is settled first by the *uncertainty method* and only then by the
inference runtime.

Two convenient alignments: deep ensembles is already what the ensemble document uses for this
purpose (`ml-shrinkage-training-architecture-ensemble.md` §5: "Model disagreement as a measure
of prediction uncertainty"), and `ml-shrinkage-architecture.md:150` already enumerates
`model_variant: "base" | "ensemble" | "uncertainty"`.

One tension to note: the ensemble document offers "Distillation: optionally distilling
ensemble knowledge into a single model" (§4), which the brief flagged as a simplification
lever. It is — it collapses the forward pass to one member — but distillation **discards
ensemble disagreement, which is the UQ signal**. Distillation and ensemble-based uncertainty
are alternatives, not complements. If UQ is required, distillation is not available; if UQ is
dropped, distillation makes this decision even easier.

### 1.4 The larger finding: the network is the small part

Whatever executes the MLP, the following must be implemented in Rust anyway, because an ONNX
graph covers only the network:

- Eigendecomposition, condition number, effective rank, eigenvalue entropy, trace, and ten
  eigenvalue ratios — `ml-shrinkage-features-part1.md` §2.
- Correlation mean/std/max/min, sign ratios, block-structure detection, threshold exceedance
  at four levels — §3.
- Volatility change and correlation stability across five lookback windows, **correlation
  decay-rate estimation** (an exponential fit), **GARCH effect estimation** (an MLE fit),
  return autocorrelation, vol-of-vol — `ml-shrinkage-features-part2.md` §1.
- Volatility and correlation regime detection, tail-event probability, trend strength, market
  rotation, VIX percentile and change — §2.
- Stored `FEATURE_MEANS` / `FEATURE_STDS` scalers, `nan_to_num(nan=0.0, posinf=3.0,
  neginf=-3.0)`, and `SELECTED_FEATURE_NAMES` ordering — §4.
- Post-processing: positive-definiteness enforcement with `conditioning_method: "nearest_pd"`
  (`ml-shrinkage-architecture.md:175`), i.e. Higham iteration over an eigendecomposition.
- The shrinkage blend itself, `Σ = δF + (1−δ)S`, across three target matrices.

`estimate_correlation_decay` and `estimate_garch_effect` are **unimplemented placeholders in
the spec** — `return decay_rate  # Placeholder` at `features-part2.md:116`.

Two consequences follow.

**Train/serve feature skew is the dominant Phase 9 risk, not inference.** `features-part1.md`
§4 builds the input vector with `sorted(features.keys())`. If the Rust pipeline computes the
same features under different names, or in a different order, or with a slightly different
GARCH estimator, the network receives permuted or subtly wrong inputs and returns a
plausible-looking number in [0,1]. There is no error, no NaN, no exception — just a wrong
shrinkage intensity, cryptographically signed and entered into the audit trail. The mitigation
is in §4: the artifact carries the ordered feature-name list and the scaler vectors, and the
Rust side refuses to run if its computed feature set does not match by name and order.

**ONNX's value shrinks to near zero.** It would remove ~150–250 lines of forward pass and
leave several hundred lines of feature engineering, PD conditioning and blending in nalgebra
regardless — while adding a runtime whose determinism properties are, as §3 shows,
disqualifying.

### 1.5 Other defects found while reading

Recorded because they will otherwise be rediscovered during Phase 9:

- `features-part1.md:80` — `np.max(np.spacing(1), np.min(eigenvalues))` is not valid numpy;
  `np.max` does not take two array arguments. It should be `np.maximum`. As written it raises.
- `ml-shrinkage-training-evaluation-part2.md:115` — `torch.maximum.accumulate` is not a torch
  API (that is a numpy ufunc idiom); `torch.cummax` is intended.
- `shrinkage/bl-ai-shrinkage-training-data.md` §1 requires **≥500 assets and ≥10 years of
  daily history**, while ADR-0002 sizes the engine for **n ≤ 50**. Condition number, effective
  rank and eigenvalue-ratio features are strongly n-dependent, so a model trained at n≥500
  would be evaluated far out of distribution at n≤50. This needs reconciling on statistical
  grounds, independent of any runtime choice.
- The same document names Bloomberg, Refinitiv and MSCI Barra as data sources. No such feed is
  contracted. Phase 9 training has an unmet data prerequisite.
- `ml-shrinkage-architecture.md:170–172` defaults to `use_gpu: true` and
  `parallel_processing: true`; `shrinkage/bl-ai-shrinkage-model.md:343` offers Int8/FP16
  quantization. All three are incompatible with the signing requirement and must be off on
  the signed path.

## 2. Decision

**Implement the ML shrinkage forward pass by hand in Rust over `nalgebra`, with all
transcendental functions taken from the `libm` crate.** Reject ONNX in both forms —
`ort` and `tract` — and reject `candle` / `burn`.

The rejection is on **determinism**, not on maturity, licensing or code quality. Each of
these is a well-made crate optimised for throughput, which is the right objective for nearly
every consumer and the wrong one here.

### 2.1 Crate facts

Verified against crates.io on 2026-08-12. The API returns HTTP 403 without a `User-Agent`
header; an earlier attempt in this session read those 403s as "crate not found", which would
have inverted the conclusion about `tract`. Anyone re-verifying should send a UA and check the
status code.

| Crate | Latest | Stable release? | Licence | Downloads | Role / note |
|---|---|---|---|---|---|
| `nalgebra` | 0.35.0 | yes | Apache-2.0 | 83.1M | Already an ADR-0002 dependency |
| `libm` | 0.2.16 | yes | MIT | 413.7M | Pure-Rust libm — **the determinism fix** (§3.2) |
| `safetensors` | 0.8.0 | yes | Apache-2.0 | 21.1M | Weight container (§4) |
| `serde_json` | 1.0.151 | yes | MIT OR Apache-2.0 | 1.16B | Manifest; already an ADR-0002 dependency |
| `tract-onnx` | 0.23.4 | **yes** | MIT OR Apache-2.0 | 2.43M | MSRV 1.91. Rejected on determinism (§3.3) |
| `ort` | 2.0.0-rc.13 | **no stable release** | MIT OR Apache-2.0 | 15.4M | RC-only status **confirmed**, latest RC 2026-07-28 |
| `candle-core` | 0.11.0 | yes | MIT OR Apache-2.0 | 6.9M | Rejected on determinism |
| `burn` | 0.21.0 | yes | MIT OR Apache-2.0 | 1.2M | Rejected on determinism |

Every crate recommended here is MIT or Apache-2.0, preserving ADR-0002's all-permissive
position. No new licence surface, no C++ dependency, no vendored ONNX Runtime binary.

Local toolchain confirmed in this worktree: `cargo 1.97.1`, `rustc 1.97.1`. This satisfies
`tract-onnx`'s MSRV of 1.91, so tract was assessed on merit rather than excluded on
toolchain grounds.

The brief's hypothesis about `tract` — stable releases, pure Rust, plausibly a better middle
path than `ort` — is **confirmed on version and licence** and **refuted on the constraint
that actually matters**. Details in §3.3.

## 3. Determinism

### 3.1 Why this is a correctness constraint

`src/vv.Domain/Docs/Domains/AI/FinancialModels/BlackLitterman-Reference.md:23` requires that
"All model inputs and outputs are cryptographically signed and auditable". A solve that
differs by one ULP between a Windows developer machine and a Linux production container fails
signature verification, and an audit trail that cannot be reproduced is not an audit trail.

Minor correction: ADR-0002 cites this as `BlackLitterman-Reference.md:22`. The line is 23.
The file is duplicated at `Domains/AI/FinancialModels/` and `Domains/AI/financial-models/`;
the two are byte-identical and the line number is 23 in both. The duplication is already
tracked in the implementation plan's documentation-defect section.

### 3.2 A correction to ADR-0002: pure Rust is *not* deterministic by construction

ADR-0002's Phase 9 note states that "a hand-written pure-Rust forward pass is deterministic
by construction where a general inference runtime is not". **The second half is right; the
first half is not true as written**, and the gap is the single most likely way to get this
implementation wrong while believing it is correct.

Rust's standard library documents its float transcendentals as explicitly non-reproducible.
For `f64::exp`, `ln`, `powf`, `tanh` and their siblings, the std documentation states:

> The precision of this function is non-deterministic. This means it varies by platform, Rust
> version, and can even differ within the same execution from one invocation to the next.

The output layer is a sigmoid, `1/(1+exp(−x))`. ELU uses `exp`. Softmax uses `exp`. The
eigenvalue-entropy feature uses `ln`. A forward pass written naively against `std` is
therefore not bit-stable across platforms, not bit-stable across Rust upgrades, and not
even guaranteed bit-stable between two calls in one process.

`sqrt` and `mul_add` are the documented exceptions: both are IEEE-754-specified operations,
guaranteed to return the correctly rounded infinite-precision result. That is useful — the
correlation features need `sqrt` of the variance diagonal, and it is safe.

**The fix, and why it works.** Take every transcendental from `libm` 0.2.16 and forbid `std`
float math inside the estimator. Verified against libm's source rather than assumed:
`libm/src/math/arch/mod.rs` gates all architecture-specific code to `sqrt`/`sqrtf`,
`fma`/`fmaf`, `rint`/`rintf`, and `ceil`/`floor`/`fabs`/`trunc`. **Every one of those is an
IEEE-754 exactly-specified operation, where the hardware instruction and the software
fallback return the identical value by definition.** `exp`, `ln`, `tanh` and `powf` have no
architecture variants at all — they use the generic pure-Rust implementations on every
target. So libm's hardware acceleration changes speed, not results.

One out-of-scope caveat: an `x86_no_sse2` configuration routes `exp` and friends through x87
(`x87_exp`, `x87_exp2`, …), which has different rounding behaviour. That is 32-bit x86
without SSE2 — absent from the `win-x64` / `linux-x64` / `osx-arm64` RID set, and absent from
`linux-musl-x64` if that is added. CI should assert the RID set so it stays absent rather
than relying on it being unlikely.

### 3.3 Per-option assessment

| Option | Bit-identical across win-x64 / linux-x64 / osx-arm64? | Why |
|---|---|---|
| **(a) Hand-written, `libm`, f64, no BLAS, no `target-cpu=native`** | **Yes**, and provable by test | Reduction order is ours and fixed; only IEEE-specified ops plus a generic pure-Rust libm |
| (a) but using `std` `f64::exp` | **No** | std documents precision as varying by platform, Rust version, and invocation (§3.2) |
| **(c) `tract-onnx` 0.23.4** | **No** | Three independent reasons, below |
| **(b) `ort` 2.0.0-rc.13** | **No** | Same SIMD dispatch as tract, plus intra-op thread pools and graph fusion; RC-only besides |
| `candle` / `burn` | **No** | Same per-architecture SIMD kernel character |
| Bayesian layers or MC dropout, under *any* runtime | **No** | RNG at inference; stochastic by design (§1.3) |

**Why tract fails**, stated in detail because it was the most promising alternative and
because its stable-release status makes it superficially the obvious answer:

1. **Per-architecture matmul kernel geometry.** `tract-linalg`'s own README documents distinct
   kernel tiles per target: ARMv7 NEON `8x4`, ARMv8 SIMD `8x8`, and x64 FMA `16x6`. Different
   tile shapes mean different accumulation orders, which means different last bits for the
   same inputs. The x64 path is FMA-based, which also contracts multiply-add into a single
   rounding where the ARM path may not.
2. **Sigmoid is not sigmoid.** The same README states that f32 sigmoid and f32 tanh are
   computed "at f32 precision, by a rationale function (no exponentiation)". tract substitutes
   a rational approximation. The model's output *is* a sigmoid — the shrinkage intensity — so
   tract would not return a value one ULP from what the trained Python model emits; it would
   return the output of a different function.
3. **Kernel choice depends on the measured CPU, not on the RID.** Per the maintainer in
   [tract discussion #716](https://github.com/sonos/tract/discussions/716), on aarch64 the
   implementation "has many variants to choose from, so we use a small dnn model to choose the
   implementation (trained for measurement several cpu variants)". Kernel selection is a
   runtime function of CPU characteristics. Two arm64 machines — or one machine before and
   after a host migration — can select different kernels and produce different bits. A
   per-RID pin, which is ADR-0002's mitigation for `target-cpu=native`, cannot address this,
   because the variation is *within* a RID.

Point 3 is what makes this a rejection rather than a configuration exercise: there is no
supported knob that makes tract bit-stable across the three target RIDs, so the property
could not be guaranteed even if the golden-hash test happened to pass on today's runners.

### 3.4 Rules Phase 9 inherits

Extending ADR-0002's four determinism rules, which continue to apply:

5. **All transcendentals via `libm`.** CI denies `f64::{exp, exp2, ln, log2, log10, powf,
   powi, tanh, sinh, cosh}` in the estimator module. A grep gate over the crate is sufficient
   and costs nothing.
6. **f64 end to end.** Do not adopt the f32 that a Keras or PyTorch ONNX export would default
   to. Reject the spec's Int8/FP16 quantization
   (`shrinkage/bl-ai-shrinkage-model.md:343`) and its `use_gpu: true` /
   `parallel_processing: true` defaults (`ml-shrinkage-architecture.md:170–172`) on the
   signed path.
7. **Fixed reduction order.** One documented iteration order for every matmul and reduction.
   No `rayon`, no `par_iter`, no explicit SIMD intrinsics inside the estimator. nalgebra's
   BLAS features remain forbidden by ADR-0002 rule 1 — this reuses that guard rather than
   adding a parallel one.
8. **Extend the cross-RID golden-hash test (plan T5.8) to Phase 9**, with the shrinkage
   intensities *and* the resulting covariance matrix in the hashed payload.
9. **Sign the model artifact hash and the feature-name list alongside inputs and outputs.** A
   perfectly reproducible forward pass over a silently swapped or reordered model is still an
   audit failure. See §4.

## 4. Weight export format and Rust-side loading

### 4.1 Export

**`safetensors` for tensors, plus a JSON manifest.** Chosen over: pickle / `.pt`, which
executes code on load; ONNX, whose entire value is graph semantics we have decided to own
ourselves; and raw JSON float arrays, which round-trip f64 through decimal text for no reason
when safetensors stores raw little-endian bytes.

Python-side export, after training in TensorFlow or PyTorch:

1. **Fold batch normalization into the preceding Dense layer.** Where BN follows Dense,
   `W' = W · γ/√(σ²+ε)` and `b' = (b − μ)·γ/√(σ²+ε) + β`. This removes BN from inference
   entirely. Note the ambiguity from §1.1: the fold is valid only for the Dense → BN ordering
   that both code samples use. If the resolution of §1.1 puts BN post-activation as
   `network.md`'s prose says, or first as `bl-ai-shrinkage-model.md` shows, it survives as a
   standalone diagonal affine op — trivial either way, but it must be recorded which layers
   were folded and which were not. Fold once, in f64, in Python.
2. **Cast every tensor to f64** and write `.safetensors`.
3. **Emit the manifest**, including a sha256 per member file.

Layout — one file per ensemble member plus a manifest:

```
ml-shrinkage-v1.2.0/
  manifest.json
  member-00.safetensors      # dense_0.w [128,F], dense_0.b [128], … head_identity.w …
  member-01.safetensors
  member-02.safetensors
  meta-learner.safetensors   # only if dynamic aggregation is selected
```

The manifest carries what the Rust side must **verify**, not merely what it must load:

```json
{
  "schema_version": 1,
  "model_version": "1.2.0",
  "dtype": "f64",
  "feature_names": ["condition_number", "correlation_mean", "effective_rank", "..."],
  "feature_means": [0.0, 0.0, 0.0],
  "feature_stds":  [1.0, 1.0, 1.0],
  "nan_policy": { "nan": 0.0, "posinf": 3.0, "neginf": -3.0 },
  "targets": ["identity", "constant_correlation", "single_factor"],
  "activation": "elu",
  "batchnorm_folded": true,
  "aggregation": "simple_mean",
  "uncertainty": "ensemble_variance",
  "members": [
    { "file": "member-00.safetensors", "sha256": "…" },
    { "file": "member-01.safetensors", "sha256": "…" }
  ],
  "layers": [
    { "name": "dense_0",        "kind": "dense",       "in": 41, "out": 128, "act": "elu" },
    { "name": "resblock_0",     "kind": "residual",    "width": 64, "act": "elu" },
    { "name": "head_identity",  "kind": "dense_stack", "dims": [32, 16, 1], "act": "elu", "out_act": "sigmoid" }
  ]
}
```

`feature_names` is load-bearing rather than documentary: it is the defence against the silent
permutation failure identified in §1.4. `nan_policy` and the scaler vectors are exported
rather than reimplemented so that the normalisation constants cannot drift apart from the
weights they were fitted with.

### 4.2 Rust side

Lives in `vv-portfolio-core` as `covariance::ml_shrinkage`, behind the `CovarianceEstimator`
trait the plan already specifies. No new heavy dependencies.

```rust
// deps: safetensors 0.8, serde_json 1, libm 0.2 — plus nalgebra 0.35, already present.
pub struct MlShrinkageModel { manifest: Manifest, members: Vec<Member> }

struct Member { layers: Vec<Layer> }

enum Layer {
    // BatchNorm already folded into w/b at export time.
    Dense    { w: DMatrix<f64>, b: DVector<f64>, act: Act },
    Residual { first: (DMatrix<f64>, DVector<f64>),
               second: (DMatrix<f64>, DVector<f64>), act: Act },
    Attention { wq: DMatrix<f64>, wk: DMatrix<f64>, wv: DMatrix<f64>, heads: usize },
}

enum Act { Elu, LeakyRelu(f64), Sigmoid, Identity }

impl MlShrinkageModel {
    /// Embedded at build time via include_bytes!, or loaded from the NuGet native payload.
    /// Verifies every member's sha256 against the manifest before returning Ok.
    pub fn load(manifest: &[u8], members: &[&[u8]]) -> Result<Self, ModelError>;

    /// Deterministic: no RNG, no threads, no dropout, no allocation-order dependence.
    pub fn predict(&self, feats: &FeatureVector) -> ShrinkagePrediction;
}

#[inline]
fn elu(x: f64, alpha: f64) -> f64 {
    if x > 0.0 { x } else { alpha * (libm::exp(x) - 1.0) }
}

#[inline]
fn sigmoid(x: f64) -> f64 {
    // Branch keeps the exp() argument non-positive, avoiding overflow for large |x|
    // and giving one canonical evaluation order per sign.
    if x >= 0.0 { 1.0 / (1.0 + libm::exp(-x)) }
    else        { let e = libm::exp(x); e / (1.0 + e) }
}
```

`FeatureVector` is constructible **only** through a builder that takes the manifest's
`feature_names` and fills slots by name, returning `Err(ModelError::FeatureMismatch)` on any
missing feature, unexpected feature, or order disagreement. A change to the feature pipeline
then fails loudly at load time instead of silently at inference time — the §1.4 failure mode.

`ShrinkagePrediction` returns the per-target intensities, the ensemble variance, and the
model artifact hash, so the caller can put the hash into the signed envelope per rule 9.

### 4.3 The test that makes this credible

The Python exporter also writes N input/output fixture pairs in f64. A `cargo test` asserts
the Rust forward pass reproduces them to **bit equality** — not to a tolerance.

This matters more than it sounds. A tolerance-based parity test passes while hiding exactly
the class of discrepancy this ADR exists to prevent: a mis-transcribed fold, a transposed
weight matrix that happens to be near-square, an activation applied in the wrong order. If
bit equality cannot be achieved, that is a real defect in the port, and a tolerance would
convert a findable bug into a permanent unexplained difference between the model that was
validated and the model that is signed.

Adding to the plan's T5 tier: a cross-RID hash equality test for the estimator (rule 8), and
a negative test that a manifest with permuted `feature_names` is rejected rather than
silently accepted.

## 5. Consequences

**Positive**

- No ONNX runtime, no C++ build dependency, no release-candidate crate on the critical path.
- Licence surface unchanged: MIT and Apache-2.0 only, preserving ADR-0002's position.
- Determinism becomes a property that is *tested* rather than hoped for, and the failure modes
  are ours to see rather than buried in a vendor kernel dispatcher.
- f64 throughout, consistent with the rest of the numeric core, instead of an f32 seam at the
  ONNX boundary.
- The estimator is `cargo test`-able with no Python, no .NET and no HTTP in the loop, matching
  how the rest of `vv-portfolio-core` is tested.
- `cargo miri` and `proptest` reach this code, as they do the rest of the core.

**Negative**

- The forward pass, the BN fold and the attention implementation are ours to own permanently
  and to keep in step with whatever the Python side trains. The fixture parity test is the
  only thing standing between those two drifting apart; it must be part of the training
  pipeline's output, not an afterthought.
- The decision is **scoped to the ML-shrinkage MLP**. The covariance overview also lists Deep
  Factor Models (autoencoders) and Graph Neural Networks. If one of those is ever adopted,
  hand-writing stops being reasonable, and the trade-off in §3 must be revisited — probably by
  accepting that such a model cannot sit on the signed path at all.
- The uncertainty restriction (§1.3) narrows the spec's menu from three approaches to one.
  That is a genuine reduction in scope, made for a stated reason.
- ~150–250 lines more first-party numerical code than the ONNX route, though far less than the
  feature pipeline that is required either way.

## 6. Blocking prerequisites surfaced by this spike

None of these are affected by the runtime decision, and Phase 9 cannot start until the first
three are closed.

1. **Resolve the two conflicting network specs** (§1.1) — activation, attention, head
   structure, BN placement. Mark one withdrawn, as ADR-0001 did for D1. **Blocking.**
2. **Select deep ensembles plus a variance head; prohibit Bayesian layers and MC dropout on
   the signed path** (§1.3). **Blocking.**
3. **Specify `estimate_correlation_decay` and `estimate_garch_effect`**, currently
   placeholders at `features-part2.md:116`. **Blocking.**
4. Reconcile the ≥500-asset training universe with n ≤ 50 production sizing (§1.5).
5. Secure training data, or accept a Fama-French / public-source fallback (§1.5).
6. Fix `np.max` → `np.maximum` at `features-part1.md:80`, and `torch.maximum.accumulate` →
   `torch.cummax` at `evaluation-part2.md:115`.

## 7. Rejected alternatives

| Option | Why not |
|---|---|
| **`ort` (ONNX Runtime bindings)** | No stable release — 2.0.0-rc.13 as of 2026-07-28, confirming ADR-0002's caveat. Independently disqualified by SIMD kernel dispatch, intra-op threading and graph fusion, none of which are bit-stable across RIDs. |
| **`tract-onnx`** | Stable (0.23.4) and pure Rust, so it clears the objections that sink `ort` — but per-architecture kernel tiles (8x4 / 8x8 / 16x6), x64 FMA contraction, a rational-function substitute for sigmoid, and aarch64 kernel selection driven by a runtime CPU-characteristic model. Not bit-stable across RIDs, and not fixable by pinning, since the variation occurs within a RID. |
| **`candle` / `burn`** | Same per-architecture SIMD kernel character; additionally oriented toward training and GPU execution, which is not what is needed. |
| **Hand-written forward pass using `std` float math** | Rejected on the std documentation's own terms: precision "varies by platform, Rust version, and can even differ within the same execution from one invocation to the next" (§3.2). This is the trap that ADR-0002's "deterministic by construction" phrasing would have led to. |
| **Python sidecar for Phase 9 only** | Would give the whole TensorFlow/PyTorch/sklearn stack for free — including isotonic regression and the GARCH fit — and is genuinely the least-effort route. Rejected for the same reason ADR-0002 rejected the Python sidecar for the solver: a second runtime to operate and deploy. It is worth reconsidering *only* if prerequisite 4 forces a much larger model than the MLP specified here. |
| **Defer Phase 9 indefinitely** | Not an alternative to this ADR — Phase 9 *is* deferred, and this ADR does not change that. Recorded only to be explicit that recommending an approach is not scheduling the work. |

## 8. Language and library placement beyond Phase 9

The Phase 9 question generalises, so the general answer is recorded here rather than
rediscovered per phase. It may be worth promoting to its own ADR once the ADR numbering
settles.

[ADR-0003](./0003-portfolio-model-strategy.md) makes signed, reproducible allocations the
product thesis rather than a compliance checkbox — "`pip install pyportfolioopt` yields a
solver. It does not yield deterministic, [signed, versioned, independently reproducible
allocations]". The consequence is that the language boundary is **not** Rust-versus-Python by
preference. It is **on the signed path or off it**.

On the signed path, Rust, and even then the library choice is constrained (§3). Off it, use
whichever ecosystem is strongest — and there, **language diversity is a feature**, because an
oracle written in Rust against `nalgebra` is not independent of the implementation it checks.

| Zone | Scope | Language | Rationale |
|---|---|---|---|
| **A. Signed path** | BL blend, QP, `2k+1` attribution, every covariance estimator, PD conditioning, feature computation, ML forward pass, HRP clustering, all ADR-0003 harness models, Michaud, result serialisation + canonicalisation + hash | **Rust only** | T1.10, T5.8 |
| **B. CI oracles** | Golden vectors, differential fixtures, Ledoit–Wolf fixtures, scipy linkage fixtures, Phase 9 parity fixtures | **Python** | Independence is the point |
| **C. Phase 9 training** | Train, calibrate, export weights | **Python** | §1.4, §4.1 |
| **D. Cross-checks** | Second QP solver; literature golden sources | **Python (cvxpy) / MATLAB** | Must be a foreign implementation |
| **E. Boundary** | DTOs, validation, decimal seam, CQRS, HTTP, signing | **C#, no numerics** | ADR-0002, unchanged |
| **F. Off-path analysis** | Backtesting engine, sensitivity analyzer, harness reporting | **Python** | Rust buys nothing off the signed path |

### 8.1 Zone B is a build-time dependency, not a second runtime

ADR-0002 rejected a Python sidecar on the grounds of "no second language runtime to operate".
That reasoning is correct for **serving** and does not apply to **CI**. The implementation
plan already depends on Python in three places — the T2 rule-3 numpy/PyPortfolioOpt
derivation, the T3 differential fixtures, and the sklearn Ledoit–Wolf fixture — and correctly
commits their outputs so the shipping build needs no Python.

Recommendation: consolidate those three ad-hoc scripts into one pinned `tools/oracle/`
package (numpy, PyPortfolioOpt, cvxpy, sklearn, scipy) that owns every fixture in Zone B.
Recording the build-time/runtime distinction explicitly so it is not later re-litigated as an
ADR-0002 violation.

For Phase 9 the same package owns training: `arch` for the GARCH-effect estimator,
`statsmodels` for autocorrelation and Hurst, `scipy.optimize` for the correlation-decay fit,
`sklearn` for isotonic calibration and the scaler constants. The rule that follows from §1.4
and blocking prerequisite 3: **design the estimators in Python, freeze fixtures, then port.**
An unspecified estimator should not be invented in Rust.

## 9. Amendments this spike proposes to other documents

Recorded here rather than applied directly. ADR-0001–0004, the implementation plan and
`docs/specs/` are, at the time of writing, uncommitted files in a sibling worktree that was
being actively modified — editing them from this branch would race another session's work.
These amendments should be applied by whoever owns those files, or in a follow-up once they
land. Line references are to the versions read on 2026-08-12.

### 9.1 ADR-0002 — cross-platform bit-determinism

1. **Correct the "deterministic by construction" claim** for a hand-written Rust forward pass.
   It is true only once transcendentals come from `libm`; Rust std documents `exp`/`ln`/
   `powf`/`tanh` precision as varying by platform, Rust version and invocation. Full
   reasoning in §3.2.
2. **Audit item 3 (Clarabel backend) is partly closed.** Verified against Clarabel 0.11.1:
   `default = ["serde"]` pulls **no BLAS**; BLAS enters only via the `sdp*` features
   (`sdp-accelerate`, `sdp-netlib`, `sdp-openblas`, `sdp-mkl`, `sdp-r`) and `faer-sparse`
   only via the `julia` feature. The two cone implementations a QP touches — `nonnegative.rs`
   and `zerocone.rs` — contain no `exp`, `ln` or `powf`. **Scope of that check:** those two
   files plus the top-level `Cargo.toml`. Equilibration, the KKT solve and step-length search
   were not audited, so the remainder of the item stands.
3. **Extend the T5.9 forbidden-feature check** to deny Clarabel's `sdp*` and `julia` features
   alongside nalgebra's BLAS backends.
4. **Fix the citation**: the signing requirement is `BlackLitterman-Reference.md:23`, not
   `:22`. The file is duplicated at `Domains/AI/FinancialModels/` and
   `Domains/AI/financial-models/`; both are byte-identical and both put it at line 23.

### 9.2 Implementation plan

1. **Move the QP cross-check from the `osqp` Rust crate into `cvxpy`** in the Zone B oracle
   package. The plan gates `osqp` behind `--features qp-crosscheck` on a single CI platform
   *specifically because* the crate wraps the OSQP C library and would otherwise drag a C
   toolchain into every runner. cvxpy with ECOS or SCS gives the same independent second
   solver with no C toolchain in any runner, and removes the caveat rather than managing it.
2. **Name the owner of output canonicalisation.** `InputHash` is already correct — SHA-256 of
   the FFI request bytes before parsing, explicitly avoiding dependence on C#-side
   re-serialisation. Apply it symmetrically: serialise, canonicalise and hash the *result* in
   Rust (`serde_json` formats floats via ryu — deterministic shortest round-trip), and have
   C#/KMS sign the hash only. .NET's `double` formatter is deterministic in isolation since
   Core 3.0, but two independently deterministic formatters that disagree on a single value is
   precisely the failure T5.8 exists to catch.
3. **Add two determinism tests** to the T5 tier:
   - HRP linkage tie-breaking (see §9.3).
   - Phase 9 cross-RID hash equality, and rejection of a manifest whose `feature_names` are
     permuted (§4.3).

### 9.3 ADR-0003 — harness models

1. **HRP linkage tie-breaking is an unaddressed determinism hazard.** Equal pairwise distances
   yield different dendrograms depending on iteration order, so HRP needs a documented total
   order over candidate merges. If scipy's `cluster.hierarchy` is the fixture oracle, the Rust
   tie-break must match scipy's or the comparison fails for a reason that is not a bug.
2. **Michaud (MR.2) — library-level detail, not a new requirement.** The plan already requires
   "Michaud seeded and bit-deterministic". Concretely that rules out `rand::StdRng`, whose
   algorithm is explicitly not stable across `rand` major versions. Pin
   `rand_chacha::ChaCha20Rng` 0.10.0 (MIT OR Apache-2.0, verified crates.io 2026-08-12) and
   route the normal-variate transform through `libm`.
3. **`libm` discipline extends beyond Phase 9.** The eigenvalue-entropy feature uses `ln`. If
   `statrs` 0.19.1 (MIT) is adopted for the `norm.ppf` that prediction intervals need, audit
   it for std transcendentals on the same basis as §3.2.
