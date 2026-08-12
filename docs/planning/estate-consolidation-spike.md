---
document_type: architecture
classification: internal
status: draft
version: 0.1.0
last_updated: '2026-08-12'
applies_to:
- Core
reviewers:
- '@tech-lead'
priority: p2
next_review: '2026-11-12'
---

# VeritasVault Estate Consolidation — Planning Spike

**Date:** 2026-08-12
**Risk addressed:** "Estate fragmentation" — `docs/investor/veritasvault-investor-overview.html:1251`

**Status: partially executed.** This began as a planning-only spike; execution of Phases 0–4 was authorised on 2026-08-12.

| Phase                | State                                                                                                                                                                                                                                                        |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 0 — mirror backups   | **Done.** All 15 artifacts, full history, 87 MB → `C:\Users\smitj\backups\vv-estate-20260812`. Verified reachable-refs, not shallow. **Outstanding: Vercel env-var and cron-schedule capture (§5a) — not yet done, and not possible without Vercel access.** |
| 1 — zero-risk fixes  | **Not done.** Needs GoDaddy access (delete `docs` CNAME) and Vercel access (`vercel.json`). Lockfile de-dup and the `wss://api.yourdomain.com` placeholder are still open.                                                                                   |
| 2 — archive the dead | **Done.** 9 repos archived: `vv-chain`, `vv-docs-v1`, `vv-documentation`, `vv-auth-frontend-demo`, `veritasvault-cognitive-mesh-nexus`, `vv-auth`, `vv-chain-services`, `vv-dev-tools`, `phoenixvc/phoenix-marketdata`. Nothing deleted.                     |
| 3 — absorb into `vv` | **Done, pending merge.** `vv-iac` → `infra/`, `vv-chain` → `contracts/` via subtree, history preserved (126 → 138 commits). PR #28. `vv-iac` stays active until it merges.                                                                                   |
| 4 — renames          | **Done.** `vv` → `veritasvault`, `vv-landing` → `veritasvault-web`. PRs and production both verified intact.                                                                                                                                                 |
| 5 — DNS to Terraform | Not started. Needs GoDaddy access.                                                                                                                                                                                                                           |
| 5a — Vercel → Azure  | Not started. Decided 2026-08-12; largest remaining item.                                                                                                                                                                                                     |
| 6 — org transfer     | **Blocked** — token lacks `admin:org`.                                                                                                                                                                                                                       |
| 7 — quality baseline | Not started.                                                                                                                                                                                                                                                 |

> _"Eleven repositories with divergent activity raise coordination and drift cost.
> Consolidate or archive dormant repos; one release process across the active core."_

---

## 1. Corrections to the stated inventory

Five findings materially change the picture. Each was measured, not inferred from repo metadata.

| #   | Brief says                                              | Measured reality                                                                                                                                                                                                                                                         | Why it matters                                                                                                                                   |
| --- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | 11 repositories                                         | **13 under JustAGhosT**, +1 archived in `VeritasVault-ai`, +1 predecessor in `phoenixvc` = **15 artifacts**                                                                                                                                                              | Two private docs repos were missed: `vv-docs-v1`, `vv-documentation`. The investor deck's "eleven" undercounts.                                  |
| 2   | `vv-landing` last push Jan 2026                         | Last push Jan 2026 was **Snyk bot branch `snyk-upgrade-0c19c3bf…`**. Last commit on `main` is **2025-06-02**.                                                                                                                                                            | The live platform's `main` has been frozen **14 months**, not 7. Bot traffic makes dormant repos look alive.                                     |
| 3   | `vv` and `vv-landing` are "the two that clearly matter" | They have **zero integration**. `vv-landing` never references the .NET backend — no Azure URL, no `api.veritasvault.net`. Its data layer is Supabase (29 client files), CoinGecko, Goldsky. `NEXT_PUBLIC_API_BASE_URL` defaults to `/api` (its own routes).              | There is no seam to preserve between them. This decides the monorepo-vs-split question (§4).                                                     |
| 4   | (not mentioned)                                         | `vv/package.json` declares `"name": "phoenix-market-data"` and `"repository": "phoenixvc/phoenix-market-data.git"`. **`phoenixvc/phoenix-marketdata`** exists — private, C#, `Phoenix.MarketData.*`, same clean-architecture shape, created 2025-05-12, dead 2025-05-14. | `vv` is a **copy-rename of `phoenix-marketdata` with history not preserved** (`fork: false`, no parent). A 15th artifact and a real duplication. |
| 5   | `vv-docs` ARCHIVED                                      | `docs.veritasvault.net` still has a live GoDaddy CNAME → `vercel-dns.com`, but **TLS handshake fails and HTTP returns 404**.                                                                                                                                             | **Dangling DNS → subdomain-takeover exposure** on a brand hostname. Highest-severity item found. See §7.                                         |

Confirmed as stated: `vv-landing` = 933 TS/TSX, 86,832 LOC, 89 `page.tsx`, 45 API routes, 14 migrations, **0 test files**.

### What is actually live

| Host                     | HTTP       | Serving                 | Backed by                                        |
| ------------------------ | ---------- | ----------------------- | ------------------------------------------------ |
| `veritasvault.net`       | 307 → www  | Vercel                  | `vv-landing`                                     |
| `www.veritasvault.net`   | **200**    | Vercel (cache age 7.2d) | `vv-landing`                                     |
| `games.veritasvault.net` | **200**    | Vercel (cache age 1.7d) | `vv-game-suite`                                  |
| `docs.veritasvault.net`  | **fails**  | nothing                 | dangling → nothing                               |
| `veritasvault.ai`        | **no DNS** | —                       | brand in every repo description does not resolve |
| `api.veritasvault.net`   | **no DNS** | —                       | the .NET backend is deployed nowhere             |

