# Read a timeframe off timeslices

Convenience wrappers over
[`as_timeframe()`](https://optimal2050.github.io/timescales/r/reference/as_timeframe.md)
for the timeframes asked for most often. Each returns an integer, and
each needs the calendar the timeslices belong to – the label text is
never parsed.

## Usage

``` r
tsl2hour(tsl, calendar)

tsl2yday(tsl, calendar)

tsl2month(tsl, calendar, year = NULL)

hour2HOUR(x, calendar = NULL)

yday2YDAY(x, calendar = NULL)
```

## Arguments

- tsl:

  Character vector of timeslice labels.

- calendar:

  A
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md),
  or the name of one (`"d365_h24"`).

- year:

  The year the timeslices fall in; see
  [`as_timeframe()`](https://optimal2050.github.io/timescales/r/reference/as_timeframe.md).

- x:

  Integer vector of timeframe values.

## Value

Integer vector, `NA` where a label is not in the calendar.

## Details

A timeframe is available when it is a function of the calendar's
timeslices. `tsl2hour()` works on `"d365_h24"` because each timeslice is
one hour, and fails on `"m12"` because a month spans 24 of them.

## Examples

``` r
tsl2hour(c("d001_h00", "d100_h20"), "d365_h24")   # 0 20
#> [1]  0 20
tsl2yday(c("d001_h00", "d100_h20"), "d365_h24")   # 1 100
#> [1]   1 100
tsl2month(c("d001_h00", "d100_h20"), "d365_h24")  # 1 4
#> [1] 1 4
hour2HOUR(c(0, 20))                               # "h00" "h20"
#> [1] "h00" "h20"
```
