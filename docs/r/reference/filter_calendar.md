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
filter_calendar(calendar, timeframe, labels)

# S3 method for class 'Calendar'
x[i, j, ...]

# S3 method for class '`timescales::Calendar`'
x[i, j, ...]
```

## Arguments

- calendar:

  A
  [Calendar](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- timeframe:

  Timeframe the labels live at.

- labels:

  Labels at `timeframe` to keep.

- x:

  A
  [Calendar](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
  (the `[` method's object).

- i, j:

  `x[i, j]` is `filter_calendar(x, timeframe = i, labels = j)`.

- ...:

  Ignored (S3 signature compatibility).

## Value

A
[Calendar](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
covering the selected part of the year.

## Details

`cal[timeframe, labels]` is subsetting sugar for the same operation.

## Examples

``` r
win <- filter_calendar(calendar("s4_h24"), "SEASON", "WIN")
win <- calendar("s4_h24")["SEASON", "WIN"]   # same
```
