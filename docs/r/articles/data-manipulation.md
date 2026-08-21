# Data manipulation with calendars

## The toolkit at a glance

| verb | direction | what it does |
|----|----|----|
| [`datetime_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/datetime_to_timeslice.md) | datetimes → labels | cut a datetime vector to a calendar’s timeslice IDs |
| [`expand_calendar()`](https://optimal2050.github.io/timescales/r/reference/expand_calendar.md) | calendar → grid | enumerate the base datetime grid of a model year |
| [`join_calendar()`](https://optimal2050.github.io/timescales/r/reference/join_calendar.md) | calendar → columns | *attach* labels, timeframe columns, share/weight to a table (no aggregation) |
| [`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md) | calendar A → calendar B | *convert* values between two resolutions, one rule per column |
| [`recast_to_timebase()`](https://optimal2050.github.io/timescales/r/reference/recast_to_timebase.md) / [`recast_from_timebase()`](https://optimal2050.github.io/timescales/r/reference/recast_to_timebase.md) | the route halves | project down to the base grid / aggregate up from it |
| [`calendar_map()`](https://optimal2050.github.io/timescales/r/reference/calendar_map.md) | A → B crosswalk | the conversion, materialised as a small table |
| [`register_rule()`](https://optimal2050.github.io/timescales/r/reference/register_rule.md) / [`register_calendar_map()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_map.md) / [`register_conversion()`](https://optimal2050.github.io/timescales/r/reference/register_conversion.md) | registries | per-column rules, exact crosswalks, functional overrides |

Everything below runs on the shipped `merra2_cities` sample (three
cities × 8,760 hours of 2019) in tidyverse style — data flows through
`|>`, and every verb accepts a `data.frame`, tibble, `data.table`,
dtplyr, or arrow input (see [Backends](#backends)).

## From datetimes to timeslices

[`datetime_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/datetime_to_timeslice.md)
is the entry point: it applies the calendar’s alignment rules and
returns the timeslice ID each instant falls in (instants the calendar
does not cover come back `NA`):

``` r

cal <- calendars$m12_h24

merra2_cities |>
  mutate(timeslice = datetime_to_timeslice(datetime, cal)) |>
  select(city, datetime, timeslice, T10M) |>
  head(3)
#>       city            datetime timeslice T10M
#> 1 Helsinki 2019-01-01 00:30:00   m01_h00    1
#> 2 Helsinki 2019-01-01 01:30:00   m01_h01    2
#> 3 Helsinki 2019-01-01 02:30:00   m01_h02    2
```

The inverse view is
[`expand_calendar()`](https://optimal2050.github.io/timescales/r/reference/expand_calendar.md):
one row per base-grid point of a model year, with the timeslice that
point belongs to — the year-aware, leap-aware grid every conversion
routes through:

``` r

expand_calendar(calendars$m12, year = 2020, by = "day") |> head(3)
#>     datetime year timeslice
#> 1 2020-01-01 2020       m01
#> 2 2020-01-02 2020       m01
#> 3 2020-01-03 2020       m01
```

## Attaching a calendar to a table

[`join_calendar()`](https://optimal2050.github.io/timescales/r/reference/join_calendar.md)
*decorates* rather than converts: it adds a label column **named after
the calendar**, plus optional timeframe columns and share/weight, all
`"<name>."`-prefixed. Keys are auto-detected — a column named like the
calendar, else `timeslice`, else a `datetime` column (labels then
computed on the base grid):

``` r

panel <- merra2_cities |>
  mutate(timeslice = datetime_to_timeslice(datetime, cal)) |>
  summarise(across(c(T10M, SWGDN), mean), .by = c(city, timeslice))

panel |>
  join_calendar(cal, timeframes = TRUE, meta = TRUE) |>
  head(3)
#>       city timeslice      T10M SWGDN m12_h24 m12_h24.MONTH m12_h24.HOUR
#> 1 Helsinki   m01_h00 -3.548387     0 m01_h00           m01          h00
#> 2 Helsinki   m01_h01 -3.419355     0 m01_h01           m01          h01
#> 3 Helsinki   m01_h02 -3.387097     0 m01_h02           m01          h02
#>   m12_h24.share m12_h24.weight
#> 1   0.003538813             31
#> 2   0.003538813             31
#> 3   0.003538813             31
```

Because every calendar attaches under its own name, several can coexist
on one dataset — and a table carrying two label columns is itself an
empirical crosswalk between those calendars:

``` r

two <- merra2_cities |>
  filter(city == "Helsinki") |>
  join_calendar(calendars$m12_h24) |>
  join_calendar(calendars$q4_hp3)
two |> select(datetime, m12_h24, q4_hp3) |> head(3)
#>              datetime m12_h24 q4_hp3
#> 1 2019-01-01 00:30:00    <NA>   <NA>
#> 2 2019-01-01 01:30:00    <NA>   <NA>
#> 3 2019-01-01 02:30:00    <NA>   <NA>
```

Existing columns are never overwritten — a clashing attach errors
instead.

## Recasting between calendars

[`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md)
converts values from one calendar to another — aggregation and
disaggregation are the same operation, routed `A -> base -> B` through
the shared grid. Three things to know:

**1. One rule per value column, and the rule is mandatory.** Pass
`rule=` for all columns, or register per-column rules once; a column
with neither errors — a silently guessed rule is a silent unit error.

``` r

register_rule("T10M",  "weighted_mean")   # intensive: temperature
register_rule("SWGDN", "sum")             # extensive proxy: energy

q <- panel |>
  recast_calendar(cal, calendars$q4, year = 2019)
head(q, 4)
#>   timeslice     city      T10M     SWGDN
#> 1        Q1 Helsinki -1.387963  3191.963
#> 2        Q2 Helsinki 10.229396 16930.799
#> 3        Q3 Helsinki 15.808877 14194.829
#> 4        Q4 Helsinki  4.458333  1755.423
```

| rule            | meaning                                        |
|-----------------|------------------------------------------------|
| `sum`           | conserve totals (split down, sum up)           |
| `weighted_mean` | share-weighted mean (declared `share`s)        |
| `mean`          | plain time-weighted mean over grid points      |
| `copy`          | constant within the target, error otherwise    |
| `sd`            | dispersion over grid points (aggregation only) |

**2. Identifier columns ride along.** Columns that are neither the key
nor values (here `city`) are grouping columns, so panel data converts in
one call — and totals conserve *per group*:

``` r

annual <- panel |>
  select(city, timeslice, SWGDN) |>
  recast_calendar(cal, to = "ANNUAL", year = 2019)
annual
#>   timeslice     city    SWGDN
#> 1    ANNUAL Helsinki 36073.01
#> 2    ANNUAL     Lima 77294.96
#> 3    ANNUAL   Sydney 63287.80

# the same totals, straight from the panel:
panel |> summarise(SWGDN = sum(SWGDN), .by = city)
#>       city    SWGDN
#> 1 Helsinki 36073.01
#> 2     Lima 77294.96
#> 3   Sydney 63287.80
```

(`to =` also accepts a timeframe name of the source calendar — the
within-calendar aggregation shortcut, `"ANNUAL"` being the root.)

**3. Coverage is explicit.** Grid points the target does not cover are
dropped with a warning by default; `na_action = "keep"` retains them as
an explicit `NA`-timeslice row so totals conserve, and
`na_action = "error"` refuses. Materialised results always return the
FULL target vocabulary (with `NA` where nothing landed), so downstream
joins see a stable schema.

## The route halves

[`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md)
is the fused route; its halves are public.
[`recast_to_timebase()`](https://optimal2050.github.io/timescales/r/reference/recast_to_timebase.md)
projects timeslice data DOWN to the base grid (extensive columns split
so totals conserve; a `weight` column carries the source shares), and
[`recast_from_timebase()`](https://optimal2050.github.io/timescales/r/reference/recast_to_timebase.md)
aggregates datetime-keyed rows UP into any calendar — their composition
is exactly
[`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md):

``` r

m <- data.frame(timeslice = sprintf("m%02d", 1:12), energy = 1:12)

g <- m |>
  recast_to_timebase(calendars$m12, year = 2019, rule = "sum", by = "day")
head(g, 2)
#>     datetime year     energy      weight
#> 1 2019-01-01 2019 0.03225806 0.002739726
#> 2 2019-01-02 2019 0.03225806 0.002739726
sum(g$energy)                      # 78 -- conserved on the grid
#> [1] 78

g |>
  recast_from_timebase(calendars$q4, rule = "sum", by = "day")
#>   timeslice year energy
#> 1        Q1 2019      6
#> 2        Q2 2019     15
#> 3        Q3 2019     24
#> 4        Q4 2019     33
```

Use the halves when you need to *do something on the grid* between the
two ends — join weather covariates by datetime, filter a season out,
resample — with conservation guarantees intact.

## The crosswalk, inspectable and overridable

Every recast is a join against a small crosswalk table — one row per
overlapping timeslice pair with grid counts and share weights.
[`calendar_map()`](https://optimal2050.github.io/timescales/r/reference/calendar_map.md)
exposes it:

``` r

calendar_map(calendars$m12, calendars$q4, year = 2019) |> head(4)
#>   year m12 q4 n_from n_overlap          w
#> 1 2019 m01 Q1     31        31 0.08493151
#> 2 2019 m02 Q1     28        28 0.07671233
#> 3 2019 m03 Q1     31        31 0.08493151
#> 4 2019 m04 Q2     30        30 0.08219178
```

When an exact correspondence is known (hand-audited concordances,
provably nested designs),
[`register_calendar_map()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_map.md)
short-circuits the grid derivation for that pair;
[`register_conversion()`](https://optimal2050.github.io/timescales/r/reference/register_conversion.md)
goes one step further and replaces the whole conversion with your
function. Both are keyed by calendar names, like the attach.

## Backends

The verbs above are single dplyr pipelines, so the SAME code runs over
an in-memory `data.frame`/tibble, a `data.table` (via dtplyr), or an
arrow Dataset/query. Eager inputs come back in their own class; lazy
inputs return the *uncollected query* unless `collect = TRUE`:

``` r

dt <- data.table::as.data.table(panel)

dt |>
  recast_calendar(cal, calendars$q4, year = 2019, rule = "sum") |>
  class()                          # data.table in, data.table out
#> [1] "data.table" "data.frame"

lazy <- dtplyr::lazy_dt(dt) |>
  recast_calendar(cal, calendars$q4, year = 2019, rule = "sum")
class(lazy)                        # the query, not the result
#> [1] "dtplyr_step_call" "dtplyr_step"
head(as.data.frame(dplyr::collect(lazy)), 3)
#>   timeslice     city       T10M     SWGDN
#> 1        Q1 Helsinki  -97.89516  3191.963
#> 2        Q2 Helsinki  737.25269 16930.799
#> 3        Q3 Helsinki 1136.03656 14194.829
```

Two contract details worth knowing for lazy sources (dtplyr, arrow):
results carry the *observed* target timeslices only — the
full-vocabulary completion happens on materialisation — and the calendar
side of every join is a small in-memory frame, so an on-disk arrow
dataset is never pulled into memory for the calendar arithmetic.

## Across dimensions

The bare
[`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md)
generic dispatches on the scale object, so one verb chains time and
space when the sibling package geoscales is loaded:

``` r

x |>
  recast(cal_hourly, cal_monthly, year = 2021, rule = "sum") |>
  recast(gs, to = "r32o11", rule = "sum")     # a geoscales Geoscale
```

Same contract on both sides: explicit rules (never a silent fallback),
identifier columns preserved, backends welcome.

## Where to next?

- [Concepts](https://optimal2050.github.io/timescales/r/articles/concepts.md)
  — why the route always goes through the base grid, and the shared
  \*scales naming lattice.
- [Calendar
  catalog](https://optimal2050.github.io/timescales/r/articles/calendars.md)
  — the 43 shipped designs, by family.
- [Visualization](https://optimal2050.github.io/timescales/r/articles/visualization.md)
  — the same pipelines flowing into ggplot2.
