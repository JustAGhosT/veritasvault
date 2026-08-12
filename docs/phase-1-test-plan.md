# Phase 1 Test Plan — VeritasVault Estate

Spike output. Prioritised plan to close the automated-testing gap across `JustAGhosT/vv-landing`
(Next.js 15 web platform) and `JustAGhosT/vv` (this repo, .NET).

Date: 2026-08-12. All figures below were measured, not estimated; method is stated inline.

---

## 0. Headline: the framing needs to change

The register describes this as a **testing gap**. Measurement says it is currently a
**live-defect gap that the absence of tests is concealing**.

While scoping which tests to write first, the following were found by reading the code that
the first tests would have to cover. These are not hypothetical failure modes:

| #   | Finding                                                                                                                                  | Evidence                                                                                                                                                                                                                                                  | Status                                                                                           |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| 1   | `PUT /api/settings/{key}` is an **unauthenticated write** to the production settings table using the **service-role key** (bypasses RLS) | [`app/api/settings/[key]/route.ts`](https://github.com/JustAGhosT/vv-landing/blob/main/app/api/settings/%5Bkey%5D/route.ts) imports `createClient` from `lib/supabase.ts`, whose server branch uses `SUPABASE_SERVICE_ROLE_KEY`; no auth call in the file | Reachable from the public internet                                                               |
| 2   | `GET /api/settings` dumps the whole settings table, same client, no auth                                                                 | same file + `app/api/settings/route.ts`                                                                                                                                                                                                                   | Reachable                                                                                        |
| 3   | JWT signing/verification **falls back to a hardcoded secret committed to the repo**                                                      | `lib/auth/auth-utils.ts:6` — `process.env.JWT_SECRET \|\| "your-secret-key-at-least-32-chars-long"`                                                                                                                                                       | Fails **open**: if the env var is unset, anyone can forge a valid session                        |
| 4   | Route-level auth enforcement is **dead code**                                                                                            | `lib/auth/auth-middleware.ts` exports `checkAuthStatus`/`isProtectedRoute`; repo-wide grep finds **zero importers**. `middleware.ts` only blocks WordPress probes and sets headers                                                                        | No edge auth on `/std\|corp/dashboard`, `/settings`, `/analytics`, …                             |
| 5   | `POST /api/voting/vote` has **no auth and no user attribution**                                                                          | `app/api/voting/vote/route.ts` — `updateVote(proposalId, vote)` takes no user id                                                                                                                                                                          | Anyone can vote; votes aren't tied to identity                                                   |
| 6   | Three mutually incompatible auth systems coexist                                                                                         | custom `jose` JWT (`auth-utils.ts`), Supabase SSR (`auth-middleware.ts`), NextAuth (`app/api/auth/[...nextauth]`)                                                                                                                                         | `withAuth` only understands the custom JWT — a GitHub-login user gets 401 from `withAuth` routes |
| 7   | `/api/portfolio/summary` returns a **hardcoded $1,000,000 mock portfolio** to any caller                                                 | `app/api/portfolio/summary/route.ts` is entirely `mockData`                                                                                                                                                                                               | The exact "wrong numbers shown to an investor" failure mode                                      |
| 8   | Risk score `0` is silently rewritten to `40`                                                                                             | `app/api/risk-assessment/route.ts` — `assessment.counterparty_score \|\| 40`                                                                                                                                                                              | Lowest-risk reads as moderate-risk                                                               |
| 9   | Missing risk assessment returns a **fabricated plausible profile**, not an empty state                                                   | same file, the `!assessment` branch invents `overall: 50` + five category scores                                                                                                                                                                          | Client cannot distinguish real from invented                                                     |
| 10  | AI fallback generates **`Math.random()` APY forecasts** with `confidence: 0.7`                                                           | `app/api/ai/route.ts` `getFallbackData()`; grep finds no consumer checking the `fallback` flag                                                                                                                                                            | Random numbers presented as forecasts                                                            |

