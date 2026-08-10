# timescales (development version)

## `calendar_recast()`, panel data, and the naming convention

* **`recast()` is deprecated; the verb is now `calendar_recast()`.** The
  stack-wide convention reserves bare names for foreign generics
  (`plot`, `autoplot`, `print`) and prefixes owned operations by their
  object — `calendar_recast()` pairs with `geoscales::geo_recast()`, so
  mixed pipelines read
  `x |> calendar_recast(...) |> geo_recast(...)`. (Bare `recast` also
  risked masking against the retired reshape2; bare `filter`/`rank`/
  `expand`/`children` are outright collisions and will never be used.)
* **Behavior fix: identifier (panel) columns are preserved.** Previously
  a city x slice table silently returned only the first city's values;
  now non-key, non-value columns group the aggregation, keep their
  types, and pass through to the output — per group, the full target
  slice vocabulary is emitted.
* **Behavior fix: `values` auto-detection excludes `from`'s timeframe
  columns** (a joined `MONTH` column no longer gets swept into the
  values); numeric identifiers like `year` still need explicit
  exclusion.
* `key = NULL` default (resolving to `"slice"`), a warning for source
  keys unknown to the calendar, geoscales-style error messages via new
  internal `.stop()`/`.warn()`/`.preview()` helpers, and a validator
  guard rejecting reserved timeframe names (`slice`, `share`,
  `weight`).

## ggplot2 layers and weather sample

* **`calendar_join()`** attaches a calendar's timeframe columns (as
  vocabulary-ordered factors) plus `share`/`weight` to slice-keyed
  data — the foundation for manual ggplot2 workflows.
* **`geom_calendar()`** (datetime mode) and **`geom_calendar_tile()`**
  (slice mode): composable single tile layers, plus the shared
  **`theme_calendar()`**. Implemented as layer factories over the plot
  data rather than ggproto Stats — ggplot2 maps positional scales
  before statistics run, so a Stat cannot emit the discrete axes a
  calendar heatmap needs (the reason timeslices carried 600+ lines of
  custom scale code, which is deliberately not ported). Calendar inputs
  are column-name arguments (`datetime=`, `slice=`, `z=`); `by=` carries
  facet columns through aggregation.
* **`merra2_cities`** dataset: hourly 2019 weather (temperature, wind,
  solar) for Helsinki, Lima, and Sydney from NASA MERRA-2 (~60 KB), and
  a new **weather-data vignette** combining the layers, energypal
  palettes, and cross-calendar recasting. energypal joins Suggests.

## Calendar visualization

First viz layer, mirroring `geoscales` (ggplot2 in Suggests, no custom
ggproto — plot-level functions over an exported plain-data layout):

* `calendar_layout()` — plotting-system-agnostic icicle geometry: one
  band per timeframe (`ANNUAL` root on top), x normalized to `[0, 1]`.
* `calendar_autoplot()` — the structure icicle; `autoplot()` and
  `plot()` on a Calendar dispatch here. Fill by chronological `order`
  (gradient recycling `within` each parent, or `global`), `share`, or
  `weight`; auto white/dark labels; rows denser than `max_segments`
  (default 2000) are binned so hourly calendars render instantly.
* `calendar_plot()` — the single data-on-calendar heatmap: data keyed by
  slice, layout finest-on-y / next-on-x / coarser-as-facets, aggregation
  with `fun=` when timeframes are dropped; no data plots the share
  structure.
* Naming convention settled: class-word prefixes (`calendar_*` now,
  `horizon_*` when Horizon lands); generics stay bare. Custom
  `stat_*`/`geom_*` layers are deferred and will wrap the same helpers.

## Calendar catalog

The curated calendar library returns, ported from `timeslices` (37
designs) — with a correctness upgrade: catalog calendars carry
**duration-proportional shares** (January is `31/365` of the year), where
the timeslices originals shipped uniform shares (`1/12`) in contradiction
with their own documentation.

* `calendar_catalog()` — the discoverable table of built-in designs
  (id, tokens, timeframes, slice count, coverage, regularity).
