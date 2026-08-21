# Recast timeslice data down to the base grid, and back

The two public halves of the `A -> base -> B` route:
`recast_to_timebase()` projects timeslice-keyed data DOWN to the base
datetime grid (one row per grid point), and `recast_from_timebase()`
aggregates datetime-keyed data UP into a calendar's timeslices. Their
composition is
[`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md):
`recast_from_timebase(recast_to_timebase(x, from), to)`.

## Usage

``` r
recast_to_timebase(
  x,
  calendar,
  year = NULL,
  key = NULL,
  values = NULL,
  rule = NULL,
  by = NULL,
  tz = "UTC",
  weight = TRUE,
  collect = NULL
)

recast_from_timebase(
  x,
  calendar,
  year = NULL,
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

  The data: for `recast_to_timebase()` keyed by timeslice (`key` column,
  plus an optional `year` column for multi-year data); for
  `recast_from_timebase()` keyed by a POSIXct `datetime` column.

- calendar:

  The
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
  the data is keyed in (`to_base`) or aggregated into (`from_base`).

- year:

  Model year(s) for the grid. `recast_to_timebase()`: defaults to the
  distinct values of `x$year` when present (required otherwise).
  `recast_from_timebase()`: defaults to the span of years observed in
  `x$datetime` (padded one year each side for year_start offsets).

- key:

  `to_base`: the timeslice key column, default `"timeslice"` (falling
  back to a column named like the calendar). `from_base`: the datetime
  column, default `"datetime"`.

- values, rule, by, tz:

  As in
  [`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md).

- weight:

  `to_base` only: attach the `weight` column (default `TRUE`).

- collect:

  For lazy inputs: materialise (`TRUE`) or return the query (default).

- na_action:

  `from_base` only: what to do with rows whose datetime the calendar
  does not cover – `"drop"` (default, warning), `"error"`, or `"keep"`
  (an `NA` timeslice row).

## Value

`recast_to_timebase()`: one row per (grid point x identifier
combination) with columns `datetime`, `year`, identifiers, values (and
`weight`). `recast_from_timebase()`: one row per (year x timeslice x
identifier combination) with columns `key`-named timeslice, `year`,
identifiers, values. Both in the input's class; lazy in, lazy out.

## Details

Going down, extensive columns (rule `"sum"`) are split equally across a
timeslice's grid points so totals conserve; intensive columns are
repeated. A `weight` column (the source timeslice's `share` divided by
its grid-point count) is attached by default so that the return trip's
`"weighted_mean"` reproduces the source calendar's weighting exactly;
pass `weight = FALSE` to omit it.

Going up, rules act on the grid rows directly: `"sum"` sums, `"mean"`
averages, `"weighted_mean"` uses the `weight` column when present (else
it equals `"mean"`), `"copy"` requires constancy, `"sd"` is the standard
deviation over the grid points.

Both ends run as dplyr pipelines and accept any supported backend (see
[`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md)'s
Backends section); the calendar side of every join is a small in-memory
grid.

## Examples

``` r
m12 <- calendar_build("m12")
x <- data.frame(timeslice = sprintf("m%02d", 1:12), energy = 1:12)
g <- recast_to_timebase(x, m12, year = 2021, rule = "sum", by = "day")
head(g)
#>     datetime year     energy      weight
#> 1 2021-01-01 2021 0.03225806 0.002739726
#> 2 2021-01-02 2021 0.03225806 0.002739726
#> 3 2021-01-03 2021 0.03225806 0.002739726
#> 4 2021-01-04 2021 0.03225806 0.002739726
#> 5 2021-01-05 2021 0.03225806 0.002739726
#> 6 2021-01-06 2021 0.03225806 0.002739726
sum(g$energy)  # 78 -- totals conserve
#> [1] 78

q4 <- calendar_build("q4")
recast_from_timebase(g, q4, rule = "sum", by = "day")
#>   timeslice year energy
#> 1        Q1 2021      6
#> 2        Q2 2021     15
#> 3        Q3 2021     24
#> 4        Q4 2021     33
```
