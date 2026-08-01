# Calendar (S7 class)

A nested time partition: a flat table of weighted leaf slices plus the
ordered hierarchy of timeframes that produced them.

## Usage

``` r
Calendar(leaves, timeframes, levels, meta = list())
```

## Arguments

- leaves:

  `data.frame` with columns `slice`, `share`, `weight`, plus one column
  per timeframe in `timeframes`.

- timeframes:

  Ordered character vector of timeframe names (coarsest first); each
  name must appear as a column in `leaves`.

- levels:

  Named list; `levels[[tf]]` is the full ordered set of allowed tokens
  at timeframe `tf`. Must equal `unique(leaves[[tf]])` as a set.

- meta:

  Named list of model-level attributes (`name`, `desc`, `year_start`,
  `utc_offset_minutes`, `year_fraction`).

## Details

Construct with
[`calendar_from_leaves()`](https://optimal2050.github.io/timescales/r/reference/calendar_from_leaves.md)
(the general escape hatch). Higher-level constructors built on tokens
and a catalog will arrive in a later phase.
