# Recast values from one calendar to another

The central conversion verb. Takes a `data.frame` keyed by slice in
calendar `from` with one or more numeric value columns, and returns a
`data.frame` keyed by slice in calendar `to`. Conversion goes through a
shared instant grid built by
[`expand_calendar()`](https://optimal2050.github.io/timescales/r/reference/expand_calendar.md)
for the given `year`.

## Usage

``` r
recast(
  x,
  from,
  to,
  year,
  key = "slice",
  values = NULL,
  rule = c("weighted_mean", "sum", "mean"),
  by = NULL,
  tz = "UTC"
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
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- year:

  Integer scalar Gregorian year used to materialise both calendars on a
  shared grid.

- key:

  Name of the slice key column in `x`. Default `"slice"`.

- values:

  Character vector of value columns to transform. Default: all numeric
  columns other than `key`.

- rule:

  Aggregation rule for many-source-instants-per-target-slice
  (downsampling). One of:

  - `"weighted_mean"` — share-weighted mean (default; physical units
    like average load).

  - `"sum"` — sum (extensive quantities like total energy).

  - `"mean"` — unweighted mean.

- by:

  Grid resolution for
  [`expand_calendar()`](https://optimal2050.github.io/timescales/r/reference/expand_calendar.md).
  Defaults to the finest of the two calendars.

- tz:

  Time zone for the shared grid. Default `"UTC"`.

## Value

A `data.frame` keyed by slice in `to`, with one row per slice in `to`
and the same value columns as in `x`.

## Details

Algorithm:

1.  Expand both calendars onto a shared instant grid for `year`.

2.  Join `x` onto the grid via `from$slice`, broadcasting each source
    slice's value to every grid instant it covers.

3.  Group by `to$slice` and aggregate per `rule`.

Instants present in one calendar but not the other (e.g. Feb 29) drop
out silently for now (will be configurable in a later phase).

## Examples

``` r
month_df <- data.frame(
  MONTH  = sprintf("m%02d", 1:12),
  share  = c(31,28,31,30,31,30,31,31,30,31,30,31) / 365,
  weight = c(31,28,31,30,31,30,31,31,30,31,30,31)
)
cal_m <- calendar_from_leaves(month_df, timeframes = "MONTH", name = "m12")

quarter_df <- data.frame(
  QUARTER = sprintf("Q%d", 1:4),
  share   = c(90, 91, 92, 92) / 365,
  weight  = c(90, 91, 92, 92)
)
cal_q <- calendar_from_leaves(quarter_df, timeframes = "QUARTER",
                              name = "q4")

x <- data.frame(
  slice = sprintf("m%02d", 1:12),
  load  = seq(100, 210, length.out = 12)
)
recast(x, from = cal_m, to = cal_q, year = 2021, rule = "weighted_mean")
#>   slice     load
#> 1    Q1 110.0000
#> 2    Q2 140.0000
#> 3    Q3 169.8913
#> 4    Q4 200.0000
```
