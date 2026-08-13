# W3 — Comparator Markov engine. Claude Code session prompt.

Paste the block below into Claude Code at the repository root. Use Sonnet.

---

Read `SPEC.md`, `CLAUDE.md` and `CHANGELOG.md` first. State the commit hash you are working against and run the full suite before touching anything.

This session builds the comparator side of the model and nothing else. **No Treg arm, no cure fraction, no price, no frontier.** Those are W4. If you find yourself writing a variable named `pi` or `P_star`, stop.

## What to build

1. **Induction decision tree.** Aliyev's binary Response / No Response structure. Responders enter the biologic maintenance matrix; non-responders enter the conventional-therapy matrix.

2. **Markov engine.** Six states, 2-week cycles, native Aliyev probabilities with no DEALE conversion. Half-cycle correction. Background mortality layered from the life table. Discounting at 3% annual applied at cycle level.

3. **Lifetime infliximab trace** — discounted costs and QALYs, produced under every combination required by `SPEC.md`: both induction windows (L5), cap-on and cap-off (L6), and all three horizons.

Write the trace and the validation tables through `stamp_output()`. These are intermediate artifacts, not aim outputs — no aim in `SPEC.md` section 6 is satisfied by this session.

## Six traps, each already paid for once

1. **Induction must accrue cost and QALYs in every arm.** The previous build started the Markov clock at end of induction, so four to six weeks accrued nowhere. Because induction length differs by arm, that omission was not symmetric — it measured 0.0243 QALYs, which was 111% of the incremental QALY difference it was distorting. Accrue induction as explicit cycles.

2. **The maintenance cap fires one cycle early if written naively.** Setting `apply_cap_now = (t == cap_cycle)` sweeps biologic mass to CT on the transition *into* the cap cycle, so the last dose cycle is never charged. Decide explicitly whether the cap applies at the start or the end of the cap cycle, write it down, and test that the number of dose cycles charged equals the number the dosing schedule specifies.

3. **Cost and efficacy layers must agree on the induction window.** The previous build charged infliximab three induction doses spanning eight weeks while running its induction transitions over two cycles — four weeks. Under L5 both windows are run as a pair, so within each member of that pair the dosing schedule and the transition window must describe the same number of weeks. Assert it.

4. **Aliyev's rows do not all sum to one.** Source rounding gives 0.9994 and 1.0006 on some rows. Decide whether to renormalise, record the decision in `SPEC_AMENDMENTS.md`, and make the choice visible. Do not silently renormalise inside the engine — an undeclared normalisation is an assumption with no owner.

5. **Verify the maintenance Moderate-Severe row against Suppl. Table 4 directly.** In the retired workbook that row appeared to be populated with the *induction* values. Confirm from the published table which it should be.

6. **Do not carry a surgery episode cost.** The Surgery state is all surgeries and procedures, costed from the Severe-Fulminant PMPM through the standard conversion (`SPEC_AMENDMENTS.md`, C7). If a colectomy figure appears anywhere, something has gone wrong.

## Tests this session must satisfy

- **T7** — every state vector sums to 1.00 ± 1e-10, every cycle, every arm, every horizon, both cap settings.
- **T8** — undiscounted life-years from the model's start age match the life table expectation within 1 year.
- **T6** — every exported numeric carries a unit suffix; cross-unit arithmetic routes through named converters.
- Cohort fully exhausted at the terminal cycle of the lifetime horizon.
- Discount factor at an arbitrary late cycle equals `1.03^(-years)` computed independently.
- Half-cycle correction moves QALYs and costs in one direction only; state which and assert it.

## Then

Run the full suite. Add a line to `CHANGELOG.md` naming what changed and which tests cover it. Commit.

Report in your closing message: lifetime discounted cost and QALYs for infliximab under each of the four combinations of induction window and cap setting, and the undiscounted life-year figure against the life-table expectation. Those six numbers are what W4 builds on.
