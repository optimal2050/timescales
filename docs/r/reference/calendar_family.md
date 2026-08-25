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
#> 2           QUARTER     Q2            HOUR   h00
#> 3           QUARTER     Q3            HOUR   h00
#> 4           QUARTER     Q4            HOUR   h00
#> 5           QUARTER     Q1            HOUR   h01
#> 6           QUARTER     Q2            HOUR   h01
#> 7           QUARTER     Q3            HOUR   h01
#> 8           QUARTER     Q4            HOUR   h01
#> 9           QUARTER     Q1            HOUR   h02
#> 10          QUARTER     Q2            HOUR   h02
#> 11          QUARTER     Q3            HOUR   h02
#> 12          QUARTER     Q4            HOUR   h02
#> 13          QUARTER     Q1            HOUR   h03
#> 14          QUARTER     Q2            HOUR   h03
#> 15          QUARTER     Q3            HOUR   h03
#> 16          QUARTER     Q4            HOUR   h03
#> 17          QUARTER     Q1            HOUR   h04
#> 18          QUARTER     Q2            HOUR   h04
#> 19          QUARTER     Q3            HOUR   h04
#> 20          QUARTER     Q4            HOUR   h04
#> 21          QUARTER     Q1            HOUR   h05
#> 22          QUARTER     Q2            HOUR   h05
#> 23          QUARTER     Q3            HOUR   h05
#> 24          QUARTER     Q4            HOUR   h05
#> 25          QUARTER     Q1            HOUR   h06
#> 26          QUARTER     Q2            HOUR   h06
#> 27          QUARTER     Q3            HOUR   h06
#> 28          QUARTER     Q4            HOUR   h06
#> 29          QUARTER     Q1            HOUR   h07
#> 30          QUARTER     Q2            HOUR   h07
#> 31          QUARTER     Q3            HOUR   h07
#> 32          QUARTER     Q4            HOUR   h07
#> 33          QUARTER     Q1            HOUR   h08
#> 34          QUARTER     Q2            HOUR   h08
#> 35          QUARTER     Q3            HOUR   h08
#> 36          QUARTER     Q4            HOUR   h08
#> 37          QUARTER     Q1            HOUR   h09
#> 38          QUARTER     Q2            HOUR   h09
#> 39          QUARTER     Q3            HOUR   h09
#> 40          QUARTER     Q4            HOUR   h09
#> 41          QUARTER     Q1            HOUR   h10
#> 42          QUARTER     Q2            HOUR   h10
#> 43          QUARTER     Q3            HOUR   h10
#> 44          QUARTER     Q4            HOUR   h10
#> 45          QUARTER     Q1            HOUR   h11
#> 46          QUARTER     Q2            HOUR   h11
#> 47          QUARTER     Q3            HOUR   h11
#> 48          QUARTER     Q4            HOUR   h11
#> 49          QUARTER     Q1            HOUR   h12
#> 50          QUARTER     Q2            HOUR   h12
#> 51          QUARTER     Q3            HOUR   h12
#> 52          QUARTER     Q4            HOUR   h12
#> 53          QUARTER     Q1            HOUR   h13
#> 54          QUARTER     Q2            HOUR   h13
#> 55          QUARTER     Q3            HOUR   h13
#> 56          QUARTER     Q4            HOUR   h13
#> 57          QUARTER     Q1            HOUR   h14
#> 58          QUARTER     Q2            HOUR   h14
#> 59          QUARTER     Q3            HOUR   h14
#> 60          QUARTER     Q4            HOUR   h14
#> 61          QUARTER     Q1            HOUR   h15
#> 62          QUARTER     Q2            HOUR   h15
#> 63          QUARTER     Q3            HOUR   h15
#> 64          QUARTER     Q4            HOUR   h15
#> 65          QUARTER     Q1            HOUR   h16
#> 66          QUARTER     Q2            HOUR   h16
#> 67          QUARTER     Q3            HOUR   h16
#> 68          QUARTER     Q4            HOUR   h16
#> 69          QUARTER     Q1            HOUR   h17
#> 70          QUARTER     Q2            HOUR   h17
#> 71          QUARTER     Q3            HOUR   h17
#> 72          QUARTER     Q4            HOUR   h17
#> 73          QUARTER     Q1            HOUR   h18
#> 74          QUARTER     Q2            HOUR   h18
#> 75          QUARTER     Q3            HOUR   h18
#> 76          QUARTER     Q4            HOUR   h18
#> 77          QUARTER     Q1            HOUR   h19
#> 78          QUARTER     Q2            HOUR   h19
#> 79          QUARTER     Q3            HOUR   h19
#> 80          QUARTER     Q4            HOUR   h19
#> 81          QUARTER     Q1            HOUR   h20
#> 82          QUARTER     Q2            HOUR   h20
#> 83          QUARTER     Q3            HOUR   h20
#> 84          QUARTER     Q4            HOUR   h20
#> 85          QUARTER     Q1            HOUR   h21
#> 86          QUARTER     Q2            HOUR   h21
#> 87          QUARTER     Q3            HOUR   h21
#> 88          QUARTER     Q4            HOUR   h21
#> 89          QUARTER     Q1            HOUR   h22
#> 90          QUARTER     Q2            HOUR   h22
#> 91          QUARTER     Q3            HOUR   h22
#> 92          QUARTER     Q4            HOUR   h22
#> 93          QUARTER     Q1            HOUR   h23
#> 94          QUARTER     Q2            HOUR   h23
#> 95          QUARTER     Q3            HOUR   h23
#> 96          QUARTER     Q4            HOUR   h23
```
