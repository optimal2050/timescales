# Attach a calendar to a dataset

Adds a timeslice-label column named after the calendar (its
`meta$name`), plus optionally the calendar's timeframe columns and
share/weight, all prefixed `"<name>."`. Because every calendar attaches
under its own name, several calendars can be joined to the same dataset
– and a dataset carrying two label columns is a direct crosswalk between
those calendars.

## Usage

``` r
join_calendar(
  x,
  calendar,
  key = NULL,
  timeframes = NULL,
  meta = FALSE,
  as_factor = TRUE,
  year = NULL,
  by = NULL,
  tz = "UTC",
  collect = NULL
)
```

## Arguments

- x:

  The dataset, in any supported backend (see
  [`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md)'s
  Backends section).

- calendar:

  A named
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- key:

  Key column of `x`: a timeslice-label column, or a POSIXct datetime
  column. `NULL` (default) auto-detects as described above.

- timeframes:

  Character vector of the calendar's timeframes to attach as
  `"<name>.<TIMEFRAME>"` columns (default: none). `TRUE` attaches all of
  them.

- meta:

  Attach `"<name>.share"` and `"<name>.weight"` columns (default
  `FALSE`).

- as_factor:

  Attach timeframe columns as vocabulary-ordered factors (default
  `TRUE`) or plain character. (Lazy backends store them as
  dictionary/character columns.)

- year:

  Model year(s) for the base grid when attaching by datetime. Default:
  the span of years observed in the data, padded one year each side.

- by, tz:

  Base-grid resolution and time zone for the datetime route, as in
  [`expand_calendar()`](https://optimal2050.github.io/timescales/r/reference/expand_calendar.md).

- collect:

  For lazy inputs: materialise (`TRUE`) or return the query (default).

## Value

`x` with the new column(s) appended, in the input's class (lazy in, lazy
out).

## Details

The key is auto-detected: an existing column named like the calendar is
used as-is; else a `timeslice` column (labels validated against the
calendar, with a warning for unknown codes); else a `datetime` column
(labels computed on the base grid via
[`datetime_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/datetime_to_timeslice.md)
– this is how a calendar is attached to raw datetime observations).
Existing columns are never overwritten; the join errors instead.

## Examples

``` r
cal <- calendar("m12_h24")
x <- data.frame(timeslice = S7::prop(cal, "leaftable")$timeslice, load = 1)
head(join_calendar(x, cal))                    # adds `m12_h24`
#>   timeslice load m12_h24
#> 1   m01_h00    1 m01_h00
#> 2   m02_h00    1 m02_h00
#> 3   m03_h00    1 m03_h00
#> 4   m04_h00    1 m04_h00
#> 5   m05_h00    1 m05_h00
#> 6   m06_h00    1 m06_h00
head(join_calendar(x, cal, timeframes = TRUE)) # + m12_h24.MONTH, ...
#>   timeslice load m12_h24 m12_h24.MONTH m12_h24.HOUR
#> 1   m01_h00    1 m01_h00           m01          h00
#> 2   m02_h00    1 m02_h00           m02          h00
#> 3   m03_h00    1 m03_h00           m03          h00
#> 4   m04_h00    1 m04_h00           m04          h00
#> 5   m05_h00    1 m05_h00           m05          h00
#> 6   m06_h00    1 m06_h00           m06          h00

# two calendars on one dataset = a direct crosswalk between them
xt <- data.frame(datetime = seq(as.POSIXct("2021-01-01", tz = "UTC"),
                                by = "hour", length.out = 48), v = 1)
xt <- join_calendar(xt, calendar("m12_h24"))
xt <- join_calendar(xt, calendar("q4_h24"))
head(xt)
#>              datetime v m12_h24 q4_h24
#> 1 2021-01-01 00:00:00 1 m01_h00 Q1_h00
#> 2 2021-01-01 01:00:00 1 m01_h01 Q1_h01
#> 3 2021-01-01 02:00:00 1 m01_h02 Q1_h02
#> 4 2021-01-01 03:00:00 1 m01_h03 Q1_h03
#> 5 2021-01-01 04:00:00 1 m01_h04 Q1_h04
#> 6 2021-01-01 05:00:00 1 m01_h05 Q1_h05
```
