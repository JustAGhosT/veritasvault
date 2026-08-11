# Regulatory Scoping Spike — Target Jurisdictions and Compliance Requirements

**Status:** Research spike · Draft v0.1
**Date:** 2026-08-11
**Author:** Engineering research, for review by counsel
**Addresses:** "Regulatory uncertainty" on the risk register in [veritasvault-investor-overview.html](../investor/veritasvault-investor-overview.html)

---

## 0. What this document is, and is not

**This is not legal advice, and it is not a substitute for legal advice.**

It is a structured requirements set assembled from public regulatory sources and from direct
inspection of this codebase, intended to be taken to a qualified financial-services lawyer in each
named jurisdiction so that the engagement is efficient and specific. Every legal characterisation in
this document is a _working hypothesis for counsel to confirm or reject_, not a conclusion.

Where a position is contestable, that is stated. §8 collects the questions that only counsel can
answer, and §9 lists the sources and their as-at dates.

Two people are needed, not one:

| Role                         | Scope                                                                 | Why                                                                     |
| ---------------------------- | --------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| SA financial-services lawyer | FAIS perimeter, FSP licensing, FICA, POPIA, offer-of-securities       | Determines whether the business can lawfully operate at all             |
| UK financial-services lawyer | FSMA perimeter, s21 financial promotions, incoming cryptoasset regime | Determines whether the second market is reachable without authorisation |

An SA tax/exchange-control adviser is a likely third if any offshore structuring is contemplated
(see Q13).

---

## 1. Headline finding

> **The stated mitigation on the risk register solves the wrong problem.**

The register records the mitigation for "Regulatory uncertainty" as _"pluggable jurisdiction-specific
policy modules; standing regulatory monitoring."_

Pluggable policy modules address **which rules to apply once you are permitted to operate**. The
near-term risk is **whether you are permitted to operate at all**. A policy module cannot manufacture
a licence, and no amount of architectural pluggability changes the answer to the perimeter question
in §3.

The register also rates this risk implicitly as a future design concern. On the evidence in §2 and
§3, for the Sextant go-to-market it is a **present-tense blocker**, and it is the highest-severity
item on the register — higher than test coverage, because a licensing breach is not remediable by
shipping more code.

Recommended change to the register entry is in §7.4.

---

## 2. Ground truth — what is actually built

Verified by inspection of this repository on 2026-08-11. This matters because the perimeter analysis
depends on what the product _does_, not what it is described as doing.

| Claim (source)                                                                                              | Verified state                                                                                                                                                                                                                                                                  |
| ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| "Comprehensive audit trails and compliance reporting — **Live**" (corporate deck)                           | **No audit-logging code exists in the .NET core.** `grep -ril "audit" --include=*.cs src` matches only two DTO files (`ComplianceModels.cs`, `WalletModels.cs`). No `AuditLogger`, no append-only store, no emitter.                                                            |
| "KYC/AML, position limits and reporting are domain contracts **enforced at execution**" (investor overview) | **No enforcement code.** `ComplianceManager` appears in 7 markdown files and **zero** `.cs`/`.ts`/`.sol` files.                                                                                                                                                                 |
| "Regulatory compliance frameworks — Roadmap" (corporate deck)                                               | Accurate. This is the only claim in the set that matches reality.                                                                                                                                                                                                               |
| Compliance domain surface                                                                                   | DTOs only: [`ComplianceModels.cs`](../../src/vv.Application/DTOs/Compliance/ComplianceModels.cs) defines `ComplianceReportDto`, `AMLAlertDto`, `TransactionScreeningDto`, `SanctionHitDto`, `LicenseDto`, `KYCStatusDto`. All are data shapes with no producer and no consumer. |
| Backend API surface                                                                                         | **One controller** — `MarketDataController.cs`. The .NET solution is a market-data service.                                                                                                                                                                                     |

### 2.1 A documentation item that needs immediate attention

[`src/vv.Domain/Docs/Domains/Risk/compliance-framework.md`](../../src/vv.Domain/Docs/Domains/Risk/compliance-framework.md)
contains a "Jurisdictional Scope" table asserting:

| Jurisdiction                                 | Implementation Status | Compliance Level |
| -------------------------------------------- | --------------------- | ---------------- |
| United States (SEC, CFTC, FinCEN, OFAC)      | Complete              | Comprehensive    |
| European Union (EMIR, MiFID II, GDPR, AMLD5) | Complete              | Comprehensive    |
| United Kingdom (FCA, PRA)                    | Complete              | Comprehensive    |
| Singapore (MAS)                              | Complete              | Comprehensive    |
| Global (FATF, Basel)                         | Complete              | Comprehensive    |

None of this is implemented. The file is marked `status: draft` / `classification: internal`, which
is mitigating but not sufficient — a document in a repository is a document that can reach a data
room. Two problems:

1. **Misrepresentation exposure.** If this reaches a prospect, an auditor, or a regulator, it asserts
   completed compliance with five regimes that has not been started.
2. **South Africa does not appear in the table at all** — the one jurisdiction that certainly applies.

**Action:** rewrite the table to a forward-looking "target scope" with honest status values, or
delete it. This is a 20-minute fix and should not wait for the rest of this spike. See §7.1 item B1.

### 2.2 The two decks describe two different products

This inconsistency is itself a regulatory risk, because the perimeter question turns on what the
product does.

|            | Sextant deck                                                                                                | Corporate deck                                                                                             |
| ---------- | ----------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Execution  | "Execution will remain your decision **by design** — Sextant recommends, it does not trade on your behalf." | "Automated rebalancing with institutional controls" (Roadmap); "Threshold-triggered rebalancing" (Roadmap) |
| Settlement | Not mentioned                                                                                               | Domain 3: "deterministic order matching and atomic settlement" — `OrderBook`, `SettlementController`       |
| AI role    | Not mentioned                                                                                               | "AI assists parameter estimation, **view suggestion** and confidence calibration"                          |

