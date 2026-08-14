# Recast values from one calendar to another

The central conversion verb. Takes a `data.frame` keyed by timeslice in
calendar `from` with one or more numeric value columns, and returns a
`data.frame` keyed by timeslice in calendar `to`. Every conversion
routes `A -> base -> B` through the shared instant grid: source values
are projected down to instants, then aggregated up to target timeslices,
so aggregation and disaggregation are one operation. A pairwise override
registered with
[`register_conversion()`](https://optimal2050.github.io/timescales/r/reference/register_conversion.md)
short-circuits the route.

## Usage

``` r
recast_calendar(
  x,
  from,
  to,
  year,
  key = NULL,
  values = NULL,
  rule = NULL,
  by = NULL,
  tz = "UTC",
  na_action = c("drop", "error", "keep")
)
```

## Arguments

- x:

  `data.frame` with a column named by `key` plus one or more numeric
  value columns; other columns are preserved as identifiers.

- from:

  Source
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- to:

  Destination
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md),
  or a timeframe name of `from` (including `"ANNUAL"`) for
  within-calendar aggregation via
  [`prune_calendar()`](https://optimal2050.github.io/timescales/r/reference/prune_calendar.md).

- year:

  Integer scalar model year used to materialise both calendars on the
  shared grid.

- key:

  Name of the timeslice key column in `x`. `NULL` (default) resolves to
  `"timeslice"`.

- values:

  Character vector of value columns to transform. Default: all numeric
  columns other than `key` and `from`'s timeframe columns. Numeric
  identifiers (e.g. `year`) must be excluded explicitly.

- rule:

  One of
  [`RECAST_RULES`](https://optimal2050.github.io/timescales/r/reference/RECAST_RULES.md),
  applied to every value column; or `NULL` (default) to look each column
  up with
  [`get_rule()`](https://optimal2050.github.io/timescales/r/reference/get_rule.md),
  falling back to `"weighted_mean"`. (Deliberate divergence from
  [`geoscales::geo_recast()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.html),
  whose fallback is `"sum"`: time-series panels skew intensive, spatial
  tables skew extensive.)

- by:

  Grid resolution for the shared instant grid. Defaults to the finest
  timeframe of the two calendars.

- tz:

  Time zone for the shared grid. Default `"UTC"`.

- na_action:

  What to do with grid instants not covered by `to`: `"drop"` (default,
  with a warning — the affected source share is genuinely lost),
  `"error"`, or `"keep"` (retain an explicit `NA` timeslice row so
  totals conserve). Instants not covered by `from` carry no data and are
  always dropped.

## Value

A `data.frame` with columns `c(key, identifiers, values)`: per
identifier combination, one row per timeslice in `to` (the full target
vocabulary, `NA` where uncovered — a deliberate divergence from
`geo_recast()`, which emits observed combinations only), plus an `NA`
timeslice row under `na_action = "keep"`. Identifier column types are
preserved.

## Details

Columns of `x` that are neither the key nor a value column are treated
as identifiers (panel columns — a `city`, a scenario) and preserved as
grouping columns, so panel data recasts correctly in one call; this is
what makes mixed pipelines like
`x |> recast_calendar(...) |> geo_recast(...)` work. Columns named like
`from`'s timeframes are treated as timeslice attributes and dropped.

[`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md)
is a deprecated alias.

Rules (see
[`RECAST_RULES`](https://optimal2050.github.io/timescales/r/reference/RECAST_RULES.md)):
`"sum"` splits each source value equally across its timeslice's grid
instants before summing up, so totals are conserved. `"weighted_mean"`
weights by the declared `leaves$share` of each source timeslice;
`"mean"` is the plain (time-weighted) mean over instants — the two
differ exactly when declared shares differ from real-time coverage.
`"copy"` requires a constant value per target timeslice; `"sd"` is
aggregation-only. There is no `weight=` argument: a calendar has exactly
one weighting, its `leaves$share`.

## Examples

``` r
cal_m <- calendar_build("m12")
cal_q <- calendar_build("q4")

x <- data.frame(
  timeslice = sprintf("m%02d", 1:12),
  load  = seq(100, 210, length.out = 12)
)
recast_calendar(x, from = cal_m, to = cal_q, year = 2021)
#>   timeslice     load
#> 1        Q1 110.0000
#> 2        Q2 140.0000
#> 3        Q3 169.8913
#> 4        Q4 200.0000

# Panel data: the city column is carried through
xp <- rbind(transform(x, city = "A"), transform(x, city = "B"))
recast_calendar(xp, cal_m, cal_q, year = 2021, rule = "sum")
#>   timeslice city load
#> 1        Q1    A  330
#> 2        Q2    A  420
#> 3        Q3    A  510
#> 4        Q4    A  600
#> 5        Q1    B  330
#> 6        Q2    B  420
#> 7        Q3    B  510
#> 8        Q4    B  600

# Within-calendar aggregation, and the ANNUAL root
cal <- calendar_build("q4", "h24")
xh <- data.frame(timeslice = S7::prop(cal, "leaves")$timeslice, energy = 1)
recast_calendar(xh, cal, to = "ANNUAL", year = 2021, rule = "sum")  # 96
#>   timeslice energy
#> 1    ANNUAL     96
```