**Auth coverage, measured across all 45 route files:** 36 have no identity check and no shared-secret
check of any kind. Some of those are legitimately public (OG images, navigation, marketing content,
public market data). The ones that are not: `settings`, `settings/[key]`, `voting/vote`,
`portfolio/summary`, `dashboard/overview`, `dashboard/performance`, `investor-metrics`,
`activities/recent`, `process-status/[id]`, `liquidity-pools/[id]/performance`, and all five `ai/*`
routes (metered LLM spend, unauthenticated).

**RLS:** 3 of 14 migrations contain `ENABLE ROW LEVEL SECURITY` / `CREATE POLICY`. For the ten routes
that reach the service-role client this is moot — service role bypasses RLS regardless.

**Implication for sequencing.** Findings 1–3 should be fixed on their own timeline, not held behind
a test-infrastructure programme. The plan below writes the regression test _with_ each fix, so the
first ten tests are a defect inventory rather than coverage padding — **eight of the ten fail on
first run against `main` today**.

---

## 1. Test stack for vv-landing

### What is already there

Measured against the repo's `HEAD` tree (`git ls-tree -r HEAD`):

- **933** `.ts`/`.tsx` files, 1,159 files total
- **45** API route files (43 `route.ts` + 2 OG `route.tsx`), **89** `page.tsx`, **14** migrations
- **0** files matching `\.(test|spec)\.[jt]sx?$`; **0** `__tests__` directories
- **No test runner in `package.json`** — no Vitest, Jest, Playwright, or `@testing-library/*`.
  There is no unused config to adopt; this is greenfield.

One asset does exist: **MSW 2.0** is already a dependency with a `dev:mocks` script and a `mocks/`
directory. That is directly reusable for network-boundary stubbing.

### Recommendation

| Layer              | Tool                                                            | Why                                                                                                                                                                                                                                                                                                  |
| ------------------ | --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Unit + integration | **Vitest 3**                                                    | Native ESM + TS, no Babel step. Jest still needs `next/jest` and struggles with ESM-only deps already in this tree (`jose`, `ai` SDK, `@supabase/ssr`). Vitest's `environmentMatchGlobs` lets route tests run in `node` and component tests in `jsdom` in one run — needed here because both matter. |
| Component          | **React Testing Library** + `vitest-browser-react` if RSC bites | React 19 + App Router. Note RTL cannot render async Server Components; those get covered by E2E instead of being forced into unit tests.                                                                                                                                                             |
| Network boundary   | **MSW 2**                                                       | Already installed. Stub Goldsky, CoinGecko, OpenAI at the HTTP boundary rather than mocking modules — the AI/market-data routes all go through `fetch`.                                                                                                                                              |
| Route handlers     | **Vitest + direct handler invocation**                          | App Router handlers are plain `(Request) => Response` functions. Import and call them with a constructed `NextRequest`. No server needed, milliseconds per test. This is what makes the auth matrix (test 4) cheap.                                                                                  |
| E2E                | **Playwright**                                                  | Auth redirect flows, RSC pages, and the OAuth callback need a real browser. Keep the suite small — ~10 specs, not a mirror of the unit suite.                                                                                                                                                        |
| DB                 | **Supabase local (Docker)** for migration/RLS tests             | The 14 migrations and RLS policies cannot be meaningfully tested against mocks. Run `supabase start` in CI for one dedicated job.                                                                                                                                                                    |

Not recommended: Jest (ESM friction with this dependency set), Cypress (Playwright is
better for multi-origin OAuth), and any snapshot-heavy component approach (locks in markup,
catches nothing that matters here).

**Why this suits Next.js 15 App Router specifically:** the highest-value surface in this codebase
is 45 pure request→response functions. They need no framework harness, no rendering, and no server.
Vitest calling them directly gives near-unit-test speed on genuinely integration-level assertions.
The App Router's `route.ts` convention is what makes the table-driven auth matrix possible at all.

