# Deprecated alias of instant_to_timeslice()

`instant_to_slice()` is deprecated; the time dimension was renamed
`slice` -\> `timeslice` across the stack (matching the TIMES/OSeMOSYS
vocabulary and pairing with geoscales' `region`).

## Usage

``` r
instant_to_slice(dtm, calendar, alignment = NULL)
```

## Arguments

- dtm:

  A `POSIXct`/`POSIXlt`/`Date` vector.

- calendar:

  A
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- alignment:

  Optional override of the calendar's alignment: a single rule applied
  to every timeframe, or a named list/vector per timeframe. `NULL`
  (default) uses `meta$alignment`.

## Value

See
[`instant_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/instant_to_timeslice.md).
