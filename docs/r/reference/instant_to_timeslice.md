# Map datetimes to calendar timeslice IDs

Extracts each calendar timeframe's component from `dtm`, applies the
calendar's alignment rules (`meta$alignment`, see
[`ALIGNMENT_RULES`](https://optimal2050.github.io/timescales/r/reference/ALIGNMENT_RULES.md)),
and looks the resulting tuple up in `calendar@leaves`. Datetimes that
produce a tuple not present in the calendar return `NA`.

## Usage

``` r
instant_to_timeslice(dtm, calendar, alignment = NULL)
```

## Arguments

- dtm:

  A `POSIXct`/`POSIXlt`/`Date` vector.

- calendar:

  A
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- alignment:

  Optional override of the calendar's alignment: a single rule applied
  to every timeframe, or a named list/vector per timeframe. `NULL`
  (default) uses `meta$alignment`.

## Value

A character vector of timeslice IDs the same length as `dtm`.

## Details

Local time is `dtm` plus `meta$utc_offset_minutes`; when
`meta$year_start` is not January 1, `YDAY` and `YEAR` are computed
relative to that anchor (MONTH/QUARTER/WEEK remain Gregorian).

Labels are resolved by formatted-token match against the calendar's
vocabulary first; for enum vocabularies of full fixed cardinality (12
months, 4 quarters, 24 hours, ...) an ordinal positional fallback
applies, which assumes the vocabulary is in natural order — this is what
makes `m12a` (`JAN`..`DEC`) work.

## Examples

``` r
cal <- calendar_build("m12")
instant_to_timeslice(lubridate::ymd(c("2020-01-15", "2020-07-04")), cal)
#> [1] "m01" "m07"

# Enum vocabularies resolve positionally
instant_to_timeslice(lubridate::ymd("2021-03-15"), calendar_build("m12a"))
#> [1] "MAR"

# d365 drops Feb 29 and keeps Dec 31 = d365 on leap years
d365 <- calendar_build("d365")
instant_to_timeslice(lubridate::ymd(c("2020-02-29", "2020-12-31")), d365)
#> [1] NA     "d365"
```