---

## 2. Coverage gate for Phase 1 exit

**Do not gate on a global percentage.** Bottom-up arithmetic shows why: the files worth testing
(45 routes + ~10 repositories + ~8 auth/lib modules + risk/allocation transforms) are roughly
75–80 of 933 files, on the order of 6–8k of ~87k LOC. Covering all of them at 85% yields
**~10–12% global line coverage**. A global gate of 80% is not ambitious, it is unreachable; and any
number low enough to pass would be hit faster by testing 455 presentational components than by
testing the money paths. Percentage gates on this shape of codebase actively misdirect effort.

### Proposed Phase 1 exit gate

| Gate                           | Threshold                                                                           | Enforcement                                                                  | Justification                                                                                                                                                                       |
| ------------------------------ | ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A. Diff coverage**           | **≥ 70%** on new/changed lines                                                      | SonarCloud "Coverage on New Code"                                            | Already the mechanism Sonar uses; 70% is Sonar's own default and is defensible without invention. Stops the hole getting deeper.                                                    |
| **B. Critical-path checklist** | **100% of a named file list** has ≥1 test asserting its auth + correctness contract | CI job asserting each path in `test/critical-paths.json` has a matching spec | A binary, auditable gate. "Every money/auth/allocation path has a test that would fail if its contract broke" is a claim you can defend to an investor; "31% line coverage" is not. |
| **C. Global ratchet**          | Coverage **may not decrease** vs `main`                                             | Sonar quality gate + Codecov-style ratchet                                   | Turns an unbounded problem into a monotonic one.                                                                                                                                    |
| **D. Absolute floor**          | **vv-landing ≥ 15% line**, measured                                                 | `vitest --coverage` threshold                                                | Deliberately low and _honest_. It is the number the bottom-up estimate supports for the scoped work. Publishing 15% that is true beats 80% that is aspirational.                    |

For the critical set itself (list B), require **90% line / 80% branch** — a bounded set of ~80 files
where that is achievable.

### .NET side — and a prerequisite

**Do not publish the current 11.5% figure until the denominator is re-baselined.** The cause has
been identified — two verified wiring defects, not a subtle instrumentation issue:

1. **`tests/vv.Application.Tests` has no `.csproj`** and does not appear in `vv.Platform.sln`.
   Its two test files (`MarketDataServiceTests.cs`,
   `ValidationMarketDataServiceDecoratorTests.cs`) **never compile and never run**. Of the 15 test
   files on disk, 13 execute.
2. **`tests/vv.Api.Tests` did not reference `coverlet.collector`**, so it contributed **zero**
   coverage data regardless of what it tested.

Only `vv.Infrastructure.Tests` was ever instrumented. That is why the denominator is
**468 coverable lines** against **8,236 LOC** in the three included assemblies (Infrastructure
4,696 / Core 1,310 / Application 2,230) — ~5.7%, where C# sequence-point density normally runs
30–45%.

Both defects are fixed in this change (coverlet added to `vv.Api.Tests`; `[vv.Api]*` added to the
runsettings `Include`). **`vv.Application.Tests` still has no project file** — creating one is a
separate task, and doing so will surface two previously-unrun tests that may not pass.

_Boundary: the suite has not been executed here. The re-baselined figure is expected to move — most
likely down, since the denominator grows. Confirm on the first green run before quoting any .NET
coverage number externally._

Proposed .NET Phase 1 gate, **after** re-baselining:

| Scope               | Line | Branch |
| ------------------- | ---- | ------ |
| `vv.Infrastructure` | 45%  | 35%    |
| Solution overall    | 35%  | 25%    |

