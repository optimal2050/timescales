# Navigate a Calendar hierarchy

Labels related to `label` across timeframes — the time-side mirror of
[`geoscales::geoscale_children()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_navigate.html)
and friends. Time levels nest strictly, so these are exact partitions:

## Usage

``` r
calendar_children(x, timeframe, label, to = NULL)

calendar_parents(x, timeframe, label, to = NULL)

calendar_descendants(x, timeframe, label, to = NULL)

calendar_ancestors(x, timeframe, label, to = NULL)
```

## Arguments

- x:

  A
  [Calendar](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- timeframe:

  The timeframe `label` lives at.

- label:

  One or more labels at `timeframe`.

- to:

  Optional target timeframe; defaults to the adjacent one
  (children/parents) or the full transitive range
  (descendants/ancestors).

## Value

`calendar_children()` / `calendar_parents()` return a character vector;
`calendar_descendants()` / `calendar_ancestors()` a
`data.frame(timeframe, label)`.

## Details

- `calendar_children()` — one step finer (or at `to`).

- `calendar_parents()` — one step coarser (or at `to`).

- `calendar_descendants()` — all finer timeframes (down to `to`).

- `calendar_ancestors()` — all coarser timeframes (up to `to`).

## Examples

``` r
cal <- calendar("q4_h24")
calendar_children(cal, "QUARTER", "Q1")
#>  [1] "h00" "h01" "h02" "h03" "h04" "h05" "h06" "h07" "h08" "h09" "h10" "h11"
#> [13] "h12" "h13" "h14" "h15" "h16" "h17" "h18" "h19" "h20" "h21" "h22" "h23"
calendar_parents(cal, "HOUR", "h00")
#> [1] "Q1" "Q2" "Q3" "Q4"
```
