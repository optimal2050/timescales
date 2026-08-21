# Crosswalk between two calendars over the base grid

Materialises the `A -> base -> B` route as a table: for the requested
model year(s), one row per pair of overlapping timeslices with

## Usage

``` r
calendar_map(from, to, year, by = NULL, tz = "UTC")
```

## Arguments

- from, to:

  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
  objects (both must be named).

- year:

  Integer vector of model year(s); multi-year maps carry all years in
  the `year` column.

- by:

  Grid resolution (`seq.POSIXt` step). Default: the finest timeframe of
  the two calendars.

- tz:

  Time zone of the grid. Default `"UTC"`.

## Value

A `data.frame` with columns `year`, `<from name>`, `<to name>` (`NA` =
uncovered by `to`), `n_from`, `n_overlap`, `w`.

## Details

- `n_from` – grid points in the `from` timeslice (its full set, before
  any target coverage is considered),

- `n_overlap` – grid points the pair shares,

- `w` – the share weight of the overlap
  (`leaves$share[from] * n_overlap / n_from`), the quantity
  `"weighted_mean"` aggregation uses.

The two label columns are named by the calendars' names (so the map
joins directly onto datasets labelled by
[`join_calendar()`](https://optimal2050.github.io/timescales/r/reference/join_calendar.md));
rows with an `NA` target label are grid points `to` does not cover. A
crosswalk registered with
[`register_calendar_map()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_map.md)
is returned as-is instead of being derived from the grid.

## Examples

``` r
m12 <- calendar_build("m12")
q4  <- calendar_build("q4")
calendar_map(m12, q4, year = 2021)
#>    year m12 q4 n_from n_overlap          w
#> 1  2021 m01 Q1     31        31 0.08493151
#> 2  2021 m02 Q1     28        28 0.07671233
#> 3  2021 m03 Q1     31        31 0.08493151
#> 4  2021 m04 Q2     30        30 0.08219178
#> 5  2021 m05 Q2     31        31 0.08493151
#> 6  2021 m06 Q2     30        30 0.08219178
#> 7  2021 m07 Q3     31        31 0.08493151
#> 8  2021 m08 Q3     31        31 0.08493151
#> 9  2021 m09 Q3     30        30 0.08219178
#> 10 2021 m10 Q4     31        31 0.08493151
#> 11 2021 m11 Q4     30        30 0.08219178
#> 12 2021 m12 Q4     31        31 0.08493151
```
