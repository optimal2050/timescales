# Calendar hierarchy queries

Read-only queries on the timeframe hierarchy of a
[Calendar](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
— the time-side mirror of
[`geoscales::geoscale_geoframes()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geoframes.html)
and friends.

## Usage

``` r
# S3 method for class 'Calendar'
names(x)

calendar_timeframes(x, finest = FALSE)

calendar_rank(x, timeframe)

calendar_timeslices(x, timeframe = NULL, qualified = FALSE)
```

## Arguments

- x:

  A
  [Calendar](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

- finest:

  `calendar_timeframes()` only: return just the finest timeframe (the
  atom layer) instead of the full ordered vector — the twin of
  `geoscales::geoscale_geoframes(x, finest = TRUE)`.

- timeframe:

  A timeframe name (see `calendar_timeframes()`).

- qualified:

  `calendar_timeslices()` only: return the qualified node IDs at
  `timeframe` – the leaf IDs of `prune_calendar(calendar, timeframe)` –
  instead of the bare member labels. This is the per-frame node view the
  energyRt bridge consumes.

## Value

`calendar_timeframes()` and `calendar_timeslices()` return a character
vector; `calendar_rank()` an integer.

## Details

- `calendar_timeframes()` — hierarchy names, coarsest first.

- `calendar_rank()` — position of a timeframe (1 = coarsest); `NA` for
  unknown names.

- `calendar_timeslices()` — with a `timeframe`, the canonical ordered
  labels at that level; without, the leaf `timeslice` ids.

- [`names()`](https://rdrr.io/r/base/names.html) on a Calendar returns
  the timeframe names (identical to `calendar_timeframes()`), NOT the
  leaftable column names.

## Examples

``` r
cal <- calendar("q4_h24")
calendar_timeframes(cal)
#> [1] "QUARTER" "HOUR"   
calendar_rank(cal, "HOUR")
#> [1] 2
calendar_timeslices(cal, "QUARTER")
#> [1] "Q1" "Q2" "Q3" "Q4"
```
