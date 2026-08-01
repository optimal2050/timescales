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

# Default S3 method
as_timeframe(x, timeframe, format = c("numeric", "token"), ...)
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
  for `WDAY` and `MWEEK`.

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
