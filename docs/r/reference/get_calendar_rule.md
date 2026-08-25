# Look up a registered rule

Look up a registered rule

## Usage

``` r
get_calendar_rule(param)
```

## Arguments

- param:

  Name of the value column.

## Value

A list with element `rule`, or `NULL` if `param` has not been
registered.

## Examples

``` r
register_calendar_rule("demand", "sum")
get_calendar_rule("demand")
#> $rule
#> [1] "sum"
#> 
get_calendar_rule("not_registered")
#> NULL
```
