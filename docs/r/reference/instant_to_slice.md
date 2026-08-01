# Map datetimes to calendar slice IDs

Extracts each calendar timeframe's token from `dtm` using
[`as_timeframe()`](https://optimal2050.github.io/timescales/r/reference/as_timeframe.md)
and looks the resulting tuple up in `calendar@leaves`. Datetimes that
produce a tuple not present in the calendar return `NA`.

## Usage

``` r
instant_to_slice(dtm, calendar)
```

## Arguments

- dtm:

  A `POSIXct`/`POSIXlt`/`Date` vector.

- calendar:

  A
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

## Value

A character vector of slice IDs the same length as `dtm`.

## Examples

``` r
df <- data.frame(
  MONTH  = sprintf("m%02d", 1:12),
  share  = c(31,28,31,30,31,30,31,31,30,31,30,31) / 365,
  weight = c(31,28,31,30,31,30,31,31,30,31,30,31)
)
cal <- calendar_from_leaves(df, timeframes = "MONTH", name = "m12")
instant_to_slice(lubridate::ymd(c("2020-01-15", "2020-07-04")), cal)
#> [1] "m01" "m07"
```