Whatever position is taken with counsel must be taken about **one** product with **one** description.

---

## 3. The perimeter question: tool or advice?

This determines nearly everything downstream. It is answered separately per jurisdiction, and the
answers differ.

### 3.1 The current assertion

The Sextant deck closes with:

> "Sextant is a portfolio analysis and allocation tool provided by VeritasVault. It does not provide
> investment advice, and nothing in this document is a recommendation to buy, sell or hold any asset."

### 3.2 Pressure-testing that assertion — South Africa

Crypto assets have been a **financial product** under FAIS since the FSCA's declaration of
19 October 2022. FAIS s1 defines "advice" as any recommendation, guidance or proposal of a financial
nature furnished in respect of the purchase of or investment in a financial product.

The relevant carve-out is **s1(3)(a)**, which excludes factual advice — descriptions of a product,
answers to routine administrative queries, objective information, promotional material — and,
critically, excludes:

> "an analysis or report on a financial product **without any express or implied recommendation,
> guidance or proposal that any particular transaction in respect of the product is appropriate**."

That final clause is where the tool position is decided. Seven observations, in descending order of
how badly each damages the assertion:

**1. The product ingests the client's actual holdings and returns target weights for them.**
The deck says so explicitly: _"We take your actual holdings and show you what the allocation method
says about them."_ The delta between current holdings and target weights **is** a set of particular
transactions. The "drift from your target weights" dashboard displays that delta directly. It is
difficult to characterise "you are 12% overweight X against your target" as anything other than an
implied proposal that a particular transaction is appropriate.

**2. "AI ... view suggestion" is fatal to the tool position if it ships.**
The corporate deck advertises AI that suggests _views_ and calibrates _confidence_. A system that
proposes what the client should believe about an asset, and how strongly, is making a recommendation
in the ordinary sense of the word. This one feature converts an arguable position into an
indefensible one.

**3. The "you set the confidence, we just compute" argument is weaker than it looks.**
The client supplies views and confidences. The vendor supplies the equilibrium prior, the covariance
estimator, the ML shrinkage, the risk-aversion parameter and the constraint set — all of which
materially determine the output weights, and none of which the client sets. The client contributes
opinions; the vendor contributes the method that converts opinions into position sizes. Regulators
generally look through "the algorithm decided" framings.

**4. A disclaimer does not change the character of the conduct.**
FAIS applies by reference to what is furnished, not by reference to what it is labelled. The FAIS
Ombud can take jurisdiction over conduct notwithstanding contractual disclaimers. This needs
confirmation from counsel (Q1), but the working assumption should be that the footer paragraph has
close to zero perimeter effect.

**5. The fee model is evidence.** A flat software subscription supports the tool characterisation. A
percentage of assets or a performance fee undermines it in substance regardless of labelling. The fee
model has not been decided; it should be decided _with_ counsel, not before.

**6. "Working directly with the founder" is the largest practical risk, and it is not a software
problem.** The Sextant deck sells a small early cohort with direct founder access. In those
conversations the founder will be asked "so what should I do?" — and any answer is advice furnished
by a natural person. The software's characterisation is irrelevant to that exposure. See §7.1 item
B5.

**7. Client sophistication does not help.** Unlike MiFID's professional-client regime, FAIS applies
regardless of how sophisticated the client is. "We only take experienced investors" is not a route
around licensing in South Africa. This closes off the most obvious workaround.

**Working conclusion (for counsel to confirm or reject):** as currently designed and marketed,
Sextant is more likely than not to constitute the furnishing of advice in respect of a financial
product in South Africa, and therefore to require a FAIS licence. Confidence: moderate-to-high on the
characterisation, low on the remedy — see Q1–Q4.

### 3.3 Pressure-testing that assertion — European Union

Under MiCA, **"providing advice on crypto-assets" and "providing portfolio management on
crypto-assets" are named, authorised crypto-asset services**, and Art 81 requires a firm doing either
to conduct a **suitability assessment** covering the client's knowledge and experience, investment
objectives and risk tolerance, financial situation and capacity to bear losses. ESMA's suitability
guidelines were published 26 March 2025.

The tool position is materially weaker here than in South Africa, because MiCA names the activity
rather than requiring it to be inferred from a general definition of advice.

**More importantly, the EU is now closed rather than merely difficult.** The MiCA transitional period
expired **1 July 2026** — six weeks ago. After that date, providing crypto-asset services to EU
clients without MiCA authorisation is a breach of EU law. Third-country firms are prohibited from
providing crypto-asset services to, or soliciting, EU clients. Reverse solicitation survives only as
a narrow exception for genuinely client-initiated, isolated approaches; ESMA has issued guidelines
specifically on detecting and preventing its use as a workaround.

**Working conclusion:** the EU is not a target market for this product at this stage. The requirement
set for the EU is therefore not "comply" but **"provably exclude"** — which is a real, concrete
engineering and marketing requirement, not a null one. See §5.3.

### 3.4 Pressure-testing that assertion — United Kingdom

The UK is the outlier, and it is the reason it is recommended as the second jurisdiction.

The Financial Services and Markets Act 2000 (Cryptoassets) Regulations 2026 were made on
4 February 2026; the FCA published final rules on 30 June 2026; the regime comes into force
**25 October 2027**, with an authorisation window opening **30 September 2026** for five months.

The new regime creates regulated activities for issuing qualifying stablecoins, safeguarding,
operating a trading platform, dealing as principal or agent, **arranging deals**, and staking.
Critically:

