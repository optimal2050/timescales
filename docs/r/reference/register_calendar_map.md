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

## Examples

``` r
m12 <- calendar_map(calendar("m12"), calendar("q4"), year = 2021)
register_calendar_map("m12", "q4", m12)
get_calendar_map("m12", "q4")
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
register_calendar_map("m12", "q4", NULL)   # remove again
```
