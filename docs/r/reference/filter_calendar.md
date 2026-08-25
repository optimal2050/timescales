# Filter a Calendar to selected labels

Keep only the leaf timeslices whose `timeframe` label is in `labels` —
the time-side mirror of
[`geoscales::filter_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/filter_geoscale.html).
Shares are NOT renormalized: the result is a partial-year calendar whose
`meta$year_fraction` is set to the surviving `sum(share)` (use
[`calendar_share()`](https://optimal2050.github.io/timescales/r/reference/calendar_share.md)
when normalized shares are needed). Level vocabularies are subset to the
surviving labels.

## Usage

``` r
filter_calendar(x, timeframe, labels)

# S3 method for class 'Calendar'
x[i, j, ...]

# S3 method for class '`timescales::Calendar`'
x[i, j, ...]
```

## Arguments

- x:

  A
  [Calendar](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
  (the `[` method's object).

- timeframe:

  Timeframe the labels live at.

- labels:

  Labels at `timeframe` to keep.

- i, j:

  `x[i, j]` is `filter_calendar(x, timeframe = i, labels = j)`.

- ...:

  Ignored (S3 signature compatibility).

## Value

A
[Calendar](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
covering the selected part of the year.

## Details

A real sample (fewer leaves than the parent) is book-kept exactly like a
geoscales sample: the result is renamed
`"base[timeframe:labels-or-hash]"` (so two different samples of one
parent never collide in registries or joins), the root parent's name and
totals are recorded in `meta$parent_name`/`meta$parent_totals`, and
`meta$coverage` holds the surviving fraction of `share` and `weight`
(read it with
[`calendar_coverage()`](https://optimal2050.github.io/timescales/r/reference/calendar_coverage.md)).
Filter-of-filter composes against the root parent. A filter that keeps
everything is a true no-op: the calendar is returned unchanged.

There is no `drop_empty_timeframes=` twin of the geoscales argument: a
calendar leaftable is total (no `NA` memberships), so no timeframe can
empty out under filtering.

`cal[timeframe, labels]` is subsetting sugar for the same operation.

## Examples

``` r
win <- filter_calendar(calendar("s4_h24"), "SEASON", "WIN")
win <- calendar("s4_h24")["SEASON", "WIN"]   # same
calendar_coverage(win)
#>     share    weight 
#> 0.2465753 0.2465753 
```
