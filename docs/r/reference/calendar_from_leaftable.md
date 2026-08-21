# Build a Calendar from a flat table of leaf timeslices

This is the most general way to construct a
[`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md):
provide the leaf timeslices directly as a `data.frame`, name the
timeframe columns, and optionally pin down the per-timeframe vocabulary
and model-level metadata.

## Usage

``` r
calendar_from_leaftable(
  leaftable,
  timeframes,
  members = NULL,
  name = "",
  desc = "",
  year_start = list(month = 1L, day = 1L),
  utc_offset_minutes = 0L,
  year_fraction = 1,
  ...
)
```

## Arguments

- leaftable:

  A `data.frame` with one row per leaf timeslice. Must contain:

  - one column per timeframe named in `timeframes`

  - `share` — numeric \> 0; sums to `year_fraction`

  - `weight` — numeric \>= 0; user-defined importance weight

  - (optional) `timeslice` — unique character ID; auto-generated if
    missing

- timeframes:

  Ordered character vector of timeframe names (coarsest first). Each
  must appear as a column in `leaftable`.

- members:

  Optional named list giving the full ordered member set per timeframe.
  If `NULL`, derived from `unique(leaftable[[tf]])` in first-appearance
  order.

- name, desc:

  Calendar name and free-text description.

- year_start:

  `list(month = , day = )`; defaults to January 1.

- utc_offset_minutes:

  Integer minutes; model-local time = UTC + offset.

- year_fraction:

  Fraction of a year covered by `sum(leaftable$share)`. Defaults to `1`.

- ...:

  Additional named entries appended to `meta` (free-form).

## Value

A
[`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
object.

## Examples

``` r
# A trivial monthly calendar with weights = days in month (non-leap year)
df <- data.frame(
  MONTH  = sprintf("m%02d", 1:12),
  share  = c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31) / 365,
  weight = c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
)
cal <- calendar_from_leaftable(df, timeframes = "MONTH", name = "m12")
cal
#> Calendar: m12 
#> Timeframes (1):
#>   - MONTH (12)
#> Leaf timeslices: 12
#> year_fraction: 1
#> year_start: month=1, day=1
#> utc_offset_minutes: 0
```
