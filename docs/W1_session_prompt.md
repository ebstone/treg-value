# W1 — Guards. Claude Code session prompt.

Paste the block below into Claude Code at the repository root. Use Sonnet.

---

Read `SPEC.md` and `CLAUDE.md` first. State the commit hash you are working
against before you begin.

Your task this session is to build the eight guards and nothing else. **Do not
write any analysis code, any model module, or any data transcription.** The
repository must end this session with an empty model and a working immune system.

Initialise an R project with `renv` and `testthat`.

Implement each guard as a **failing test first**, then the minimum machinery to
make it pass on an empty repository, then a fixture under `tests/violations/`
that proves the guard fires when deliberately violated. A guard without a
violation fixture is not done.

**G1 — provenance.** A `.source.yaml` schema (citation, table or page,
retrieval date, sha256) and a validator. `test-provenance.R` walks `data/raw/`
and fails on any file without a valid sidecar, then walks `data/derived/` and
fails on any file with no producing script in `derive/` and no re-derivation
test.

**G2 — units.** `R/units.R` holds the permitted suffix list: `_usd_per_course`,
`_usd_per_dose`, `_usd_per_cycle`, `_usd_per_qaly`, `_prob_2wk`, `_per_year`,
`_qaly`, `_cycles`, `_weeks`, `_cells_per_kg`. `test-units.R` lints all exported
numeric names against it. Converters are the only functions permitted to change
a suffix; each must name both units in its own name.

**G3 — denominators.** A small constructor that attaches a `denominator`
attribute to probability-like parameters, and `test-cure-denominator.R`
asserting that any parameter named `pi_cure` carries `denominator = "all_treated"`.
The mechanical assertion against the cure mechanic comes in W4; scaffold the
test so it will bind then.

**G4 — no snapshots.** `test-no-snapshots.R` greps test files for numeric
literals of four or more significant figures outside `tests/testthat/test-provenance.R`
and fails on them.

**G5 — stamping.** `stamp_output()` writes a header carrying the git commit hash
and the SHA-256 of `SPEC.md` at run time, and refuses to run if the working tree
has uncommitted changes to `SPEC.md`. `test-stamping.R` asserts `write.csv` and
`write_csv` appear nowhere in `R/` or `analysis/`.

**G6 — aim coverage.** `test-aims-covered.R` parses the aims table in `SPEC.md`
section 6, and fails if any aim has neither its named output file nor a matching
row in `SPEC_AMENDMENTS.md`. On an empty repository every aim will be uncovered,
so this test should be written to skip with an explicit message until
`output/tables/` is populated — but it must not pass silently.

**G7 — no defaults.** `test-no-defaults.R` parses the open-items table in
`OPEN_QUESTIONS.md` and asserts that no function in `R/` supplies a default for
an argument matching one of those names.

**G8 — no status prose.** `test-no-stale-prose.R` greps `R/` and `README.md` for
"currently", "not yet", "still a stub", "TODO", "flagged for", "for now", and
fails on any hit.

Finish by running the full suite and confirming that all eight pass on the empty
repository and all eight fail against their violation fixtures. Add one line to
`CHANGELOG.md`. Commit.
