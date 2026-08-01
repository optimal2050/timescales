# Build a Calendar from a flat table of leaf slices

This is the most general way to construct a
[`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md):
provide the leaf slices directly as a `data.frame`, name the timeframe
columns, and optionally pin down the per-timeframe vocabulary and
model-level metadata.

## Usage

``` r
calendar_from_leaves(
  leaves,
  timeframes,
  levels = NULL,
  name = "",
  desc = "",
  year_start = list(month = 1L, day = 1L),
  utc_offset_minutes = 0L,
  year_fraction = 1,
  ...
)
```

## Arguments

- leaves:

  A `data.frame` with one row per leaf slice. Must contain:

  - one column per timeframe named in `timeframes`

  - `share` — numeric \> 0; sums to `year_fraction`

  - `weight` — numeric \>= 0; user-defined importance weight

  - (optional) `slice` — unique character ID; auto-generated if missing

- timeframes:

  Ordered character vector of timeframe names (coarsest first). Each
  must appear as a column in `leaves`.

- levels:

  Optional named list giving the full ordered token set per timeframe.
  If `NULL`, derived from `unique(leaves[[tf]])` in first-appearance
  order.

- name, desc:

  Calendar name and free-text description.

- year_start:

  `list(month = , day = )`; defaults to January 1.

- utc_offset_minutes:

  Integer minutes; model-local time = UTC + offset.

- year_fraction:

  Fraction of a year covered by `sum(leaves$share)`. Defaults to `1`.

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
cal <- calendar_from_leaves(df, timeframes = "MONTH", name = "m12")
cal
#> <timescales::Calendar>
#>  @ leaves    :'data.frame':  12 obs. of  4 variables:
#>  .. $ MONTH : chr  "m01" "m02" "m03" "m04" ...
#>  .. $ share : num  0.0849 0.0767 0.0849 0.0822 0.0849 ...
#>  .. $ weight: num  31 28 31 30 31 30 31 31 30 31 ...
#>  .. $ slice : chr  "m01" "m02" "m03" "m04" ...
#>  @ timeframes: chr "MONTH"
#>  @ levels    :List of 1
#>  .. $ MONTH: chr [1:12] "m01" "m02" "m03" "m04" ...
#>  @ meta      :List of 5
#>  .. $ name              : chr "m12"
#>  .. $ desc              : chr ""
#>  .. $ year_start        :List of 2
#>  ..  ..$ month: int 1
#>  ..  ..$ day  : int 1
#>  .. $ utc_offset_minutes: int 0
#>  .. $ year_fraction     : num 1
```
