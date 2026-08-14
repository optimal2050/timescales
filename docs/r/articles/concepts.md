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
#>  [1] "YEAR"     "QUARTER"  "MONTH"    "MDAY"     "YDAY"     "HOUR"    
#>  [7] "MINUTE"   "SECOND"   "WDAY"     "WHOUR"    "MWEEK"    "WEEK"    
#> [13] "SEASON"   "DAYTYPE"  "HOURTYPE"
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
#>  [1] "d360"  "d364"  "d365"  "d366"  "h168"  "h24"   "hp3"   "m12"   "m12a" 
#> [10] "min60" "q4"    "s4"    "w52"   "w53"   "wd7"   "wk2"
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

| Token  | Timeframe | Labels       | Notes                             |
|--------|-----------|--------------|-----------------------------------|
| `d365` | YDAY      | `d001..d365` | day-of-year; aligns `drop_feb29`  |
| `d360` | YDAY      | `d001..d360` | stylised year; aligns `drop_last` |
| `m12`  | MONTH     | `m01..m12`   | numeric month                     |
| `m12a` | MONTH     | `JAN..DEC`   | abbreviated month                 |
| `q4`   | QUARTER   | `Q1..Q4`     | day-weighted shares               |
| `wd7`  | WDAY      | `MON..SUN`   | ISO weekday order                 |
| `h24`  | HOUR      | `h00..h23`   | hour-of-day                       |
| `h168` | WHOUR     | `h000..h167` | hour-of-week (Mon 00:00 = `h000`) |

Custom tokens are added with
[`register_token()`](https://optimal2050.github.io/timescales/r/reference/register_token.md),
optionally declaring an *alignment* rule (see below).

### Alignment: mapping real years onto stylised ones

A `d365` calendar has no label for Feb 29; a `d360` calendar has none
for the last days of December. *Alignment rules* (`ALIGNMENT_RULES`)
declare what happens to such instants: `drop_feb29` (Feb 29 is `NA`,
later ydays shift down so Dec 31 is still `d365`), `drop_last`,
`repeat_last` (clamp to the last label — how week 53 folds into `w52`),
and `exact` (error). Built-in tokens carry sensible defaults; calendars
record them in `meta$alignment`, and
[`instant_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/instant_to_timeslice.md)
accepts an override.

``` r

d365 <- calendar_build("d365")
instant_to_timeslice(as.Date(c("2020-02-29", "2020-12-31")), d365)
#> [1] NA     "d365"
```

## 3. Calendars

A **Calendar** is the actual product of one or more tokens. The leaves
of the resulting tree are the timeslices the rest of your model talks
about.

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
#>   QUARTER HOUR      share weight timeslice
#> 1      Q1  h00 0.01027397     90    Q1_h00
#> 2      Q2  h00 0.01038813     91    Q2_h00
#> 3      Q3  h00 0.01050228     92    Q3_h00
cat(nrow(cal@leaves), "leaves, share sums to", sum(cal@leaves$share))
#> 96 leaves, share sums to 1
```

## 4. Recasting between calendars

Conversion is the central verb. The same
[`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md)
function handles upsampling, downsampling, and irregular-to-irregular
mappings, given that both calendars cover the same year fraction.

``` r

cal_m <- calendar("m12")     # source: monthly
cal_q <- calendar("q4")      # target: quarterly

monthly <- data.frame(
  timeslice = cal_m@leaves$timeslice,
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

### Aggregation rules

Conversion routes through the **base grid** of real instants: source
values are projected *down* to instants, then aggregated *up* to target
timeslices, so aggregation and disaggregation are one operation
(`RECAST_RULES`):

| Rule | Down (timeslice → instants) | Up (instants → timeslice) |
|----|----|----|
| `weighted_mean` | copy | mean weighted by declared `share` (default) |
| `sum` | split across grid instants | sum — **totals are conserved** |
| `mean` | copy | plain (time-weighted) mean |
| `copy` | copy | the common value; error if not constant |
| `sd` | copy | spread of the fine signal |

`weighted_mean` and `mean` differ exactly when a calendar’s declared
shares differ from its real-time coverage. Per-parameter defaults can be
registered with
[`register_rule()`](https://optimal2050.github.io/timescales/r/reference/register_rule.md),
and a pairwise calendar-to-calendar override with
[`register_conversion()`](https://optimal2050.github.io/timescales/r/reference/register_conversion.md).
Instants not covered by one of the calendars are governed by
`na_action = "drop"` (warns), `"error"`, or `"keep"` (an explicit `NA`
row that conserves totals).

### Within-calendar aggregation and the ANNUAL root

Every calendar has an implicit whole-year root named `ANNUAL`.
[`prune_calendar()`](https://optimal2050.github.io/timescales/r/reference/prune_calendar.md)
truncates a calendar at one of its own timeframes, and
[`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md)
accepts a timeframe name for `to=`:

``` r

cal <- calendar("q4_h24")
x <- data.frame(timeslice = cal@leaves$timeslice, energy = 1)
recast_calendar(x, cal, to = "ANNUAL", year = 2025, rule = "sum")
#>   timeslice energy
#> 1    ANNUAL     96
```

## Design boundaries

- **Year-bounded calendars, multi-year base.** A calendar describes one
  model year (or a fraction of one); the base instant grid
  ([`base_calendar()`](https://optimal2050.github.io/timescales/r/reference/base_calendar.md))
  spans real multi-year time, which is how leap years stay
  representable. Multi-year horizons remain a future layer.
- **Label-stable.** A calendar’s timeslice IDs and ordering are fixed at
  construction time. Conversions never mutate them.
- **Explicit registries only.** Constructors return values; the token,
  rule, and conversion registries change behaviour only when you
  register into them.
