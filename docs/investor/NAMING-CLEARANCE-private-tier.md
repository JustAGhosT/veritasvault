# Brand clearance research: "Sextant"

**Date:** 2026-08-12
**Scope:** Preliminary knock-out screen for "Sextant" as the VeritasVault private-client tier brand.
**Verdict on Sextant: BLOCKED — do not adopt.**

> ## Outcome: renamed to **Muniment**
>
> Sextant was rejected on the evidence below. After three screening rounds, **Muniment** was
> selected and the deck has been rewritten and renamed:
>
> - `docs/investor/muniment-private-deck.html` — renamed, rebranded, cover mark redrawn, and
>   the navigation metaphor replaced throughout (see "Deck rewrite" at the end of this document)
> - `docs/investor/Muniment-Private-Deck.pdf` — regenerated from the new HTML; verified 7 pages,
>   0 occurrences of "Sextant", 14 of "Muniment"
>
> Still outstanding: `STANDARD_PRODUCT_NAME` in `JustAGhosT/vv-landing`, the git-history
> question, and attorney clearance. See "Recommended sequence".

> **This is research, not legal advice.** It is a knock-out screen: it is designed to find
> disqualifying collisions cheaply, not to certify that a name is safe. A clean result here
> would still require a registered trademark attorney to run full clearance (including
> phonetic//similar-mark searching and common-law use) before any filing or public launch.
> This screen found disqualifying collisions, so that step is moot for this name.

---

## 0. Immediate issue: the name is already public

The premise of the task was "clear it before it is used externally." That has already happened.

| Fact                                           | Evidence                                                                                                                                                                                                                                       |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Repo `neuralliquid/veritasvault` is **PUBLIC** | `gh repo view --json nameWithOwner,visibility` → `neuralliquid/veritasvault`, `PUBLIC`. Note: `JustAGhosT/vv` is a **redirect alias**, not the canonical name — `gh api repos/JustAGhosT/vv` silently resolves to `neuralliquid/veritasvault`. |
| Deck is on the default branch                  | `docs/investor/sextant-private-deck.html` + `Sextant-Private-Deck.pdf` on `origin/main`, commit `4d08aad`                                                                                                                                      |

Both the HTML deck and the rendered PDF are world-readable on GitHub right now. Anyone
searching the repo, and any code-search index, can see the private-client tier branded
"Sextant". This does not create trademark liability by itself — liability attaches to _use
in commerce as a source identifier_, and a repo file is weak on that — but it does mean the
name is discoverable, indexable, and no longer confidential. Treat it as disclosed.

---

## 1. Trademark screen

"Sextant" is a common word, and the working assumption was that prior art would exist in
adjacent software but might miss the relevant classes. That assumption is wrong. The prior
art lands squarely in **class 36**, which is the class that matters most for a private-client
financial tier.

### Class 36 — financial services (fatal)

| #   | Holder                                                    | What                                                                                                                        | Where                         | Why it matters                                                                                                                                               |
| --- | --------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | **Amiral Gestion**                                        | Entire **Sextant SICAV fund range**: Sextant PEA, Sextant Europe, Sextant PME, Sextant Autour du Monde, Sextant Grand Large | France / EU-wide distribution | Independent asset manager, founded 2003, **€3.5bn+ AUM**, explicitly serving _"institutional investors, private banks, **family offices**, and individuals"_ |
| 2   | **Saturna Investment Trust** (managed by Saturna Capital) | **Sextant Mutual Funds** family — Growth, International, Core, Bond Income, Global High Income                              | US                            | Saturna's own terms page states the _"Sextant Funds logo… are trademarks of Saturna Investment Trust"_                                                       |
| 3   | **Sextant Group, Inc.**                                   | US mark `SEXTANT`, filed **1996-09-09**                                                                                     | US                            | Goods/services: _"financial services, namely, investment brokerage and management, financial research, financing services, and financial consulting"_        |
| 4   | Sextant Advisory Services                                 | Capital raising / asset management advisory                                                                                 | **UK & EMEA**                 | 60+ year track record; network across private equity, institutional investors, wealth management, **family offices**, SWFs                                   |
| 5   | Sextant Wealth Management                                 | Wealth management                                                                                                           | US                            | Operating firm                                                                                                                                               |
| 6   | Sextant Capital Solutions                                 | Capital raising and structuring advisory                                                                                    | US                            | Operating firm                                                                                                                                               |
| 7   | Sextant Wealth Advisory Group of Raymond James            | Wealth advisory                                                                                                             | US (Jacksonville, FL)         | Operating under a major broker-dealer                                                                                                                        |

**Item 1 is the disqualifier.** It is the TrueMoney collision repeated almost exactly:

|                  | TrueMoney (rejected)                | Sextant (proposed)                                                                  |
| ---------------- | ----------------------------------- | ----------------------------------------------------------------------------------- |
| Incumbent        | Ascend Money's TrueMoney            | Amiral Gestion's Sextant funds                                                      |
| Sector           | Same (fintech / financial services) | Same (investment management)                                                        |
| Customer overlap | Same (retail financial services)    | **Closer** — family offices and private banks _are_ the private-client tier's buyer |
| Geography        | SE Asia                             | **EU/UK — a market VeritasVault would actually market into**                        |

The reason TrueMoney was set aside was "same sector, overlapping geographies, which is the
most dangerous class of collision." Sextant meets that test on the same terms, with the
added problem that the incumbent's customer segment is _identical_ to the tier being named,
not merely adjacent.

### Classes 9 and 42 — software and technology services

| Mark                                     | Classes      | Status                 | Notes                                                                |
| ---------------------------------------- | ------------ | ---------------------- | -------------------------------------------------------------------- |
| `SEXTANT TECHNOLOGY CONSULTING`          | **9 and 42** | Registered             | Computer software; computer programming and software design services |
| `SEXTANT VWT`                            | 42           | Abandoned (filed 2005) | Geospatial analysis/visualisation software                           |
| Sextant Avionique (absorbed into Thales) | 9            | Historical, French     | Deep EU class 9 history in avionics/instrumentation                  |

So the software classes are occupied too — the name does not survive by retreating from
"financial services" to "software".

### Register coverage — what this screen did and did not check

| Register                | Status            | Note                                                                                                                                                                                                                                           |
| ----------------------- | ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| USPTO                   | **Indirect**      | Records surfaced via public trademark mirrors and search, not read from TESS directly. USPTO's search app is a JS SPA and its API was not reachable from this environment; Justia and Trademarkia both returned HTTP 403 to automated fetches. |
| EUIPO                   | **Indirect**      | Amiral Gestion's use is documented and unambiguous; the specific EUTM registration numbers were not pulled from the register.                                                                                                                  |
| UK IPO                  | **Indirect**      | Sextant Advisory Services' UK/EMEA operation documented; register not read directly.                                                                                                                                                           |
| CIPC (South Africa)     | **Not completed** | No "Sextant" financial-services entity surfaced in search, but CIPC's BizPortal requires an interactive session. Treat as _unchecked_, not _clear_.                                                                                            |
| TMview (multi-register) | **Failed**        | API returned empty.                                                                                                                                                                                                                            |

**This gap does not change the verdict.** Items 1–3 alone are disqualifying, and every
uncompleted check could only add collisions, never remove them. But it does mean the
evidence below is "documented commercial use" rather than "certified register extracts" —
which is the correct standard for a knock-out screen and the wrong standard for clearance.

---

## 2. Domain availability

Verified via DNS-over-HTTPS `NS` lookups (NXDOMAIN = unregistered) and RDAP where the TLD
supports it.

> Methodology note: `rdap.org` returns HTTP 404 for `.io`, `.co`, `.vc` and `.wealth` even
> for domains that are definitely registered (control-tested against `github.io`,
> `google.co`, `github.vc`). Those 404s mean "no RDAP server for this TLD", **not**
> "available". An earlier pass of this research briefly read them as available. The NS
> results below are the correct answer.

### Taken

| Domain            | Registered | Note                                         |
| ----------------- | ---------- | -------------------------------------------- |
| `sextant.com`     | 1997-06-27 |                                              |
| `sextant.net`     | 1997-01-28 |                                              |
| `sextant.finance` | —          | OVH nameservers                              |
| `sextant.ai`      | —          | DNSimple                                     |
| `sextant.capital` | —          | cdmon                                        |
| `sextant.io`      | —          | Spaceship                                    |
| `sextant.vc`      | —          | IONOS                                        |
| `sextant.co`      | —          | **Afternic nameservers — parked for resale** |
| `sextant.app`     | —          | **Afternic nameservers — parked for resale** |

### Taken, and this is the important part

| Domain               | Registered                     | What's there                                            |
| -------------------- | ------------------------------ | ------------------------------------------------------- |
| **`getsextant.com`** | **2025-05-12**                 | Live page: _"Launching Soon"_ + email capture form      |
| **`usesextant.com`** | **2026-07-28 — two weeks ago** | Live page: _"We're under construction"_, on Squarespace |

Two separate parties have taken the two canonical startup domain patterns (`get-` and
`use-`), both are pre-launch, and one was registered a fortnight ago. Neither reveals its
sector. This is the pattern of a name being actively contested right now. Even setting
trademark aside, launching into that is a fight over search results and brand recall with
at least two unknown parties who moved first.

### Available

`sextant.wealth`, `sextant.money`, `sextant.fund`

All three are low-trust TLDs. For a tier whose entire proposition is verifiability and
institutional credibility with family offices, `.money` and `.fund` actively work against
the positioning.

---

## 3. Social handles

| Handle                                          | Status                                                                                                                                                                |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `github.com/Sextant`                            | **Taken** — user ID 14338428, created 2015-09-17, 0 public repos, dormant. Squatted; GitHub does not release inactive usernames on request.                           |
| `github.com/sextantfinance`                     | Available                                                                                                                                                             |
| `x.com/sextant`, `linkedin.com/company/sextant` | **Unverified.** Both hosts return HTTP 200 for the SPA shell regardless of whether the handle exists, so the probe proves nothing. These need a manual eyeball check. |

---

## 4. Verdict

### BLOCKED.

Not "risky" — blocked. Three independent grounds, any one of which would be enough:

1. **Class 36 is occupied by a €3.5bn EU asset manager whose stated clientele is private
   banks and family offices.** That is not adjacent prior art; that is the same product
   category sold to the same buyer in a market you would enter.
2. **Classes 9 and 42 are also occupied**, so there is no retreat into "we're a software
   brand, not a financial one."
3. **The commercial runway is gone anyway** — every credible domain is taken, two of them
   by pre-launch startups using the exact naming pattern you would need, and the GitHub
   handle is squatted.

### On the subdomain question — it does not solve this

The hypothesis was that `sextant.veritasvault.net` might sidestep the problem for an early
cohort. It does not, and it is worth being precise about why.

`veritasvault.net` is registered and under your control (GoDaddy nameservers, valid SOA), so
the subdomain is _technically_ available — but availability was never the issue.

Trademark infringement turns on **use in commerce as a source identifier**, not on where a
DNS record points. Putting "Sextant" on an investor deck, a pitch, a product surface, or a
statement sent to a prospective private client in the EU or UK is use in commerce whether
it is served from `sextant.veritasvault.net`, `sextant.com`, or a PDF attachment. A
subdomain solves _domain acquisition cost_. It does nothing for the legal exposure, and it
does nothing about the two startups racing you to the name.

An internal codename for an unreleased cohort is fine. The current deck is investor-facing,
which is external by definition.

---

## 5. What to do instead

### Primary recommendation: don't brand the tier at all

Use a **descriptive tier designator under the VeritasVault masterbrand**:

> **VeritasVault Private** (or _VeritasVault Private Client_)

Why this is the right answer rather than a fallback:

- **Nothing to clear.** A descriptive tier label riding a masterbrand isn't an independent
  mark. The mark you defend is VeritasVault — the one that's actually worth owning. Zero
  clearance cost, zero timeline, zero collision surface.
- **It's what the category does.** Schwab Private Client, J.P. Morgan Private Bank, Citigold
  Private Client. None of those are separately-branded companies; they're tiers. The
  private-client segment reads a masterbrand tier as _more_ institutional, not less — a
  standalone brand for a tier can read as a thinner, unrelated entity.
- **It compounds.** Every impression of "VeritasVault Private" builds the VeritasVault mark.
  Every impression of "Sextant" builds a second brand you'd have to clear, register,
  defend, and explain, funded from the same budget.
- **It kills the current problem immediately.** No search, no attorney, no waiting.

The cost is that "Private" is generic and unownable standing alone. For a _tier_, that's
correct — you don't want to own it, you want it to be instantly legible.

### If a distinct brand is genuinely wanted

Then it needs to happen _after_ the screen, not before. Two corrections to the shortlist:

| Candidate     | Prior assessment                               | Actual finding                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| ------------- | ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Plumbline** | "distinctive, low collision, needs explaining" | **Dirtier than assumed.** Plumb Line Capital Partners (PE firm, founded 2017, Charlotte NC); Plumb Financial (RIA); Plumb Funds (Wisconsin Capital Management); and **Plumb Bill Pay**, a financial-administration product explicitly for _HNW individuals and families_ — i.e. squarely in the private-client lane. `plumbline.com`, `plumbline.co` and `getplumbline.com` are all registered; only `plumbline.finance` is free. Not the clean option it looked like. |
| **Lodestar**  | "some existing finance usage"                  | Confirmed direction — and note the deeper problem below.                                                                                                                                                                                                                                                                                                                                                                                                               |
| **Ballast**   | "reads defensive"                              | Agreed, plus Ballast Point / Ballast Rock Capital exist in the space.                                                                                                                                                                                                                                                                                                                                                                                                  |

**The structural problem with the whole shortlist:** Sextant, Lodestar, Ballast and Astrolabe
are all navigation-and-seamanship metaphors, and that metaphor space is the most heavily
mined ground in asset management. Compass, Meridian, Waypoint, North Star, Lodestar,
Anchor, Beacon, Helm — all have multiple incumbent financial firms. Picking another
dictionary word from that well will keep producing this same result. Screening confirms it:
`astrolabe.com`/`.finance` and `keel.com`/`.finance` are all already registered.

If a distinct brand is required, the brief should be **a coined or compound mark**, not a
borrowed one. Coined marks are inherently distinctive, which makes them far easier to
register and to defend, and they leave the domain and handle space open. That is a naming
exercise, not a search exercise — and whatever it produces goes through this same screen
_before_ it enters a deck.

### Screened sub-brand shortlist (second pass)

A second round screened sub-brand candidates for the `VeritasVault <word>` compound pattern.
Under a masterbrand the tier word does not need to be ownable standing alone — the mark is
the compound — so a taken `.com` is not disqualifying. What _is_ disqualifying is an
incumbent using the word as a financial-services brand.

**Killed, with evidence:**

| Candidate | Why it died                                                                                                                                                  |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Keel      | 6+ RIAs: Keel Wealth Management, Keel Financial Partners, Keel Capital Management, On Keel Capital, WealthKeel                                               |
| **Spike** | Spike Financial (Houston), Spike Wallet, Spike Payments — and **Spike (Cape Town, 2018, open-banking API)**, a South African fintech. Home-market collision. |
| Filament  | Filament Inc — blockchain/DLT for IIoT, $39.8M raised, Verizon-backed. Adjacent to VeritasVault's own space.                                                 |
| Assay     | Assay Wealth Partners (Dallas RIA), Regent Assay Corporate Finance (UK M&A), Assay Advisory (London PE/VC), Assay AI                                         |
| Crucible  | Crucible Capital ($50M fund, Nomura-anchored) and Crucible Fintech                                                                                           |
| Vernier   | Vernier Capital Partners (hedge fund); Vernier Capital Advisors — serves _"wealth managers, private banks, institutional investors"_                         |
| Gnomon    | Gnomon Capital (PE, invests in financial services/fintech); Gnomon Alpha (global macro hedge fund)                                                           |
| Verax     | Verax Capital Partners, Verax Investments, Verax Partners, Verax Business Group                                                                              |
| Faraday   | **Faraday Capital** — _"specialist wealth management company"_; Faraday Capital LP (RIA); Faraday Venture Partners (fintech VC); plus Faraday Future         |

**Survivors — no financial-services incumbent found, `.finance` available:**

| Candidate    | Meaning                                                                                         | Fit                                                                                                   | Caveat                                                                         |
| ------------ | ----------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| **Colophon** | The inscription naming who made a work, where, when, and how — literally a provenance statement | **Best thesis fit.** The deck's argument is _"when every position traces"_; a colophon _is_ the trace | Only collision is a publishing SaaS. Quiet/bookish — no energy                 |
| **Cupel**    | The fire-assay vessel that separates true precious metal from base                              | Perfect thesis fit — separating a good decision from a lucky one                                      | **Zero collisions found anywhere.** But phonetically risky (heard as "couple") |
| **Voltaic**  | The voltaic pile — first true battery; stored potential                                         | Energy/charge feel                                                                                    | Adjective, reads slightly odd as a tier noun                                   |
| **Galvanic** | Both _energising_ and _galvanised_ = protected from corrosion                                   | Energy **plus** protection — pairs with "Vault"                                                       | Adjective; four syllables                                                      |
| Escapement   | Watch mechanism metering energy in precise countable increments                                 | Precision + horology/luxury adjacency                                                                 | Contains "escape" — wrong morpheme for a vault brand. Deprioritised            |

**Recommendation: Colophon**, with **Galvanic** as the energy-forward alternative.

All of these are knock-out-screened only. Whichever is chosen still needs attorney clearance
before filing or launch.

### Screened sub-brand shortlist (third pass — medieval financial vocabulary)

Medieval treasury, coinage and conveyancing vocabulary is under-mined commercially _and_
maps directly onto the product thesis: the tally stick, the Trial of the Pyx and muniments
of title are all tamper-evidence and proof-of-ownership mechanisms.

**Killed, with evidence:**

| Candidate     | Why it died                                                                                                                                                                                       |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Seneschal** | **Seneschal Family Office** — RIA, Tacoma WA, $1M–$15M+ account minimums. Precisely the target segment.                                                                                           |
| Demesne       | Demesne Investments — RIA registered in South Carolina and Virginia                                                                                                                               |
| Exchequer     | Exchequer Wealth Management Limited (UK, Companies House 13735189); `.finance` taken                                                                                                              |
| Moneyer       | The Moneyer — personal finance management platform, Amsterdam                                                                                                                                     |
| Counterfoil   | An operating company exists on LinkedIn under this name                                                                                                                                           |
| Pyx           | No finance collision, but `.pyx` is the **Cython source-file extension** — permanently unsearchable for a software brand. Dropped on judgement, not collision.                                    |
| **Allodial**  | No commercial collision, but "allodial title" is a signature claim of the **sovereign-citizen pseudo-legal movement**. Toxic association for a regulated financial product. Dropped on judgement. |

**Survivors — no collision found in any sector, `.finance` available:**

| Candidate      | Meaning                                                                                                         |
| -------------- | --------------------------------------------------------------------------------------------------------------- |
| **Muniment**   | Documentary evidence proving ownership — deeds, grants, title. Still live legal usage ("muniments of title").   |
| **Chirograph** | A document written twice on one sheet and cut apart through the lettering, so each half authenticates the other |
| **Cartulary**  | The register in which a house or institution transcribed its charters and title deeds                           |

#### Recommendation: **Muniment**

- **Etymology is the pitch.** From Latin _munire_, "to fortify" — the same root as _munitions_.
  A muniment is, literally, _fortified proof_.
- **A muniment room** was the strongroom in a great house or cathedral where title deeds were
  kept — a vault whose sole contents were proof of ownership. VeritasVault, described in the
  13th century.
- **Still a live legal term.** "Muniments of title" remains current in English-derived
  property and probate practice, so it reads as serious rather than invented to lawyers and
  family-office counsel.
- **Zero commercial collisions found** in any sector or class.
- **Available:** `muniment.finance`, `muniment.co`, `muniments.com`. (`muniment.com` and the
  GitHub handle are taken — neither is needed for a masterbrand tier.)
- **Pairs with the masterbrand.** Veritas and muniment are both Latin-rooted: _the truth, and
  the fortified proof of it._

Cost: it is obscure and needs one sentence of explanation. That sentence is also the product
pitch, which is the best case for an obscure name.

**Alternates:** _Chirograph_ has the better mechanism story — each half proves the other, which
is attestation four centuries before cryptography — but "chiro-" misreads and it will be
misspelled. _Cartulary_ is clean but phonetically close to "cautionary".

### Process fix

The reason this happened is that the name went into a committed, public deck before it was
screened. A ten-minute domain-and-register check ahead of the design work would have caught
Amiral Gestion. Suggested rule: **no proposed brand name enters a document that gets
committed until it has passed a knock-out screen.** Working sessions can use a placeholder.

---

## 6. What happens to "Neural Liquidity"

**Recommendation: rename it — but for a different reason than Sextant, and the reason
matters.**

**Trademark exposure: low.** No registered mark for "Neural Liquidity" surfaced in
financial services or software. The only adjacent usage found is "Neural Liquidity Cloud",
a 2028 roadmap item in a crypto project's (NeuraFusion) marketing material — a future
product vision, not an operating brand or a registration. On trademark grounds alone this
would be survivable.

**The actual problem is investor-facing, not legal.** `neuralliquid.ai` and
`neuralliquid.com` are both registered, and the `neuralliquid` GitHub organisation is live
(both confirmed). That is a **separate venture of the founder's**. Shipping a VeritasVault
product tier called "Neural Liquidity" while a distinct company called Neuralliquid exists
under the same founder creates an apparent related-party question in exactly the document
where you least want one: is this tier VeritasVault IP or Neuralliquid IP? Is there a
licence? Does VeritasVault own its own product name? A diligent investor will ask, and the
honest answer costs a slide.

That's a sharper reason to fix it than trademark risk, and it doesn't depend on how the
Sextant decision lands.

**This is stronger than first assessed.** The VeritasVault repository does not merely share a
word with the separate venture — **it lives inside that venture's GitHub organisation.** The
canonical repo is `neuralliquid/veritasvault`; `JustAGhosT/vv` is only a redirect alias that
resolves silently, which is why the earlier pass recorded the wrong owner. An investor running
code diligence does not find a VeritasVault repo that happens to use the phrase "Neural
Liquidity" — they land on `github.com/neuralliquid/veritasvault` and see the platform hosted
under another company's org. That converts the naming question into an asset-ownership
question, which is a materially harder one to answer in a data room.

Renaming the product tier does not by itself resolve this. The repository's home org is the
larger issue and is worth a deliberate decision before any raise.

**Recommendation:** apply the same masterbrand logic — make it a descriptor, not a brand.

| Current                                      | Proposed                                                                             |
| -------------------------------------------- | ------------------------------------------------------------------------------------ |
| `STANDARD_PRODUCT_NAME = "Neural Liquidity"` | `"VeritasVault"` (or `"VeritasVault Standard"` if the tier must be named in-product) |
| Private tier                                 | `"VeritasVault Private"`                                                             |

One brand, two legible tiers. No clearance needed for either, no related-party ambiguity,
and the marketing spend compounds into a single mark.

### Scoping note for the rename

`product-info.ts` is **not in this repository.** This repo (`neuralliquid/veritasvault`) is a .NET
solution plus docs; a full grep for `STANDARD_PRODUCT_NAME`, `Neural Liquidity`,
`NeuralLiquid` and `TrueMoney` across all source and markdown returns nothing. The constant
lives in **`JustAGhosT/vv-landing`** at `lib/config/product-info.ts`, so the code change is
separate-repo work.

In _this_ repo the only affected artefacts were:

- `docs/investor/sextant-private-deck.html` → now `muniment-private-deck.html`
- `docs/investor/Sextant-Private-Deck.pdf` → now `Muniment-Private-Deck.pdf`

Both were on `main`, both public.

---

## 7. Recommended sequence

1. ~~**Decide the naming architecture.**~~ **Done** — a distinct sub-brand under the
   VeritasVault masterbrand was chosen over a descriptive tier. Name: **Muniment**.
2. ~~**Rewrite and rename the deck.**~~ **Done** — see "Deck rewrite" below.
3. **Purge from history if the name is considered sensitive.** A plain rename commit leaves
   "Sextant" in the git history of a public repo. If that matters, it needs a history
   rewrite and a force-push, which is a deliberate, disruptive act on a shared public repo —
   your call, not a default.
4. **Update `product-info.ts` in `vv-landing`** to retire "Neural Liquidity".
5. **Engage a trademark attorney for VeritasVault itself.** This is the mark actually worth
   protecting, and the one that should be registered in the relevant classes (9, 36, 42)
   across ZA / EU / UK / US. Everything above is a knock-out screen, not clearance.

---

## Sources

- [Sextant PEA – Amiral Gestion](https://www.amiralgestion.com/en/sextant-pea)
- [Sextant Grand Large – Amiral Gestion](https://www.amiralgestion.com/en/sextant-grand-large)
- [Sextant SICAV – Amiral Gestion](https://www.amiralgestion.com/en/nos-fonds-sextant)
- [Amiral Gestion asset manager profile – Preqin](https://www.preqin.com/data/profile/investor/amiral-gestion/382390)
- [Terms & Conditions – Saturna Capital](https://www.saturna.com/terms-conditions)
- [All Mutual Funds – Saturna Capital](https://www.saturna.com/funds)
- [Sextant Group, Inc. trademarks – Justia](https://trademark.justia.com/owners/sextant-group-inc-809658)
- [SEXTANT TECHNOLOGY CONSULTING – Justia](https://trademarks.justia.com/763/21/sextant-technology-consulting-76321163.html)
- [SEXTANT VWT – Justia](https://trademark.justia.com/786/26/sextant-vwt-78626014.html)
- [Sextant Advisory Services](https://sextantas.com/)
- [Sextant Wealth Management](https://www.sextantwealthmanagement.com/services)
- [Sextant Capital Solutions](https://www.sextantcapitalsolutions.com/)
- [Sextant Wealth Advisory Group of Raymond James](https://www.raymondjames.com/sextantwealth)
- [Plumb Line Capital Partners – PitchBook](https://pitchbook.com/profiles/investor/504138-34)
- [Plumb Bill Pay – The Wealth Mosaic](https://www.thewealthmosaic.com/vendors/the-wealth-mosaic/news/introducing-plumb-bill-pay-developed-by-financial-/)
- [Plumb Financial](https://plumb-financial.com/)
- [EUIPO – Nice classification FAQ](https://www.euipo.europa.eu/en/help-centre/searches/faq-nice-classification)

---

## 8. Deck rewrite (what actually changed)

The rename was not a find-and-replace. The deck was built on a navigation metaphor that the
name carried, so the metaphor had to be replaced along with the word.

**Worth noting:** the deck's own argument was already about record-keeping, not navigation —
_"No record of why"_, _"Every decision leaves a record"_, _"when every position traces back to
a dated, written, confidence-weighted view"_. The navigation framing had been working against
the content. The swap improves coherence rather than merely preserving it.

| Element              | Before                                                                             | After                                                                                                                                 |
| -------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `<title>` / wordmark | Sextant                                                                            | Muniment                                                                                                                              |
| Cover mark (SVG)     | Hand-drawn sextant: arc, degree ticks, index arm, horizon mirror                   | **Indenture** — one deed cut in two along a toothed line so each half authenticates the other, bound by a seal struck across the join |
| Cover tagline        | "Know where you stand."                                                            | "Know what you hold — and why."                                                                                                       |
| Method slide title   | "Take a reading. Then set your course."                                            | "Start from evidence. Then state your case."                                                                                          |
| Method subtitle      | "A sextant does not tell you where to sail. It tells you precisely where you are…" | "A muniment is the document that proves what you hold and on what basis. This method produces one for every allocation decision…"     |
| Step 1               | Fix your position                                                                  | Establish the baseline                                                                                                                |
| Step 2               | Declare your bearing                                                               | Record your view                                                                                                                      |
| Step 3               | Sail the blended course                                                            | Hold the blended position                                                                                                             |
| CTA 1                | Take a reading                                                                     | Look for yourself                                                                                                                     |
| CTA 2                | Chart your own book                                                                | Enter your own book                                                                                                                   |
| Footer marks (×6)    | Sextant · by VeritasVault                                                          | Muniment · by VeritasVault                                                                                                            |

**Deliberately left unchanged:** _"What changes with an instrument"_ and _"The instrument never
overrules you"_. A muniment **is** a legal instrument, so both lines survive the rename and read
more precisely than before.

**Verification performed:**

- `grep -rin sextant` across all `.html/.md/.ts/.tsx/.json` → zero hits outside this document
- Cover SVG geometry measured in-browser: both halves 64 units wide, mark centred at (100, 99)
  in a 200×200 viewBox, teeth meshing with a constant 8-unit channel
- PDF regenerated from the new HTML with headless Chrome and text-extracted: **7 pages,
  0 occurrences of "Sextant", 14 of "Muniment"**, new tagline present

**Not done, deliberately:** no code renamed in any repo (out of scope per the brief, and
`product-info.ts` lives in `vv-landing` regardless); no git history rewritten.