> The existing regulated activities of **managing investments** and **advising on specified
> investments** have **not** been expanded to capture qualifying cryptoassets. Both remain regulated
> in respect of _specified investment cryptoassets_ (e.g. tokenised shares or bonds).

So in the UK, advice and portfolio management on pure qualifying cryptoassets currently sit **outside**
the perimeter — meaning Sextant can plausibly serve UK clients without FCA authorisation. That is a
genuine, and quite narrow, window. It comes with four hard edges:

- **Specified investment cryptoassets are in scope.** If the asset universe ever includes tokenised
  equities, bonds or fund units, advising on them is regulated. The asset universe therefore becomes
  a compliance-controlled surface, not a product-roadmap surface.
- **Arranging deals becomes regulated from Oct 2027.** Automated rebalancing, order routing, or
  anything that puts a client in touch with a venue is likely to be "arranging". This is the same
  boundary as §2.2.
- **Staking becomes regulated from Oct 2027.** The product's liquidity-pool surfaces need to be
  assessed against this.
- **The financial promotion regime already applies.** Qualifying cryptoasset promotions have been
  within s21 FSMA since 8 October 2023. A public website reachable from the UK is a live issue
  _today_, independent of the perimeter analysis. See Q9.

---

## 4. Recommended jurisdiction scope

**Target: South Africa (mandatory) + United Kingdom (deliberate second). European Union: excluded and
provably so.**

|                                | South Africa                                                             | United Kingdom                                                                                                                                     | European Union                                                                                                               |
| ------------------------------ | ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| **Posture**                    | Comply — unavoidable                                                     | Target — reachable without authorisation, for now                                                                                                  | Exclude — provably                                                                                                           |
| **Why**                        | Founder is SA-based and the activity is conducted from SA. Not a choice. | Advice/portfolio management on qualifying cryptoassets remain outside the perimeter; institutional buyers for the corporate tier concentrate here. | Advice is a named licensed service; transitional period expired 1 July 2026; authorisation is out of reach at current stage. |
| **Lead time to serve clients** | Months (FSP licence) unless the tool position holds                      | Weeks (contracts, promotions compliance, data)                                                                                                     | Not applicable                                                                                                               |
| **Watch date**                 | Ongoing FSCA enforcement; COFI Bill                                      | **30 Sep 2026** application window opens; **25 Oct 2027** regime live                                                                              | If EU ever becomes a target, authorisation is a 12-month-plus project                                                        |

### 4.1 Why not a crypto-friendly hub as the second

Considered and rejected for now. Mauritius (FSC / VAITOS), UAE (VARA / ADGM) and Switzerland are all
viable on paper, and Mauritius is the natural offshore choice for an SA founder on timezone, language
and treaty grounds. Rejected because:

- It adds an entity, a licence, local substance requirements and cost, for a product with zero
  revenue and one full-time person.
- It does **not** remove the South African obligation. Advice furnished from South Africa is likely
  still SA-regulated regardless of where the entity sits (Q3).
- SA place-of-effective-management rules mean an offshore company run from Durban is likely
  SA tax-resident anyway, and moving IP offshore engages SARB exchange control (Q13).

Revisit if and when there is revenue to support it, or if counsel advises that the SA licensing route
is closed.

---

## 5. Per-jurisdiction requirements matrix

Legend for the "Applies" column: **Y** = applies on the working hypothesis · **Y?** = applies if the
advice characterisation is confirmed · **N/A** = not applicable on current scope.

### 5.1 South Africa

