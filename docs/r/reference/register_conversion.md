# Register a pairwise calendar conversion override

By default
[`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md)
routes every conversion through the shared instant grid
(`A -> base -> B`). A registered override short-circuits that route for
one named calendar pair — the escape hatch for exact nested-calendar
arithmetic or anything the grid cannot express.

## Usage

``` r
register_conversion(from, to, fun)

get_conversion(from, to)

list_conversions()

clear_conversions(key = NULL)
```

## Arguments

- from, to:

  Calendar names (`meta$name`) the override applies to.

- fun:

  A function with signature `fun(x, from, to, ...)` receiving the same
  arguments as
  [`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md)
  and returning the recast `data.frame`. `NULL` removes a previously
  registered override.

- key:

  Optional character vector of `"from->to"` keys to remove; `NULL`
  (default) clears everything.

## Value

Invisibly, the registry key (`"from->to"`).

`get_conversion()` returns the registered function or `NULL`.

`list_conversions()` returns a `data.frame` with column `key`.

## Examples

``` r
register_conversion("m12", "q4", function(x, from, to, ...) {
  # trivial exact nesting: quarters are consecutive month triples
  q <- rep(sprintf("Q%d", 1:4), each = 3)
  stats::aggregate(x[-1], list(slice = q[match(x$slice,
    S7::prop(from, "leaves")$slice)]), sum)
})
"m12->q4" %in% list_conversions()$key
#> [1] TRUE
clear_conversions()
```
