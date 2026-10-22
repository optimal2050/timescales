# Register / look up a direct calendar crosswalk

A registered map short-circuits the derivation in
[`calendar_map()`](https://optimal2050.github.io/timescales/r/reference/calendar_map.md)
or
[`calendar_map_between()`](https://optimal2050.github.io/timescales/r/reference/calendar_map_between.md)
(and thereby
[`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md))
for one pair of resolutions – the table analogue of the functional
override in
[`register_calendar_conversion()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_conversion.md),
for cases where the exact correspondence is known (provably nested
calendars, hand-audited crosswalks).

## Usage

``` r
register_calendar_map(
  x,
  source,
  target,
  map,
  from = lifecycle::deprecated(),
  to = lifecycle::deprecated()
)

register_calendar_map_between(
  source,
  target,
  map,
  from = lifecycle::deprecated(),
  to = lifecycle::deprecated()
)

get_calendar_map(
  x,
  source,
  target,
  from = lifecycle::deprecated(),
  to = lifecycle::deprecated()
)

get_calendar_map_between(
  source,
  target,
  from = lifecycle::deprecated(),
  to = lifecycle::deprecated()
)
```

## Arguments

- x:

  The
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
  the timeframes belong to, or its name.

- source, target:

  For the within-calendar functions, timeframe names of `x`.

- map:

  A `data.frame` shaped like the corresponding map result: the two label
  columns named after the timeframes (plus `n_from`, `n_overlap`, `w`,
  `w_from`) or after the calendars (plus `year`, `n_from`, `n_overlap`,
  `w`). `NULL` removes a previously registered map.

- from, to:

  Deprecated names of `source` and `target`. For the `_between`
  functions, two
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
  objects or their names (`meta$name`).

## Value

Invisibly, the registry key. The `get_` functions return the registered
map (or `NULL`).

## Details

`register_calendar_map()` and `get_calendar_map()` handle a pair of
timeframes of one calendar; the map is scoped to that calendar, so the
same timeframe pair in two calendars does not collide.
`register_calendar_map_between()` and `get_calendar_map_between()`
handle a pair of calendars.

## Examples

``` r
between <- calendar_map_between(calendar("m12"), calendar("q4"), year = 2021)
register_calendar_map_between("m12", "q4", between)
get_calendar_map_between("m12", "q4")
#>    year m12 q4 n_from n_overlap          w
#> 1  2021 m01 Q1     31        31 0.08493151
#> 2  2021 m02 Q1     28        28 0.07671233
#> 3  2021 m03 Q1     31        31 0.08493151
#> 4  2021 m04 Q2     30        30 0.08219178
#> 5  2021 m05 Q2     31        31 0.08493151
#> 6  2021 m06 Q2     30        30 0.08219178
#> 7  2021 m07 Q3     31        31 0.08493151
#> 8  2021 m08 Q3     31        31 0.08493151
#> 9  2021 m09 Q3     30        30 0.08219178
#> 10 2021 m10 Q4     31        31 0.08493151
#> 11 2021 m11 Q4     30        30 0.08219178
#> 12 2021 m12 Q4     31        31 0.08493151
list_calendar_maps()
#>       key from to
#> 1 m12->q4  m12 q4
register_calendar_map_between("m12", "q4", NULL)   # remove again

cal <- calendar("m12_h24")
within <- calendar_map(cal, "MONTH", "HOUR")
register_calendar_map(cal, "MONTH", "HOUR", within)
identical(get_calendar_map(cal, "MONTH", "HOUR"), within)
#> [1] TRUE
clear_calendar_maps(registry = TRUE)
```