| #     | Obligation                                            | Applies                                       | Source                                                                        | What it concretely requires                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ----- | ----------------------------------------------------- | --------------------------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SA-1  | **FSP licence, Category I, crypto asset subcategory** | Y?                                            | FAIS s7(1); FSCA Declaration 19 Oct 2022                                      | Licence application; a Key Individual meeting fit-and-proper (RE1 exam, recognised qualification, demonstrated crypto experience); operational-ability evidence including a clear business plan. FSCA has declined applications specifically for weak business plans and unevidenced crypto competence.                                                                                                                                                                               |
| SA-2  | **FSP licence, Category II (discretionary)**          | N/A now; **Y if automated rebalancing ships** | FAIS                                                                          | Additional RE3 for the KI, higher operational requirements. This is the licensing consequence of the roadmap item in §2.2.                                                                                                                                                                                                                                                                                                                                                            |
| SA-3  | **FICA accountable institution**                      | Y?                                            | FIC Act Sch 1 item 12 (from 1 Dec 2023)                                       | **Anyone providing advice or intermediary services in respect of a crypto asset is an accountable institution.** No custody or execution required. Triggers: registration with the FIC, a documented Risk Management and Compliance Programme, customer due diligence, sanctions/PEP screening, transaction monitoring, suspicious-transaction reporting, and an appointed compliance officer. **The "we never touch assets so AML doesn't apply" assumption fails in South Africa.** |
| SA-4  | **Record-keeping**                                    | Y?                                            | FAIS s18; FIC Act; FAIS General Code of Conduct                               | Records of advice furnished, client records, and CDD records. Retention periods to be confirmed by counsel (Q6) — plan for 5 years from termination of the relationship as a working figure.                                                                                                                                                                                                                                                                                          |
| SA-5  | **Record of advice / needs analysis**                 | Y?                                            | FAIS General Code of Conduct                                                  | Before furnishing advice: obtain information on the client's financial situation, experience and objectives; conduct a suitability analysis; record what was recommended and why, and any alternatives considered. **This is the structural item — see §6.2.**                                                                                                                                                                                                                        |
| SA-6  | **Travel Rule**                                       | N/A on current scope                          | FIC Directive 9 (published Nov 2024)                                          | Applies to accountable institutions under Sch 1 items 12 and 22 acting as ordering/intermediary/recipient CASPs for crypto transfers. A pure advice product does not transfer crypto. **Becomes live the moment execution or rebalancing ships.**                                                                                                                                                                                                                                     |
| SA-7  | **POPIA — Information Officer**                       | Y                                             | POPIA                                                                         | Registered Information Officer (the founder, by default, as head of the entity), registered with the Information Regulator; PAIA manual.                                                                                                                                                                                                                                                                                                                                              |
| SA-8  | **POPIA — lawful processing & notice**                | Y                                             | POPIA ss9–12, 18                                                              | Privacy notice, lawful basis, purpose limitation, retention limits, security safeguards (s19), breach notification (s22).                                                                                                                                                                                                                                                                                                                                                             |
| SA-9  | **POPIA — cross-border transfer**                     | Y                                             | POPIA s72                                                                     | Client data in Azure regions outside SA is a transfer requiring an s72 basis. Includes backups, logs, telemetry, and **any AI provider the gateway routes to**. The Information Regulator has signalled increased attention here and a forthcoming guidance note.                                                                                                                                                                                                                     |
| SA-10 | **POPIA — direct marketing**                          | Y                                             | POPIA s69; Information Regulator Guidance Note on Direct Marketing (Dec 2024) | Unsolicited electronic direct marketing requires prior consent unless the recipient is an existing customer; consent must be requested in the prescribed manner and form; existing-customer marketing is limited to similar products with a right to object. **The Sextant GTM is founder-led outreach to private investors — this provision governs it directly.** See §7.1 item B4.                                                                                                 |
| SA-11 | **Advertising / marketing conduct**                   | Y?                                            | FAIS General Code of Conduct; Consumer Protection Act                         | Marketing must not be misleading. The claims audited in §2 are the exposure here, not a hypothetical.                                                                                                                                                                                                                                                                                                                                                                                 |
| SA-12 | **Complaints handling / FAIS Ombud**                  | Y?                                            | FAIS                                                                          | Documented internal complaints procedure; clients must be informed of their right to approach the FAIS Ombud.                                                                                                                                                                                                                                                                                                                                                                         |
| SA-13 | **PI / fidelity cover**                               | Check                                         | Board Notice 123 of 2009                                                      | Exemptions from PI and fidelity cover exist for crypto asset FSPs. Confirm the current position with counsel — do not assume the exemption applies (Q7).                                                                                                                                                                                                                                                                                                                              |
| SA-14 | **Offer of securities**                               | **Open — resolve urgently**                   | Companies Act ch 4                                                            | The Sextant deck says _"This is what the early group is funding"_ and _"You are considering trusting this with real capital."_ If the early cohort pays for software, that is a customer prepayment. If they take equity or a convertible, it is an offer of securities with prospectus/private-offer consequences. **The deck currently blurs the two.** See Q11.                                                                                                                    |

### 5.2 United Kingdom

| #    | Obligation                                              | Applies                       | Source                                                       | What it concretely requires                                                                                                                                                                                                                                                                                                                                                            |
| ---- | ------------------------------------------------------- | ----------------------------- | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| UK-1 | **FCA authorisation for advising / managing**           | **N** on current scope        | FSMA RAO; FCA PS of 30 Jun 2026                              | Advising on investments and managing investments were **not** extended to qualifying cryptoassets. No authorisation needed for advice on pure qualifying cryptoassets.                                                                                                                                                                                                                 |
| UK-2 | **Authorisation for specified investment cryptoassets** | Y if in scope                 | FSMA RAO                                                     | Tokenised shares, bonds and fund units remain specified investments. Advising or managing in respect of them is regulated. **Requires the asset universe to be a compliance-gated list.**                                                                                                                                                                                              |
| UK-3 | **Arranging deals in qualifying cryptoassets**          | N now; **Y from 25 Oct 2027** | FSMA 2000 (Cryptoassets) Regulations 2026                    | Triggered by automated rebalancing, order routing, or introducing clients to venues.                                                                                                                                                                                                                                                                                                   |
| UK-4 | **Qualifying cryptoasset staking**                      | N now; **Y from 25 Oct 2027** | Same                                                         | Assess the liquidity-pool surfaces against this before Oct 2027.                                                                                                                                                                                                                                                                                                                       |
| UK-5 | **Financial promotions (s21 FSMA)**                     | **Y — already live**          | Cryptoasset financial promotions regime, in force 8 Oct 2023 | Promotions of qualifying cryptoassets to UK consumers must be made or approved by an authorised person, carry prescribed risk warnings, observe a cooling-off period for first-time investors, and avoid incentives to invest. Whether promoting a _tool_ falls within this is the live question — see Q9. A publicly reachable website plus founder outreach is the exposure surface. |
| UK-6 | **MLRs 2017 registration**                              | N on current scope            | MLRs 2017                                                    | Applies to cryptoasset exchange providers and custodian wallet providers. An advice-only tool is neither. **Changes if custody or execution ships.**                                                                                                                                                                                                                                   |
| UK-7 | **UK GDPR + Data Protection Act 2018**                  | Y                             | UK GDPR                                                      | Lawful basis, transparency, DSARs, international transfer mechanism for data leaving the UK, processor contracts including AI sub-processors.                                                                                                                                                                                                                                          |
| UK-8 | **Authorisation window**                                | Diarise                       | FCA                                                          | Opens **30 September 2026**, five months. Applicants in the window get a transitional regime. If the product will ever arrange or stake, this window is the cheap moment to act.                                                                                                                                                                                                       |

### 5.3 European Union — exclusion requirements

Not a target market. The obligations below are what "excluded" has to mean in practice to be
defensible, and they are engineering work.

