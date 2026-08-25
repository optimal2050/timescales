# Clear the crosswalk cache (and optionally the registered maps)

Mainly useful in tests, or after mutating a Calendar object in place
(maps are memoised by calendar NAME).

## Usage

``` r
clear_calendar_maps(registry = FALSE)
```

## Arguments

- registry:

  Also clear maps registered with
  [`register_calendar_map()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_map.md).
  Default `FALSE`.

## Value

Invisibly `NULL`.

## Examples

``` r
clear_calendar_maps()                 # drop the memo cache only
clear_calendar_maps(registry = TRUE)  # ... and the registered maps
```
