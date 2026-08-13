# W4 — Treg arm and price frontier. Claude Code session prompt.

Paste the block below into Claude Code at the repository root. **Use Opus** —
both of the previous build's structural defects lived in this session's scope.

---

Read `SPEC.md` in full — sections 1, 4 and 7 especially — then `CLAUDE.md` and `SPEC_AMENDMENTS.md`. State the commit hash and run the full suite first.

This session adds the Treg arm and derives the price frontier. It is the gate the last two builds needed and did not have.

## What to build

1. **Two-fate split at cycle 6** (12 weeks, L1). A share `pi_cure` of **all treated patients** enters sustained drug-free remission. The remainder enters standard care in full.

2. **Pre-landmark trajectory (L9).** In cycles 0–5 Treg patients follow **conventional-therapy** dynamics. They receive no biologic, so they are given neither infliximab's transitions nor infliximab's costs.

3. **Sustained drug-free remission state** with an ongoing annual relapse hazard `h`. `h` is continuous and runs forever — not a one-time event at year one. Relapsed patients rejoin standard care (L4).

4. **Non-cured patients enter standard care in full (L3)** from cycle 6: the comparator's transition probabilities *and* its drug, administration and monitoring costs, including the induction course a rescued patient clinically requires at that point.

5. **Compute `B` directly** as the discounted lifetime NMB difference between a cured patient and a standard-care patient, at each `h` and each `λ`.

6. **Derive `A`**, then assemble `P*(π, h, λ) = A + π·B`.

## The two defects that have already happened here

**The denominator.** `pi_cure` has twice been implemented as a share of a subset — patients in remission on the biologic track — and reported as though it were a share of everyone treated. That flattened the price curve roughly fivefold and made every analog comparison incommensurable. The cure peels `pi_cure × (full cohort at cycle 6)`. Guard 3 and T4 exist for this. Assert it against the trace, not against the parameter's declared attribute.

**The intercept.** `P*(0)` must equal `A` and nothing else. Compute `A` twice — once from the model by evaluating at `pi_cure = 0`, and once by hand from the sourced unit prices and the 12-week window — and require agreement to $1. That is T1.

**`A` may be negative, and this is correct.** Under L9 a therapy that cures nobody has left the patient on conventional therapy for a quarter-year and then started them on the induction course anyway. If `A` comes out negative, do not adjust anything to prevent it. Report it. An intercept sitting at a few thousand dollars of unexplained savings is the failure mode; a small negative intercept is the honest result.

## Tests this session must satisfy

- **T1** — `P*(0)` equals independently computed `A` to within $1, whatever its sign.
- **T2** — `(P*(1) − P*(0))` equals `B`, and `B` computed directly as the cured-versus-standard-care NMB difference agrees to within $1. Two independent routes to the same quantity; if they disagree, the mechanic is wrong, not the tolerance.
- **T3** — `P*(π)` linear across a 101-point grid, deviation under $0.01. If it is not affine, something downstream of the split depends on `π` that should not.
- **T4** — at `pi_cure = 1`, the share of the **treated cohort** in drug-free remission at cycle 6 equals 1.00.
- **T5** — `P*` strictly decreasing in `h`, strictly increasing in `λ`; `B` decreasing in `h`.
- **T7** still holds with the new state: vectors sum to 1.00 ± 1e-10.
- **T11** — the analog comparison uses `pi_cure · exp(−h·t)` evaluated at each analog's own timepoint, never `pi_cure` itself. PolTREG reports at 24 months, Ovasave at week 8, and this study's landmark is 12 weeks. Comparing them directly is the denominator error wearing different clothes.
- **T12** — no pricing function reads the manufacturing benchmark. Grep, zero call sites.

## Out of scope

No probabilistic analysis, no EVPI, no EVPPI — those are W6. No manufacturing benchmark — that is W5 and it never enters the frontier. Do not compute an ICER; `SPEC.md` section 2 states this study reports none.

## Record

If you must decide anything not already in `SPEC.md` — whether a relapsed patient is charged a second induction course, for instance — add it to `SPEC_AMENDMENTS.md` in the same commit, with reasoning. Do not decide it in code.

## Then

Run the full suite. Add a line to `CHANGELOG.md`. Commit.

Report: `A` with its sign and both routes to it; `B` at each of the three `h` values and three `λ` values; `P*` at π = 0, 0.25, 0.5, 0.75, 1.0 for the central case; and the required cure fraction at $50k, $100k and $150k for a hypothetical $20,000 course, on the all-treated denominator.
