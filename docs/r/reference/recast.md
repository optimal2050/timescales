# Recast values from one calendar to another

The central conversion verb. Takes a `data.frame` keyed by slice in
calendar `from` with one or more numeric value columns, and returns a
`data.frame` keyed by slice in calendar `to`. Every conversion routes
`A -> base -> B` through the shared instant grid: source values are
projected down to instants, then aggregated up to target slices, so
aggregation and disaggregation are one operation. A pairwise override
registered with
[`register_conversion()`](https://optimal2050.github.io/timescales/r/reference/register_conversion.md)
short-circuits the route.

## Usage

``` r
recast(
  x,
  from,
  to,
  year,
  key = "slice",
  values = NULL,
  rule = NULL,
  by = NULL,
  tz = "UTC",
  na_action = c("drop", "error", "keep")
)
```

## Arguments

- x:

  `data.frame` with a column named by `key` (default `"slice"`) plus one
  or more numeric value columns.

- from:

  Source
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- to:

  Destination
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md),
  or a timeframe name of `from` (including `"ANNUAL"`) for
  within-calendar aggregation via
  [`calendar_at_level()`](https://optimal2050.github.io/timescales/r/reference/calendar_at_level.md).

- year:

  Integer scalar model year used to materialise both calendars on the
  shared grid.

- key:

  Name of the slice key column in `x`. Default `"slice"`.

- values:

  Character vector of value columns to transform. Default: all numeric
  columns other than `key`.

- rule:

  One of
  [`RECAST_RULES`](https://optimal2050.github.io/timescales/r/reference/RECAST_RULES.md),
  applied to every value column; or `NULL` (default) to look each column
  up with
  [`get_rule()`](https://optimal2050.github.io/timescales/r/reference/get_rule.md),
  falling back to `"weighted_mean"`.

- by:

  Grid resolution for the shared instant grid. Defaults to the finest
  timeframe of the two calendars.

- tz:

  Time zone for the shared grid. Default `"UTC"`.

- na_action:

  What to do with grid instants not covered by `to`: `"drop"` (default,
  with a warning — the affected source share is genuinely lost),
  `"error"`, or `"keep"` (retain an explicit `NA` slice row so totals
  conserve). Instants not covered by `from` carry no data and are always
  dropped.

## Value

A `data.frame` keyed by slice in `to`, with one row per slice in `to`
(plus an `NA` row under `na_action = "keep"`) and the same value columns
as in `x`.

## Details

Rules (see
[`RECAST_RULES`](https://optimal2050.github.io/timescales/r/reference/RECAST_RULES.md)):
`"sum"` splits each source value equally across its slice's grid
instants before summing up, so totals are conserved. `"weighted_mean"`
weights by the declared `leaves$share` of each source slice; `"mean"` is
the plain (time-weighted) mean over instants — the two differ exactly
when declared shares differ from real-time coverage. `"copy"` requires a
constant value per target slice; `"sd"` is aggregation-only.

## Examples

``` r
cal_m <- calendar_build("m12")
cal_q <- calendar_build("q4")

x <- data.frame(
  slice = sprintf("m%02d", 1:12),
  load  = seq(100, 210, length.out = 12)
)
recast(x, from = cal_m, to = cal_q, year = 2021)
#>   slice     load
#> 1    Q1 110.0000
#> 2    Q2 140.0000
#> 3    Q3 169.8913
#> 4    Q4 200.0000

# Within-calendar aggregation, and the ANNUAL root
cal <- calendar_build("q4", "h24")
xh <- data.frame(slice = S7::prop(cal, "leaves")$slice, energy = 1)
recast(xh, cal, to = "ANNUAL", year = 2021, rule = "sum")  # 96
#>    slice energy
#> 1 ANNUAL     96
```
