# Supported alignment rules

Alignment declares how Gregorian instants that fall outside a calendar's
vocabulary map onto it. It is a separate axis from aggregation.

## Usage

``` r
ALIGNMENT_RULES
```

## Format

A character vector of length 4.

## Value

A character vector of the four alignment rule names.

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
[`datetime_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/datetime_to_timeslice.md).
Unaligned out-of-vocabulary grid points map to `NA`, surfaced by
[`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md)'s
`na_action`.

## Examples

``` r
ALIGNMENT_RULES
#> [1] "exact"       "drop_last"   "drop_feb29"  "repeat_last"
```
