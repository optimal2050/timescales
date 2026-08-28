# Changelog

## timescales 0.5.0.9000

- `Remotes:` added to DESCRIPTION so CI and `pak` users can resolve the
  GitHub-only energypal Suggests from GitHub (the packages are not on
  CRAN/r-universe yet). Drop the field at CRAN submission time.

### Base-generic methods on Calendar

- [`summary()`](https://rdrr.io/r/base/summary.html) — the quantitative
  complement of [`print()`](https://rdrr.io/r/base/print.html): member
  counts, sampled coverage (with the parent’s name), catalog
  classification, share/weight ranges. Returns a `"summary_Calendar"`
  with its own print.
- [`names()`](https://rdrr.io/r/base/names.html) — the timeframe names
  (identical to
  [`calendar_timeframes()`](https://optimal2050.github.io/timescales/r/reference/calendar_queries.md)).
- [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) and
  [`ggplot2::fortify()`](https://ggplot2.tidyverse.org/reference/fortify.html)
  — the leaftable, so `ggplot(cal) + geom_*()` works directly. All
  mirrored by the geoscales twins.

## timescales 0.5.0

Hard-break release: the sibling APIs of timescales and geoscales were
harmonized against each other (the pairing table and naming rules live
in the stack-wide CONVENTIONS.md, “Sibling API mirror”). NO deprecation
aliases are kept – old names are gone, not wrapped.

### Breaking changes

- Registries follow `register_<class>_<thing>` everywhere:
  `register_rule`/`get_rule`/`list_rules`/`clear_rules` are now
  `register_calendar_rule`/`get_calendar_rule`/`list_calendar_rules`/
  `clear_calendar_rules`; the conversion registry is
  `register_calendar_conversion`/`get_calendar_conversion`/
  `list_calendar_conversions`/`clear_calendar_conversions`; the token
  registry is `register_calendar_token`/`get_calendar_token`/
  `list_calendar_tokens`. `RECAST_RULES` is now `CALENDAR_RULES`.
  (`ALIGNMENT_RULES` and the `calendar_map` registry family already
  complied and are unchanged.)
- The deprecated shim family is REMOVED: `instant_to_slice`,
  `instant_to_timeslice`, `calendar_at_level`, `calendar_join`,
  `calendar_recast`, `calendar_from_leaves` (archived under `drafts/`).
- The structure-object argument is `x` everywhere (was `calendar` or
  `object`): navigation/queries, `filter_calendar`, `prune_calendar`,
  `expand_calendar`, the wall family, and `calendar_autoplot`.
  Data-first verbs (`join_calendar`, `recast_*`,
  `datetime_to_timeslice`) keep `x` = data and the structure as
  `calendar`.
- `recast_to_timebase(weight = )` is now `attach_weight =` (matching
  [`geoscales::recast_to_geoatoms()`](https://optimal2050.github.io/geoscales/r/reference/recast_to_geoatoms.html)).
- `calendar_autoplot(rule = )` defaults to `"weighted_mean"` (was
  `NULL`), matching `geoscale_autoplot()`.
- The catalog metadata field `coverage` is renamed `coverage_class`
  (`"complete"`/`"truncated"`/`"representative"`, in
  [`calendar_catalog()`](https://optimal2050.github.io/timescales/r/reference/calendar_catalog.md)
  and `meta$coverage_class`) – `meta$coverage` now belongs to sample
  bookkeeping (below), mirroring geoscales.

### Sampled calendars are book-kept (the geoscales convention)

[`filter_calendar()`](https://optimal2050.github.io/timescales/r/reference/filter_calendar.md)
now records what a sample IS: the result is renamed
`"base[timeframe:labels-or-hash]"` – so two different samples of one
parent never collide in registries or joins – with the root parent’s
name and totals in `meta$parent_name`/`meta$parent_totals` and the
surviving fraction of `share`/`weight` in `meta$coverage` (validated
against the leaftable at 1e-8; read it with the new
[`calendar_coverage()`](https://optimal2050.github.io/timescales/r/reference/calendar_coverage.md)).
Filter-of-filter composes against the root; a filter that keeps
everything is now a true no-op.
[`prune_calendar()`](https://optimal2050.github.io/timescales/r/reference/prune_calendar.md)
records its immediate parent in `meta$parent_name` alongside its
existing `"base@timeframe"` renaming. `meta$year_fraction` behaves as
before.

### New

- `calendar_coverage(x, weight = NULL)` – surviving fraction of the root
  parent, per built-in weight column.
- `calendar_leaftable(x)` – exported accessor for the leaf table (stop
  reaching for `x@leaftable`).
- `calendar_ancestry(x)` – all ancestor-descendant pairs across every
  ordered timeframe pair (twin of
  [`geoscales::geoscale_ancestry()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_ancestry.html);
  [`calendar_family()`](https://optimal2050.github.io/timescales/r/reference/calendar_family.md)
  remains the adjacent-pairs view).
- `calendar_timeframes(x, finest = TRUE)` returns just the atom layer
  (twin of
  [`geoscales::geoscale_geoframes()`](https://optimal2050.github.io/geoscales/r/reference/geoscale_geoframes.html)).

## timescales 0.4.2

The development line rewrites the 0.1 skeleton around a conserving
conversion core, a curated calendar catalog, and a ggplot2 viz layer,
sharing one naming convention with the sibling package geoscales.

### Breaking changes

- `recast_calendar(rule = "sum")` conserves totals; `"weighted_mean"`
  weights by the declared `share`s. Previously values were broadcast to
  every grid instant and added.
- A value column with neither `rule=` nor a `register_rule()` entry is
  now an error; the silent `weighted_mean` fallback is gone.
- Uncovered grid points are no longer dropped silently:
  `na_action = c("drop", "error", "keep")` (`"drop"` warns; `"keep"`
  retains an explicit `NA` timeslice row so totals conserve).
- [`join_calendar()`](https://optimal2050.github.io/timescales/r/reference/join_calendar.md)
  attaches only a label column named after the calendar by default;
  `timeframes = TRUE` / `meta = TRUE` restore the timeframe and
  share/weight columns, now `"<name>."`-prefixed. Existing columns are
  never overwritten (error).
- `Calendar@levels` is now `@members` and `@leaves` is `@leaftable`,
  matching geoscales;
  [`calendar_from_leaftable()`](https://optimal2050.github.io/timescales/r/reference/calendar_from_leaftable.md)
  replaces `calendar_from_leaves()`.
- The time dimension is `timeslice` (was `slice`) in every output and
  key default;
  [`calendar_catalog()`](https://optimal2050.github.io/timescales/r/reference/calendar_catalog.md)
  column `n_slices` is now `n_timeslices`.
- [`expand_calendar()`](https://optimal2050.github.io/timescales/r/reference/expand_calendar.md)
  gains a `year` output column and accepts a vector of years.
- The `h168` token lives on the new `WHOUR` timeframe (hour of week,
  Monday-first) and now maps datetimes correctly.

### New features

#### Conversion

- `recast_calendar(x, from, to, year, rule)` converts values between any
  two calendars via the base datetime grid; identifier (panel) columns
  are preserved as groups, and `to =` accepts a timeframe name
  (`"ANNUAL"` = the root) for within-calendar aggregation.
- [`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md)
  is an S7 generic dispatching on the scale object, so pipelines chain
  across packages:
  `x |> recast(cal_a, cal_b) |> recast(gs, to = "country")`.
- [`recast_to_timebase()`](https://optimal2050.github.io/timescales/r/reference/recast_to_timebase.md)
  /
  [`recast_from_timebase()`](https://optimal2050.github.io/timescales/r/reference/recast_to_timebase.md)
  expose the route halves; their composition equals
  [`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md).
- `calendar_map(from, to, year)` materialises the conversion as a small
  crosswalk table;
  [`register_calendar_map()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_map.md)
  installs exact crosswalks and `register_conversion()` functional
  overrides, both keyed by calendar names.
- All converters run over `data.frame`, tibble, `data.table`, dtplyr,
  and arrow inputs; results come back in the input’s class, and lazy
  inputs return the uncollected query unless `collect = TRUE`.
- [`join_calendar()`](https://optimal2050.github.io/timescales/r/reference/join_calendar.md)
  supports several calendars on one dataset (the pair of label columns
  is itself a crosswalk); keys auto-detect from a calendar-named,
  `timeslice`, or POSIXct `datetime` column.
- `base_calendar(years, by, tz)` enumerates the cached multi-year
  datetime grid;
  [`datetime_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/datetime_to_timeslice.md)
  maps datetimes to timeslice IDs under per-timeframe alignment rules
  (`ALIGNMENT_RULES`: `exact`, `drop_last`, `drop_feb29`,
  `repeat_last`).
- `meta$year_start` and `meta$utc_offset_minutes` are honoured
  throughout: the model year spans `[anchor(y), anchor(y+1))` and local
  time = UTC + offset.
- Rules `"copy"` and `"sd"` join `RECAST_RULES`; per-column defaults via
  `register_rule()` / `get_rule()` / `list_rules()` / `clear_rules()`.

#### Calendars and catalog

- [`calendar_catalog()`](https://optimal2050.github.io/timescales/r/reference/calendar_catalog.md)
  lists 43 curated designs; all ship pre-built in the `calendars`
  dataset with duration-proportional shares (January is 31/365 of a
  year, not 1/12).
- Six April-start fiscal designs: `fy04_m12`, `fy04_m12_h24`, `fy04_q4`,
  `fy04_q4_h24`, `fy04_d365`, `fy04_d365_h24`. The anchored `YEAR` is
  the starting Gregorian year (“FY 2021-22” -\> 2021); labels stay
  Gregorian (`m04` is April) while the member order starts at the
  anchor. Catalog entries may carry `year_start`/`utc_offset_minutes`
  (caller arguments win), e.g.
  `calendar("fy04_m12", utc_offset_minutes = 330L)` for IST.
- A nontrivial `year_start` rotates the MONTH/QUARTER member order in
  [`calendar_build()`](https://optimal2050.github.io/timescales/r/reference/calendar_build.md)
  (fiscal axes read April-first everywhere).
- New timeframes `SEASON`, `DAYTYPE`, `HOURTYPE` (with tokens `s4`,
  `wk2`, `hp3`) are fully datetime-convertible.
- Navigation and subsetting:
  [`calendar_timeframes()`](https://optimal2050.github.io/timescales/r/reference/calendar_queries.md),
  [`calendar_timeslices()`](https://optimal2050.github.io/timescales/r/reference/calendar_queries.md)
  (with `qualified = TRUE` node IDs),
  [`calendar_rank()`](https://optimal2050.github.io/timescales/r/reference/calendar_queries.md),
  [`calendar_family()`](https://optimal2050.github.io/timescales/r/reference/calendar_family.md),
  [`calendar_children()`](https://optimal2050.github.io/timescales/r/reference/calendar_navigate.md)
  / `_parents()` / `_descendants()` / `_ancestors()`,
  [`calendar_share()`](https://optimal2050.github.io/timescales/r/reference/calendar_share.md),
  [`filter_calendar()`](https://optimal2050.github.io/timescales/r/reference/filter_calendar.md)
  / `cal[timeframe, labels]`,
  [`prune_calendar()`](https://optimal2050.github.io/timescales/r/reference/prune_calendar.md).
- `merra2_cities` dataset: hourly 2019 weather for Helsinki, Lima, and
  Sydney (NASA MERRA-2).

#### Visualization

- [`theme_calendar()`](https://optimal2050.github.io/timescales/r/reference/geom_calendar.md)
  draws a solid white plot background (transparent figures are illegible
  on dark-mode pages); article figures build on a solid background
  site-wide.
- Composable layers
  [`geom_calendar()`](https://optimal2050.github.io/timescales/r/reference/geom_calendar.md)
  (datetime mode) and
  [`geom_calendar_tile()`](https://optimal2050.github.io/timescales/r/reference/geom_calendar.md)
  (timeslice mode) with
  [`theme_calendar()`](https://optimal2050.github.io/timescales/r/reference/geom_calendar.md);
  facet columns ride through `by=`; `calendar_breaks(n)` thins dense
  discrete axes while keeping the end values.
- Wall calendars:
  [`calendar_wall_plot()`](https://optimal2050.github.io/timescales/r/reference/calendar_wall_plot.md)
  (month facets in member order, single-letter weekday headers,
  year-labelled facets — a fiscal wall reads APR 2019 .. MAR 2020), with
  [`calendar_wall_layout()`](https://optimal2050.github.io/timescales/r/reference/calendar_wall_layout.md)
  and
  [`calendar_weekdays()`](https://optimal2050.github.io/timescales/r/reference/calendar_weekdays.md)
  (weekday, week-of-month, anchored week-of-year) underneath.
- Structure figures:
  [`calendar_autoplot()`](https://optimal2050.github.io/timescales/r/reference/calendar_autoplot.md)
  (icicle;
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)/
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) dispatch
  here) and
  [`calendar_plot()`](https://optimal2050.github.io/timescales/r/reference/calendar_plot.md)
  (heatmap), over the exported
  [`calendar_layout()`](https://optimal2050.github.io/timescales/r/reference/calendar_layout.md)
  geometry. `calendar_autoplot(type = "stack")` draws the layer-stack
  view: one plane per timeframe, `ANNUAL` on top, segments at their true
  duration shares – with `view` presets
  (oblique/top-down/cavalier/cabinet/military/isometric/
  dimetric/trimetric/perspective), `angle`/`ratio` obliques, `rotate=`,
  `direction=`, and an almost-touching default spacing. `frame=` draws
  each plane’s outline (“sheet”), `frame_fill=` fills the sheets (best
  mostly transparent), and `connectors=` adds dashed corner guides
  between planes; `colour=`/`linewidth=` style segment borders per plane
  (defaults `"grey35"`/`0.2`, ggplot2’s own sf polygon border), and the
  canvas hugs the content (tight limits, label room sized to the
  timeframe names). The stack also takes data: `data`/`z` colour every
  plane by a timeslice-keyed value, recast to each plane’s timeframe
  (`rule=`, `year=`; base grid `by = "hour"`) so the whole stack shares
  one continuous scale; for `type = "stack"` `labels=` names timeframes
  whose member names are drawn on the plane, and `palette = NULL` adds
  no fill scale (bring your own). Mirrored in
  `geoscales::geoscale_autoplot(type = "stack")` (deliberate
  differences: oblique defaults, palette letter, `annual=` here vs
  geometry-only `precision=` there).
- The structure icicle carries data too:
  `calendar_autoplot(data =, z =, rule =, year =)` fills every band with
  the value recast to that band’s timeframe (dense bands binned with
  width-weighted means) – the 2D twin of the stack’s data fill.
- `merra2_cities` grew from 3 to all 12 cities of the source extract and
  from 5 to 11 columns (adds `locid` – the MERRA-2 grid-cell id bridging
  to the space dimension – plus `W10M`, `WDIR`, `ALBEDO`, `PRECTOTCORR`,
  `RHOA`). ~353 KB compressed.
- README rewritten around a real-data hero (Reykjavik wind on `m12_h24`,
  twinned with the geoscales Iceland map hero) and a five-point “What
  timescales offers” intro; all README demos now run on `merra2_cities`.
- Crosswalk registry rounded out:
  [`get_calendar_map()`](https://optimal2050.github.io/timescales/r/reference/get_calendar_map.md)
  and
  [`list_calendar_maps()`](https://optimal2050.github.io/timescales/r/reference/list_calendar_maps.md)
  join
  [`register_calendar_map()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_map.md)
  /
  [`clear_calendar_maps()`](https://optimal2050.github.io/timescales/r/reference/clear_calendar_maps.md)
  (parity with the geoscales registry), and the register/clear pair
  gained examples.

### Deprecations

Old names warn and forward; removal before 1.0: `calendar_recast()` -\>
[`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md),
`calendar_join()` -\>
[`join_calendar()`](https://optimal2050.github.io/timescales/r/reference/join_calendar.md),
`calendar_at_level()` -\>
[`prune_calendar()`](https://optimal2050.github.io/timescales/r/reference/prune_calendar.md),
`instant_to_timeslice()` / `instant_to_slice()` -\>
[`datetime_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/datetime_to_timeslice.md),
`calendar_from_leaves()` -\>
[`calendar_from_leaftable()`](https://optimal2050.github.io/timescales/r/reference/calendar_from_leaftable.md).

### Bug fixes

- [`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md)
  preserves identifier columns (a city x timeslice panel previously
  returned only the first group) and no longer sweeps `from`’s timeframe
  columns into the auto-detected values.
- [`calendar_build()`](https://optimal2050.github.io/timescales/r/reference/calendar_build.md)
  forwards named `...` to `meta` as documented (previously dropped
  silently); collisions with construction arguments error.
- `m12a` and other full-cardinality enum vocabularies map datetimes
  (label match with positional fallback) instead of returning `NA`.

### Documentation

- The intro is the package-named
  [`vignette("timescales")`](https://optimal2050.github.io/timescales/r/articles/timescales.md),
  surfaced as the site’s top-level “Get started” item; all articles sit
  directly in the Articles menu; superseded URLs redirect.
- New
  [`vignette("data-manipulation")`](https://optimal2050.github.io/timescales/r/articles/data-manipulation.md)
  (attach, recast, crosswalks, backends) and
  [`vignette("visualization")`](https://optimal2050.github.io/timescales/r/articles/visualization.md)
  (the ggplot2 integration contract and plot-type tour; absorbs the
  weather-data vignette).
- [`vignette("calendars")`](https://optimal2050.github.io/timescales/r/articles/calendars.md)
  presents the catalog by family, one icicle per family; the shared
  \*scales glossary ships in
  [`vignette("concepts")`](https://optimal2050.github.io/timescales/r/articles/concepts.md).
  Vignette code follows the stack-wide tidyverse + `|>` style.

## timescales 0.1.0.9000

- Phase 1 skeleton: `Calendar` S7 class with validator, token registry
  (`register_token()`, `get_token()`, `list_tokens()`), three-layer
  constructors
  ([`calendar()`](https://optimal2050.github.io/timescales/r/reference/calendar_build.md),
  [`calendar_build()`](https://optimal2050.github.io/timescales/r/reference/calendar_build.md),
  `calendar_from_leaves()`),
  [`as_timeframe()`](https://optimal2050.github.io/timescales/r/reference/as_timeframe.md),
  first-generation `instant_to_timeslice()` /
  [`expand_calendar()`](https://optimal2050.github.io/timescales/r/reference/expand_calendar.md)
  /
  [`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md),
  three vignettes, pkgdown site, CI.

## timescales 0.0.0.9000

- Initial scaffolding. Successor to `timeslices`; code migration in
  progress.
