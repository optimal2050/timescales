# Changelog

## timescales (development version)

### Harmonized naming with geoscales

The sibling packages now share one convention: **`verb_class()`** for
data operations and object transforms, **class-prefixed nouns** for
properties and queries, constructors and registries unchanged.

- Renamed (old names warn and forward; removal before 1.0):
  [`calendar_recast()`](https://optimal2050.github.io/timescales/r/reference/timescales-deprecated.md)
  -\>
  [`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md),
  [`calendar_join()`](https://optimal2050.github.io/timescales/r/reference/timescales-deprecated.md)
  -\>
  [`join_calendar()`](https://optimal2050.github.io/timescales/r/reference/join_calendar.md),
  [`calendar_at_level()`](https://optimal2050.github.io/timescales/r/reference/timescales-deprecated.md)
  -\>
  [`prune_calendar()`](https://optimal2050.github.io/timescales/r/reference/prune_calendar.md)
  (pairs with
  [`geoscales::prune_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/prune_geoscale.html)).
- **[`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md)
  is now an S7 generic owned by timescales** (it was a deprecated
  alias), dispatching on the scale object in `from`:
  `x |> recast(cal_a, cal_b) |> recast(gs, to = "country")` — geoscales
  registers the `Geoscale` method.
- New navigation/query family mirroring geoscales:
  [`calendar_timeframes()`](https://optimal2050.github.io/timescales/r/reference/calendar_queries.md),
  [`calendar_timeslices()`](https://optimal2050.github.io/timescales/r/reference/calendar_queries.md),
  [`calendar_rank()`](https://optimal2050.github.io/timescales/r/reference/calendar_queries.md),
  [`calendar_family()`](https://optimal2050.github.io/timescales/r/reference/calendar_family.md),
  [`calendar_children()`](https://optimal2050.github.io/timescales/r/reference/calendar_navigate.md),
  [`calendar_parents()`](https://optimal2050.github.io/timescales/r/reference/calendar_navigate.md),
  [`calendar_descendants()`](https://optimal2050.github.io/timescales/r/reference/calendar_navigate.md),
  [`calendar_ancestors()`](https://optimal2050.github.io/timescales/r/reference/calendar_navigate.md),
  [`calendar_share()`](https://optimal2050.github.io/timescales/r/reference/calendar_share.md).
- New subsetting: `filter_calendar(cal, timeframe, labels)` and
  `cal[timeframe, labels]`. Shares are kept raw; the result is a
  partial-year calendar with `meta$year_fraction = sum(share)`.

### The time dimension is now `timeslice`

Stack-wide rename `slice` -\> `timeslice` (pre-first-release; energyRt
follows on its v0.80 branch): the term matches the TIMES/OSeMOSYS
vocabulary and pairs with geoscales’ `region` in mixed panels.

- The leaf/key column is `timeslice` everywhere: `leaves$timeslice`,
  [`expand_calendar()`](https://optimal2050.github.io/timescales/r/reference/expand_calendar.md)/[`calendar_layout()`](https://optimal2050.github.io/timescales/r/reference/calendar_layout.md)/[`calendar_recast()`](https://optimal2050.github.io/timescales/r/reference/timescales-deprecated.md)
  outputs, `key` defaults, `geom_calendar_tile(timeslice=)`.
- [`instant_to_slice()`](https://optimal2050.github.io/timescales/r/reference/instant_to_slice.md)
  is deprecated in favor of
  [`instant_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/instant_to_timeslice.md).