* `calendars` dataset — all 37 pre-built as lean package data (~40 KB vs
  timeslices' 1.9 MB).
* `calendar(id)` now consults the catalog first: catalog builds carry
  `meta$coverage` / `meta$regularity`, and the non-Cartesian `m12_md*`
  family (ragged month/day grids — February is short) routes to a
  dedicated builder. Feb 29 under `m12_md365` and day 31 under
  `m12_md360` map to `NA` naturally.
* New timeframes `SEASON` (meteorological, `WIN` = Dec–Feb), `DAYTYPE`
  (`WORKDAY`/`WEEKEND`), and `HOURTYPE` (`DAY`/`NIGHT` h22–h05/`PEAK`
  h17–h20) join `CORE_TIMEFRAMES` with full datetime extraction — the
  9 type-axis designs (`s4*`, `wk2*`, `hp3`, `*_hp3`) are
  datetime-convertible for the first time (timeslices could construct
  but never populate them).
* New tokens `s4`, `wk2`, `hp3` with duration-weighted shares.

## Conversion core rewrite (v0.2 line)

Fixes the five conversion defects diagnosed in `dev/review-core-plan.md`;
the design decisions are recorded in `dev/review-core.md`. `recast()` now
routes every conversion `A -> base -> B` through a multi-year grid of real
instants (the geoscales atom pattern), projecting source values down to
instants and aggregating up to target slices.

### Breaking changes

* `recast(rule = "sum")` now **conserves totals** — each source value is
  split across its slice's grid instants before summing. Previously values
  were broadcast to every instant and added (96 unit leaves recast
  `q4_h24 -> q4` returned 8760; it now returns 96).
* `recast(rule = "weighted_mean")` now weights by the declared
  `leaves$share`. It differs from `"mean"` (the plain time-weighted grid
  mean) exactly when declared shares differ from real-time coverage.
* `expand_calendar()` gains a `year` column in its output
  (`datetime, year, slice`) and accepts a vector of years.
* The `h168` token now lives on the new `WHOUR` timeframe (hour of week,
  Monday-first ISO, `h000`..`h167`) instead of being mis-declared as
  `HOUR`, and maps datetimes correctly.
* Uncovered grid instants are no longer dropped silently:
  `recast(na_action = c("drop", "error", "keep"))` — `"drop"` warns,
  `"keep"` retains an explicit `NA` slice row so totals conserve.

### New features

* **Base calendar**: `base_calendar(years, by, tz)` enumerates the cached
  multi-year grid of real POSIXct instants — the 1:1 correspondence
  between calendars and date-time (leap years included: 2020 has 8784
  hourly rows).
* **ANNUAL root and within-calendar aggregation**:
  `calendar_at_level(cal, tf)` truncates a calendar at one of its own
  timeframes (`"ANNUAL"` returns the implicit one-slice whole-year root),
  and `recast()` accepts a timeframe name for `to=`.
* **Alignment rules** (`ALIGNMENT_RULES`): `exact`, `drop_last`,
  `drop_feb29`, `repeat_last` declare how real instants beyond a
  calendar's vocabulary map onto it. Stored per-timeframe in
  `meta$alignment`, seeded by tokens (`d365 -> drop_feb29`,
  `d360`/`d364` -> `drop_last`, `w52 -> repeat_last`), overridable in
  `instant_to_slice()`. `register_token()` gains an `alignment` argument.
* **New rules**: `"copy"` (common value, error if non-constant) and
  `"sd"` join `RECAST_RULES`.
* **Registries** (mirroring `geoscales`): `register_rule()` /
  `get_rule()` / `list_rules()` / `clear_rules()` map value-column names
  to default rules; `register_conversion()` / `get_conversion()` /
  `list_conversions()` / `clear_conversions()` register pairwise
  calendar-to-calendar overrides consulted before the base route.
* **Vocabulary unification**: `instant_to_slice()` resolves labels by
  formatted-token match first, then a positional fallback for
  full-cardinality enum vocabularies — `m12a` (`JAN`..`DEC`) and custom
  enum tokens now map instead of returning `NA`.
* **`meta$year_start` and `meta$utc_offset_minutes` are live**: the model
  year spans `[anchor(y), anchor(y+1))`, `YDAY`/`YEAR` are anchored to
  `year_start`, and local time = UTC + offset throughout
  `instant_to_slice()` and `expand_calendar()`.
* **Token provenance** restored: `calendar_build()` records
  `meta$tokens` (token per timeframe).

# timescales 0.1.0.9000

* Phase 1 skeleton: `Calendar` S7 class with validator, token registry
  (`register_token()`, `get_token()`, `list_tokens()`), three-layer
  constructors (`calendar()`, `calendar_build()`,
  `calendar_from_leaves()`), `as_timeframe()`, first-generation
  `instant_to_slice()` / `expand_calendar()` / `recast()`, three
  vignettes, pkgdown site, CI.

# timescales 0.0.0.9000

* Initial scaffolding. Successor to `timeslices`; code migration in progress.
