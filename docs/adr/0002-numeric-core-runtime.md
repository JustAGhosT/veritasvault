# ADR-0002 — Numeric core runtime: Rust native library via P/Invoke

|             |                                                                                                                           |
| ----------- | ------------------------------------------------------------------------------------------------------------------------- |
| **Status**  | **Accepted** (runtime choice), **Proposed** (FFI design details below)                                                    |
| Date        | 2026-08-12                                                                                                                |
| Decision by | Repository owner, this session                                                                                            |
| Related     | [ADR-0001](./0001-black-litterman-model-conventions.md), [Implementation plan](../black-litterman-implementation-plan.md) |

## Context

An earlier draft of the implementation plan assumed the Black-Litterman solver
would be written in C# against MathNet.Numerics, on the reasoning that the
platform is a .NET solution and in-process is simplest.

That reasoning does not survive contact with three facts:

1. **.NET has no maintained quadratic programming solver.** Verified on
   nuget.org: `Accord.Math` is archived at 3.8.0, `Google.OrTools` 9.15's
   continuous solvers are LP, and alglib's free edition is GPL — incompatible
   with a commercial product. The C# plan therefore required hand-rolling
   Goldfarb–Idnani: ~200 lines of subtle numerical code the team would own
   permanently, written only because the ecosystem lacked an alternative.
2. **The test oracle was going to be a different language anyway.** The
   differential-testing tier specifies numpy/PyPortfolioOpt as the reference.
   Having the reference implementation be more trustworthy than the
   implementation under test is an argument about which one should be shipping.
3. **Phase 9 is already written in another language.** The ML shrinkage specs
   (`bl-ai-shrinkage-loss-kl-gaussian.md`, `bl-ai-shrinkage-loss-spectral.md`)
   are TensorFlow, not language-neutral pseudocode. No plan that assumes C# for
   that phase is credible.

## Decision

**The numeric core is a Rust library, consumed from .NET as a native library via
P/Invoke.** C# retains DTO contracts, validation, CQRS orchestration, and the
HTTP surface; it performs no numerical computation.

```
crates/vv-portfolio-core/    pure Rust: BL math, optimizer, attribution. No FFI, no C ABI.
crates/vv-portfolio-ffi/     cdylib: thin C ABI shim. Serialization + panic containment only.
src/vv.Analytics/     C# P/Invoke bindings, SafeHandle, IBlackLittermanEngine impl.
```

`vv-portfolio-core` knows nothing about FFI and is testable with `cargo test` alone.
That separation is what keeps the mathematics debuggable.

**On the name.** An earlier draft called this `vv-bl-core`. That boxes it in: this
repository already carries specifications for `MarkowitzModel.md`,
`MichaudResampling.md`, `EqualRiskContribution.md` and `portfolio-optimization.md`,
every one of which needs the same optimizer, the same covariance estimators, and
the same matrix guards. Black-Litterman is a `black_litterman` module inside a
portfolio-mathematics crate, not the crate itself. Renaming later means churning
the FFI package name, the NuGet id, and every downstream reference — cheap now,
expensive after Phase 7. The C ABI entry point stays `vv_bl_solve` precisely so
that a future `vv_mvo_solve` can sit beside it.

### Dependencies

Verified on crates.io, 2026-08-12. Local toolchain confirmed: cargo/rustc 1.97.1.

| Crate                  | Version | Licence        | Downloads | Role                                                  |
| ---------------------- | ------- | -------------- | --------- | ----------------------------------------------------- |
| `nalgebra`             | 0.35.0  | Apache-2.0     | 83.1M     | dense LA: Cholesky, symmetric eigendecomposition, SVD |
| `clarabel`             | 0.11.1  | Apache-2.0     | 1.67M     | interior-point conic solver — **the QP**              |
| `serde` / `serde_json` | —       | MIT/Apache-2.0 | —         | FFI payload                                           |

**Every dependency is permissive-licensed.** On the .NET side the only mature QP
option was GPL; that constraint disappears here. This is a genuine and slightly
unexpected advantage of the Rust route.

`clarabel` is the reference implementation of that solver — its Python and Julia
packages are wrappers over this crate — so using it from Rust removes a layer
rather than adding one. `faer` 0.24.4 (MIT) was considered for the linear algebra
and is faster, but `nalgebra`'s maturity and documentation matter more than speed
at n ≤ 50, where a full solve is sub-millisecond either way.

