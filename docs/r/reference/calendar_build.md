# Build a Calendar from token names

Declarative constructor: name the timeframe vocabulary tokens in
coarsest- to-finest order. The Cartesian product of their labels becomes
the leaf table; each leaf's share is the product of its tokens' shares,
scaled to `year_fraction`.

Convenience shortcut: parses a token-style name like `"d365_h24"` or
`"m12_h24"` into its tokens and dispatches to `calendar_build()`. The
leading `y_` prefix (year-qualified) is currently stripped and recorded
in `meta$year_qualified` — full year-prefix semantics arrive in a later
phase.

## Usage

``` r
calendar_build(
  ...,
  name = NULL,
  desc = "",
  year_start = list(month = 1L, day = 1L),
  utc_offset_minutes = 0L,
  year_fraction = 1
)

calendar(name, ...)
```

## Arguments

- ...:

  Passed through to `calendar_build()` (`year_start`,
  `utc_offset_minutes`, `year_fraction`, `desc`).

- name:

  Character scalar — a token-style calendar name (`"d365"`,
  `"d365_h24"`, `"m12_h24"`, `"q4_h24"`, ...).

- desc:

  Free-text description.

- year_start:

  `list(month = , day = )`; defaults to January 1.

- utc_offset_minutes:

  Integer minutes; defaults to 0.

- year_fraction:

  Year fraction covered. Defaults to 1.

## Value

A
[`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

A
[`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

## Examples

``` r
cal <- calendar_build("d365", "h24", name = "d365_h24")
cal
#> <timescales::Calendar>
#>  @ leaves    :'data.frame':  8760 obs. of  5 variables:
#>  .. $ YDAY  : chr  "d001" "d002" "d003" "d004" ...
#>  .. $ HOUR  : chr  "h00" "h00" "h00" "h00" ...
#>  .. $ share : num  0.000114 0.000114 0.000114 0.000114 0.000114 ...
#>  .. $ weight: num  1 1 1 1 1 1 1 1 1 1 ...
#>  .. $ slice : chr  "d001_h00" "d002_h00" "d003_h00" "d004_h00" ...
#>  @ timeframes: chr [1:2] "YDAY" "HOUR"
#>  @ levels    :List of 2
#>  .. $ YDAY: chr [1:365] "d001" "d002" "d003" "d004" ...
#>  .. $ HOUR: chr [1:24] "h00" "h01" "h02" "h03" ...
#>  @ meta      :List of 5
#>  .. $ name              : chr "d365_h24"
#>  .. $ desc              : chr ""
#>  .. $ year_start        :List of 2
#>  ..  ..$ month: int 1
#>  ..  ..$ day  : int 1
#>  .. $ utc_offset_minutes: int 0
#>  .. $ year_fraction     : num 1

cal2 <- calendar_build("m12", "h24")
cal2
#> <timescales::Calendar>
#>  @ leaves    :'data.frame':  288 obs. of  5 variables:
#>  .. $ MONTH : chr  "m01" "m02" "m03" "m04" ...
#>  .. $ HOUR  : chr  "h00" "h00" "h00" "h00" ...
#>  .. $ share : num  0.00354 0.0032 0.00354 0.00342 0.00354 ...
#>  .. $ weight: num  31 28 31 30 31 30 31 31 30 31 ...
#>  .. $ slice : chr  "m01_h00" "m02_h00" "m03_h00" "m04_h00" ...
#>  @ timeframes: chr [1:2] "MONTH" "HOUR"
#>  @ levels    :List of 2
#>  .. $ MONTH: chr [1:12] "m01" "m02" "m03" "m04" ...
#>  .. $ HOUR : chr [1:24] "h00" "h01" "h02" "h03" ...
#>  @ meta      :List of 5
#>  .. $ name              : chr "m12_h24"
#>  .. $ desc              : chr ""
#>  .. $ year_start        :List of 2
#>  ..  ..$ month: int 1
#>  ..  ..$ day  : int 1
#>  .. $ utc_offset_minutes: int 0
#>  .. $ year_fraction     : num 1
calendar("d365_h24")
#> <timescales::Calendar>
#>  @ leaves    :'data.frame':  8760 obs. of  5 variables:
#>  .. $ YDAY  : chr  "d001" "d002" "d003" "d004" ...
#>  .. $ HOUR  : chr  "h00" "h00" "h00" "h00" ...
#>  .. $ share : num  0.000114 0.000114 0.000114 0.000114 0.000114 ...
#>  .. $ weight: num  1 1 1 1 1 1 1 1 1 1 ...
#>  .. $ slice : chr  "d001_h00" "d002_h00" "d003_h00" "d004_h00" ...
#>  @ timeframes: chr [1:2] "YDAY" "HOUR"
#>  @ levels    :List of 2
#>  .. $ YDAY: chr [1:365] "d001" "d002" "d003" "d004" ...
#>  .. $ HOUR: chr [1:24] "h00" "h01" "h02" "h03" ...
#>  @ meta      :List of 5
#>  .. $ name              : chr "d365_h24"
#>  .. $ desc              : chr ""
#>  .. $ year_start        :List of 2
#>  ..  ..$ month: int 1
#>  ..  ..$ day  : int 1
#>  .. $ utc_offset_minutes: int 0
#>  .. $ year_fraction     : num 1
calendar("m12_h24")
#> <timescales::Calendar>
#>  @ leaves    :'data.frame':  288 obs. of  5 variables:
#>  .. $ MONTH : chr  "m01" "m02" "m03" "m04" ...
#>  .. $ HOUR  : chr  "h00" "h00" "h00" "h00" ...
#>  .. $ share : num  0.00354 0.0032 0.00354 0.00342 0.00354 ...
#>  .. $ weight: num  31 28 31 30 31 30 31 31 30 31 ...
#>  .. $ slice : chr  "m01_h00" "m02_h00" "m03_h00" "m04_h00" ...
#>  @ timeframes: chr [1:2] "MONTH" "HOUR"
#>  @ levels    :List of 2
#>  .. $ MONTH: chr [1:12] "m01" "m02" "m03" "m04" ...
#>  .. $ HOUR : chr [1:24] "h00" "h01" "h02" "h03" ...
#>  @ meta      :List of 5
#>  .. $ name              : chr "m12_h24"
#>  .. $ desc              : chr ""
#>  .. $ year_start        :List of 2
#>  ..  ..$ month: int 1
#>  ..  ..$ day  : int 1
#>  .. $ utc_offset_minutes: int 0
#>  .. $ year_fraction     : num 1
```
