# Extract timeframe values from datetime vectors

Extracts a single timeframe component (`YEAR`, `MONTH`, `HOUR`, ...)
from a `Date`, `POSIXct`, or `POSIXlt` vector, optionally formatted as a
token string.

## Usage

``` r
as_timeframe(x, timeframe, format = c("numeric", "token"), ...)

# S3 method for class 'POSIXt'
as_timeframe(x, timeframe, format = c("numeric", "token"), ...)

# S3 method for class 'Date'
as_timeframe(x, timeframe, format = c("numeric", "token"), ...)

# S3 method for class 'numeric'
as_timeframe(
  x,
  timeframe,
  format = c("numeric", "token"),
  calendar = NULL,
  ...
)

# Default S3 method
as_timeframe(x, timeframe, format = c("numeric", "token"), ...)

# S3 method for class 'character'
as_timeframe(
  x,
  timeframe,
  format = c("numeric", "token"),
  calendar = NULL,
  year = NULL,
  ...
)
```

## Arguments

- x:

  A datetime vector (`Date`, `POSIXct`, or `POSIXlt`).

- timeframe:

  Character scalar naming the timeframe to extract; one of
  [`CORE_TIMEFRAMES`](https://optimal2050.github.io/timescales/r/reference/CORE_TIMEFRAMES.md).

- format:

  `"numeric"` (default) for raw integer values, or `"token"` for
  formatted strings (`"m01"`, `"h00"`, `"d365"`, `"MON"`, ...).

- ...:

  Currently `week_start` is forwarded to
  [`lubridate::wday()`](https://lubridate.tidyverse.org/reference/day.html)
  for `WDAY` and `MWEEK`. Token vocabularies such as `wd7` are ISO
  (Monday first), so pair them with `week_start = 1`; the default is
  lubridate's (Sunday first) and differs from those vocabularies by one.

- calendar:

  A
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md),
  or the name of one (`"d365_h24"`). Required for character input: the
  timeframe is read from the calendar rather than parsed out of the
  label. For numeric input it is optional, and selects the calendar's
  own label vocabulary over the canonical one.

- year:

  The year the timeslices fall in. Needed only when `timeframe` is
  weekday-derived (`WDAY`, `MWEEK`, `DAYTYPE`, `WHOUR`); `MONTH`,
  `YDAY`, `QUARTER`, `SEASON`, `WEEK` and `MDAY` are the same in every
  year.

## Value

Integer/numeric vector for `format = "numeric"`, character vector for
`format = "token"`. Preserves `NA` positions.

## Details

For datetime input (no calendar), `lubridate` defaults apply:

- `WDAY` uses `getOption("lubridate.week.start", 7)` (1 = Sunday).

- `MONTH`: 1 = January, 12 = December.

- `HOUR`: 0-23.

- `MWEEK`: calendar-grid week-of-month aligned to `WDAY`.

## Examples

``` r
library(lubridate)
#> 
#> Attaching package: 'lubridate'
#> The following objects are masked from 'package:base':
#> 
#>     date, intersect, setdiff, union
dtm <- ymd_h("2020-03-15 14", tz = "UTC")
as_timeframe(dtm, "MONTH")                   # 3
#> [1] 3
as_timeframe(dtm, "YDAY", format = "token")  # "d075"
#> [1] "d075"
```
