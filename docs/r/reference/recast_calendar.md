# Recast values from one calendar to another

The central conversion verb. Takes a table keyed by timeslice in
calendar `from` with one or more numeric value columns, and returns the
same table keyed by timeslice in calendar `to`. Every conversion routes
`A -> base -> B` through the shared datetime grid: source values are
projected down to grid points, then aggregated up to target timeslices,
so aggregation and disaggregation are one operation. The route is
evaluated as one dplyr pipeline against the
[`calendar_map()`](https://optimal2050.github.io/timescales/r/reference/calendar_map.md)
crosswalk, so `x` may live in any supported backend (see below). A
pairwise override registered with
[`register_conversion()`](https://optimal2050.github.io/timescales/r/reference/register_conversion.md)
(or a crosswalk registered with
[`register_calendar_map()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_map.md))
short-circuits the grid route.

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
  na_action = c("drop", "error", "keep"),
  collect = NULL
)
```

## Arguments

- x:

  The data to recast, in any supported backend, with a column named by
  `key` plus one or more numeric value columns; other columns are
  preserved as identifiers.

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
  [`get_rule()`](https://optimal2050.github.io/timescales/r/reference/get_rule.md).
  A column with neither an explicit `rule=` nor a registry entry is an
  ERROR – there is deliberately no fallback (a silently guessed rule is
  a silent unit error).

- by:

  Grid resolution for the shared datetime grid. Defaults to the finest
  timeframe of the two calendars.

- tz:

  Time zone for the shared grid. Default `"UTC"`.

- na_action:

  What to do with grid points not covered by `to`: `"drop"` (default,
  with a warning – the affected source share is genuinely lost),
  `"error"`, or `"keep"` (retain an explicit `NA` timeslice row so
  totals conserve). Grid points not covered by `from` carry no data and
  are always dropped.

- collect:

  For lazy inputs (arrow, dtplyr): materialise the result (`TRUE`) or
  return the uncollected query (default).

## Value

The recast table in the input's class, with columns
`c(key, identifiers, values)`: per identifier combination, one row per
timeslice in `to` (the full target vocabulary, `NA` where uncovered – a
deliberate divergence from `geo_recast()`, which emits observed
combinations only), plus an `NA` timeslice row under
`na_action = "keep"`. Identifier column types are preserved.

## Details

Columns of `x` that are neither the key nor a value column are treated
as identifiers (panel columns – a `city`, a scenario) and preserved as
grouping columns, so panel data recasts correctly in one call; this is
what makes mixed pipelines like
`x |> recast_calendar(...) |> geo_recast(...)` work. Columns named like
`from`'s timeframes are treated as timeslice attributes and dropped.

The public halves of the route are
[`recast_to_timebase()`](https://optimal2050.github.io/timescales/r/reference/recast_to_timebase.md)
and
[`recast_from_timebase()`](https://optimal2050.github.io/timescales/r/reference/recast_to_timebase.md);
`recast_calendar(x, from, to)` is equivalent to
`recast_from_timebase(recast_to_timebase(x, from), to)`.

Rules (see
[`RECAST_RULES`](https://optimal2050.github.io/timescales/r/reference/RECAST_RULES.md)):
`"sum"` splits each source value equally across its timeslice's grid
points before summing up, so totals are conserved. `"weighted_mean"`
weights by the declared `leaves$share` of each source timeslice;
`"mean"` is the plain (time-weighted) mean over grid points – the two
differ exactly when declared shares differ from real-time coverage.
`"copy"` requires a constant value per target timeslice; `"sd"` is
aggregation-only. There is no `weight=` argument: a calendar has exactly
one weighting, its `leaves$share`.

## Backends

`x` may be a `data.frame`, tibble, `data.table`, `dtplyr` lazy table, or
an arrow Dataset/Table/query. The result comes back in the input's
class; lazy inputs (arrow, dtplyr) return the uncollected query unless
`collect = TRUE`. Lazy results contain the observed target timeslices
only – the full-vocabulary completion (and its `NA` rows) applies when
the result is materialised.

## Examples

``` r
cal_m <- calendar_build("m12")
cal_q <- calendar_build("q4")

x <- data.frame(
  timeslice = sprintf("m%02d", 1:12),
  load  = seq(100, 210, length.out = 12)
)
recast_calendar(x, from = cal_m, to = cal_q, year = 2021,
                rule = "weighted_mean")
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
xh <- data.frame(timeslice = S7::prop(cal, "leaftable")$timeslice, energy = 1)
recast_calendar(xh, cal, to = "ANNUAL", year = 2021, rule = "sum")  # 96
#>   timeslice energy
#> 1    ANNUAL     96
```