`veritasvault.net` DNS is at **GoDaddy** (`ns59/ns60.domaincontrol.com`), manually managed. Mail is GoDaddy (`smtp.secureserver.net`, `v=spf1 include:secureserver.net -all`).

### Estate-wide governance state

Measured across all 13 repos: **0 releases, 0 tags, 0 branch protection rules.**

`vv-iac/github/Create-VVRepos.ps1` — the script that created the original five — defaults to `$Org = "phoenixvc"` and applies 1-review protection with `enforce_admins:=true`. **None of that intent survives.** The repos live under a personal account with no protection, and the script's own five-repo list (`vv-landing`, `vv-game-suite`, `vv-docs`, `vv-chain-services`, `vv-iac`) shows the other eight accreted unplanned.

Consequence: `vv-auth/.github/workflows/publish.yml` triggers `on: release`. With zero releases ever, **`@veritasvault/vv-auth` was never published** and has no consumers.

---

## 2. Per-repo disposition

Liveness is judged on **last human commit to the default branch**, ignoring bot pushes.

| Repo                                | Last human commit                         | Verdict                                             | Depended on by                             | Duplicated elsewhere                                         |
| ----------------------------------- | ----------------------------------------- | --------------------------------------------------- | ------------------------------------------ | ------------------------------------------------------------ |
| **`vv`**                            | 2026-08-11 (docs only; last code 2025-12) | **Live — sole green CI**                            | nothing                                    | supersedes `phoenixvc/phoenix-marketdata`                    |
| **`vv-landing`**                    | 2025-06-02                                | **Live in prod, dormant in code**                   | serves `veritasvault.net`                  | source of 48 shadcn files copied into 4 repos                |
| `vv-game-suite`                     | 2025-07-19                                | Dormant, **live deployment**                        | serves `games.veritasvault.net`            | no                                                           |
| `vv-docs`                           | 2025-07-10                                | **Dead** (archived)                                 | dangling `docs.` CNAME                     | content overlaps `vv/src/**` 385 MD                          |
| `vv-chain-services`                 | 2025-05-28                                | Dead                                                | Goldsky subgraphs shared with `vv-landing` | `market-data` / `risk` overlap `vv` + `vv-landing`           |
| `vv-iac`                            | 2025-05-11                                | **Dead but historically valuable**                  | nothing (no CI, manual `deploy.ps1`)       | no — holds original estate design                            |
| `vv-chain`                          | 2025-05-18 (3 commits, 11 KB)             | **Dead scaffold**                                   | nothing                                    | no                                                           |
| `vv-auth`                           | 2025-05-27                                | **Dead** (Dependabot-only since)                    | **nothing** — never published              | no                                                           |
| `vv-auth-frontend-demo`             | 2025-05-27                                | **Dead prototype**                                  | nothing                                    | 48/49 shadcn files                                           |
| `veritasvault-cognitive-mesh-nexus` | 2025-07-11 (3 commits / 7 min)            | **Dead throwaway** (Lovable `vite_react_shadcn_ts`) | nothing                                    | 48/49 shadcn; concept lives in `neuralliquid/cognitive-mesh` |
| `vv-dev-tools`                      | 2025-05-24                                | Dead code; **cron ran to 2025-09-22**               | nothing                                    | no                                                           |
| `vv-docs-v1`                        | 2025-05-10                                | **Dead** (missed by inventory)                      | nothing                                    | 48/49 shadcn                                                 |
| `vv-documentation`                  | 2025-05-08                                | **Dead** (missed by inventory)                      | nothing                                    | 48/49 shadcn                                                 |
| `VeritasVault-ai/vv-docs-archive`   | 2025-05-08                                | Dead, already archived                              | nothing                                    | —                                                            |
| `phoenixvc/phoenix-marketdata`      | 2025-05-14                                | **Dead predecessor of `vv`**                        | nothing                                    | superseded by `vv`                                           |

**Duplication measured:** 48 of ~49 `components/ui/*.tsx` filenames are shared between `vv-landing` and each of `vv-documentation`, `vv-docs-v1`, `veritasvault-cognitive-mesh-nexus`, `vv-auth-frontend-demo`. This is v0.dev/Lovable scaffolding, not shared engineering — but it confirms those four repos carry almost no unique substance. Non-boilerplate content: `vv-docs-v1` ~49 files, `nexus` ~29, `vv-auth-frontend-demo` ~58.

**Four documentation attempts exist** (`vv-docs`, `vv-docs-v1`, `vv-documentation`, `vv-docs-archive`) plus 385 markdown files under `vv/src/**`. Documentation is the most fragmented asset in the estate, not code.

---

## 3. Recommended target end-state

**Two repositories. Not a monorepo.**

| Target                                          | Contents                                                                                                        | Rationale                                                                                                                                        |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| **`veritasvault`** (rename of `vv`)             | .NET 9 core (172 `.cs`, 14,288 LOC), 385 domain spec docs, `vv-iac` Bicep, `vv-chain` contracts, investor decks | One toolchain (`dotnet`), one green CI, one owner. Absorbs the dead-but-valuable infra and contract scaffolds so they stop being separate repos. |
| **`veritasvault-web`** (rename of `vv-landing`) | Next.js 15 platform, 14 migrations, Supabase schema, Vercel wiring                                              | Deployment-coupled to Vercel and to `veritasvault.net`. Must keep its own repo root.                                                             |

