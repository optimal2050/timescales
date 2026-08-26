# Working on timescales

Discrete time representations (calendars) for modeling — the time half of
the *scales siblings, part of the optimal2050 stack. Phase 1 is pure R
(`cpp/`, `python/` are placeholders for later phases).

Stack-wide rules (naming, style, git policy, API principles) live in the
unified conventions document: `optimal2050/.github/CONVENTIONS.md`
(https://github.com/optimal2050/.github/blob/main/CONVENTIONS.md).
Everything below is repo-specific.

## Layout

| Path | What it is |
|---|---|
| `R/` | package source; S7 `Calendar` class |
| `man/`, `NAMESPACE` | roxygen-generated — never edit by hand |
| `docs/` | pkgdown output — never edit by hand |
| `drafts/` | archived removed code — do not edit, do not source |
| `data/calendars.rda` | derived from `.CALENDAR_CATALOG`; regenerate with `Rscript data-raw/calendars.R` after catalog changes (serialized S7 objects carry property names, so class-prop renames REQUIRE regeneration) |
| `specs/` | language-agnostic golden fixtures |
| `vignettes/timescales.Rmd` | the package-named intro — pkgdown's "Get started" |

## Things that fail silently or the hard way

- **Never add `geoscales` (or `energyRt`) as a dependency** — geoscales
  Imports timescales; the reverse closes a loop.
- The `recast()` S7 generic is OWNED here; geoscales registers its
  method externally. Renaming or re-signaturing it is a cross-package
  change.
- Converter pipelines must build expressions with `rlang::sym()` (never
  `.data[[var]]` or string-RHS `rename()`) — dtplyr and arrow
  mistranslate those; `.datatable.aware <- TRUE` in `R/backend.R` is
  load-bearing for dtplyr.
- On THIS machine, arrow 25.0.0 corrupts POSIXct at ingestion — the
  datetime-route arrow test guards with a roundtrip skip; don't chase
  that ghost.
- Vignettes render against the INSTALLED package: after adding exported
  functions used in a vignette, `devtools::install(quick = TRUE)`
  before `rmarkdown::render()`/pkgdown.
- Fiscal calendars: labels stay Gregorian (`m04` = April, always);
  fiscal identity = anchored `YEAR`/`YDAY` + member ORDER. A
  fiscal-renumbered vocabulary would silently mis-resolve through the
  positional label fallback in `.tf_labels()`.
- `R CMD check` is clean (0 errors / 0 warnings / 0 notes). Keep it
  that way; lint (80 cols) runs in CI.
- 0.5.0 removed every deprecated alias (hard break; archived in
  drafts/). The testing system lives in tests/README.md +
  dev/TESTING.md: tiers via SCALES_TEST_TIER, @covers tags, invariant
  and backend harnesses, coverage matrix, specs/ goldens.

*Last verified 2026-08-21. Drafted with AI assistance; content is the
maintainer's responsibility.*