| #    | Requirement                                                                           | Why                                                                                                                                                                                                                                                                                                                                                                                                              |
| ---- | ------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| EU-1 | No marketing, advertising or outreach directed at EU-established persons              | Third-country firms are prohibited from soliciting EU clients. Includes cold email, EU-targeted SEO, EU conference outreach, and EU-language landing pages.                                                                                                                                                                                                                                                      |
| EU-2 | Declared residence and tax residence captured at onboarding, with EU answers rejected | Self-declaration is the primary control; IP geolocation alone is not sufficient evidence of exclusion.                                                                                                                                                                                                                                                                                                           |
| EU-3 | IP-based geo-blocking as a secondary control, with logs retained                      | Evidence of intent to exclude. Not sufficient alone.                                                                                                                                                                                                                                                                                                                                                             |
| EU-4 | No reliance on reverse solicitation as a business model                               | ESMA treats it as a narrow exception and has issued guidelines on detecting circumvention. If it is ever relied on, the client's unsolicited initiative must be independently evidenced and dated.                                                                                                                                                                                                               |
| EU-5 | Terms of service state the exclusion, and it is enforced in code, not only in prose   | Unenforced terms are not evidence of exclusion.                                                                                                                                                                                                                                                                                                                                                                  |
| EU-6 | GDPR still applies to any EU personal data already held                               | Exclusion prospectively does not cure past processing. If any EU person's data is already held, Art 44–49 transfer rules and the full GDPR obligation set apply to it.                                                                                                                                                                                                                                           |
| EU-7 | **EU AI Act — Art 50 transparency applies now**                                       | Regulation (EU) 2026/1744 (Digital Omnibus on AI, in force 27 July 2026) deferred **Annex III high-risk** obligations to **2 December 2027**, but **did not defer Art 50 transparency**, which applied from 2 August 2026. Relevant if any AI-generated content or chatbot interaction is exposed to EU-established users. Given EU exclusion this should be moot — but it is the reason exclusion must be real. |

---

## 6. Mapping obligations onto the architecture

### 6.1 Maps cleanly to the pluggable-policy design

These are genuinely configuration-shaped, and the existing design intent accommodates them:

| Obligation                                                     | Mechanism                                                                                                            |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Jurisdiction-keyed disclosures, risk warnings, disclaimer text | Policy module returns a content bundle keyed by client jurisdiction                                                  |
| Marketing gating and geo restriction (EU-1 to EU-5)            | Jurisdiction resolver at onboarding + edge geo-block + audit log of decisions                                        |
| Record retention periods (SA-4)                                | Retention policy as per-jurisdiction configuration on the storage layer                                              |
| Sanctions / PEP screening provider selection (SA-3)            | Adapter behind a screening port; provider chosen per jurisdiction                                                    |
| Regulatory report formats (FIC STR/CTR)                        | Report templates per jurisdiction; `ComplianceReportDto` is a reasonable starting shape                              |
| Position limits, exposure bounds, asset restrictions           | Already first-class in the allocation design per the corporate deck; jurisdiction becomes one more constraint source |
| **Asset-universe gating (UK-2)**                               | Per-jurisdiction allow-list of instrument types, excluding specified investment cryptoassets from UK advice flows    |

### 6.2 Requires structural change — not pluggable

These cannot be delivered by a policy module because they introduce concepts the domain model does
not currently contain.

**S1 — Suitability assessment, and the firm's willingness to say no.**
Both SA-5 (FAIS needs analysis) and EU Art 81 require the _firm_ to assess whether a recommendation
is suitable given the client's knowledge, experience, objectives, risk tolerance and capacity for
loss — and to decline where it is not. This is in direct tension with the product's stated philosophy:
_"The instrument never overrules you."_ A suitability regime is precisely a mechanism by which the
instrument overrules the client. New entities required: client profile, risk tolerance, knowledge and
experience assessment, capacity for loss, suitability determination, suitability statement artefact,
and periodic review. None exist today. **This is the single largest architectural consequence of the
advice characterisation.**

**S2 — Regulated client identity.**
The current identity model is account/wallet-centric. Regulated onboarding needs a verified natural
or legal person, beneficial ownership for entities, source of funds, a client risk rating, and
scheduled CDD refresh. `KYCStatusDto` is a status string with no lifecycle, no evidence store and no
producer — it is a placeholder, not a foundation.

**S3 — Audit as legal evidence, and the record of advice.**
The decks position auditability as the core differentiator, and the domain design agrees. But there
is no audit code (§2), and "record of advice" has prescribed content: what was recommended, on what
basis, what information was relied on, what alternatives were considered. That is a different artefact
from a generic append-only event log, and it should be designed as a first-class domain concept
rather than reconstructed from events later — which is exactly the failure mode the investor overview
criticises competitors for.

**S4 — A hard, testable advice boundary.**
For the product to be switchable between tool-mode and advice-mode per jurisdiction, **every
client-facing output must be classified** as factual/objective versus personalised-recommendation, and
that classification must be enforced at the API boundary and covered by tests. This is a
cross-cutting product-architecture change, not a feature flag. It is also the only way the pluggable
policy story becomes true rather than aspirational.

**S5 — AI view-suggestion gating and provenance.**
Per §3.2 item 2, view suggestion must be capable of being disabled per jurisdiction and per client,
and when enabled its outputs must carry model version, inputs and timestamp into the advice record.
The corporate deck already claims a model registry and "AI switched off" operation — the new
requirement is that the switch is _jurisdiction-driven and evidenced_, which the current design does
not express.

