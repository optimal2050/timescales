# Enumerate the instants of one or more model years mapped to slices

Materialises the calendar on the base instant grid: one row per instant
of each requested model year, with the slice that instant belongs to
(via
[`instant_to_slice()`](https://optimal2050.github.io/timescales/r/reference/instant_to_slice.md)).
The model year spans `[year_start(y), year_start(y + 1))` in the
calendar's local time (`meta$year_start`, `meta$utc_offset_minutes`);
with the default metadata that is simply the Gregorian year in `tz`.

## Usage

``` r
expand_calendar(calendar, year, by = NULL, tz = "UTC", alignment = NULL)
```

## Arguments

- calendar:

  A
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- year:

  Integer vector — the model year(s) to enumerate.

- by:

  Resolution string passed to `seq.POSIXt`'s `by` argument (`"hour"`,
  `"day"`, `"15 min"`, ...). Defaults to the finest of the calendar's
  timeframes.

- tz:

  Time zone of the returned instants. Defaults to `"UTC"`.

- alignment:

  Optional alignment override, as in
  [`instant_to_slice()`](https://optimal2050.github.io/timescales/r/reference/instant_to_slice.md).

## Value

A `data.frame` with columns `datetime` (POSIXct), `year` (integer, model
year) and `slice` (character). Rows where `slice` is `NA` are instants
the calendar does not cover.

## Examples

``` r
cal <- calendar_build("m12")
grid <- expand_calendar(cal, year = 2021, by = "day")
nrow(grid)                                  # 365
#> [1] 365
nrow(expand_calendar(cal, 2020, by = "day"))  # 366 (leap year)
#> [1] 366
```