### QP formulation for Clarabel

Clarabel takes `min ½xᵀPx + qᵀx  s.t.  Ax + s = b, s ∈ K`. The portfolio problem
maps cleanly:

```
maximize   wᵀμ − (λ/2) wᵀΣw
⟺ minimize ½ wᵀ(λΣ) w − μᵀw          so  P = λΣ,  q = −μ

budget   Σw = 1              →  ZeroCone block
L ≤ Aw ≤ U                   →  two NonnegativeCone blocks
box 0 ≤ w ≤ 1                →  special case of the above
```

**Spike required before Phase 5 commits to this**: confirm Clarabel 0.11's exact
Rust API surface and cone-construction ergonomics against a worked example. The
version and licence are verified; the API shape is not.

## FFI design

This is where projects of this shape fail, so the rules are explicit.

### One call per solve, self-describing payload

The C ABI is deliberately narrow — **not** a chatty surface passing matrix
pointers:

```c
int32_t vv_bl_solve(const uint8_t* req, size_t req_len,
                    uint8_t** out, size_t* out_len);
void    vv_bl_free(uint8_t* ptr, size_t len);
int32_t vv_bl_abi_version(void);
```

Request and response are JSON (`serde` ⇄ `System.Text.Json`).

Rationale: at n ≤ 50 the covariance matrix is ~20 KB and there is **one crossing
per HTTP request**, so serialization cost is irrelevant next to correctness.
Marshalling nested variable-length arrays across P/Invoke means manual
`[StructLayout]`, pinning, and lifetime management — precisely the class of bug
that produces silent memory corruption rather than a clean failure. JSON is
self-describing and versionable, and `vv_bl_abi_version` lets C# refuse a
mismatched binary at startup instead of misreading it.

If profiling ever shows this matters — it will not at this size — a flat
`f64` buffer layout can replace JSON behind the same wrapper.

