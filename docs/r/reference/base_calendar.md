# Enumerate the base instant grid for one or more years

Returns the multi-year grid of real date-time instants that conversions
route through — the 1:1 correspondence between the package's calendars
and `POSIXct`. Each instant represents the interval `[t, t + step)`; a
leap year at `by = "hour"` has 8784 rows. Results are cached per
`(years, by, tz)`.

## Usage

``` r
base_calendar(years, by = "hour", tz = "UTC")
```

## Arguments

- years:

  Integer vector of Gregorian years.

- by:

  Grid step, passed to `seq.POSIXt` (`"hour"`, `"day"`, `"15 min"`,
  ...). Default `"hour"`.

- tz:

  Time zone of the grid. Default `"UTC"`.

## Value

A `data.frame` with columns `datetime` (POSIXct) and `year` (integer,
the Gregorian year the instant belongs to).

## Examples

``` r
nrow(base_calendar(2020))            # 8784 (leap year)
#> [1] 8784
nrow(base_calendar(2021))            # 8760
#> [1] 8760
nrow(base_calendar(2019:2020, by = "day"))  # 365 + 366
#> [1] 731
```
