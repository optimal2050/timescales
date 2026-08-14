# Getting started with timescales

## What problem does this solve?

Energy-system, climate, and operations models all carve the year into
discrete *time timeslices*. Different models pick different slicings:
365 days, 12 months, 4 quarters × 24 hours, 168 hours of a
representative week, and so on. The timeslice **labels** are arbitrary,
the **shares of a year** are model-defined, and converting data between
slicings is error-prone.

`timescales` represents any such slicing as a **Calendar**: an ordered
hierarchy of *timeframes* (`YEAR`, `MONTH`, `HOUR`, …) whose terminal
*leaves* form the timeslices. With one object you get:

- a stable schema for the timeslice labels and their year-share weights,
- well-defined mappings to and from real datetimes,
- well-defined conversions between any two calendars covering the same
  year fraction.

## A 5-minute tour

### 1. Build a calendar

The fastest path uses **token-based names**:

``` r

cal_my <- calendar("m12_h24")    # 12 months × 24 hours = 288 leaves
cal_my
#> Calendar: m12_h24 
#> Timeframes (2):
#>   - MONTH (12) [token: m12]
#>   - HOUR (24) [token: h24]
#> Leaf timeslices: 288
#> year_fraction: 1
#> year_start: month=1, day=1
#> utc_offset_minutes: 0
```

Equivalent declarative form:

``` r

cal_my2 <- calendar_build("m12", "h24")
identical(cal_my@timeframes, cal_my2@timeframes)
#> [1] TRUE
```

For full control there is the lowest-level constructor
[`calendar_from_leaves()`](https://optimal2050.github.io/timescales/r/reference/calendar_from_leaves.md),
where you supply the leaves table directly.

### 2. Inspect the structure

A `Calendar` has four parts:

``` r

cal_my@timeframes               # the timeframe hierarchy, coarsest first
#> [1] "MONTH" "HOUR"
head(cal_my@leaves, 4)          # the leaf table (one row per timeslice)
#>   MONTH HOUR       share weight timeslice
#> 1   m01  h00 0.003538813     31   m01_h00
#> 2   m02  h00 0.003196347     28   m02_h00
#> 3   m03  h00 0.003538813     31   m03_h00
#> 4   m04  h00 0.003424658     30   m04_h00
cal_my@levels$MONTH             # ordered label vocabulary per timeframe
#>  [1] "m01" "m02" "m03" "m04" "m05" "m06" "m07" "m08" "m09" "m10" "m11" "m12"
cal_my@meta[c("name", "year_fraction")]
#> $name
#> [1] "m12_h24"
#> 
#> $year_fraction
#> [1] 1
```

`leaves` is a plain `data.frame`. Each row is one timeslice, with
columns:

- `timeslice` — the unique timeslice ID,
- `share` — fraction of a year,
- `weight` — timeslice weight in hours (default `share * 8760`),
- one column per timeframe — the label at that level.

### 3. Map real datetimes onto the calendar

``` r

times <- as.POSIXct(c("2025-01-15 03:00", "2025-07-20 18:00"), tz = "UTC")
instant_to_timeslice(times, cal_my)
#> [1] "m01_h03" "m07_h18"
```

### 4. Convert data between calendars

Suppose you have monthly load values and need quarterly averages:

``` r

cal_m <- calendar("m12")
cal_q <- calendar("q4")

monthly <- data.frame(
  timeslice = sprintf("m%02d", 1:12),
  load  = c(120, 118, 105,  92,  85,  88,  95, 100,  98,  90, 105, 122)
)

recast_calendar(monthly, from = cal_m, to = cal_q, year = 2025,
       rule = "weighted_mean", by = "day")
#>   timeslice      load
#> 1        Q1 114.21111
#> 2        Q2  88.29670
#> 3        Q3  97.66304
#> 4        Q4 105.67391
```

The result is day-weighted: Q1 = (31·v₁ + 28·v₂ + 31·v₃) / 90.

## Where to next?

- [Concepts](https://optimal2050.github.io/timescales/r/articles/concepts.md)
  — the core ideas behind calendars and timeframes.
- [Data
  structures](https://optimal2050.github.io/timescales/r/articles/data-structures.md)
  — anatomy of a `Calendar` object and its supporting registries.
