# Fixture SPEC (G6 violation)

Not the real SPEC.md -- a minimal stand-in with just an aims table, used to
prove `uncovered_aims()` fires when an aim has neither an output file nor an
amendment.

Aim IDs are written in bold and output paths in backticks, matching the real
SPEC.md's conventions. An earlier version of this fixture wrote both bare,
which exercised a shape SPEC.md never produces and so concealed the parse
asymmetry that left the amendment branch unreachable: `**A1**` cannot match an
unbolded identifier in SPEC_AMENDMENTS.md. A fixture that does not use the
governed file's own formatting proves nothing about the governed file.

## 6. Aims and their outputs

| Aim | Statement | Output file |
|---|---|---|
| **A1** | Fixture aim one, has its output produced | `output/tables/one.csv` |
| **A2** | Fixture aim two, deliberately never produced or amended | `output/tables/two.csv` |
| **A3** | Fixture aim three, dropped and recorded as an amendment | `output/tables/three.csv` |

## 7. Not used by this fixture