Rationale: Infrastructure is the largest project (4,696 LOC) and holds the correctness risk. 45% is
what the ranked work below (Cosmos repository 603 LOC, query extensions 447, versioned repository
343, versioning component 170, mappers ~200) actually buys — those five areas are ~1,760 LOC, and
covering them well lands Infrastructure near 45% on its own. Note the existing
`coverage-threshold.xml` already declares 50% for Infrastructure — 45% is chosen as the honest
first ratchet, with 50% as the next step, not the Phase 1 gate.

---

## 3. CI wiring so coverage cannot regress

Two defects in the current pipeline, both measured:

1. **`coverage-threshold.xml` is enforced by nothing.** Repo-wide grep for `coverage-threshold`
   returns only the file itself. Its 60/70/50 thresholds have never gated anything.
2. **The threshold step cannot fail the build.** `.github/workflows/build-and-test.yml` uses
   `irongut/CodeCoverageSummary@v1.3.0` **without `fail_below_min`**, so it reports and passes.

### Changes

**This repo (.NET)** — in `build-and-test.yml`:

```yaml
- name: Check code coverage threshold
  uses: irongut/CodeCoverageSummary@v1.3.0
  with:
    filename: coverage-report/Cobertura.xml
    fail_below_min: true # <-- currently absent; without it the gate is decorative
    thresholds: "35 60" # fail under 35% line, warn under 60%
    badge: true
    format: markdown
    output: both
```

Also drop `--no-build` from the coverage run, or verify instrumentation covers all three assemblies
(see the denominator issue above).

**vv-landing** — new `.github/workflows/test.yml`, three jobs:

- `unit` — `vitest run --coverage`, thresholds from `vitest.config.ts`, uploads `lcov.info`
- `critical-paths` — asserts every entry in `test/critical-paths.json` has a spec (gate B)
- `e2e` — Playwright, sharded, on PR only

**SonarCloud.** No Sonar step or config existed in any workflow, so coverage was never reaching
Sonar — its quality gate has been evaluating code smells and reliability but **not** coverage.

Two mechanism details matter here and change the fix:

- **SonarScanner for .NET does not read `sonar-project.properties`.** Analysis parameters must be
  passed as `/d:` arguments to `dotnet sonarscanner begin`. A properties file added to this repo
  would look configured and do nothing. Wiring is therefore in `build-and-test.yml` (now added),
  with `begin` before the build and `end` after the tests, since the scanner hooks MSBuild.
- **SonarCloud Automatic Analysis cannot import coverage reports.** With no CI analysis step
  present, this project must currently be on Automatic Analysis. It has to be switched off at
  _Project → Administration → Analysis Method_ or the CI-based analysis will be rejected and
  coverage will still never appear.

C# coverage is imported via `sonar.cs.opencover.reportsPaths`; the runsettings already emit
`opencover` alongside `cobertura`, so no change was needed there. `sonar.qualitygate.wait=true`
makes the job block on the verdict instead of reporting and passing.

For **vv-landing** a `sonar-project.properties` _is_ the correct mechanism (the JS/TS CLI scanner
does read it) — written, pointing at `coverage/lcov.info`, and inert until the Vitest suite exists.

The gate condition itself — _Coverage on New Code ≥ 70%_ — is a SonarCloud-side setting on the
quality gate, not a repo file. See §3.1.

**Ordering note.** Turn gate A (diff coverage) on _first_, before writing tests. It costs nothing
today — there is no new code in flight — and it stops the gap widening while the backlog is worked.
Gates B and D come on as the first ten tests land.

### 3.1 Turning the diff-coverage gate on — remaining manual steps

The repo-side wiring is committed. The following cannot be done from the repository and must be
performed in SonarCloud by someone with admin on the project:

1. **Add the `SONAR_TOKEN` secret.** SonarCloud → _My Account → Security_ → generate a token, then
   add it at GitHub → _Settings → Secrets and variables → Actions_. Without it the new
   `SonarCloud begin` step fails and takes the build with it.
