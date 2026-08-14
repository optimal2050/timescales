# Build a Calendar from token names

Declarative constructor: name the timeframe vocabulary tokens in
coarsest- to-finest order. The Cartesian product of their labels becomes
the leaf table; each leaf's share is the product of its tokens' shares,
scaled to `year_fraction`.

Convenience shortcut. Names listed in
[`calendar_catalog()`](https://optimal2050.github.io/timescales/r/reference/calendar_catalog.md)
build the catalog design (with `coverage`/`regularity` metadata
attached; the `m12_md*` family uses a dedicated ragged month/day
builder). Any other name is parsed as `_`-joined tokens and dispatched
to `calendar_build()`. The leading `y_` prefix (year-qualified) is
currently stripped and recorded in `meta$year_qualified` — full
year-prefix semantics arrive in a later phase.

## Usage

``` r
calendar_build(
  ...,
  name = NULL,
  desc = "",
  year_start = list(month = 1L, day = 1L),
  utc_offset_minutes = 0L,
  year_fraction = 1
)

calendar(name, ...)
```

## Arguments

- ...:

  Passed through to `calendar_build()` (`year_start`,
  `utc_offset_minutes`, `year_fraction`, `desc`).

- name:

  Character scalar — a token-style calendar name (`"d365"`,
  `"d365_h24"`, `"m12_h24"`, `"q4_h24"`, ...).

- desc:

  Free-text description.

- year_start:

  `list(month = , day = )`; defaults to January 1.

- utc_offset_minutes:

  Integer minutes; defaults to 0.

- year_fraction:

  Year fraction covered. Defaults to 1.

## Value

A
[`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

A
[`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md).

## Examples

``` r
cal <- calendar_build("d365", "h24", name = "d365_h24")
cal
#> Calendar: d365_h24 
#> Timeframes (2):
#>   - YDAY (365) [token: d365, alignment: drop_feb29]
#>   - HOUR (24) [token: h24]
#> Leaf timeslices: 8760
#> year_fraction: 1
#> year_start: month=1, day=1
#> utc_offset_minutes: 0

cal2 <- calendar_build("m12", "h24")
cal2
#> Calendar: m12_h24 
#> Timeframes (2):
#>   - MONTH (12) [token: m12]
#>   - HOUR (24) [token: h24]
#> Leaf timeslices: 288
#> year_fraction: 1
#> year_start: month=1, day=1
#> utc_offset_minutes: 0
calendar("d365_h24")
#> Calendar: d365_h24 
#> Timeframes (2):
#>   - YDAY (365) [token: d365, alignment: drop_feb29]
#>   - HOUR (24) [token: h24]
#> Leaf timeslices: 8760
#> year_fraction: 1
#> year_start: month=1, day=1
#> utc_offset_minutes: 0
calendar("m12_h24")
#> Calendar: m12_h24 
#> Timeframes (2):
#>   - MONTH (12) [token: m12]
#>   - HOUR (24) [token: h24]
#> Leaf timeslices: 288
#> year_fraction: 1
#> year_start: month=1, day=1
#> utc_offset_minutes: 0
```
