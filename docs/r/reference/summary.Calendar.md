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
#> $name
#> [1] "m12_h24"
#> 
#> $desc
#> [1] ""
#> 
#> $timeframes
#> MONTH  HOUR 
#>    12    24 
#> 
#> $n_timeslices
#> [1] 288
#> 
#> $year_fraction
#> [1] 1
#> 
#> $coverage
#>  share weight 
#>      1      1 
#> 
#> $sampled
#> [1] FALSE
#> 
#> $parent_name
#> NULL
#> 
#> $coverage_class
#> [1] "complete"
#> 
#> $regularity
#> [1] "regular"
#> 
#> $share_range
#> [1] 0.003196347 0.003538813
#> 
#> $weight_range
#> [1] 28 31
#> 
#> $year_start
#> $year_start$month
#> [1] 1
#> 
#> $year_start$day
#> [1] 1
#> 
#> 
#> $utc_offset_minutes
#> [1] 0
#> 
#> attr(,"class")
#> [1] "summary_Calendar"
summary(filter_calendar(calendar("s4_h24"), "SEASON", "WIN"))
#> $name
#> [1] "s4_h24[SEASON:WIN]"
#> 
#> $desc
#> [1] ""
#> 
#> $timeframes
#> SEASON   HOUR 
#>      1     24 
#> 
#> $n_timeslices
#> [1] 24
#> 
#> $year_fraction
#> [1] 0.2465753
#> 
#> $coverage
#>     share    weight 
#> 0.2465753 0.2465753 
#> 
#> $sampled
#> [1] TRUE
#> 
#> $parent_name
#> [1] "s4_h24"
#> 
#> $coverage_class
#> [1] "representative"
#> 
#> $regularity
#> [1] "regular"
#> 
#> $share_range
#> [1] 0.01027397 0.01027397
#> 
#> $weight_range
#> [1] 90 90
#> 
#> $year_start
#> $year_start$month
#> [1] 1
#> 
#> $year_start$day
#> [1] 1
#> 
#> 
#> $utc_offset_minutes
#> [1] 0
#> 
#> attr(,"class")
#> [1] "summary_Calendar"
```
