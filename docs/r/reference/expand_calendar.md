# Enumerate every instant in a year mapped to its calendar slice

Returns a `data.frame` with one row per instant in the requested year at
the requested resolution, plus a `slice` column giving the calendar
slice that instant belongs to (via
[`instant_to_slice()`](https://optimal2050.github.io/timescales/r/reference/instant_to_slice.md)).
This is the ground truth used by
[`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md).

## Usage

``` r
expand_calendar(calendar, year, by = NULL, tz = "UTC")
```

## Arguments

- calendar:

  A
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- year:

  Integer scalar — the Gregorian year to enumerate.

- by:

  Resolution string passed to `seq.POSIXt`'s `by` argument (`"hour"`,
  `"day"`, `"15 min"`, ...). Defaults to `"hour"` if `HOUR` is in the
  calendar's timeframes, otherwise `"day"`.

- tz:

  Time zone string. Defaults to `"UTC"`.

## Value

A `data.frame` with columns `datetime` (POSIXct) and `slice`
(character). Rows where `slice` is `NA` correspond to instants the
calendar does not cover (e.g. Feb 29 in a 365-day calendar).

## Examples

``` r
df <- data.frame(
  MONTH  = sprintf("m%02d", 1:12),
  share  = c(31,28,31,30,31,30,31,31,30,31,30,31) / 365,
  weight = c(31,28,31,30,31,30,31,31,30,31,30,31)
)
cal <- calendar_from_leaves(df, timeframes = "MONTH", name = "m12")
grid <- expand_calendar(cal, year = 2021, by = "month")
head(grid)
#>     datetime slice
#> 1 2021-01-01   m01
#> 2 2021-02-01   m02
#> 3 2021-03-01   m03
#> 4 2021-04-01   m04
#> 5 2021-05-01   m05
#> 6 2021-06-01   m06
```
