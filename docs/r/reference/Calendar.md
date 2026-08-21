# Calendar (S7 class)

A nested time partition: a flat table of weighted leaf timeslices plus
the ordered hierarchy of timeframes that produced them.

## Usage

``` r
Calendar(leaftable, timeframes, members, meta = list())
```

## Arguments

- leaftable:

  `data.frame` with columns `timeslice`, `share`, `weight`, plus one
  column per timeframe in `timeframes`.

- timeframes:

  Ordered character vector of timeframe names (coarsest first); each
  name must appear as a column in `leaftable`.

- members:

  Named list; `members[[tf]]` is the full ordered set of allowed labels
  at timeframe `tf`. Must equal `unique(leaftable[[tf]])` as a set.

- meta:

  Named list of model-level attributes (`name`, `desc`, `year_start`,
  `utc_offset_minutes`, `year_fraction`).

## Details

Construct with
[`calendar_from_leaftable()`](https://optimal2050.github.io/timescales/r/reference/calendar_from_leaftable.md)
(the general escape hatch). Higher-level constructors built on tokens
and a catalog will arrive in a later phase.
