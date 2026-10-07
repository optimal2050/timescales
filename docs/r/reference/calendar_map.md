# Crosswalk between two timeframes of a calendar

Materialises the `from -> timeslices -> to` route within one calendar as
a table: one row per pair of overlapping units with `n_from` (timeslices
in the `from` unit), `n_overlap` (timeslices the pair shares), `w` (the
weight of the overlap) and `w_from` (the full weight of the `from`
unit). The two label columns are named by the timeframes. A crosswalk
registered with
[`register_calendar_map()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_map.md)
is returned as-is instead of being derived.

## Usage

``` r
calendar_map(x, from, to, weight = NULL, ...)
```

## Arguments

- x:

  The
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
  the timeframes belong to.

- from, to:

  Timeframe names of `x`.

- weight:

  Weight column for `w`. `NULL` uses the calendar's default weight; when
  it declares none, every timeslice gets weight 1.

- ...:

  Passed to the shared core, e.g. `by =` for extra identifier columns.

## Value

A `data.frame` with columns `<from>`, `<to>` (`NA` = uncovered by `to`),
`n_from`, `n_overlap`, `w`, `w_from`.

## See also

[`calendar_map_between()`](https://optimal2050.github.io/timescales/r/reference/calendar_map_between.md)
for the map between two calendars.

## Examples

``` r
cal <- calendar("m12_h24")
head(calendar_map(cal, "MONTH", "HOUR"))
#>   MONTH HOUR n_from n_overlap           w     w_from
#> 1   m01  h00     24         1 0.003538813 0.08493151
#> 2   m01  h01     24         1 0.003538813 0.08493151
#> 3   m01  h02     24         1 0.003538813 0.08493151
#> 4   m01  h03     24         1 0.003538813 0.08493151
#> 5   m01  h04     24         1 0.003538813 0.08493151
#> 6   m01  h05     24         1 0.003538813 0.08493151
```