**S6 — Genuine data residency.**
"Bespoke reporting and data residency" is sold at the Enterprise tier. Real residency under POPIA s72
means the region constrains storage, processing, backups, logs, telemetry **and the AI gateway's
downstream model provider**. The corporate deck's "AI workloads route through our own gateway ...
which model provider sits behind it is a configuration decision" is the exact point where personal
data can silently leave the region. This is an infrastructure-topology requirement, not a policy
module.

**S7 — Complaints handling (SA-12).**
A new operational surface with a record trail and Ombud referral disclosure. Small, but it does not
exist.

### 6.3 Consequence for the risk-register mitigation

The mitigation should read, approximately:

> **Regulatory uncertainty.** _Exposure:_ the perimeter question (tool vs regulated advice) is
> unresolved in the home jurisdiction, and no compliance control is implemented — the compliance
> surface is DTOs and specification only. _Mitigation:_ target jurisdictions named (SA, UK); perimeter
> opinion obtained from SA and UK counsel before first client onboarding; pre-launch blocker list
> tracked to closure; suitability, client-identity and advice-record domain concepts added to the
> Phase 2 scope; jurisdiction-pluggable policy modules deliver the configuration-shaped subset only.

---

## 7. Pre-launch blockers — before the first private client

Ordered by lead time, because the long-lead items determine the launch date and nothing else does.
"Client" here means a person whose real holdings are ingested — not a demo-mode visitor.

### 7.1 Must be closed before onboarding client #1

| ID     | Blocker                                                                                                                                                                                                                                                                                                                                                                                                                               | Owner                | Lead time                           |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------- | ----------------------------------- |
| **A1** | **Obtain a written perimeter opinion from SA counsel** on whether Sextant as designed constitutes furnishing advice under FAIS. Everything else branches off this answer.                                                                                                                                                                                                                                                             | Founder + SA counsel | 2–4 weeks                           |
| **A2** | **Choose the route implied by A1** and start it: (i) apply for a Cat I FSP licence with crypto subcategory; or (ii) operate as a representative/juristic representative under an existing licensed FSP; or (iii) restructure the product so the tool position is genuinely defensible — which realistically means not ingesting client holdings, i.e. demo and education only.                                                        | Founder              | Months (i), weeks (ii), weeks (iii) |
| **B1** | **Fix the compliance claims.** Rewrite or delete the jurisdictional-scope table in `Domains/Risk/compliance-framework.md` (§2.1). Reconcile the corporate deck's "audit trails — Live" against §2. Reconcile the two decks' execution story (§2.2).                                                                                                                                                                                   | Engineering          | 1 day                               |
| **B2** | **Disable or remove AI view suggestion** from anything client-facing until A1 is answered (§3.2 item 2).                                                                                                                                                                                                                                                                                                                              | Engineering          | Hours                               |
| **B3** | **Implement and evidence jurisdiction exclusion** — declared residence and tax residence at onboarding, EU rejected, geo-block, decision logging (EU-1 to EU-5).                                                                                                                                                                                                                                                                      | Engineering          | 1 week                              |
| **B4** | **Bring outreach within POPIA s69** — consent-first approach for non-customers, in the prescribed manner and form; stop using a personal Gmail account for client personal information.                                                                                                                                                                                                                                               | Founder              | Days                                |
| **B5** | **Written founder-conduct rule** for the "direct access" sessions: no personal recommendations, scripted boundaries, sessions logged. This is the highest-probability breach vector and it is behavioural, not technical (§3.2 item 6).                                                                                                                                                                                               | Founder              | 1 day                               |
| **C1** | **Client agreement + terms of service + risk disclosure.** The deck's closing paragraph is a disclaimer, not a contract. Nothing exists in this repository. Needs: scope of service, characterisation consistent with A1, fees, liability, IP, data processing, termination.                                                                                                                                                          | Counsel              | 2–3 weeks                           |
| **C2** | **POPIA baseline:** registered Information Officer, PAIA manual, privacy notice, lawful basis register, s72 transfer basis for the Azure region actually in use, DPAs with sub-processors including any AI provider, breach-notification runbook.                                                                                                                                                                                     | Founder + counsel    | 2–3 weeks                           |
| **C3** | **Resolve "what the early group is funding"** — customer prepayment or securities offering (SA-14). If the latter, Companies Act offer rules apply and the deck itself becomes a regulated document.                                                                                                                                                                                                                                  | Counsel              | 1–2 weeks                           |
| **C4** | **Decide the fee model with counsel**, not before (§3.2 item 5).                                                                                                                                                                                                                                                                                                                                                                      | Founder + counsel    | With A1                             |
| **D1** | **Minimum security posture for holding client portfolio data.** The Sextant deck states no independent security audit has been done. Ingesting real holdings and wallet addresses before any review is a data-protection exposure under POPIA s19, not only a product risk. Either commission a scoped penetration test of the surfaces that hold client data, or design the first cohort so no client data is persisted server-side. | Engineering          | 2–4 weeks                           |

### 7.2 If A1 confirms advice (build before, or immediately after, licence grant)

| ID  | Item                                                                                   | Maps to        |
| --- | -------------------------------------------------------------------------------------- | -------------- |
| E1  | Suitability assessment flow and suitability statement artefact                         | S1, SA-5       |
| E2  | Client profile / risk tolerance / capacity-for-loss domain entities                    | S1, S2         |
| E3  | Record of advice — prescribed content, immutable, retrievable                          | S3, SA-4, SA-5 |
| E4  | FICA programme: RMCP, FIC registration, CDD, screening, monitoring, STR/CTR capability | SA-3           |
| E5  | Complaints procedure and Ombud disclosure                                              | S7, SA-12      |
| E6  | Audit-log implementation in the .NET core — currently zero                             | S3             |

### 7.3 Explicitly deferred, with named triggers

