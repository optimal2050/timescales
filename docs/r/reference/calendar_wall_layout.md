# Wall-calendar tile layout

The layout worker behind
[`calendar_wall_plot()`](https://optimal2050.github.io/timescales/r/reference/calendar_wall_plot.md):
one row per day cell with facet key and grid position. Two arrangements:

## Usage

``` r
calendar_wall_layout(
  calendar,
  year = NULL,
  arrange = c("weekday", "sequence"),
  week_start = "MON"
)
```

## Arguments

- calendar:

  A
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
  with a day-resolution timeframe (`YDAY` or `MDAY`). Sub-daily
  timeframes are collapsed to the day layer via
  [`prune_calendar()`](https://optimal2050.github.io/timescales/r/reference/prune_calendar.md).

- year:

  Integer model year (required for the weekday arrangement; `NULL` falls
  back to `"sequence"` with a message).

- arrange:

  `"weekday"` or `"sequence"` (see above).

- week_start:

  Weekday the week starts on: one of `"MON"`..`"SUN"` (default `"MON"`,
  ISO).

## Value

A `data.frame`: `timeslice`, `MONTH` (factor in member order), `label`
(day-of-month number), `col`, `row`, `wday` (factor, `NA` in sequence
mode), `date` (`NA` in sequence mode).

## Details

- `arrange = "weekday"` – a true wall calendar: columns are weekdays
  (starting at `week_start`), rows are weeks of the month. Needs `year`
  (weekdays are year-specific); when `year` is `NULL` it FALLS BACK to
  `"sequence"` with a message.

- `arrange = "sequence"` – year-free: days flow left-to-right in fixed
  7-wide rows, no weekday meaning.

## Examples

``` r
head(calendar_wall_layout(calendar("m12_md365"), year = 2021))
#>   timeslice MONTH label col row wday       date
#> 1   m01_d01   m01     1   5   1  FRI 2021-01-01
#> 2   m01_d02   m01     2   6   1  SAT 2021-01-02
#> 3   m01_d03   m01     3   7   1  SUN 2021-01-03
#> 4   m01_d04   m01     4   1   2  MON 2021-01-04
#> 5   m01_d05   m01     5   2   2  TUE 2021-01-05
#> 6   m01_d06   m01     6   3   2  WED 2021-01-06
head(calendar_wall_layout(calendar("m12_md365")))  # sequence fallback
#> weekday arrangement needs `year=` (weekdays are year-specific); falling back to arrange = "sequence"
#>   timeslice MONTH label col row wday date
#> 1   m01_d01   m01     1   1   1 <NA> <NA>
#> 2   m01_d02   m01     2   2   1 <NA> <NA>
#> 3   m01_d03   m01     3   3   1 <NA> <NA>
#> 4   m01_d04   m01     4   4   1 <NA> <NA>
#> 5   m01_d05   m01     5   5   1 <NA> <NA>
#> 6   m01_d06   m01     6   6   1 <NA> <NA>
```