Everything else archives (§9), with `vv-game-suite` as the one live-deployment exception.

### Why not a monorepo

The monorepo case rests on shared code between backend and frontend. **Finding #3 shows there is none.** Merging would produce:

- **A toolchain collision with no upside.** `dotnet` + `pnpm` in one root, two CI graphs, no shared artifact.
- **Vercel Root Directory churn on the live site.** `vv-landing` has **no `vercel.json`** — every build setting lives only in the Vercel dashboard, uncommitted and unreproducible. Relocating to `apps/web/` requires manually re-pointing Root Directory on the project serving production, with no committed record to restore from.
- **Path-length pressure on Windows.** The deepest path is already 127 chars (`components/corporate/dashboard/tools/strategies-dashboard/components/performance/historical-performance/performance-heatmap.tsx`). Nesting under `apps/web/` makes it 136. That is fine in a normal checkout (`C:\Users\smitj\repos\…` ≈ 33 chars) but **fails past ~124 chars of prefix** — which a Claude Code worktree path (76 chars) survives and a deep temp path does not. _(Measured: a bare clone into the session scratchpad failed with `Filename too long`; the same repo clones fine at a short prefix. This is a caution about deep checkouts, not a blocker on the repo itself.)_
- **No test suite to unify.** `vv-landing` has 0 tests. There is no cross-cutting quality gate that a monorepo would let you share.

