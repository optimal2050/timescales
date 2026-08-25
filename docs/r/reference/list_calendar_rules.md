# List registered rules

List registered rules

## Usage

``` r
list_calendar_rules()
```

## Value

A `data.frame` with columns `param` and `rule`.

## Examples

``` r
register_calendar_rule("invcost", "weighted_mean")
list_calendar_rules()
#>     param          rule
#> 1  demand           sum
#> 2 invcost weighted_mean
```
