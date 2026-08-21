# Register / look up a direct calendar crosswalk

A registered map short-circuits the base-grid derivation in
[`calendar_map()`](https://optimal2050.github.io/timescales/r/reference/calendar_map.md)
(and thereby
[`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md))
for one calendar pair – the table analogue of the functional override in
[`register_conversion()`](https://optimal2050.github.io/timescales/r/reference/register_conversion.md),
for cases where the exact correspondence is known (provably nested
calendars, hand-audited crosswalks).

## Usage

``` r
register_calendar_map(from, to, map)
```

## Arguments

- from, to:

  Calendar names (`meta$name`) the map applies to, or
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
  objects (their names are used).

- map:

  A `data.frame` shaped like a
  [`calendar_map()`](https://optimal2050.github.io/timescales/r/reference/calendar_map.md)
  result: the two label columns named after `from` and `to`, plus
  `year`, `n_from`, `n_overlap` and `w`. `NULL` removes a previously
  registered map.

## Value

Invisibly, the registry key (`"from->to"`).
