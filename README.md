# treg-value

Early health technology assessment of a hypothetical allogeneic regulatory
T-cell therapy for moderate-to-severe Crohn's disease.

Jadambaa, Stone, Abraham — Johns Hopkins Bloomberg School of Public Health.

**`SPEC.md` is the governing authority for what this study does.** It
supersedes every memo, comment and conversation. Read it first.

## Layout

| Path | Contents |
|---|---|
| `SPEC.md` | Governing specification |
| `SPEC_AMENDMENTS.md` | Every departure from the spec |
| `OPEN_QUESTIONS.md` | Unresolved items; none may have a default in code |
| `CLAUDE.md` | Working rules for Claude Code sessions |
| `data/raw/` | Transcription from published sources, each with a `.source.yaml` |
| `data/derived/` | Produced only by scripts in `derive/`, re-derived by tests |
| `derive/` | Scripts that build `data/derived/` from `data/raw/` |
| `R/` | Model modules |
| `analysis/` | Runnable pipelines |
| `tests/testthat/` | Test suite, including the eight guards |
| `tests/violations/` | Fixtures proving each guard fails when violated |
| `output/` | Stamped outputs; every file carries commit and spec hash |