| Deferred                               | Trigger that un-defers it                                                                                      |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| EU market entry / MiCA authorisation   | A decision to target EU clients. 12-month-plus project.                                                        |
| SA Category II (discretionary) licence | Automated rebalancing or any discretionary execution                                                           |
| FIC Directive 9 travel rule            | Any crypto transfer on a client's behalf                                                                       |
| UK authorisation                       | Arranging, staking, or specified investment cryptoassets entering the asset universe; window opens 30 Sep 2026 |
| Crypto-hub entity (Mauritius / UAE)    | Revenue sufficient to support it, or SA route closing                                                          |
| EU AI Act Annex III high-risk          | Only if EU entry happens; deferred to 2 Dec 2027 in any event                                                  |

### 7.4 What is _not_ a blocker

Worth stating, so the list is not read as "stop everything":

- Demo mode with no client holdings ingested. The deck's `veritasvault.net/standard-demo` flow, as
  described, is generic and illustrative — the §3.2 argument turns on ingesting _the client's actual
  holdings_, which demo mode does not do. Confirm with counsel (Q5), but this is the strongest
  candidate for something that can continue unchanged.
- Building the Black-Litterman solver. Engineering work on the engine is orthogonal to the perimeter
  question.
- The corporate/institutional track, which is second in the stated GTM sequence and has a longer sales
  cycle anyway.

---

## 8. Questions for a qualified financial-services lawyer

### South Africa — perimeter

1. Does the Sextant product as described — ingesting a client's actual holdings, taking their stated
   views and confidences, and returning target portfolio weights plus drift against those weights —
   constitute "advice" under FAIS s1, or does it fall within the s1(3)(a) exclusion for an analysis or
   report without express or implied recommendation? Specifically: **is displaying the delta between
   current and target weights an implied proposal that a particular transaction is appropriate?**
2. Does the disclaimer in the Sextant deck have any perimeter effect at all, or is it purely a
   contractual allocation of risk between the parties?
3. **Territorial reach:** if advice is furnished _from_ South Africa to clients who are all
   non-resident, does FAIS still apply? And conversely, if the entity were offshore but the founder
   operates from South Africa, does that change the answer?
4. If the answer to Q1 is "advice", what are the realistic routes: own Cat I licence; operating as a
   representative or juristic representative of an existing licensed FSP; or product restructuring?
   What is the current realistic FSCA turnaround, and what would make this applicant's fit-and-proper
   case weak given the FSCA's stated decline reasons (operational ability / business plan, and
   demonstrated crypto competence)?
5. Is a purely illustrative demo mode — no client holdings, worked examples only — safely outside the
   perimeter?

### South Africa — obligations

6. Confirm the record-keeping retention periods that apply under FAIS and the FIC Act for an
   advice-only crypto FSP, and the required content of a record of advice.
7. Does the Board Notice 123 of 2009 PI/fidelity exemption for crypto asset FSPs currently apply to
   this profile, and on what conditions?
8. Under POPIA s69 and the Information Regulator's December 2024 guidance note, what exactly may
   founder-led outreach to prospective private clients look like — first contact, consent capture,
   and record-keeping?

### United Kingdom

9. **Does the s21 financial promotion regime capture the promotion of a portfolio-analysis tool for
   qualifying cryptoassets, as distinct from the promotion of the cryptoassets themselves?** This is
   the operative question for the public website and the Sextant deck, and it is live today.
10. Confirm that advising on and managing pure qualifying cryptoassets remain outside the perimeter
    following the 30 June 2026 final rules, and identify precisely which product behaviours would
    cross into "arranging deals" from 25 October 2027.
11. Given the 30 September 2026 application window and its transitional benefit, is there a case for
    applying pre-emptively on the assumption that rebalancing or staking eventually ships?

### Structure and offering

12. Is the Sextant early cohort a customer prepayment or an offer of securities? If the latter, which
    Companies Act exemption is relied on, and does the deck itself need to change?
13. If offshore structuring is considered: what are the SARB exchange-control consequences of moving
    IP or establishing an offshore entity, and does place-of-effective-management make an offshore
    company SA tax-resident in this fact pattern? _(Tax/exchange-control adviser, not FS counsel.)_

### Cross-cutting

14. On the working assumption that the SA answer is "advice" and the UK answer is "not regulated
    advice" — can one product lawfully serve both, with jurisdiction-conditional behaviour, or does
    the SA licence condition constrain the UK offering too?
15. What is the minimum defensible evidence of EU exclusion, given ESMA's guidelines on detecting
    circumvention of reverse solicitation?

---

## 9. Sources and as-at dates

All sources consulted 2026-08-11. Regulatory positions change; re-verify before relying on any of
this. The UK and EU positions in particular moved within the last ten weeks.

**South Africa**