2. **Disable Automatic Analysis.** SonarCloud → _Project → Administration → Analysis Method_ →
   turn off Automatic Analysis. CI-based analysis is rejected while it is on, and Automatic
   Analysis never imports coverage.
3. **Confirm the project key and organization.** `build-and-test.yml` uses
   `/k:"JustAGhosT_vv" /o:"justaghost"`, derived from the GitHub slug by SonarCloud's usual import
   convention. **This is a convention-based guess and has not been verified** — check the real
   values on the project's _Information_ page and correct the workflow if they differ.
4. **Add the gate condition.** SonarCloud → _Quality Gates_ → the gate applied to this project →
   _Add Condition_ → On New Code → **Coverage** → **is less than 70%**. Keep the existing
   A-reliability-on-new-code condition.
   Use a **custom** gate, not the built-in "Sonar way" — built-in gates cannot be edited, so the
   condition has to go on a copy that is then assigned to the project.
5. **Set the New Code definition** to _Previous version_ or _Number of days_, whichever matches the
   release cadence. This determines what "new code" means and therefore what the gate measures.
6. **Make the check required.** GitHub → _Settings → Branches → main_ → require the SonarCloud
   status check. `sonar.qualitygate.wait=true` fails the job, but only branch protection stops a
   merge.

Do steps 1–3 before 4. Enabling the condition while analysis is still failing produces a red gate
on every PR for the wrong reason and invites people to route around it.

---

## 4. The first ten tests, in order

Ordered by _(cost of failure × probability currently broken) ÷ effort_. Eight of the ten are
expected to **fail on first run** — that is deliberate. Each is written alongside the fix.

| #   | Test                                                                                                                             | Target                                           | Expected first run        |
| --- | -------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ | ------------------------- |
| 1   | `PUT /api/settings/{key}` rejects an unauthenticated write                                                                       | `app/api/settings/[key]/route.ts`                | **FAIL**                  |
| 2   | `GET /api/settings` rejects an unauthenticated read                                                                              | `app/api/settings/route.ts`                      | **FAIL**                  |
| 3   | A token signed with the literal default secret is rejected; `withAuth` refuses to start when `JWT_SECRET` is unset               | `lib/auth/auth-utils.ts`                         | **FAIL**                  |
| 4   | **Auth matrix** — table-driven over all 45 routes: each is either in an explicit public allowlist or returns 401 unauthenticated | all `app/api/**/route.ts`                        | **FAIL** (36 unprotected) |
| 5   | `POST /api/voting/vote` requires auth and attributes the vote to the caller                                                      | `app/api/voting/vote/route.ts`                   | **FAIL**                  |
| 6   | `middleware.ts` redirects unauthenticated requests for each `protectedPatterns` entry                                            | `middleware.ts`, `lib/auth/auth-middleware.ts`   | **FAIL** (dead code)      |
| 7   | `counterparty_score: 0` renders as `0`, not `40`                                                                                 | `app/api/risk-assessment/route.ts`               | **FAIL**                  |
| 8   | Absent assessment returns an explicit empty state, not invented scores                                                           | `app/api/risk-assessment/route.ts`               | **FAIL**                  |
| 9   | `/api/portfolio/summary` returns caller-scoped data and never the `$1,000,000` fixture                                           | `app/api/portfolio/summary/route.ts`             | **FAIL**                  |
| 10  | AI fallback is labelled and no `Math.random()` value is presented as a forecast                                                  | `app/api/ai/route.ts` + `allocation-section.tsx` | **FAIL**                  |

### Why this order

- **1–3 first** because they are live, internet-reachable, and fail open. 1 before 2 because an
  unauthenticated _write_ with an RLS-bypassing key outranks a read. 3 third because it is the
  widest blast radius (forge any session) but needs an env-var change rather than a code path fix,
  so it can land in parallel.
