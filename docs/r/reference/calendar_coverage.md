# Coverage of a sampled Calendar

The fraction of the ROOT parent calendar that a
[`filter_calendar()`](https://optimal2050.github.io/timescales/r/reference/filter_calendar.md)
sample retains, per built-in weight column (`share`, `weight`) — the
time-side mirror of
[`geoscales::geoscale_coverage()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_coverage.html).
A calendar that was never sampled reports 1 for both.

## Usage

``` r
calendar_coverage(x, weight = NULL)
```

## Arguments

- x:

  A
  [Calendar](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- weight:

  `"share"`, `"weight"`, or `NULL` (default) for the named vector over
  both.

## Value

A named numeric vector, or a single value with `weight=`.

## Examples

``` r
calendar_coverage(filter_calendar(calendar("s4_h24"), "SEASON", "WIN"))
#>     share    weight 
#> 0.2465753 0.2465753 
```