- [FSCA update on licensing and supervision of crypto asset service providers — DLA Piper Africa](https://www.dlapiperafrica.com/en/south-africa/insights/2026/FSCA_Update_on_Licensing_and_Supervision_of_Crypto_Asset_Service_Providers) — as at 31 Mar 2026: 533 CASP applications, 310 approved, 17 declined, 124 withdrawn; FSCA's powers extend to advice, intermediary and investment management services in respect of crypto assets
- [FSCA licenses most crypto provider applicants — as enforcement tightens (Moonstone)](https://www.moonstone.co.za/fsca-licenses-most-crypto-provider-applicants-as-enforcement-tightens/) — decline reasons: fit and proper, operational ability, competency
- [What constitutes 'advice' in terms of the FAIS Act? (FSB Bulletin)](https://www.fsca.co.za/News%20Documents/2008%20FSB%20Bulletin%20Third%20Quarter.pdf) — s1(3)(a) exclusions
- [When does conduct constitute financial advice? (Mondaq)](https://www.mondaq.com/southafrica/financial-services/807278/when-does-conduct-constitute-financial-advice)
- [The Travel Rule — what CASPs need to know about Directive 9 (Masthead)](https://www.masthead.co.za/newsletter/the-travel-rule-what-casps-need-to-know-about-directive-9/) — Sch 1 items 12 and 22
- [Crypto KYC South Africa — CASP FICA Item 22 (VerifyNow)](https://www.verifynow.co.za/industries/crypto) — advice/intermediary services in respect of crypto = accountable institution under item 12 since 1 Dec 2023
- [FSCA releases amended exemptions for crypto asset FSPs (Moonstone)](https://www.moonstone.co.za/fsca-releases-amended-exemptions-for-crypto-asset-fsps/) — Board Notice 123 of 2009 PI/fidelity exemptions
- [Fit and proper requirements (RegulatoryExams)](https://regulatoryexams.co.za/blog/fit-and-proper-requirements-fsca) — RE1 for KIs, RE3 for Cat II/IIA
- [POPIA s69](https://popia.co.za/section-69-direct-marketing-by-means-of-unsolicited-electronic-communications/) and [Information Regulator's Guidance Note on Direct Marketing, Dec 2024 (Covington)](https://www.globalpolicywatch.com/2024/12/long-awaited-popia-guidance-on-direct-marketing-published-by-south-africas-information-regulator/)
- [Information Regulator signals tougher POPIA and PAIA enforcement (Moonstone)](https://www.moonstone.co.za/information-regulator-signals-tougher-popia-and-paia-enforcement/) — forthcoming s72 cross-border guidance note

**United Kingdom**

- [FCA Finalises Core Rules for the UK Cryptoasset Regime (Skadden, Jul 2026)](https://www.skadden.com/insights/publications/2026/07/fca-finalises-core-rules-for-the-uk-cryptoasset-regime)
- [UK Finalises Cryptoasset Rules: Key Considerations for Non-UK Firms (Morgan Lewis, Jul 2026)](https://www.morganlewis.com/pubs/2026/07/uk-finalises-cryptoasset-rules-key-considerations-for-non-uk-firms) — managing investments and advising on specified investments **not** extended to qualifying cryptoassets
- [Overview of our cryptoassets regime policy statements (FCA)](https://www.fca.org.uk/publications/policy-statements/cryptoasset-regime) — final rules 30 Jun 2026; regime live 25 Oct 2027; application window from 30 Sep 2026
- [CP26/13: Cryptoasset perimeter guidance (FCA)](https://www.fca.org.uk/publications/consultation-papers/cp26-13-cryptoasset-perimeter-guidance) — proposed PERG ch 19
- [Drawing the Line: the FCA's New Cryptoasset Perimeter Guidance (Freshfields)](https://www.freshfields.com/en/our-thinking/blogs/technology-quotient/drawing-the-line-navigating-the-fcas-new-cryptoasset-perimeter-guidance-102mvlt)

**European Union**

- [Statement on the end of transitional periods under MiCA (ESMA, Apr 2026)](https://www.esma.europa.eu/sites/default/files/2026-04/ESMA75-113276571-1679_Statement_on_the_end_of_transitional_periods_under_MiCA.pdf) — transitional expiry 1 Jul 2026
- [1 July 2026 MiCA cut-off (Harneys)](https://www.harneys.com/our-blogs/regulatory/1-july-2026-mica-cut-off-esma-s-statement-on-the-end-of-mica-transitional-periods/)
- [MiCA Article 81 (mica.wtf)](https://www.mica.wtf/mica/title-v-authorisation-and-operating-conditions-for-crypto-asset-service-providers-art.-59-85/chapter-3/article-81) — suitability for advice and portfolio management
- [ESMA Guidelines on suitability and periodic statement under MiCA, 26 Mar 2025](https://www.esma.europa.eu/sites/default/files/2025-03/ESMA35-1872330276-2031_Guidelines_on_suitability_and_periodic_statement_MiCA.pdf)
- [ESMA compliance table on MiCA reverse solicitation guidelines](https://www.esma.europa.eu/sites/default/files/2025-07/ESMA35-24871704-2592_Compliance_table_on_MiCA_reverse_solicitation_Guidelines.pdf)
- [EU AI Act Omnibus Agreement — postponed high-risk deadlines (Gibson Dunn)](https://www.gibsondunn.com/eu-ai-act-omnibus-agreement-postponed-high-risk-deadlines-and-other-key-changes/) — Reg (EU) 2026/1744, in force 27 Jul 2026; Annex III deferred to 2 Dec 2027; Art 50 transparency **not** deferred
- [The EU AI Act: what actually applies from August 2026](https://www.digitalapplied.com/blog/eu-ai-act-august-2026-transparency-obligations-agency-checklist)

**Repository evidence** — verified 2026-08-11 in worktree `nostalgic-gates-d71dec`

- [`src/vv.Application/DTOs/Compliance/ComplianceModels.cs`](../../src/vv.Application/DTOs/Compliance/ComplianceModels.cs)
- [`src/vv.Domain/Docs/Domains/Risk/compliance-framework.md`](../../src/vv.Domain/Docs/Domains/Risk/compliance-framework.md)
- [`src/vv.Domain/Docs/Crosscutting/implementation-guidance/compliance/enforcement.md`](../../src/vv.Domain/Docs/Crosscutting/implementation-guidance/compliance/enforcement.md)
- [`docs/investor/sextant-private-deck.html`](../investor/sextant-private-deck.html), [`veritasvault-corporate-deck.html`](../investor/veritasvault-corporate-deck.html), [`veritasvault-investor-overview.html`](../investor/veritasvault-investor-overview.html)
