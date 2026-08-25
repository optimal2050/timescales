# Register how a parameter should be recast

Records the aggregation rule to use for a named value column, so callers
of
[`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md)
need not repeat it. Downstream packages can register their own parameter
maps at load time. An explicit `rule=` argument to
[`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md)
always wins; unregistered columns default to `"weighted_mean"`.

## Usage

``` r
register_calendar_rule(param, rule)
```

## Arguments

- param:

  Name of the value column.

- rule:

  One of
  [`CALENDAR_RULES`](https://optimal2050.github.io/timescales/r/reference/CALENDAR_RULES.md).

## Value

Invisibly, the registered entry.

## Examples

``` r
register_calendar_rule("energy", "sum")
register_calendar_rule("price", "weighted_mean")
get_calendar_rule("energy")
#> $rule
#> [1] "sum"
#> 
```
