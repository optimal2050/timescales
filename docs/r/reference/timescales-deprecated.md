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

- [`instant_to_slice()`](https://optimal2050.github.io/timescales/r/reference/instant_to_slice.md)
  -\>
  [`instant_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/instant_to_timeslice.md)
