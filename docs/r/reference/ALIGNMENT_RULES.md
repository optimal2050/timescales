# Supported alignment rules

Alignment declares how real Gregorian instants that fall outside a
calendar's vocabulary map onto it — a separate axis from aggregation
(conflating the two is how a non-conserving `sum` arises). Resurrects
the `alignment_rule` vocabulary of the predecessor `timeslices` package.

## Usage

``` r
ALIGNMENT_RULES
```

## Format

A character vector of length 4.

## Details

- `exact`:

  Error if any instant falls outside the vocabulary.

- `drop_last`:

  Instants past the last label map to `NA` (e.g. the trailing days of
  the year for `d360`).

- `drop_feb29`:

  Feb 29 maps to `NA`; later ydays shift down by one, so Dec 31 of a
  leap year is still `d365`.

- `repeat_last`:

  Instants past the last label clamp to it (e.g. week 53 folds into
  `w52`).

Alignment lives per-timeframe in a calendar's `meta$alignment` (a named
list), seeded by the tokens that built it and overridable at
construction or in
[`instant_to_slice()`](https://optimal2050.github.io/timescales/r/reference/instant_to_slice.md).
Unaligned out-of-vocabulary instants map to `NA`, surfaced by
[`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md)'s
`na_action`.

## Examples

``` r
ALIGNMENT_RULES
#> [1] "exact"       "drop_last"   "drop_feb29"  "repeat_last"
```
