# Look up a registered rule

Look up a registered rule

## Usage

``` r
get_rule(param)
```

## Arguments

- param:

  Name of the value column.

## Value

A list with element `rule`, or `NULL` if `param` has not been
registered.

## Examples

``` r
register_rule("demand", "sum")
get_rule("demand")
#> $rule
#> [1] "sum"
#> 
get_rule("not_registered")
#> NULL
```