- **4 is the leverage multiplier** and is deliberately placed before the remaining individual holes.
  One table-driven test converts "we don't know which routes are protected" into a tracked,
  enforced inventory, and fails on every future unprotected route. It is also the cheapest test
  here — App Router handlers are plain functions, so all 45 run in well under a second. Writing 4
  before 5–6 means those two become line items in an existing matrix rather than bespoke specs.
- **5–6** close the remaining auth holes: governance writes, then the dead edge middleware.
- **7–10 are the "wrong numbers to an investor" class**, ordered by how silently each fails.
  7 is a one-character bug (`||` → `??`) with a plausible-looking wrong output — the hardest to spot
  by eye and the cheapest to pin. 8 and 9 return entirely fabricated data that renders identically
  to real data. 10 is last in this group only because the random forecast at least carries a
  `fallback: true` marker — the defect is that nothing reads it.
- Deprioritised throughout, per the brief: the 455 presentational components, marketing pages, and
  static content. None appear above.

**Immediately after these ten:** the Supabase data layer — `lib/repository/base-repository.ts` and
the two split repository directories (`lib/repository/` and `lib/repositories/` both exist, a
split-brain data layer worth consolidating first), then RLS policy tests against a local Supabase
for the 11 migrations that lack policies.

---

## 5. .NET — vv.Infrastructure first

Ranked by LOC × correctness risk. Coverage tooling is already wired
(`Generate-CoverageReport.ps1` / `.sh`, `coverage.runsettings`).

| Order | Target                                                              | LOC  | Why                                                                            |
| ----- | ------------------------------------------------------------------- | ---- | ------------------------------------------------------------------------------ |
| 0     | **Re-baseline the denominator**                                     | —    | Prerequisite; see §2. Everything below is unmeasurable until this is resolved. |
| 1     | `Repositories/CosmosRepository.cs`                                  | 603  | Largest single file, all persistence flows through it                          |
| 2     | `Repositories/Extensions/CosmosRepositoryQueryExtensions.cs`        | 447  | Query construction — silent wrong-result risk                                  |
| 3     | `Repositories/VersionedCosmosRepository.cs`                         | 343  | Versioning correctness; wrong version = wrong data served                      |
| 4     | `Repositories/Components/VersioningComponent.cs`                    | 170  | Core versioning logic, named in the brief                                      |
| 5     | `Mapping/*Mapper.cs`                                                | ~200 | Partial tests exist (2 of 3 mappers); `BaseMarketDataMapper` uncovered         |
| 6     | `Repositories/Extensions/CosmosRepositoryPartitionKeyExtensions.cs` | 157  | Partition key errors are silent cross-tenant read risk                         |

Existing tests already cover Repository CRUD/batch/delete/query/error-handling shapes and two
mappers — extend those files rather than starting new ones.

---

## 6. Caveats and what was not done

- **No tests were written.** This is a spike; authoring follows.
- **`/team-testing` is not available in this repo.** `ls .claude/commands/` returns nothing and
  `.claude/` does not exist — the Retort slash commands are only present in onboarded repos. The
  workspace convention of delegating test authoring to the TESTING agent cannot be followed here
  until this repo is onboarded to Retort ([onboarding ticket](https://github.com/phoenixvc/retort/issues/new?title=Onboard+vv&labels=onboarding)),
  or the tests are written directly.
- **vv-landing was measured from the commit tree, not a working checkout.** The clone hit Windows
  `MAX_PATH` on
  `components/corporate/dashboard/tools/strategies-dashboard/components/performance/…`; counts come
  from `git ls-tree -r HEAD`. Worth noting independently: that path depth will break Windows CI
  runners and any Windows dev without `core.longpaths`.
- **Counts differ slightly from the brief** (measured: 45 route files, 89 `page.tsx`; brief: 44 and
  93). Method is stated above; the difference does not change any conclusion.
- **The security findings were not exploited**, only read from source. Findings 1–3 warrant
  verification against the live deployment and, if confirmed, disclosure handling rather than a
  routine backlog ticket.
