# List registered rules

List registered rules

## Usage

``` r
list_rules()
```

## Value

A `data.frame` with columns `param` and `rule`.

## Examples

``` r
register_rule("invcost", "weighted_mean")
list_rules()
#>     param          rule
#> 1  demand           sum
#> 2 invcost weighted_mean
```
