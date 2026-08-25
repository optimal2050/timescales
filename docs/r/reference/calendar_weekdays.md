# Weekdays of a calendar's day layer in a given model year

Maps every day of the calendar's day layer (its `YDAY` or `MDAY`
timeframe) onto the real dates of one model year and reports the weekday
structure: weekday, week-of-month row, and an anchored week-of-year
index. The model year honours `meta$year_start` (so for the `fy04_*`
fiscal calendars it runs April..March and `wyear` counts fiscal weeks
from April 1) and `meta$utc_offset_minutes`.

## Usage

``` r
calendar_weekdays(x, year, week_start = "MON")
```

## Arguments

- x:

  A
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
  with a day-resolution timeframe (`YDAY` or `MDAY`). Sub-daily
  timeframes are collapsed to the day layer via
  [`prune_calendar()`](https://optimal2050.github.io/timescales/r/reference/prune_calendar.md).

- year:

  Integer scalar model year.

- week_start:

  Weekday the week starts on: one of `"MON"`..`"SUN"` (default `"MON"`,
  ISO).

## Value

A `data.frame`, one row per day of the day layer, in calendar order:
`timeslice` (day-level node ID), `date` (`Date`, `NA` where the stylized
day has no real date), `MONTH` (facet key: the calendar's MONTH members
when present, else the Gregorian `m01..m12` template; fiscal-ordered
under a nontrivial `year_start`), `mday` (day-of-month number), `wday`
(factor, vocabulary rotated to `week_start`), `wrow` (week-of-month row,
1 = first week, breaking on `week_start`), and `wyear` (week-of-year,
week 1 = the week containing the year anchor).

## Details

Stylized days with no real date in that year (`m12_md360`'s day 31, the
`d366` label in a non-leap year) get `date = NA` with one warning.

## Examples

``` r
wd <- calendar_weekdays(calendar("m12_md365"), 2021)
head(wd)
#>   timeslice       date MONTH mday wday wrow wyear
#> 1   m01_d01 2021-01-01   m01    1  FRI    1     1
#> 2   m01_d02 2021-01-02   m01    2  SAT    1     1
#> 3   m01_d03 2021-01-03   m01    3  SUN    1     1
#> 4   m01_d04 2021-01-04   m01    4  MON    2     2
#> 5   m01_d05 2021-01-05   m01    5  TUE    2     2
#> 6   m01_d06 2021-01-06   m01    6  WED    2     2
# fiscal weeks: April 1 opens week 1
head(calendar_weekdays(calendar("fy04_d365"), 2021))
#>   timeslice       date MONTH mday wday wrow wyear
#> 1      d001 2021-04-01   m04    1  THU    1     1
#> 2      d002 2021-04-02   m04    2  FRI    1     1
#> 3      d003 2021-04-03   m04    3  SAT    1     1
#> 4      d004 2021-04-04   m04    4  SUN    1     1
#> 5      d005 2021-04-05   m04    5  MON    2     2
#> 6      d006 2021-04-06   m04    6  TUE    2     2
```
