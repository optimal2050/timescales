# Concepts

## Three layers of abstraction

`timescales` is built around three concentric ideas. Working out from
the centre:

1.  **Timeframes** — the atomic vocabulary (`YEAR`, `MONTH`, `HOUR`, …).
2.  **Tokens** — named recipes for the labels at one timeframe
    (e.g. `m12` = `m01..m12`, `m12a` = `JAN..DEC`).
3.  **Calendars** — the actual partition of a year into labelled leaves,
    formed by composing tokens.

Most users only ever touch layer 3.

## 1. Timeframes

A *timeframe* is a unit of time at which a calendar can carry labels.
The package ships with a fixed core set:

``` r

CORE_TIMEFRAMES
#>  [1] "YEAR"    "QUARTER" "MONTH"   "MDAY"    "YDAY"    "HOUR"    "MINUTE" 
#>  [8] "SECOND"  "WDAY"    "MWEEK"   "WEEK"
```

The function
[`as_timeframe()`](https://optimal2050.github.io/timescales/r/reference/as_timeframe.md)
extracts the value of a chosen timeframe from any datetime:

``` r

t <- as.POSIXct("2025-04-15 13:45", tz = "UTC")
as_timeframe(t, "MONTH")
#> [1] 4
as_timeframe(t, "MONTH", format = "token")
#> [1] "m04"
as_timeframe(t, "HOUR")
#> [1] 13
as_timeframe(t, "WDAY", format = "token")
#> [1] "TUE"
```

`format = "token"` returns the same label style that the built-in tokens
use, which is what the calendar machinery needs internally.

## 2. Tokens

A *token* is a named, reusable recipe for the labels of one timeframe,
plus each label’s within-year share. Tokens are how vocabularies are
shared across calendars.

``` r

list_tokens()
#>  [1] "d360"  "d364"  "d365"  "d366"  "h168"  "h24"   "m12"   "m12a"  "min60"
#> [10] "q4"    "w52"   "w53"   "wd7"
get_token("m12")$expand() |> head(3)
#>   label      share
#> 1   m01 0.08493151
#> 2   m02 0.07671233
#> 3   m03 0.08493151
get_token("h24")$expand() |> head(3)
#>   label      share
#> 1   h00 0.04166667
#> 2   h01 0.04166667
#> 3   h02 0.04166667
```

A few built-ins:

| Token  | Timeframe | Labels       | Notes                         |
|--------|-----------|--------------|-------------------------------|
| `d365` | YDAY      | `d001..d365` | day-of-year, 365-day calendar |
| `m12`  | MONTH     | `m01..m12`   | numeric month                 |
| `m12a` | MONTH     | `JAN..DEC`   | abbreviated month             |
| `q4`   | QUARTER   | `Q1..Q4`     | day-weighted shares           |
| `wd7`  | WDAY      | `MON..SUN`   | ISO weekday order             |
| `h24`  | HOUR      | `h00..h23`   | hour-of-day                   |
| `h168` | HOUR      | `h000..h167` | hour-of-week                  |

Custom tokens are added with
[`register_token()`](https://optimal2050.github.io/timescales/r/reference/register_token.md).

## 3. Calendars

A **Calendar** is the actual product of one or more tokens. The leaves
of the resulting tree are the slices the rest of your model talks about.

Three constructors, in increasing flexibility:

``` r

calendar("m12_h24")                    # layer 1: by name
calendar_build("m12", "h24")           # layer 2: by token list
calendar_from_leaves(leaves, ...)      # layer 3: by raw leaf table
```

The first two compose tokens with a Cartesian product; share is the
product of per-token shares scaled to `year_fraction`. The third is the
escape hatch for irregular calendars (e.g. representative weeks that
intentionally do not cover the full year).

### What the leaves table looks like

``` r

cal <- calendar("q4_h24")
head(cal@leaves, 3)
#>   QUARTER HOUR      share weight  slice
#> 1      Q1  h00 0.01027397     90 Q1_h00
#> 2      Q2  h00 0.01038813     91 Q2_h00
#> 3      Q3  h00 0.01050228     92 Q3_h00
cat(nrow(cal@leaves), "leaves, share sums to", sum(cal@leaves$share))
#> 96 leaves, share sums to 1
```

## 4. Recasting between calendars

Conversion is the central verb. The same
[`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md)
function handles upsampling, downsampling, and irregular-to-irregular
mappings, given that both calendars cover the same year fraction.

``` r

cal_m <- calendar("m12")     # source: monthly
cal_q <- calendar("q4")      # target: quarterly

monthly <- data.frame(
  slice = cal_m@leaves$slice,
  load  = c(120, 118, 105,  92,  85,  88,  95, 100,  98,  90, 105, 122)
)

recast(monthly, from = cal_m, to = cal_q, year = 2025,
       rule = "weighted_mean", by = "day")
#>   slice      load
#> 1    Q1 114.21111
#> 2    Q2  88.29670
#> 3    Q3  97.66304
#> 4    Q4 105.67391
```

### Aggregation rules

| Rule            | Meaning                                       |
|-----------------|-----------------------------------------------|
| `weighted_mean` | Average weighted by leaf share (the default). |
| `mean`          | Plain mean over the shared expansion grid.    |
| `sum`           | Sum over the shared expansion grid.           |

On a uniform grid `weighted_mean` and `mean` coincide because longer
source slices contribute proportionally more rows.

## Design boundaries

- **Year-bounded.** A calendar describes one year (or a fraction of
  one). Multi-year horizons are out of scope for v0.1; build them on top
  of this layer.
- **Label-stable.** A calendar’s slice IDs and ordering are fixed at
  construction time. Conversions never mutate them.
- **No side effects.** Every constructor returns a value; nothing is
  registered or globally configured.
