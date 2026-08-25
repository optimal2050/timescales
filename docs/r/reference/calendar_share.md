# Duration shares at a timeframe

Leaf shares summed to a timeframe and normalized — the time-side mirror
of
[`geoscales::geoscale_share()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_share.html).
Without `within`, shares sum to 1 over the whole calendar; with `within`
(a coarser timeframe), they sum to 1 inside each parent label.

## Usage

``` r
calendar_share(x, timeframe, within = NULL)
```

## Arguments

- x:

  A
  [Calendar](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- timeframe:

  Timeframe to aggregate the shares at.

- within:

  Optional coarser timeframe to normalize within.

## Value

A `data.frame` with the `timeframe` column (and the `within` column when
given) plus `share`.

## Examples

``` r
calendar_share(calendar("m12"), "MONTH")
#>    MONTH      share
#> 1    m01 0.08493151
#> 2    m02 0.07671233
#> 3    m03 0.08493151
#> 4    m04 0.08219178
#> 5    m05 0.08493151
#> 6    m06 0.08219178
#> 7    m07 0.08493151
#> 8    m08 0.08493151
#> 9    m09 0.08219178
#> 10   m10 0.08493151
#> 11   m11 0.08219178
#> 12   m12 0.08493151
calendar_share(calendar("q4_h24"), "HOUR", within = "QUARTER")
#>    QUARTER HOUR      share
#> 1       Q1  h00 0.04166667
#> 2       Q1  h01 0.04166667
#> 3       Q1  h02 0.04166667
#> 4       Q1  h03 0.04166667
#> 5       Q1  h04 0.04166667
#> 6       Q1  h05 0.04166667
#> 7       Q1  h06 0.04166667
#> 8       Q1  h07 0.04166667
#> 9       Q1  h08 0.04166667
#> 10      Q1  h09 0.04166667
#> 11      Q1  h10 0.04166667
#> 12      Q1  h11 0.04166667
#> 13      Q1  h12 0.04166667
#> 14      Q1  h13 0.04166667
#> 15      Q1  h14 0.04166667
#> 16      Q1  h15 0.04166667
#> 17      Q1  h16 0.04166667
#> 18      Q1  h17 0.04166667
#> 19      Q1  h18 0.04166667
#> 20      Q1  h19 0.04166667
#> 21      Q1  h20 0.04166667
#> 22      Q1  h21 0.04166667
#> 23      Q1  h22 0.04166667
#> 24      Q1  h23 0.04166667
#> 25      Q2  h00 0.04166667
#> 26      Q2  h01 0.04166667
#> 27      Q2  h02 0.04166667
#> 28      Q2  h03 0.04166667
#> 29      Q2  h04 0.04166667
#> 30      Q2  h05 0.04166667
#> 31      Q2  h06 0.04166667
#> 32      Q2  h07 0.04166667
#> 33      Q2  h08 0.04166667
#> 34      Q2  h09 0.04166667
#> 35      Q2  h10 0.04166667
#> 36      Q2  h11 0.04166667
#> 37      Q2  h12 0.04166667
#> 38      Q2  h13 0.04166667
#> 39      Q2  h14 0.04166667
#> 40      Q2  h15 0.04166667
#> 41      Q2  h16 0.04166667
#> 42      Q2  h17 0.04166667
#> 43      Q2  h18 0.04166667
#> 44      Q2  h19 0.04166667
#> 45      Q2  h20 0.04166667
#> 46      Q2  h21 0.04166667
#> 47      Q2  h22 0.04166667
#> 48      Q2  h23 0.04166667
#> 49      Q3  h00 0.04166667
#> 50      Q3  h01 0.04166667
#> 51      Q3  h02 0.04166667
#> 52      Q3  h03 0.04166667
#> 53      Q3  h04 0.04166667
#> 54      Q3  h05 0.04166667
#> 55      Q3  h06 0.04166667
#> 56      Q3  h07 0.04166667
#> 57      Q3  h08 0.04166667
#> 58      Q3  h09 0.04166667
#> 59      Q3  h10 0.04166667
#> 60      Q3  h11 0.04166667
#> 61      Q3  h12 0.04166667
#> 62      Q3  h13 0.04166667
#> 63      Q3  h14 0.04166667
#> 64      Q3  h15 0.04166667
#> 65      Q3  h16 0.04166667
#> 66      Q3  h17 0.04166667
#> 67      Q3  h18 0.04166667
#> 68      Q3  h19 0.04166667
#> 69      Q3  h20 0.04166667
#> 70      Q3  h21 0.04166667
#> 71      Q3  h22 0.04166667
#> 72      Q3  h23 0.04166667
#> 73      Q4  h00 0.04166667
#> 74      Q4  h01 0.04166667
#> 75      Q4  h02 0.04166667
#> 76      Q4  h03 0.04166667
#> 77      Q4  h04 0.04166667
#> 78      Q4  h05 0.04166667
#> 79      Q4  h06 0.04166667
#> 80      Q4  h07 0.04166667
#> 81      Q4  h08 0.04166667
#> 82      Q4  h09 0.04166667
#> 83      Q4  h10 0.04166667
#> 84      Q4  h11 0.04166667
#> 85      Q4  h12 0.04166667
#> 86      Q4  h13 0.04166667
#> 87      Q4  h14 0.04166667
#> 88      Q4  h15 0.04166667
#> 89      Q4  h16 0.04166667
#> 90      Q4  h17 0.04166667
#> 91      Q4  h18 0.04166667
#> 92      Q4  h19 0.04166667
#> 93      Q4  h20 0.04166667
#> 94      Q4  h21 0.04166667
#> 95      Q4  h22 0.04166667
#> 96      Q4  h23 0.04166667
```
