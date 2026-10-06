# Summarize a Calendar

Complements [`print()`](https://rdrr.io/r/base/print.html) with the
quantitative view: coverage of a sampled calendar, share/weight
statistics, and the catalog classification when present. Returns a
`"summary_Calendar"` object (a list) with its own print method — the
mirror of `summary.Geoscale()` in geoscales.

## Usage

``` r
# S3 method for class 'Calendar'
summary(object, ...)

# S3 method for class '`timescales::Calendar`'
summary(object, ...)

# S3 method for class 'summary_Calendar'
print(x, ...)
```

## Arguments

- object:

  A
  [Calendar](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- ...:

  Ignored.

- x:

  A `"summary_Calendar"` object (the print method's argument).

## Value

[`summary()`](https://rdrr.io/r/base/summary.html) returns a list of
class `"summary_Calendar"`: `name`, `desc`, `timeframes` (named member
counts), `n_timeslices`, `year_fraction`, `coverage` (see
[`calendar_coverage()`](https://optimal2050.github.io/timescales/r/reference/calendar_coverage.md)),
`sampled`, `parent_name`, `coverage_class`/`regularity` (catalog designs
only), `share_range`, `weight_range`, `year_start`,
`utc_offset_minutes`.

## Examples

``` r
summary(calendar("m12_h24"))
#> <summary of Calendar 'm12_h24' >
#>   timeframes:     MONTH (12) / HOUR (24)
#>   timeslices:     288
#>   year_fraction:  1
#>   catalog:        complete, regular
#>   share range:    0.003196 .. 0.003539
#>   weight range:   28 .. 31
#>   year_start:     month=1, day=1
#>   utc offset:     0 min
summary(filter_calendar(calendar("s4_h24"), "SEASON", "WIN"))
#> <summary of Calendar 's4_h24[SEASON:WIN]' >
#>   timeframes:     SEASON (1) / HOUR (24)
#>   timeslices:     24
#>   year_fraction:  0.246575
#>   SAMPLED:        share 24.7%, weight 24.7% of 's4_h24'
#>   catalog:        representative, regular
#>   share range:    0.01027 .. 0.01027
#>   weight range:   90 .. 90
#>   year_start:     month=1, day=1
#>   utc offset:     0 min
```
