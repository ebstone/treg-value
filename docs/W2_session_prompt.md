# W2 — Transcription. Claude Code session prompt.

Paste the block below into Claude Code at the repository root. Use Sonnet.
Requires W1 complete (all eight guards passing with violation fixtures).

Source PDFs must be placed in the working directory before the session starts:
Aliyev et al. 2019 Appendix S1 and Appendix S2, and ten Ham et al. 2020.

---

Read `SPEC.md`, `CLAUDE.md` and `docs/W2_sourcing_register.md` first. State the
commit hash you are working against.

This session transcribes published figures into `data/raw/`. **Transcription
only. Compute nothing.** Every conversion, adjustment and derivation belongs in
`derive/` in a later session. If you find yourself multiplying two numbers
together, stop — you are out of scope.

**Do not copy any file from the `treg-cd` repository.** Not as a starting point,
not to check your work, not to fill a gap. Every value comes from a published
source you have opened in this session.

## What to transcribe

| Target file | Source |
|---|---|
| `aliyev2019_induction_transitions.csv` | Aliyev Appendix S1, Suppl. Table 3 |
| `aliyev2019_maintenance_transitions.csv` | Aliyev Appendix S1, Suppl. Table 4 |
| `aliyev2019_source_parameters.csv` | Aliyev Appendix S1, Suppl. Table 2 — all 59 rows including distributions and alpha/beta |
| `aliyev2019_assumptions.csv` | Aliyev Appendix S1, Suppl. Table 1 — 29 assumptions with justifications |
| `tenham2020_case_studies.csv` | ten Ham et al. 2020 — all 8 case studies |

Already committed, do not redo: `data/raw/cms_asp_infliximab_2026.csv`.

## Sidecars

Every file gets `<file>.source.yaml` with citation, table or page, retrieval
date, sha256, and a `status` field. Follow the shape of the ASP sidecar already
in `data/raw/`. Where a figure is ambiguous or a cell is unreadable, record it
as an `unresolved` item in the sidecar with the consumer it blocks. **Do not
resolve ambiguity by choosing a reading.**

## Four traps, each of which has already cost this project time

1. **Suppl. Table 1's text layer extracts in scrambled, non-row order.** Pair
   each assumption with its justification against the rendered table image, not
   the extracted text stream. Mark any row you cannot confidently pair as
   `confidence: low` in the sidecar and say which rows they are. Several
   justification strings recur verbatim across different assumptions, so string
   matching will silently mis-pair them.

2. **ten Ham reports per *treatment*, not per *dose*.** A batch yields 22
   treatments at 4 doses each. Transcribe the published
   `total_per_treatment_eur` column verbatim — it is the commensurable unit and
   its absence is how a per-course figure was previously relabelled as a
   per-dose retail price. Add a `unit_note` to the sidecar stating that ten Ham
   treatments are 4 doses.

3. **Suppl. Table 2 costs are PMPM in 2008 USD.** Transcribe them as PMPM in
   2008 USD, named `_usd_pmpm_2008`. Do not convert to per-cycle figures. The
   PMPM-to-cycle rule is a `derive/` script (see `docs/W2_sourcing_register.md`
   S-2), and Aliyev's published per-cycle values are its *test fixture*, not a
   transcription target.

4. **Transition probabilities are native 2-week.** Transcribe at 2 weeks, suffix
   `_prob_2wk`. No DEALE conversion in this session.

## Then

Write the `derive/` script for health-state costs and its re-derivation test:
PMPM to 2-week cycle (14/30.44) times the 2008 to 2017 cost trend (1.03^9),
combined 0.60009. The test asserts the rule reproduces Aliyev's four published
per-cycle figures ($884, $217, $91, $10) within $2. This is the one permitted
value-snapshot test under guard 4, because it is a provenance re-derivation.

Note in the sidecar that the 2008 dollar-year and the choice of a 3% trend are
both inferred from the reconciliation rather than stated by Aliyev, and that
re-basing 2017 to 2025 USD requires a named index — which is a `derive/`
decision, not a transcription.

Run the full suite. Confirm guard G1 passes on populated directories, not just
empty ones. Add a line to `CHANGELOG.md`. Commit.

## Gate A

Do not proceed to W3 until: every file in `data/raw/` has a valid sidecar with a
resolving citation; every file in `data/derived/` re-derives from `data/raw/` by
a test; and the health-state cost rule reproduces all four published figures.
