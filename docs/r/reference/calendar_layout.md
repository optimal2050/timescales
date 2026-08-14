# Icicle layout of a calendar's structure

Computes the rectangle geometry of the structure plot as a plain
`data.frame` — one band per timeframe (coarsest at the top, plus the
implicit `ANNUAL` root), one rectangle per contiguous timeslice segment,
x normalized to `[0, 1]` (share of the covered year). Exposed so the
layout can be drawn with something other than ggplot2; the same frame
backs
[`calendar_autoplot()`](https://optimal2050.github.io/timescales/r/reference/calendar_autoplot.md).

## Usage

``` r
calendar_layout(calendar, annual = TRUE)
```

## Arguments

- calendar:

  A
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- annual:

  Include the `ANNUAL` root band on top? Default `TRUE`.

## Value

A `data.frame` with columns `timeframe`, `label` (the level value of the
segment), `timeslice` (the full prefix path id), `rank` (0 for `ANNUAL`,
then 1 = coarsest), `xmin`/`xmax` (in `[0, 1]`), `ymin`/`ymax` (bands,
top row highest), `share` (segment share of the year), `weight` (segment
weight sum), `order` (index of the segment's first leaf in chronological
order), and `within` (1-based position among its siblings, restarting
per parent).

## Examples

``` r
head(calendar_layout(calendar("q4_h24")))
#>   timeframe  label timeslice rank      xmin       xmax ymin ymax      share
#> 1    ANNUAL ANNUAL    ANNUAL    0 0.0000000 1.00000000    2  2.9 1.00000000
#> 2   QUARTER     Q1        Q1    1 0.0000000 0.24657534    1  1.9 0.24657534
#> 3   QUARTER     Q2        Q2    1 0.2465753 0.49589041    1  1.9 0.24931507
#> 4   QUARTER     Q3        Q3    1 0.4958904 0.74794521    1  1.9 0.25205479
#> 5   QUARTER     Q4        Q4    1 0.7479452 1.00000000    1  1.9 0.25205479
#> 6      HOUR    h00    Q1_h00    2 0.0000000 0.01027397    0  0.9 0.01027397
#>   weight order within
#> 1   8760     1      1
#> 2   2160     1      1
#> 3   2184    25      2
#> 4   2208    49      3
#> 5   2208    73      4
#> 6     90     1      1
```
