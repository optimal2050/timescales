# All ancestor-descendant pairs of a Calendar hierarchy

One row per observed (ancestor label, descendant label) pair across
EVERY ordered timeframe pair — not just adjacent ones. The time-side
twin of
[`geoscales::geoscale_ancestry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_ancestry.html);
[`calendar_family()`](https://optimal2050.github.io/timescales/r/reference/calendar_family.md)
is the adjacent-pairs-only view.

## Usage

``` r
calendar_ancestry(x)
```

## Arguments

- x:

  A
  [Calendar](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

## Value

`data.frame(parent_timeframe, parent, child_timeframe, child)`.

## Examples

``` r
head(calendar_ancestry(calendar("q4_h24")))
#>   parent_timeframe parent child_timeframe child
#> 1          QUARTER     Q1            HOUR   h00
#> 2          QUARTER     Q1            HOUR   h01
#> 3          QUARTER     Q1            HOUR   h02
#> 4          QUARTER     Q1            HOUR   h03
#> 5          QUARTER     Q1            HOUR   h04
#> 6          QUARTER     Q1            HOUR   h05
```
