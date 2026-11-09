# The timeslice that follows each timeslice

The successor chain at a timeframe: for every timeslice, the one that
comes next. Used wherever a quantity is carried from one slice into the
next — a storage level, a ramping limit — and by order-constrained
clustering.

## Usage

``` r
calendar_next(x, timeframe = NULL, within = NULL, wrap = TRUE)
```

## Arguments

- x:

  A
  [Calendar](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- timeframe:

  Timeframe whose timeslices are chained. Defaults to the finest.

- within:

  Optional coarser timeframe whose boundaries the chain stays inside:
  the successor of the last slice of a day is the first slice of that
  same day, not of the next one. `NULL` (default) chains the whole
  timeframe as one sequence, and `"ANNUAL"` says the same thing
  explicitly – the root is the whole year, so a chain confined to it is
  not confined at all.

- wrap:

  `TRUE` (default) closes each chain into a cycle, so the last slice's
  successor is the first of its group. `FALSE` gives `NA` there, leaving
  the sequence open.

## Value

A `data.frame` with one row per timeslice at `timeframe`, in
chronological order: `timeslice` and `next_timeslice`, both qualified
node ids as
[`calendar_timeslices()`](https://optimal2050.github.io/timescales/r/reference/calendar_queries.md)
with `qualified = TRUE` returns them. With `wrap = FALSE`,
`next_timeslice` is `NA` on the last row of each group.

## Details

A cycle is the default because an energy-system calendar represents a
*typical* period rather than a one-off interval: a storage level that
must return to where it started makes the period repeatable, and an open
chain lets the model empty the store for free on the last slice.

Grouping under `within` uses each node's whole path, not its label, so a
calendar whose hour labels repeat under every day chains each day
separately rather than pooling the twenty-four labels into one group.

## See also

[`calendar_children()`](https://optimal2050.github.io/timescales/r/reference/calendar_navigate.md),
[`calendar_timeslices()`](https://optimal2050.github.io/timescales/r/reference/calendar_queries.md)

## Examples

``` r
cal <- calendar("d365_h24")
head(calendar_next(cal))                             # all 8760, cyclic
#>   timeslice next_timeslice
#> 1  d001_h00       d001_h01
#> 2  d001_h01       d001_h02
#> 3  d001_h02       d001_h03
#> 4  d001_h03       d001_h04
#> 5  d001_h04       d001_h05
#> 6  d001_h05       d001_h06
head(calendar_next(cal, within = "YDAY"))            # 365 cycles of 24
#>   timeslice next_timeslice
#> 1  d001_h00       d001_h01
#> 2  d001_h01       d001_h02
#> 3  d001_h02       d001_h03
#> 4  d001_h03       d001_h04
#> 5  d001_h04       d001_h05
#> 6  d001_h05       d001_h06
head(calendar_next(cal, within = "YDAY", wrap = FALSE))
#>   timeslice next_timeslice
#> 1  d001_h00       d001_h01
#> 2  d001_h01       d001_h02
#> 3  d001_h02       d001_h03
#> 4  d001_h03       d001_h04
#> 5  d001_h04       d001_h05
#> 6  d001_h05       d001_h06
```
