# Register or look up a calendar token

Tokens are named recipes for the labels (and within-year shares) of one
timeframe in a calendar hierarchy. A handful of built-in tokens covers
the common cases (`d365`, `m12`, `m12a`, `q4`, `w52`, `w53`, `wd7`,
`h24`, `h168`, `min60`, `d360`, `d364`, `d366`). Custom tokens may be
added with `register_calendar_token()`.

## Usage

``` r
register_calendar_token(name, timeframe, expand, alignment = NULL)

get_calendar_token(name)

list_calendar_tokens()
```

## Arguments

- name:

  Character scalar — the token name (e.g. `"m12"`).

- timeframe:

  One of
  [`CORE_TIMEFRAMES`](https://optimal2050.github.io/timescales/r/reference/CORE_TIMEFRAMES.md).

- expand:

  A zero-argument function returning a `data.frame` with columns `label`
  (character, unique) and `share` (numeric \> 0, summing to 1).

- alignment:

  Optional default alignment rule (one of
  [`ALIGNMENT_RULES`](https://optimal2050.github.io/timescales/r/reference/ALIGNMENT_RULES.md))
  declaring how real instants beyond this token's vocabulary map onto it
  (e.g. `"drop_feb29"` for `d365`). Calendars built from the token
  inherit it in `meta$alignment`.

## Value

`register_calendar_token()` invisibly returns the token name.
`get_calendar_token()` returns the token definition (a list with
`timeframe`, `expand`, and optionally `alignment`).
`list_calendar_tokens()` returns a character vector of all registered
token names.

## Examples

``` r
# Register a custom 4-period day-of-year partition
register_calendar_token("d4q", "YDAY", function() {
  data.frame(label = c("Q1d", "Q2d", "Q3d", "Q4d"),
             share = c(90, 91, 92, 92) / 365)
})
"d4q" %in% list_calendar_tokens()
#> [1] TRUE
```
