# Deprecated timescales functions

These functions were renamed under the harmonized naming convention
shared with the geoscales package: operations on data and object
transforms are `verb_calendar()`, properties and queries are
`calendar_*()`. The old names warn and forward to their replacements;
they will be removed before the 1.0 release.

## Usage

``` r
calendar_recast(...)

calendar_join(...)

calendar_at_level(...)

instant_to_timeslice(...)

instant_to_slice(...)

calendar_from_leaves(leaves, timeframes, levels = NULL, ...)
```

## Arguments

- ...:

  Arguments forwarded to the replacement function.

## Value

See the replacement function.

## Details

- `calendar_recast()` -\>
  [`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md)
  (or the
  [`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md)
  generic)

- `calendar_join()` -\>
  [`join_calendar()`](https://optimal2050.github.io/timescales/r/reference/join_calendar.md)

- `calendar_at_level()` -\>
  [`prune_calendar()`](https://optimal2050.github.io/timescales/r/reference/prune_calendar.md)

- `instant_to_timeslice()` -\>
  [`datetime_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/datetime_to_timeslice.md)
  ("instant" retired from the public vocabulary: the column is
  `datetime`, the grid is the base calendar)

- `instant_to_slice()` -\>
  [`datetime_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/datetime_to_timeslice.md)
