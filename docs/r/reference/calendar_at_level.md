# Derive a coarser calendar by truncating the hierarchy at a timeframe

Aggregates a calendar to one of its own timeframe levels: leaves are
grouped by the timeframes down to (and including) `timeframe`, and their
`share`/`weight` are summed. `timeframe = "ANNUAL"` returns the implicit
whole-year root — a one-slice calendar (the root is named `ANNUAL`,
never `YEAR`, which is reserved for the Gregorian-year axis).

## Usage

``` r
calendar_at_level(calendar, timeframe)
```

## Arguments

- calendar:

  A
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- timeframe:

  One of `calendar`'s timeframes, or `"ANNUAL"` for the whole-year root.

## Value

A
[`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
whose hierarchy stops at `timeframe`.

## Details

Together with
[`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md)'s
acceptance of a timeframe name for `to=`, this covers within-calendar
aggregation (e.g. `q4_h24 -> q4`) without constructing a second calendar
by hand.

## Examples

``` r
cal <- calendar_build("q4", "h24")
calendar_at_level(cal, "QUARTER")   # 4 slices, shares summed over hours
#> Calendar: q4_h24@QUARTER 
#> Timeframes (1):
#>   - QUARTER (4) [token: q4]
#> Leaf slices: 4
#> year_fraction: 1
#> year_start: month=1, day=1
#> utc_offset_minutes: 0
calendar_at_level(cal, "ANNUAL")    # 1 slice covering the year
#> Calendar: q4_h24@ANNUAL 
#> Timeframes (1):
#>   - ANNUAL (1)
#> Leaf slices: 1
#> year_fraction: 1
#> year_start: month=1, day=1
#> utc_offset_minutes: 0
```
