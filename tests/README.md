# The timescales test suite

Mirrored 1:1 in geoscales (same helpers, same conventions — the sibling
packages share one testing system; see `dev/TESTING.md` for recipes).

## Tiers

`SCALES_TEST_TIER` (one env var drives both siblings):

| tier  | runs                                                        |
|-------|-------------------------------------------------------------|
| check | core invariants, data.frame backend — what R CMD check runs |
| fast  | + data.table/tibble + one lazy smoke per engine (default)   |
| full  | + the whole dtplyr/arrow backend sweep and property grid    |

Unset → `check` under R CMD check, `fast` otherwise. Guard with
`skip_if_tier_below("full")` (helper-tiers.R).

## Layers

- `helper-fixtures.R` — canonical calendars (`.month_cal()`,
  `.quarter_cal()`, `.month_hour_cal()`, `.fiscal_cal()`) + `fx_tbl()`
  keyed value tables. Never rebuild these inside a test file.
- `helper-invariants.R` — the named contracts (`expect_conserves`,
  `expect_composition_identity`, `expect_join_contract`, ...) swept by
  `test-properties.R`.
- `helper-backends.R` — `expect_backend_contract()`: one statement of
  the whole backend contract (class restoration, lazy-stays-lazy,
  collect semantics, observed-groups asymmetry), driven over
  `test_backends()`. `test-backends.R` covers every entry point x
  backend cell with it.
- `setup-registries.R` — registries start and end clean for the suite.
- `test-regressions.R` — pins of the 0.1.0 conversion-core defects.
- `test-specs-golden.R` — re-verifies the cross-language goldens under
  `specs/` (generator: `tools/specs/make_goldens.R`).
- `test-coverage-matrix.R` — validates `@covers` tags and the surface.

## @covers tags

A comment line above the test it describes:

```r
# @covers recast_calendar depth=B backends=data.frame,tibble,data.table,dtplyr,arrow
```

Depth `U` (unit) < `P` (property) < `B` (backend-swept); backends from
the harness list. A tag naming an unknown export FAILS the suite.
Argument-level rows exist for the join/recast/filter/prune family
(`recast_calendar(rule)` etc.) and are inferred from usage.

## Regeneration

```sh
Rscript tools/coverage/build_matrix.R      # tests/coverage/ artifacts
Rscript tools/coverage/build_matrix.R --check
Rscript tools/specs/make_goldens.R         # specs/ goldens (byte-stable)
```

Behaviour change ⇒ regenerate the goldens in the same commit and review
the diff. The committed `tests/coverage/matrix-summary.md` is the gap
report — keep "Zero-coverage rows" at 0.
