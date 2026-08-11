# Working rules for this repository

`SPEC.md` is the governing authority. Read it before anything else. If this file
and `SPEC.md` disagree, `SPEC.md` wins and this file is wrong.

## Session open

1. State the commit hash you are working against in your first message.
2. Run the full test suite. Report failures before doing anything else.

## The eight guards

These are enforced by tests. Do not work around a failing guard — fix the code
or amend the spec.

1. **Provenance.** Never write a value into `data/derived/` that is not produced
   by a script in `derive/` and re-derived from `data/raw/` by a test. Every file
   in `data/raw/` has a `<file>.source.yaml` with citation, table or page,
   retrieval date and SHA-256.

2. **Units in the identifier.** Every exported numeric ends in a unit suffix.
   The permitted list lives in `R/units.R`. Arithmetic combining two different
   suffixes must route through a named converter. Do not add a suffix to the
   list without adding its converters.

3. **Denominators are declared.** Every probability-like parameter carries an
   explicit denominator. `pi_cure` is `all_treated`. If a change makes the cure
   fraction conditional on remission, response, or track — stop and say so.

4. **Tests assert properties, not values.** Do not add a test that asserts a
   function returns the number currently sitting in a file. Value snapshots are
   permitted only inside provenance re-derivations.

5. **One spec, hash-stamped.** All output goes through `stamp_output()`, which
   writes the git commit hash and the SHA-256 of `SPEC.md`. Never call
   `write.csv` directly.

6. **Amendments are recorded or they do not happen.** If you change what an
   output means, or drop or narrow an aim, add an entry to
   `SPEC_AMENDMENTS.md` in the same commit.

7. **Open questions get no defaults.** Anything in `OPEN_QUESTIONS.md` is a
   required argument. The function refuses to run rather than assume a value.

8. **No status prose in code.** Do not write "currently", "not yet", "still a
   stub", "TODO" or "flagged for" into `R/` or `README.md`. Status belongs in
   `OPEN_QUESTIONS.md` only.

## Two things that have gone wrong before

- **The intercept.** At a cure fraction of zero the price must equal the
  independently computed rescue-window value and nothing else. If unexplained
  value appears there, something is being given away without being charged.
- **The denominator.** The cure fraction is a share of everyone treated. It has
  twice been implemented as a share of a subset and reported as if it were not.

## Session close

Run the full suite. Commit. Add one line to `CHANGELOG.md` naming what changed
and which tests now cover it.

## Model choice

Sonnet for transcription, scaffolding and figures. Opus for the cure mechanic
and the value-of-information work, and for any reconciliation that does not
close on the first attempt.
