# Attach a calendar's timeframe columns to timeslice-keyed data

Joins the calendar's timeframe columns, `share`, and `weight` onto a
`data.frame` keyed by timeslice ID — the attachment step for manual
ggplot2 work, faceting, or grouped summaries. Timeframe columns are
added as factors in vocabulary order so axes and facets sort correctly.

## Usage

``` r
calendar_join(
  x,
  calendar,
  key = "timeslice",
  timeframes = NULL,
  as_factor = TRUE
)
```

## Arguments

- x:

  A `data.frame` with a column of timeslice IDs.

- calendar:

  A
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- key:

  Name of the timeslice key column in `x`. Default `"timeslice"`.

- timeframes:

  Which timeframe columns to attach. Default: all of the calendar's
  timeframes.

- as_factor:

  Attach timeframe columns as vocabulary-ordered factors (default
  `TRUE`) or plain character.

## Value

`x` with the requested timeframe columns plus `share` and `weight`
appended. Rows whose key is not a timeslice of the calendar get `NA`s
(with a warning).

## Examples

``` r
cal <- calendar("m12_h24")
x <- data.frame(timeslice = S7::prop(cal, "leaves")$timeslice, load = 1)
head(calendar_join(x, cal))
#>   timeslice load MONTH HOUR       share weight
#> 1   m01_h00    1   m01  h00 0.003538813     31
#> 2   m02_h00    1   m02  h00 0.003196347     28
#> 3   m03_h00    1   m03  h00 0.003538813     31
#> 4   m04_h00    1   m04  h00 0.003424658     30
#> 5   m05_h00    1   m05  h00 0.003538813     31
#> 6   m06_h00    1   m06  h00 0.003424658     30
```
