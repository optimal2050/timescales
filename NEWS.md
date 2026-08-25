# timescales (development version)

The development line rewrites the 0.1 skeleton around a conserving
conversion core, a curated calendar catalog, and a ggplot2 viz layer,
sharing one naming convention with the sibling package geoscales.

## Breaking changes

* `recast_calendar(rule = "sum")` conserves totals; `"weighted_mean"`
  weights by the declared `share`s. Previously values were broadcast to
  every grid instant and added.
* A value column with neither `rule=` nor a `register_rule()` entry is
  now an error; the silent `weighted_mean` fallback is gone.
* Uncovered grid points are no longer dropped silently:
  `na_action = c("drop", "error", "keep")` (`"drop"` warns; `"keep"`
  retains an explicit `NA` timeslice row so totals conserve).
* `join_calendar()` attaches only a label column named after the
  calendar by default; `timeframes = TRUE` / `meta = TRUE` restore the
  timeframe and share/weight columns, now `"<name>."`-prefixed.
  Existing columns are never overwritten (error).
* `Calendar@levels` is now `@members` and `@leaves` is `@leaftable`,
  matching geoscales; `calendar_from_leaftable()` replaces
  `calendar_from_leaves()`.
* The time dimension is `timeslice` (was `slice`) in every output and
  key default; `calendar_catalog()` column `n_slices` is now
  `n_timeslices`.
* `expand_calendar()` gains a `year` output column and accepts a vector
  of years.
* The `h168` token lives on the new `WHOUR` timeframe (hour of week,
  Monday-first) and now maps datetimes correctly.

## New features

### Conversion

* `recast_calendar(x, from, to, year, rule)` converts values between any
  two calendars via the base datetime grid; identifier (panel) columns
  are preserved as groups, and `to =` accepts a timeframe name
  (`"ANNUAL"` = the root) for within-calendar aggregation.
* `recast()` is an S7 generic dispatching on the scale object, so
  pipelines chain across packages:
  `x |> recast(cal_a, cal_b) |> recast(gs, to = "country")`.
* `recast_to_timebase()` / `recast_from_timebase()` expose the route
  halves; their composition equals `recast_calendar()`.
* `calendar_map(from, to, year)` materialises the conversion as a small
  crosswalk table; `register_calendar_map()` installs exact crosswalks
  and `register_conversion()` functional overrides, both keyed by
  calendar names.
* All converters run over `data.frame`, tibble, `data.table`, dtplyr,
  and arrow inputs; results come back in the input's class, and lazy
  inputs return the uncollected query unless `collect = TRUE`.
* `join_calendar()` supports several calendars on one dataset (the pair
  of label columns is itself a crosswalk); keys auto-detect from a
  calendar-named, `timeslice`, or POSIXct `datetime` column.
* `base_calendar(years, by, tz)` enumerates the cached multi-year
  datetime grid; `datetime_to_timeslice()` maps datetimes to timeslice
  IDs under per-timeframe alignment rules (`ALIGNMENT_RULES`:
  `exact`, `drop_last`, `drop_feb29`, `repeat_last`).
* `meta$year_start` and `meta$utc_offset_minutes` are honoured
  throughout: the model year spans `[anchor(y), anchor(y+1))` and
  local time = UTC + offset.
* Rules `"copy"` and `"sd"` join `RECAST_RULES`; per-column defaults via
  `register_rule()` / `get_rule()` / `list_rules()` / `clear_rules()`.

### Calendars and catalog

* `calendar_catalog()` lists 43 curated designs; all ship pre-built in
  the `calendars` dataset with duration-proportional shares (January is
  31/365 of a year, not 1/12).
* Six April-start fiscal designs: `fy04_m12`, `fy04_m12_h24`, `fy04_q4`,
  `fy04_q4_h24`, `fy04_d365`, `fy04_d365_h24`. The anchored `YEAR` is
  the starting Gregorian year ("FY 2021-22" -> 2021); labels stay
  Gregorian (`m04` is April) while the member order starts at the
  anchor. Catalog entries may carry `year_start`/`utc_offset_minutes`
  (caller arguments win), e.g.
  `calendar("fy04_m12", utc_offset_minutes = 330L)` for IST.
* A nontrivial `year_start` rotates the MONTH/QUARTER member order in
  `calendar_build()` (fiscal axes read April-first everywhere).
* New timeframes `SEASON`, `DAYTYPE`, `HOURTYPE` (with tokens `s4`,
  `wk2`, `hp3`) are fully datetime-convertible.
* Navigation and subsetting: `calendar_timeframes()`,
  `calendar_timeslices()` (with `qualified = TRUE` node IDs),
  `calendar_rank()`, `calendar_family()`, `calendar_children()` /
  `_parents()` / `_descendants()` / `_ancestors()`, `calendar_share()`,
  `filter_calendar()` / `cal[timeframe, labels]`, `prune_calendar()`.
* `merra2_cities` dataset: hourly 2019 weather for Helsinki, Lima, and
  Sydney (NASA MERRA-2).

### Visualization

* `theme_calendar()` draws a solid white plot background (transparent
  figures are illegible on dark-mode pages); article figures build on a
  solid background site-wide.
