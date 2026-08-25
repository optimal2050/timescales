# The leaftable of a Calendar

The one-row-per-timeslice table the calendar is built on, as a plain
`data.frame` — the exported accessor to prefer over reaching for
`x@leaftable` (the twin of
[`geoscales::geoscale_leaftable()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_leaftable.html)).

## Usage

``` r
calendar_leaftable(x)
```

## Arguments

- x:

  A
  [Calendar](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

## Value

A `data.frame`: one row per timeslice, with the timeframe columns plus
`timeslice`, `share`, `weight`.

## Examples

``` r
head(calendar_leaftable(calendar("m12")))
#>   MONTH      share weight timeslice
#> 1   m01 0.08493151    744       m01
#> 2   m02 0.07671233    672       m02
#> 3   m03 0.08493151    744       m03
#> 4   m04 0.08219178    720       m04
#> 5   m05 0.08493151    744       m05
#> 6   m06 0.08219178    720       m06
```
