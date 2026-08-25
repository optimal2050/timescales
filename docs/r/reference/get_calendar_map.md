# Look up one registered crosswalk

Returns the map registered with
[`register_calendar_map()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_map.md)
for the pair, or `NULL` when none is registered (mirrors
[`geoscales::get_geo_map()`](https://optimal2050.github.io/geoscales/r/reference/register_geo_map.html)).

## Usage

``` r
get_calendar_map(from, to)
```

## Arguments

- from, to:

  Calendar names (`meta$name`) the map applies to, or
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
  objects (their names are used).

## Value

The registered `data.frame`, or `NULL`.

## Examples

``` r
get_calendar_map("m12", "q4")   # NULL unless registered
#> NULL
```
