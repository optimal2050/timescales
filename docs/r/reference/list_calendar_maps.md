# List the registered crosswalks

List the registered crosswalks

## Usage

``` r
list_calendar_maps()
```

## Value

A `data.frame` with one row per registered map: `key` (`"from->to"`),
`from`, `to`. Zero rows when none are registered (mirrors
[`geoscales::list_geoscale_maps()`](https://optimal2050.github.io/geoscales/r/reference/register_geoscale_map.html)).

## Examples

``` r
list_calendar_maps()
#> [1] key  from to  
#> <0 rows> (or 0-length row.names)
```