**Critically, the entire solve happens Rust-side, including the `2k+1`
attribution solves from [ADR-0001 §D5](./0001-black-litterman-model-conventions.md#d5--definitions-for-the-undefined-result-fields).**
Attribution must use the same optimizer and constraints as the main solve, so a
per-solve boundary crossing would be both slow and incoherent.

### Memory ownership

Rust allocates the response; **Rust frees it.** C# wraps the pointer in a
`SafeHandle` subclass so release happens even on exception.

**Never free Rust-allocated memory with `Marshal.FreeHGlobal`** — different
allocator, immediate heap corruption. This is stated here because it is the
mistake that gets made.

### Panics must not cross the boundary

Unwinding across an FFI boundary is undefined behaviour. Every `extern "C"`
entry point wraps its body in `std::panic::catch_unwind` and converts a panic
into an error status code. `panic = "abort"` is **rejected** — it would take down
the API process on a bad input.

### Error handling

Non-zero status code plus a structured error object in the response payload,
carrying the same diagnostics contract as the success path. No `NaN`, no `Inf`,
no sentinel values crossing the boundary — [ADR-0001 §D6](./0001-black-litterman-model-conventions.md#d6--numerical-policy) applies at the Rust
edge, not just the C# one.

### C# binding style

`[LibraryImport]` (source-generated, .NET 7+), not `[DllImport]` — no runtime
marshalling stubs, AOT-friendly. Requires `partial` methods and
`AllowUnsafeBlocks`.

## Cross-platform bit-determinism is a hard requirement

`BlackLitterman-Reference.md:22` requires that _"all model inputs and outputs are
cryptographically signed and auditable."_ That promotes reproducibility from a
nice-to-have to a **correctness constraint**: if a solve on a Windows developer
machine and the same solve in a Linux production container differ by one ULP, the
signature does not verify and the audit trail is worthless.

This is a real risk under ADR-0002 and it is cheap to eliminate _if decided now_
and expensive to retrofit:

1. **`nalgebra` must stay on its pure-Rust path.** It is deterministic by
   default, but enabling any BLAS/LAPACK feature delegates to a vendor kernel
   whose result depends on CPU dispatch and thread count. The BLAS features are
   **forbidden**, enforced by a CI check on the resolved feature set, not by
   convention.
2. **No `-C target-cpu=native`.** It selects different SIMD paths per build
   machine, which changes summation order and therefore the last bits. Pin an
   explicit baseline target-feature set per RID.
3. **Audit `clarabel`'s backend.** It may optionally link an external linear
   solver; confirm the default is pure Rust and single-threaded, or pin it so.
   Fold this into the Clarabel API spike already scheduled before Phase 5.
4. **CI proves it rather than assuming it**: run the golden fixtures on all three
   RIDs, hash the canonicalized result JSON, assert the hashes are equal. A
   determinism claim that is not tested is a determinism hope.

Rust helps here — no fast-math by default, and no implicit FMA contraction — but
none of that survives a BLAS backend or `target-cpu=native`, so the guard rails
are explicit.

**Consequence for Phase 9.** Any ONNX runtime with SIMD or threading backends is
a direct threat to this constraint, which raises the bar on that spike
considerably: a hand-written pure-Rust forward pass is deterministic by
construction where a general inference runtime is not.

## Build and distribution — the real cost

This is what the Rust choice actually costs, stated plainly.

1. **Cross-platform build matrix.** `win-x64`, `linux-x64`, and `osx-arm64` for
   local development. If anything deploys to Alpine, `linux-musl-x64` as well —
   glibc/musl is not interchangeable and the failure mode is a load error at
   startup.
2. **Packaged as NuGet with `runtimes/{rid}/native/` layout**, so `dotnet publish`
   selects the correct binary automatically. Retrofitting this later is worse
   than doing it now; do not start with loose files copied to output.
3. **CI**: build Rust on three runners, pack, publish to an internal feed. This
   is the largest single new piece of infrastructure in the plan.
4. **Reproducibility**: pin the toolchain with `rust-toolchain.toml`, commit
   `Cargo.lock`.

## Consequences

**Positive**

- No hand-rolled QP. Clarabel is a maintained interior-point solver with a real
  user base, replacing ~200 lines the team would otherwise own forever.
- All dependencies permissive-licensed.
- `proptest` gives property-based testing of the ADR-0001 invariants (B1–B5,
  τ-invariance) across generated inputs, which is stronger than hand-written
  example cases.
- `cargo miri` can check the core for UB — a class of assurance unavailable in
  the C# plan.
- The math is testable with `cargo test`, with no .NET, no DI container, and no
  HTTP in the loop.

**Negative**

- Debugging across the FFI boundary is worse than in-process. Mitigated by
  keeping `vv-portfolio-core` FFI-free and reproducing every failure as a `cargo test`.
- **No off-the-shelf Ledoit–Wolf.** It must be written (~40 lines, closed-form),
  where sklearn would have supplied it. Acceptable — a closed-form estimator is a
  very different proposition from a QP solver, and it is validated against
  sklearn output captured as a fixture.
- CI and packaging cost, as above.
- Rust is present in this workspace (phoenix-rooivalk) but is not this team's
  primary language.

**Phase 9 is not stranded.** The TensorFlow shrinkage models do not run in Rust,
but they do not need to: train in Python, export ONNX, infer in Rust via the
`ort` crate (15.4M downloads, MIT/Apache-2.0). Caveat verified and worth
recording — `ort` currently publishes **release candidates only**, no stable
version on crates.io as of 2026-08-12. Phase 9 needs its own spike; it is not
resolved by this ADR.

## Rejected alternatives

| Option                                       | Why not                                                                                                                                                                                       |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **C# + MathNet + hand-rolled QP**            | No maintained .NET QP solver; requires owning Goldfarb–Idnani; Phase 9 not credible in .NET                                                                                                   |
| **Python sidecar (FastAPI + cvxpy)**         | Strongest ecosystem fit and the recommendation this ADR did not take — rejected in favour of a single deployed artifact with no additional runtime, and no second language runtime to operate |
| **Hybrid: C# through Phase 3, Python after** | Splits the engine mid-pipeline; attribution needs `2k+1` solves against the same optimizer, so the seam lands in the worst possible place                                                     |
| **MATLAB**                                   | Not a server runtime. Retains relevance as a _source_ of golden vectors — Meucci's reference code is MATLAB                                                                                   |