The two-repo split preserves the one thing that works (`vv`'s green CI) and isolates the one thing that is load-bearing and fragile (Vercel production wiring).

### The uncomfortable corollary

`vv` and `vv-landing` do not talk to each other. Consolidation is **filing, not integration**. It reduces drift and coordination cost — the stated risk — but it does not make the platform coherent. Building the `vv` → `vv-landing` seam (a real `api.veritasvault.net`, or a decision to keep Supabase and retire the .NET core) is a **separate, larger decision** that this spike deliberately does not pre-empt. Flagging it because the investor risk wording ("one release process across the active core") implies an integrated core that does not currently exist.

---

## 4. What breaks on consolidation

Ordered by blast radius.

### 4.1 Vercel — production, highest risk

| Item           | State                                                                                                  | Breaks if                                                                                                         |
| -------------- | ------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| Build config   | **No `vercel.json` in `vv-landing`**                                                                   | Any Root Directory / build-command change is made from the dashboard with no committed source of truth to restore |
| Deploy trigger | Vercel Git integration on `JustAGhosT/vv-landing`                                                      | Repo is renamed or transferred — the integration must be re-authorized against the new owner/name                 |
| Env vars       | Dashboard-only: `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_ANON_KEY`, `COINGECKO_API_KEY`, NextAuth secrets | Project is recreated rather than renamed — **all env vars are lost and unrecoverable from git**                   |
| Domain binding | `veritasvault.net` + `www` bound to the Vercel project                                                 | Project is deleted/recreated, or DNS moves before the binding is re-verified (§7)                                 |

**Mitigation, in order:** commit a `vercel.json` capturing current settings _before_ touching anything → export env vars via `vercel env pull` → rename the repo (GitHub redirects, integration survives) → never delete the Vercel project.

### 4.2 CI workflows

| Repo            | Workflow              | Current state                                                                           |
| --------------- | --------------------- | --------------------------------------------------------------------------------------- |
| `vv`            | `build-and-test.yml`  | **passing** — .NET 9, coverage gate via `CodeCoverageSummary`                           |
| `vv`            | `.spellcheck.yml`     | **failing** on every run                                                                |
| `vv-landing`    | `ai-config-audit.yml` | **failing** since 2026-01-03 — the only workflow on the production repo                 |
| `vv-game-suite` | `monica-auth.yml`     | **failing** every run since 2025-07-19                                                  |
| `vv-docs`       | `doc-sync.yml`        | **failed daily to 2026-03-17** — scheduled, burning Actions minutes on an archived repo |
| `vv-auth`       | `publish.yml`         | **never fired** (needs a release; none exist)                                           |
| `vv-dev-tools`  | `sendgrid-mailer.yml` | weekly cron, **succeeded** to 2025-09-22, then GitHub auto-disabled it for inactivity   |

Two live side-effects to be aware of before archiving: `vv-dev-tools` sends real email on a cron (currently dormant, but re-enables on any push), and `vv-docs`'s scheduled workflow ran for ~6 weeks after the repo went quiet.

### 4.3 Azure IaC

`vv-iac` references resources by name (`ml-engine-api`, `risk-bot`, `metrics-bot`, `alert-function`, `archival-function`, Cosmos DB, Redis, Front Door, VNet peering) with per-env parameter files. It has **no CI at all** — no `.github/workflows`, only `iac/scripts/deploy.ps1`. Nothing imports it and nothing verifies it.

It is safe to relocate: no pipeline consumes it. But it is **not safe to assume it matches reality** — it has never been validated against a live subscription, and the function apps it declares (`risk-bot`, `ml-engine-api`) correspond to `vv-chain-services`, which is dead. Treat the Bicep as _historical design intent_, not deployable infrastructure. `vv-iac/github/` also holds the estate's origin scripts (`Create-VVRepos.ps1`, `roadmap-final.csv`, `import-issue-log.json`) — these are the only record of the original plan and must not be lost.

### 4.4 Import paths

Low risk, because there is nothing to rewire:

- No repo imports `@veritasvault/*` (the grep hits in `vv-landing` are email addresses and social handles in marketing copy, not package imports).
- `vv-auth` was never published, so no lockfile anywhere references it.
- `vv-landing`'s API base URL already defaults to `/api` — self-contained.
- **`vv-landing` ships two lockfiles** (`package-lock.json` _and_ `pnpm-lock.yaml`). Vercel picks one by detection order; a consolidation that changes the working directory can silently flip package manager and resolve different transitive versions. Delete one **before** any move, as an isolated commit.

### 4.5 Pre-existing defects to fix in passing

- `vv-landing/config/api-config.ts:9` — `WS_BASE_URL` defaults to the literal placeholder `wss://api.yourdomain.com`, committed to the production branch.
- `vv-landing/next.config.mjs` — `typescript.ignoreBuildErrors: true` and `eslint.ignoreDuringBuilds: true`. Combined with 0 tests, **production has no quality gate whatsoever**. See §6 for why this cannot simply be switched on.

---

## 5. DNS as code — `veritasvault.net` into Terraform

_Added per request: "move dns to terraform on the nl sub."_

### Current state

|                      |                                                                                                                                                                                          |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Registrar / DNS host | **GoDaddy** — `ns59/ns60.domaincontrol.com`, SOA `dns.jomax.net`, serial `2025072804`                                                                                                    |
| Records              | apex A → `76.76.21.21` (Vercel); `www`, `games` → `vercel-dns.com`; **`docs` → `vercel-dns.com` (dead)**                                                                                 |
| Mail                 | MX `smtp.secureserver.net` (0), `mailstore1.secureserver.net` (10); SPF `include:secureserver.net -all`                                                                                  |
| Other TXT            | `google-site-verification=GMpwKCksYu47OTQ998GCLx4tkq7VDjQren1L9CWZ_Yc`                                                                                                                   |
| In Azure DNS?        | **No.** Subscription `bb4e3882-2079-4bab-8974-611bc0b8bb58` / `mys-global-shared-rg` holds `mystira.app`, `neuralliquid.ai`, `nexamesh.ai`, `phoenixvc.tech` — **no `veritasvault.net`** |

The "nl sub" is confirmed as `bb4e3882-2079-4bab-8974-611bc0b8bb58` — the same subscription `neuralliquid/neuralliquid-org`'s `infra/terraform/dns/` already targets, and Azure CLI authenticates against it successfully today.

### Where it goes

`neuralliquid-org` already has the right machinery: `infra/terraform/dns/{main,variables,imports,backend,versions}.tf`, a `terraform-dns.yml` workflow (OIDC to the nl subscription, `environment: production`, `workflow_dispatch` plan/apply), `docs/runbooks/dns-cutover.md`, `docs/inventory/dns.md`, and a `products/*.yaml` registry. Add `products/veritasvault.yaml` and extend the DNS module.

This is also why the repos should live in `neuralliquid` (§8): the org that owns the DNS zone for `veritasvault.net` ends up owning the code that the zone points at, and `products/veritasvault.yaml` serves both the DNS module and the product registry. Splitting repo ownership and DNS ownership across two orgs was the weakest part of the alternative.

### The pattern gap is transitional, not permanent

The existing module is built for one shape: `<product>.neuralliquid.ai` CNAME → `*.azurewebsites.net`, paired with an `asuid.*` TXT for App Service hostname verification. `veritasvault.net` fits none of that **today** — it is a separate apex zone pointing at Vercel.

But hosting is moving off Vercel to Azure (§5a). That means the module gap closes on its own: the end state is exactly the App-Service-plus-`asuid` shape the module already models. So build the zone in two steps rather than designing around Vercel permanently.

**Step 1 — interim, Vercel-shaped.** Replicate what exists so the NS cutover is a no-op for users:

- `azurerm_dns_zone` for `veritasvault.net` (**new zone — nothing to import**, so `imports.tf` gains no entries)
- apex `azurerm_dns_a_record` → `76.76.21.21`
- `azurerm_dns_cname_record` for `www`, `games` → `cname.vercel-dns.com`
- `azurerm_dns_mx_record` + SPF/verification `azurerm_dns_txt_record` — **replicated from GoDaddy, not invented**
- **no `docs` record** — dropping it is the fix for the dangling CNAME (§7)

**Step 2 — after the Azure cutover.** Replace the apex A and `www`/`games` CNAMEs with the standard `product_cnames` + `app_service_validation_records` entries, and add `products/veritasvault.yaml`. At that point VeritasVault is just another row in the existing module.

Sequence the NS cutover **before** the hosting migration. Two reasons: it is the smaller change, and once the zone is in Terraform, the hosting cutover becomes a reviewable diff instead of a manual dashboard edit.

---

## 5a. Vercel → Azure hosting migration

_Decided 2026-08-12: hosting moves off Vercel to Terraform-managed Azure. This section scopes what that actually costs — it is a larger change than the DNS move._

### Azure Static Web Apps is not a viable target

Measured against `vv-landing` as it exists:

| Coupling                                                     | Evidence                                                                          | Consequence on Azure                                                                                                                                               |
| ------------------------------------------------------------ | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **`middleware.ts`** (62 lines)                               | present at repo root                                                              | Next middleware needs a real Node server. **Static Web Apps does not support it properly** → the target must be **App Service (Node)** or **Container Apps**       |
| **45 API routes** + `next-auth` + `force-dynamic` (3 routes) | `app/api/**/route.ts`                                                             | Confirms a long-running Node runtime, not managed functions                                                                                                        |
| **`export const runtime = "edge"`** on 2 routes              | `app/api/og/{corporate,standard}/route.tsx` using `next/og` `ImageResponse`       | **Edge runtime does not exist on App Service or Container Apps.** Must be switched to `nodejs`. `next/og` does run under Node on Next 15, but each needs verifying |
| **`@vercel/analytics`**                                      | `package.json`, `app/VersionSelectionPage.tsx`, `lib/analytics/auth-analytics.ts` | Must be replaced — Application Insights is the natural swap                                                                                                        |
| **Vercel Cron**                                              | `app/api/cron/sync/route.ts`, gated on `process.env.CRON_SECRET`                  | Needs an Azure timer trigger (Function or Container App job) calling the endpoint with the secret                                                                  |

**Recommendation: Container Apps.** It gives a plain Node runtime for `next start`, supports middleware and all 45 routes unchanged, and the org already has Container Apps precedent (`sluice`). App Service (Node) is the lower-ceiling alternative.

### The schedule is not in git

There is no `vercel.json` (§4.1), so **the Vercel Cron schedule exists only in the dashboard**. It is not recoverable from the repo, and unlike env vars there is no `vercel env pull` equivalent for it. **Capture the cron schedule during Phase 0**, alongside the env-var export — otherwise `sync-service` silently stops running after the migration and nothing fails loudly.

### What stays on Vercel until explicitly moved

`games.veritasvault.net` (`vv-game-suite`) is a second live Vercel project. It is a static WebGL/Phaser build with no middleware and no API routes, so it is a genuinely easy Static Web Apps candidate — but it is **out of scope for the first migration**. Move `veritasvault-web` first, leave games alone, and keep its Vercel CNAME in the Terraform zone (Step 1 above) until it is moved deliberately.

### Ordering against the rest of this plan

The hosting migration is the **largest** item in this document and depends on the org transfer having settled. Slot it after Phase 6, not before — attempting it while repo ownership is still moving means debugging two cutovers at once. The env-var and cron capture, however, belongs in **Phase 0**, because that data is lost the moment the Vercel project is disturbed.

### Hazards — read before executing

> **This is the one workstream in this plan that can take the live site and company email down.**

1. **Email is the sharpest edge.** Cutting NS from GoDaddy to Azure DNS moves _the entire zone_. If MX and SPF are not correct in Azure DNS **before** the NS switch, inbound mail to `@veritasvault.net` fails and outbound starts failing SPF. Replicate MX/TXT first; verify by querying the Azure DNS nameservers directly before cutting over.
2. **Vercel domain verification must survive.** Vercel validates ownership via the DNS records it expects. Confirm apex A and `www` CNAME resolve correctly from the new nameservers **before** cutover, or Vercel can invalidate the binding and drop the managed certificate.
3. **The existing runbook does not cover this case.** `docs/runbooks/dns-cutover.md` assumes an App Service target and per-host CNAME changes within an already-Azure zone — not an apex NS migration off GoDaddy to a Vercel-fronted zone. It needs a new section; do not follow it as-is.
4. **TTL staging.** Current default TTL is 600s. Lower TTLs at GoDaddy ≥24h before cutover so rollback propagates in minutes, not hours.
5. **Rollback = restore GoDaddy NS.** Keep a verbatim export of every GoDaddy record (screenshot + zone file) as the rollback artifact. This is the only real undo.
6. **Registrar access is out of band.** The NS change happens in the GoDaddy account, not in Terraform. Terraform can hold the zone and records; it cannot flip the delegation. Sequence accordingly.

A cheaper non-solution, for completeness: adding a `veritasvault` host under the existing `neuralliquid.ai` zone requires no cutover and no risk — but it leaves `veritasvault.net` at GoDaddy, so it does not put the production domain under code and does not fix the dangling `docs.` record. Not recommended; noted so the tradeoff is explicit.

---

## 6. One release/CI process across what survives

Three shared gates, implemented per-stack rather than in a single pipeline (the two survivors share no toolchain).

**Gate 1 — build + test.** `vv` already has this and it passes; keep it as the reference. `veritasvault-web` needs the inverse of its current posture.

**Gate 2 — typecheck + lint.** This is where the sequencing matters. `vv-landing` has shipped for 14 months with `ignoreBuildErrors: true`. **Do not flip that flag as part of the migration.** 86,832 lines that have never been typechecked will produce an error wall, and any attempt to fix it inside the consolidation commit makes the migration irreversible in practice. Instead:

1. Land the move with the flags **unchanged** — behaviour-preserving.
2. Separately, run `tsc --noEmit` and commit the raw error count as a baseline.
3. Add a CI check that fails only on _regression_ against that baseline.
4. Burn the baseline down over time; flip the flag when it reaches zero.

**Gate 3 — tagged releases.** The estate has never cut one. Adopt conventional commits (already the house standard) and `vX.Y.Z` tags on both survivors. This also makes `vv-auth`'s dead `publish.yml` pattern moot rather than latent.

**Branch protection**, absent everywhere, is the cheapest durable win: 1 required review + required status checks on `main` for both survivors — which is what `Create-VVRepos.ps1` intended in the first place.

**Cost control** (Actions minutes): consolidating 13 repos to 2 removes 5 failing/scheduled workflows. Archiving `vv-docs` stops a daily failing cron. Prefer `pull_request` + `workflow_dispatch` triggers over `push` on both survivors.

---

## 7. Security: dangling `docs.veritasvault.net`

**Treat as the most urgent item in this document — it is independent of consolidation and should be fixed first.**

`docs.veritasvault.net` CNAMEs to `vercel-dns.com`. The Vercel project is gone (TLS handshake fails; plain HTTP returns 404) but the GoDaddy record remains. A dangling CNAME to a shared hosting provider is the standard **subdomain-takeover** setup: whoever next claims that hostname in a Vercel project can serve content on a `veritasvault.net` subdomain — which is a phishing and cookie-scoping problem for a platform whose investor materials are public.

Compounding evidence of the confusion: `vv-docs` deployed to **Azure Static Web Apps** (`static-website-deploy-workflow.yml` + `staticwebapp.config.json`), yet the DNS points at **Vercel**. Two conflicting hosting histories, and neither endpoint exists now.

**Fix:** delete the `docs` CNAME at GoDaddy. One record, no dependencies, immediately reversible. Do it before, and independently of, everything else here.

---

## 8. Ownership: personal account → org

**Decision: transfer to `neuralliquid`.** Not `phoenixvc`, not `veritasvault-ai`.

An earlier draft of this spike recommended `phoenixvc`. That recommendation rested on two _records of intent_ — `vv-iac/github/Create-VVRepos.ps1` defaulting to `$Org = "phoenixvc"` (written May 2025) and baton's `veritasvault` project description saying _"transfer to `phoenixvc/veritasvault`"_. Both are stale plans, not current architecture. Weighed against what the orgs actually contain and do today, `neuralliquid` is the better home on four independent counts:

1. **The executed precedent points here.** `house-of-veritas` was transferred `JustAGhosT` → **`neuralliquid`** on 2026-05-14. That is the only completed transfer of this shape in the workspace, and it did not go to `phoenixvc`. Same brand family, too (`veritas`).
2. **The product registry is here.** `neuralliquid-org/products/*.yaml` already holds `cognitive-mesh`, `convolens`, `house-of-veritas`, `omnipost`. `products/veritasvault.yaml` is the natural next entry — and §5 needs that file anyway for DNS. One registration, two purposes.
3. **The Azure trust path is here.** `neuralliquid-org/.github/workflows/terraform-dns.yml` authenticates to the nl subscription via **OIDC** (`ARM_USE_OIDC: true`, `vars.AZURE_CLIENT_ID`, `environment: production`). The federated-credential relationship to `bb4e3882-…` already exists at this org. When `vv-iac`'s Bicep eventually needs to deploy, the identity pattern is in place rather than needing to be built.
4. **Category fit.** `neuralliquid` is where _products_ live (HOV, ConvoLens, OmniPost, Cognitive Mesh). `phoenixvc` is where _tooling and infrastructure_ live (retort, baton, docket, sluice, org-meta, codeflow, phoenix-runner). VeritasVault is a product.

Putting the repos in `neuralliquid` also puts them in the same org as the DNS control plane that will own `veritasvault.net` (§5). Repo ownership and infrastructure ownership end up aligned instead of split across two orgs — which was the weakest part of the `phoenixvc` option.

Confirmed free of collisions: `neuralliquid/veritasvault`, `neuralliquid/veritasvault-web`, and `neuralliquid/vv` do not exist.

### One caveat: `neuralliquid` is on the Free plan

|                     | `neuralliquid` | `phoenixvc` |
| ------------------- | -------------- | ----------- |
| Plan                | **Free**       | Enterprise  |
| Public repos        | 5              | 13          |
| Owned private repos | **0**          | 20          |

Two consequences, both manageable:

- **The survivors must stay public.** Both `vv` and `vv-landing` are public today, so nothing changes — and **public repos get unlimited Actions minutes on any plan**, so `vv`'s .NET build+test+coverage workflow costs nothing. But this is a _condition_, not a free pass: making either repo private on a Free org would put it under the 2,000 min/month cap shared across the whole org, and would also lose ruleset-based branch protection (Free tier restricts that to public repos). If either survivor ever needs to go private, revisit the org choice.
- **Do not transfer the dead private repos.** `vv-docs-v1`, `vv-documentation`, `vv-auth-frontend-demo`, and `veritasvault-cognitive-mesh-nexus` are private. Archive them in place under `JustAGhosT` (Phase 2) rather than moving dead private code into a Free org. This was already the plan; the Free-plan finding reinforces it.

`phoenix-runner`'s self-hosted Azure VMSS runners stay in `phoenixvc` and would not be reachable from `neuralliquid` repos if they are org-scoped. I could not verify their scope — `gh api orgs/*/actions/runners` returns 403 at the current token scope (needs `admin:org`). Likely moot, since public repos get free hosted runners and nothing in the estate currently uses self-hosted.

### `phoenixvc` keeps one thing

`phoenixvc/phoenix-marketdata` — `vv`'s dead predecessor — stays where it is and gets archived there (Phase 2). The lineage record ends up in a different org from its descendant, which is slightly untidy but harmless: it is dead code whose only remaining value is provenance, and §1 finding #4 documents the relationship in writing.

### `veritasvault-ai` — do not revive

A confirmed abandoned consolidation attempt: exactly one repo (`vv-docs-archive`, private, archived, dead 2025-05-08). Its residue is visible as merge commits from `VeritasVault-ai/*` branches in `vv-landing`, `vv-docs`, `vv-chain-services`, and `vv-auth` — work was routed through it in mid-2025, then dropped. Reusing it means adopting a name whose `.ai` domain **does not resolve** while every repo description still advertises "VeritasVault.ai". Retire the name; keep `.net` as the brand.

### Stale records to correct

Because this decision reverses a written intent, two records need updating or they will mislead the next reader:

- Baton project `veritasvault` description — currently says _"transfer to `phoenixvc/veritasvault`"_.
- `vv-iac/github/Create-VVRepos.ps1` — `$Org` default. It is historical and no longer run, so annotate rather than edit; it is also the estate's origin record (§4.3).

### What a transfer breaks

| Item                        | Effect                                                                                                     | Handling                                                                                                                                           |
| --------------------------- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Clone URLs                  | GitHub **redirects indefinitely**                                                                          | Still update `origin` locally; do not rely on redirects long-term (this workspace has already been burned by rename-redirects masking stale names) |
| **Vercel Git integration**  | **Breaks — must be re-authorized** for the new owner                                                       | Highest-risk step. Do the transfer in its own window, with the Vercel reconnect as the immediate next action                                       |
| Actions secrets             | **Not transferred**                                                                                        | Re-add `AZURE_STATIC_WEB_APPS_API_TOKEN`, `NPM_TOKEN`, SendGrid keys before re-enabling any workflow                                               |
| GitHub Apps                 | Snyk, Dependabot, Copilot review need re-install at org scope                                              | Re-install after transfer                                                                                                                          |
| Private repos on a Free org | `veritasvault-cognitive-mesh-nexus`, `vv-docs-v1`, `vv-documentation`, `vv-auth-frontend-demo` are private | Archive these in place under `JustAGhosT` _before_ transferring — never move dead private code into a Free org                                     |
| Actions minutes             | Free plan caps private-repo minutes at 2,000/month org-wide                                                | Both survivors are **public**, so minutes are unlimited. Keep them public, or revisit the org choice (§8)                                          |
| Branch protection           | Free tier restricts rulesets on private repos                                                              | Fine while the survivors are public — this is still the fix for §1's zero-protection finding                                                       |
| Azure OIDC                  | `neuralliquid-org`'s federated credential is subject-scoped to that repo                                   | New repos need their own federated credential added to the existing app registration — pattern exists, entry does not                              |

**Sequence: fix DNS (§7) → archive the dead (§9 Phase 2) → then transfer only the survivors.** Transferring 13 repos and then archiving is strictly more work and more risk than archiving first.

---

## 9. Sequenced, reversible migration path

Every phase is independently reversible. Reversibility degrades left-to-right, so the irreversible steps come last and only after the estate is small.

### Phase 0 — Safety net _(fully reversible; do this first)_

1. ~~**Mirror-clone all 15 artifacts** (`git clone --mirror`) to durable offline storage, including `phoenixvc/phoenix-marketdata` and `VeritasVault-ai/vv-docs-archive`.~~ **Done** — 87 MB at `C:\Users\smitj\backups\vv-estate-20260812`, full history verified. This was the precondition for every later step.
2. Export GoDaddy zone verbatim (file + screenshot). **Outstanding.**
3. `vercel env pull` for the `veritasvault-web` project; store securely outside git. **Outstanding.**
4. **Capture the Vercel Cron schedule** for `app/api/cron/sync/route.ts`. **Outstanding, and the easiest thing here to lose** — there is no `vercel.json`, so the schedule exists only in the dashboard and has no `env pull` equivalent (§5a). If it is lost, `sync-service` stops running after the Azure migration and nothing fails loudly.
5. Screenshot Vercel project settings (Root Directory, build command, Node version, install command) for **both** `veritasvault-web` and `vv-game-suite`. **Outstanding.**
6. Record the current `tsc --noEmit` error count for `veritasvault-web` as the §6 baseline. **Outstanding.**

**Rollback:** nothing changed.

> Steps 2–6 all need GoDaddy or Vercel credentials and could not be completed from this session. **They are preconditions for Phases 1, 5 and 5a** — none of those should start until steps 2–6 are done.

### Phase 1 — Zero-risk fixes _(reversible; no consolidation yet)_

6. **Delete the `docs` CNAME at GoDaddy** (§7).
7. Commit `vercel.json` to `vv-landing` capturing current settings — makes the config reproducible _before_ it is ever moved.
8. Remove one of the two lockfiles in `vv-landing` (keep whichever Vercel currently resolves; verify with a preview deploy).
9. Fix the `wss://api.yourdomain.com` placeholder.
10. Enable branch protection on `vv` and `vv-landing` (1 review + required checks).

**Rollback:** revert commits; re-add the DNS record from the Phase 0 export.

### Phase 2 — Archive the dead _(reversible — archiving is a toggle, not a delete)_

11. Archive, in this order: `vv-chain`, `vv-docs-v1`, `vv-documentation`, `vv-auth-frontend-demo`, `veritasvault-cognitive-mesh-nexus`, `vv-auth`, `vv-chain-services`, `vv-dev-tools`, `phoenixvc/phoenix-marketdata`.
12. Before archiving `vv-dev-tools`, confirm its SendGrid cron is disabled so archiving cannot re-trigger mail.
13. Leave `vv-docs` archived as-is; leave `vv-game-suite` **active** (live deployment).

**Rollback:** un-archive. No history is touched. **Do not delete any repo at any point in this plan.**

### Phase 3 — Absorb into `vv` _(reversible; history-preserving)_

14. Merge `vv-iac` into `vv` at `infra/` using `git subtree add --prefix=infra` (or a merge with `--allow-unrelated-histories`) so **commit history is preserved**. Include `vv-iac/github/` verbatim — it is the estate's origin record.
15. Merge `vv-chain` into `vv` at `contracts/` the same way.
16. Fix `vv/package.json`: `name` → `veritasvault`, drop the stale `phoenixvc/phoenix-market-data` repository URL.
17. Keep `vv`'s `build-and-test.yml` green throughout; fix or delete the failing `.spellcheck.yml`.

**Rollback:** revert the subtree merge commits; the source repos still exist (archived, not deleted).

> **Hazard:** do **not** use `git filter-repo`, squash-merge, or a fresh-copy import for these merges — any of those destroys history, which is exactly the mistake that produced `vv` from `phoenix-marketdata` and lost that lineage. Subtree merge only.

### Phase 4 — Rename _(reversible; GitHub redirects)_

18. Rename `vv` → `veritasvault`.
19. Rename `vv-landing` → `veritasvault-web`.
20. Verify the Vercel integration survived the rename (it should — rename preserves the repo ID) and that a preview deploy still builds.

**Rollback:** rename back. GitHub redirects both ways.

### Phase 5 — DNS to Terraform _(partially reversible — highest operational risk)_

21. Add `products/veritasvault.yaml` + the Vercel-shaped zone block to `neuralliquid-org/infra/terraform/dns/` (§5).
22. Extend `docs/runbooks/dns-cutover.md` with an apex-NS-migration section; update `docs/inventory/dns.md`.
23. Lower GoDaddy TTLs; wait ≥24h.
24. `terraform apply` to create the Azure DNS zone and **all** records — including MX and SPF.
25. Verify by querying the Azure DNS nameservers **directly**, before delegation: apex A, `www`, `games`, MX, SPF, Google verification.
26. Cut NS at GoDaddy → Azure DNS. Watch mail flow and `https://www.veritasvault.net` continuously.

**Rollback:** restore GoDaddy NS from the Phase 0 export. Propagation-bound, not instant — hence the TTL staging.

### Phase 6 — Org transfer _(least reversible; do last)_

27. Transfer `veritasvault` → **`neuralliquid`**. Confirm it lands public.
28. Transfer `veritasvault-web` → **`neuralliquid`**, public. **Immediately** re-authorize the Vercel Git integration and confirm a production deploy before doing anything else.
29. Decide `vv-game-suite`: transfer with the others, or leave until `games.veritasvault.net` is retired. Either is defensible; leaving it is lower-risk.
30. Re-add Actions secrets; re-install GitHub Apps at org scope; re-apply branch protection.
31. Add `products/veritasvault.yaml` to `neuralliquid-org` if Phase 5 has not already created it, and update `docs/inventory/dns.md`.
32. Correct the stale records that name `phoenixvc` (§8): baton project description, and annotate `Create-VVRepos.ps1`.

**Rollback:** transfer back (possible, but each hop re-breaks the Vercel integration). Treat as one-way in practice.

### Phase 7 — Quality baseline _(ongoing, no migration risk)_

33. Add the typecheck-regression gate against the Phase 0 baseline; burn it down; flip `ignoreBuildErrors` only at zero.
34. Introduce the first tests to `veritasvault-web` — start with the 45 API routes, which are the highest-value, lowest-effort surface.
35. Cut `v0.1.0` tags on both survivors — the estate's first releases.

---

## 10. Destructive-action register

Nothing in this document instructs a delete. These are the points where a careless step would destroy something unrecoverable.

| Action                                                        | Destroys                                                                 | Guard                                                                  |
| ------------------------------------------------------------- | ------------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| `git filter-repo` / squash / fresh-copy import during Phase 3 | Commit history — the `phoenix-marketdata` → `vv` mistake, repeated       | Subtree merge only; Phase 0 mirrors as backstop                        |
| Deleting (not archiving) any repo                             | History, issues (`vv-docs` has **101 open issues**), PR discussion       | **Archive only. Never delete.**                                        |
| Recreating the Vercel project instead of renaming             | All env vars — unrecoverable from git                                    | Phase 0 `vercel env pull`; rename, never recreate                      |
| NS cutover without MX/SPF in place                            | Inbound and outbound company email                                       | Phase 5 steps 24–25, verified against Azure nameservers pre-delegation |
| Changing Vercel Root Directory with no `vercel.json`          | The only record of current build config                                  | Phase 1 step 7 precedes any move                                       |
| Flipping `ignoreBuildErrors` inside a migration commit        | Reversibility of the migration itself                                    | §6 baseline-then-burn-down                                             |
| Archiving `vv-dev-tools` while its cron is armed              | Sends unintended email                                                   | Phase 2 step 12                                                        |
| Transferring dead private repos into `neuralliquid`           | Puts dead private code on a Free-plan org, under the 2,000 min/month cap | Archive in place under `JustAGhosT` first (Phase 2 → Phase 6)          |
| Making either survivor private after transfer                 | Unlimited public Actions minutes, and Free-tier ruleset protection       | Keep both public, or revisit the org choice (§8)                       |

**Live-deployment tripwires:** `www.veritasvault.net` (Vercel ← `vv-landing`) and `games.veritasvault.net` (Vercel ← `vv-game-suite`). Every phase that touches either repo's name, owner, or DNS must be followed by an explicit production check before the next phase starts.
