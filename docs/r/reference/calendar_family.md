# Immediate parent-child pairs of a Calendar hierarchy

One row per observed (parent label, child label) pair between each
consecutive timeframe pair — the time-side mirror of
[`geoscales::geoscale_family()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_family.html).

## Usage

``` r
calendar_family(x, parent = NULL, child = NULL)
```

## Arguments

- x:

  A
  [Calendar](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- parent, child:

  Optional timeframe names restricting the output to one hierarchy step.

## Value

`data.frame(parent_timeframe, parent, child_timeframe, child)`.

## Examples

``` r
calendar_family(calendar("q4_h24"))
#>    parent_timeframe parent child_timeframe child
#> 1           QUARTER     Q1            HOUR   h00
#> 2           QUARTER     Q1            HOUR   h01
#> 3           QUARTER     Q1            HOUR   h02
#> 4           QUARTER     Q1            HOUR   h03
#> 5           QUARTER     Q1            HOUR   h04
#> 6           QUARTER     Q1            HOUR   h05
#> 7           QUARTER     Q1            HOUR   h06
#> 8           QUARTER     Q1            HOUR   h07
#> 9           QUARTER     Q1            HOUR   h08
#> 10          QUARTER     Q1            HOUR   h09
#> 11          QUARTER     Q1            HOUR   h10
#> 12          QUARTER     Q1            HOUR   h11
#> 13          QUARTER     Q1            HOUR   h12
#> 14          QUARTER     Q1            HOUR   h13
#> 15          QUARTER     Q1            HOUR   h14
#> 16          QUARTER     Q1            HOUR   h15
#> 17          QUARTER     Q1            HOUR   h16
#> 18          QUARTER     Q1            HOUR   h17
#> 19          QUARTER     Q1            HOUR   h18
#> 20          QUARTER     Q1            HOUR   h19
#> 21          QUARTER     Q1            HOUR   h20
#> 22          QUARTER     Q1            HOUR   h21
#> 23          QUARTER     Q1            HOUR   h22
#> 24          QUARTER     Q1            HOUR   h23
#> 25          QUARTER     Q2            HOUR   h00
#> 26          QUARTER     Q2            HOUR   h01
#> 27          QUARTER     Q2            HOUR   h02
#> 28          QUARTER     Q2            HOUR   h03
#> 29          QUARTER     Q2            HOUR   h04
#> 30          QUARTER     Q2            HOUR   h05
#> 31          QUARTER     Q2            HOUR   h06
#> 32          QUARTER     Q2            HOUR   h07
#> 33          QUARTER     Q2            HOUR   h08
#> 34          QUARTER     Q2            HOUR   h09
#> 35          QUARTER     Q2            HOUR   h10
#> 36          QUARTER     Q2            HOUR   h11
#> 37          QUARTER     Q2            HOUR   h12
#> 38          QUARTER     Q2            HOUR   h13
#> 39          QUARTER     Q2            HOUR   h14
#> 40          QUARTER     Q2            HOUR   h15
#> 41          QUARTER     Q2            HOUR   h16
#> 42          QUARTER     Q2            HOUR   h17
#> 43          QUARTER     Q2            HOUR   h18
#> 44          QUARTER     Q2            HOUR   h19
#> 45          QUARTER     Q2            HOUR   h20
#> 46          QUARTER     Q2            HOUR   h21
#> 47          QUARTER     Q2            HOUR   h22
#> 48          QUARTER     Q2            HOUR   h23
#> 49          QUARTER     Q3            HOUR   h00
#> 50          QUARTER     Q3            HOUR   h01
#> 51          QUARTER     Q3            HOUR   h02
#> 52          QUARTER     Q3            HOUR   h03
#> 53          QUARTER     Q3            HOUR   h04
#> 54          QUARTER     Q3            HOUR   h05
#> 55          QUARTER     Q3            HOUR   h06
#> 56          QUARTER     Q3            HOUR   h07
#> 57          QUARTER     Q3            HOUR   h08
#> 58          QUARTER     Q3            HOUR   h09
#> 59          QUARTER     Q3            HOUR   h10
#> 60          QUARTER     Q3            HOUR   h11
#> 61          QUARTER     Q3            HOUR   h12
#> 62          QUARTER     Q3            HOUR   h13
#> 63          QUARTER     Q3            HOUR   h14
#> 64          QUARTER     Q3            HOUR   h15
#> 65          QUARTER     Q3            HOUR   h16
#> 66          QUARTER     Q3            HOUR   h17
#> 67          QUARTER     Q3            HOUR   h18
#> 68          QUARTER     Q3            HOUR   h19
#> 69          QUARTER     Q3            HOUR   h20
#> 70          QUARTER     Q3            HOUR   h21
#> 71          QUARTER     Q3            HOUR   h22
#> 72          QUARTER     Q3            HOUR   h23
#> 73          QUARTER     Q4            HOUR   h00
#> 74          QUARTER     Q4            HOUR   h01
#> 75          QUARTER     Q4            HOUR   h02
#> 76          QUARTER     Q4            HOUR   h03
#> 77          QUARTER     Q4            HOUR   h04
#> 78          QUARTER     Q4            HOUR   h05
#> 79          QUARTER     Q4            HOUR   h06
#> 80          QUARTER     Q4            HOUR   h07
#> 81          QUARTER     Q4            HOUR   h08
#> 82          QUARTER     Q4            HOUR   h09
#> 83          QUARTER     Q4            HOUR   h10
#> 84          QUARTER     Q4            HOUR   h11
#> 85          QUARTER     Q4            HOUR   h12
#> 86          QUARTER     Q4            HOUR   h13
#> 87          QUARTER     Q4            HOUR   h14
#> 88          QUARTER     Q4            HOUR   h15
#> 89          QUARTER     Q4            HOUR   h16
#> 90          QUARTER     Q4            HOUR   h17
#> 91          QUARTER     Q4            HOUR   h18
#> 92          QUARTER     Q4            HOUR   h19
#> 93          QUARTER     Q4            HOUR   h20
#> 94          QUARTER     Q4            HOUR   h21
#> 95          QUARTER     Q4            HOUR   h22
#> 96          QUARTER     Q4            HOUR   h23
```