* Composable layers `geom_calendar()` (datetime mode) and
  `geom_calendar_tile()` (timeslice mode) with `theme_calendar()`;
  facet columns ride through `by=`; `calendar_breaks(n)` thins dense
  discrete axes while keeping the end values.
* Wall calendars: `calendar_wall_plot()` (month facets in member order,
  single-letter weekday headers, year-labelled facets — a fiscal wall
  reads APR 2019 .. MAR 2020), with `calendar_wall_layout()` and
  `calendar_weekdays()` (weekday, week-of-month, anchored week-of-year)
  underneath.
* Structure figures: `calendar_autoplot()` (icicle; `autoplot()`/
  `plot()` dispatch here) and `calendar_plot()` (heatmap), over the
  exported `calendar_layout()` geometry. `calendar_autoplot(type =
  "stack")` draws the layer-stack view: one plane per timeframe,
  `ANNUAL` on top, segments at their true duration shares -- with
  `view` presets (oblique/top-down/cavalier/cabinet/military/isometric/
  dimetric/trimetric/perspective), `angle`/`ratio` obliques,
  `rotate=`, `direction=`, and an almost-touching default spacing.
  `frame=` draws each plane's outline ("sheet"), `frame_fill=` fills
  the sheets (best mostly transparent), and `connectors=` adds dashed
  corner guides between planes; `colour=`/`linewidth=` style segment
  borders per plane (defaults `"grey35"`/`0.2`, ggplot2's own sf
  polygon border), and the canvas hugs the content (tight limits,
  label room sized to the timeframe names). The stack also takes data:
  `data`/`z` colour every plane by a timeslice-keyed value, recast to
  each plane's timeframe (`rule=`, `year=`; base grid `by = "hour"`)
  so the whole stack shares one continuous scale; for `type = "stack"`
  `labels=` names timeframes whose member names are drawn on the
  plane, and `palette = NULL` adds no fill scale (bring your own).
  Mirrored in `geoscales::geoscale_autoplot(type = "stack")`
  (deliberate differences: oblique defaults, palette letter, `annual=`
  here vs geometry-only `precision=` there).
* The structure icicle carries data too: `calendar_autoplot(data =,
  z =, rule =, year =)` fills every band with the value recast to that
  band's timeframe (dense bands binned with width-weighted means) --
  the 2D twin of the stack's data fill.
* `merra2_cities` grew from 3 to all 12 cities of the source extract
  and from 5 to 11 columns (adds `locid` -- the MERRA-2 grid-cell id
  bridging to the space dimension -- plus `W10M`, `WDIR`, `ALBEDO`,
  `PRECTOTCORR`, `RHOA`). ~353 KB compressed.
* README rewritten around a real-data hero (Reykjavik wind on
  `m12_h24`, twinned with the geoscales Iceland map hero) and a
  five-point "What timescales offers" intro; all README demos now run
  on `merra2_cities`.
* Crosswalk registry rounded out: `get_calendar_map()` and
  `list_calendar_maps()` join `register_calendar_map()` /
  `clear_calendar_maps()` (parity with the geoscales registry), and
  the register/clear pair gained examples.

## Deprecations

Old names warn and forward; removal before 1.0:
`calendar_recast()` -> `recast_calendar()`, `calendar_join()` ->
`join_calendar()`, `calendar_at_level()` -> `prune_calendar()`,
`instant_to_timeslice()` / `instant_to_slice()` ->
`datetime_to_timeslice()`, `calendar_from_leaves()` ->
`calendar_from_leaftable()`.

## Bug fixes

* `recast_calendar()` preserves identifier columns (a city x timeslice
  panel previously returned only the first group) and no longer sweeps
  `from`'s timeframe columns into the auto-detected values.
* `calendar_build()` forwards named `...` to `meta` as documented
  (previously dropped silently); collisions with construction arguments
  error.
* `m12a` and other full-cardinality enum vocabularies map datetimes
  (label match with positional fallback) instead of returning `NA`.

## Documentation

* The intro is the package-named `vignette("timescales")`, surfaced as
  the site's top-level "Get started" item; all articles sit directly in
  the Articles menu; superseded URLs redirect.
* New `vignette("data-manipulation")` (attach, recast, crosswalks,
  backends) and `vignette("visualization")` (the ggplot2 integration
  contract and plot-type tour; absorbs the weather-data vignette).
* `vignette("calendars")` presents the catalog by family, one icicle
  per family; the shared *scales glossary ships in
  `vignette("concepts")`. Vignette code follows the stack-wide
  tidyverse + `|>` style.

# timescales 0.1.0.9000

* Phase 1 skeleton: `Calendar` S7 class with validator, token registry
  (`register_token()`, `get_token()`, `list_tokens()`), three-layer
  constructors (`calendar()`, `calendar_build()`,
  `calendar_from_leaves()`), `as_timeframe()`, first-generation
  `instant_to_timeslice()` / `expand_calendar()` / `recast()`, three
  vignettes, pkgdown site, CI.

# timescales 0.0.0.9000

* Initial scaffolding. Successor to `timeslices`; code migration in progress.