- [`calendar_catalog()`](https://optimal2050.github.io/timescales/r/reference/calendar_catalog.md)
  column `n_slices` is now `n_timeslices`.
- `slice` remains a reserved timeframe name alongside `timeslice`.
- The bundled `calendars` dataset is regenerated with the new column.
- (Entries below this section predate the rename and are written with
  the new vocabulary.)

### `calendar_recast()`, panel data, and the naming convention

- **[`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md)
  is deprecated; the verb is now
  [`calendar_recast()`](https://optimal2050.github.io/timescales/r/reference/timescales-deprecated.md).**
  The stack-wide convention reserves bare names for foreign generics
  (`plot`, `autoplot`, `print`) and prefixes owned operations by their
  object —
  [`calendar_recast()`](https://optimal2050.github.io/timescales/r/reference/timescales-deprecated.md)
  pairs with
  [`geoscales::geo_recast()`](https://optimal2050.github.io/geoscales/r/reference/geoscales-deprecated.html),
  so mixed pipelines read
  `x |> calendar_recast(...) |> geo_recast(...)`. (Bare `recast` also
  risked masking against the retired reshape2; bare `filter`/`rank`/
  `expand`/`children` are outright collisions and will never be used.)
- **Behavior fix: identifier (panel) columns are preserved.** Previously
  a city x timeslice table silently returned only the first city’s
  values; now non-key, non-value columns group the aggregation, keep
  their types, and pass through to the output — per group, the full
  target timeslice vocabulary is emitted.
- **Behavior fix: `values` auto-detection excludes `from`’s timeframe
  columns** (a joined `MONTH` column no longer gets swept into the
  values); numeric identifiers like `year` still need explicit
  exclusion.
- `key = NULL` default (resolving to `"timeslice"`), a warning for
  source keys unknown to the calendar, geoscales-style error messages
  via new internal `.stop()`/`.warn()`/`.preview()` helpers, and a
  validator guard rejecting reserved timeframe names (`timeslice`,
  `share`, `weight`).

### ggplot2 layers and weather sample

- **[`calendar_join()`](https://optimal2050.github.io/timescales/r/reference/timescales-deprecated.md)**
  attaches a calendar’s timeframe columns (as vocabulary-ordered
  factors) plus `share`/`weight` to timeslice-keyed data — the
  foundation for manual ggplot2 workflows.
- **[`geom_calendar()`](https://optimal2050.github.io/timescales/r/reference/geom_calendar.md)**
  (datetime mode) and
  **[`geom_calendar_tile()`](https://optimal2050.github.io/timescales/r/reference/geom_calendar.md)**
  (timeslice mode): composable single tile layers, plus the shared
  **[`theme_calendar()`](https://optimal2050.github.io/timescales/r/reference/geom_calendar.md)**.
  Implemented as layer factories over the plot data rather than ggproto
  Stats — ggplot2 maps positional scales before statistics run, so a
  Stat cannot emit the discrete axes a calendar heatmap needs (the
  reason timeslices carried 600+ lines of custom scale code, which is
  deliberately not ported). Calendar inputs are column-name arguments
  (`datetime=`, `timeslice=`, `z=`); `by=` carries facet columns through
  aggregation.
- **`merra2_cities`** dataset: hourly 2019 weather (temperature, wind,
  solar) for Helsinki, Lima, and Sydney from NASA MERRA-2 (~60 KB), and
  a new **weather-data vignette** combining the layers, energypal
  palettes, and cross-calendar recasting. energypal joins Suggests.

### Calendar visualization

First viz layer, mirroring `geoscales` (ggplot2 in Suggests, no custom
ggproto — plot-level functions over an exported plain-data layout):

- [`calendar_layout()`](https://optimal2050.github.io/timescales/r/reference/calendar_layout.md)
  — plotting-system-agnostic icicle geometry: one band per timeframe
  (`ANNUAL` root on top), x normalized to `[0, 1]`.
- [`calendar_autoplot()`](https://optimal2050.github.io/timescales/r/reference/calendar_autoplot.md)
  — the structure icicle;
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  and [`plot()`](https://rdrr.io/r/graphics/plot.default.html) on a
  Calendar dispatch here. Fill by chronological `order` (gradient
  recycling `within` each parent, or `global`), `share`, or `weight`;
  auto white/dark labels; rows denser than `max_segments` (default 2000)
  are binned so hourly calendars render instantly.
- [`calendar_plot()`](https://optimal2050.github.io/timescales/r/reference/calendar_plot.md)
  — the single data-on-calendar heatmap: data keyed by timeslice, layout
  finest-on-y / next-on-x / coarser-as-facets, aggregation with `fun=`
  when timeframes are dropped; no data plots the share structure.
- Naming convention settled: class-word prefixes (`calendar_*` now,
  `horizon_*` when Horizon lands); generics stay bare. Custom
  `stat_*`/`geom_*` layers are deferred and will wrap the same helpers.

### Calendar catalog

The curated calendar library returns, ported from `timeslices` (37
designs) — with a correctness upgrade: catalog calendars carry
**duration-proportional shares** (January is `31/365` of the year),
where the timeslices originals shipped uniform shares (`1/12`) in
contradiction with their own documentation.

- [`calendar_catalog()`](https://optimal2050.github.io/timescales/r/reference/calendar_catalog.md)
  — the discoverable table of built-in designs (id, tokens, timeframes,
  timeslice count, coverage, regularity).
- `calendars` dataset — all 37 pre-built as lean package data (~40 KB vs
  timeslices’ 1.9 MB).
- `calendar(id)` now consults the catalog first: catalog builds carry
  `meta$coverage` / `meta$regularity`, and the non-Cartesian `m12_md*`
  family (ragged month/day grids — February is short) routes to a
  dedicated builder. Feb 29 under `m12_md365` and day 31 under
  `m12_md360` map to `NA` naturally.
- New timeframes `SEASON` (meteorological, `WIN` = Dec–Feb), `DAYTYPE`
  (`WORKDAY`/`WEEKEND`), and `HOURTYPE` (`DAY`/`NIGHT` h22–h05/`PEAK`
  h17–h20) join `CORE_TIMEFRAMES` with full datetime extraction — the 9
  type-axis designs (`s4*`, `wk2*`, `hp3`, `*_hp3`) are
  datetime-convertible for the first time (timeslices could construct
  but never populate them).
- New tokens `s4`, `wk2`, `hp3` with duration-weighted shares.

### Conversion core rewrite (v0.2 line)

Fixes the five conversion defects diagnosed in
`dev/review-core-plan.md`; the design decisions are recorded in
`dev/review-core.md`.
[`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md)
now routes every conversion `A -> base -> B` through a multi-year grid
of real instants (the geoscales atom pattern), projecting source values
down to instants and aggregating up to target timeslices.

#### Breaking changes

- `recast(rule = "sum")` now **conserves totals** — each source value is
  split across its timeslice’s grid instants before summing. Previously
  values were broadcast to every instant and added (96 unit leaves
  recast `q4_h24 -> q4` returned 8760; it now returns 96).
- `recast(rule = "weighted_mean")` now weights by the declared
  `leaves$share`. It differs from `"mean"` (the plain time-weighted grid
  mean) exactly when declared shares differ from real-time coverage.
- [`expand_calendar()`](https://optimal2050.github.io/timescales/r/reference/expand_calendar.md)
  gains a `year` column in its output (`datetime, year, timeslice`) and
  accepts a vector of years.
- The `h168` token now lives on the new `WHOUR` timeframe (hour of week,
  Monday-first ISO, `h000`..`h167`) instead of being mis-declared as
  `HOUR`, and maps datetimes correctly.
- Uncovered grid instants are no longer dropped silently:
  `recast(na_action = c("drop", "error", "keep"))` — `"drop"` warns,
  `"keep"` retains an explicit `NA` timeslice row so totals conserve.

#### New features

- **Base calendar**: `base_calendar(years, by, tz)` enumerates the
  cached multi-year grid of real POSIXct instants — the 1:1
  correspondence between calendars and date-time (leap years included:
  2020 has 8784 hourly rows).
- **ANNUAL root and within-calendar aggregation**:
  `calendar_at_level(cal, tf)` truncates a calendar at one of its own
  timeframes (`"ANNUAL"` returns the implicit one-timeslice whole-year
  root), and
  [`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md)
  accepts a timeframe name for `to=`.
- **Alignment rules** (`ALIGNMENT_RULES`): `exact`, `drop_last`,
  `drop_feb29`, `repeat_last` declare how real instants beyond a
  calendar’s vocabulary map onto it. Stored per-timeframe in
  `meta$alignment`, seeded by tokens (`d365 -> drop_feb29`,
  `d360`/`d364` -\> `drop_last`, `w52 -> repeat_last`), overridable in
  [`instant_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/instant_to_timeslice.md).
  [`register_token()`](https://optimal2050.github.io/timescales/r/reference/register_token.md)
  gains an `alignment` argument.
- **New rules**: `"copy"` (common value, error if non-constant) and
  `"sd"` join `RECAST_RULES`.
- **Registries** (mirroring `geoscales`):
  [`register_rule()`](https://optimal2050.github.io/timescales/r/reference/register_rule.md)
  /
  [`get_rule()`](https://optimal2050.github.io/timescales/r/reference/get_rule.md)
  /
  [`list_rules()`](https://optimal2050.github.io/timescales/r/reference/list_rules.md)
  /
  [`clear_rules()`](https://optimal2050.github.io/timescales/r/reference/clear_rules.md)
  map value-column names to default rules;
  [`register_conversion()`](https://optimal2050.github.io/timescales/r/reference/register_conversion.md)
  /
  [`get_conversion()`](https://optimal2050.github.io/timescales/r/reference/register_conversion.md)
  /
  [`list_conversions()`](https://optimal2050.github.io/timescales/r/reference/register_conversion.md)
  /
  [`clear_conversions()`](https://optimal2050.github.io/timescales/r/reference/register_conversion.md)
  register pairwise calendar-to-calendar overrides consulted before the
  base route.
- **Vocabulary unification**:
  [`instant_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/instant_to_timeslice.md)
  resolves labels by formatted-token match first, then a positional
  fallback for full-cardinality enum vocabularies — `m12a`
  (`JAN`..`DEC`) and custom enum tokens now map instead of returning
  `NA`.
- **`meta$year_start` and `meta$utc_offset_minutes` are live**: the
  model year spans `[anchor(y), anchor(y+1))`, `YDAY`/`YEAR` are
  anchored to `year_start`, and local time = UTC + offset throughout
  [`instant_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/instant_to_timeslice.md)
  and
  [`expand_calendar()`](https://optimal2050.github.io/timescales/r/reference/expand_calendar.md).
- **Token provenance** restored:
  [`calendar_build()`](https://optimal2050.github.io/timescales/r/reference/calendar_build.md)
  records `meta$tokens` (token per timeframe).

## timescales 0.1.0.9000

- Phase 1 skeleton: `Calendar` S7 class with validator, token registry
  ([`register_token()`](https://optimal2050.github.io/timescales/r/reference/register_token.md),
  [`get_token()`](https://optimal2050.github.io/timescales/r/reference/register_token.md),
  [`list_tokens()`](https://optimal2050.github.io/timescales/r/reference/register_token.md)),
  three-layer constructors
  ([`calendar()`](https://optimal2050.github.io/timescales/r/reference/calendar_build.md),
  [`calendar_build()`](https://optimal2050.github.io/timescales/r/reference/calendar_build.md),
  [`calendar_from_leaves()`](https://optimal2050.github.io/timescales/r/reference/calendar_from_leaves.md)),
  [`as_timeframe()`](https://optimal2050.github.io/timescales/r/reference/as_timeframe.md),
  first-generation
  [`instant_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/instant_to_timeslice.md)
  /
  [`expand_calendar()`](https://optimal2050.github.io/timescales/r/reference/expand_calendar.md)
  /
  [`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md),
  three vignettes, pkgdown site, CI.

## timescales 0.0.0.9000

- Initial scaffolding. Successor to `timeslices`; code migration in
  progress.
