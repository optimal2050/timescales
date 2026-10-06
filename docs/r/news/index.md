# Changelog

## timescales 0.5.0.9000

### The shared core

- The [`recast()`](https://rdrr.io/pkg/multiscales/man/recast.html)
  generic is now owned by `multiscales`, the dimension-agnostic core,
  and re-exported here.
  [`timescales::recast`](https://rdrr.io/pkg/multiscales/man/recast.html)
  resolves exactly as before and dispatches on `Calendar` exactly as
  before – the object behind the name is simply shared with `geoscales`
  rather than owned by this package. Nothing changes for callers.
- [`calendar_ancestry()`](https://optimal2050.github.io/timescales/r/reference/calendar_ancestry.md),
  [`calendar_share()`](https://optimal2050.github.io/timescales/r/reference/calendar_share.md),
  [`calendar_coverage()`](https://optimal2050.github.io/timescales/r/reference/calendar_coverage.md)
  and the navigation verbs
  ([`calendar_children()`](https://optimal2050.github.io/timescales/r/reference/calendar_navigate.md),
  [`calendar_parents()`](https://optimal2050.github.io/timescales/r/reference/calendar_navigate.md),
  [`calendar_descendants()`](https://optimal2050.github.io/timescales/r/reference/calendar_navigate.md),
  [`calendar_ancestors()`](https://optimal2050.github.io/timescales/r/reference/calendar_navigate.md))
  now compute through `multiscales`. Their output is unchanged.
- Rules registered with
  [`register_calendar_rule()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_rule.md)
  are kept in the `multiscales` registry under the scope `"calendar"`,
  so
  [`multiscales::recast_scale()`](https://rdrr.io/pkg/multiscales/man/recast_scale.html)
  on a Calendar finds them too. A rule registered there without a scope
  now also applies to calendars.
- [`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md)
  aggregates through
  [`multiscales::recast_crosswalk()`](https://rdrr.io/pkg/multiscales/man/recast_crosswalk.html).
  Results are unchanged. Panel data no longer builds an in-memory grid
  of every identifier combination times the crosswalk before joining.
- [`expand_calendar()`](https://optimal2050.github.io/timescales/r/reference/expand_calendar.md)
  and
  [`datetime_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/datetime_to_timeslice.md)
  label a sampled calendar correctly when it carries no recorded tokens
  (one rebuilt from a leaftable, as energyRt’s sampled calendars are).
  Before, every grid point came back `NA`: day numbers were measured
  against the sampled days rather than the whole year.
- [`calendar_family()`](https://optimal2050.github.io/timescales/r/reference/calendar_family.md)
  returns an empty table, not a 1 x 1 logical matrix, when
  `parent=`/`child=` select no timeframe pair.
- `multiscales` is added to `Imports`. It brings no new external
  dependency: its own imports (`dplyr`, `rlang`, `S7`, `stats`, `utils`)
  were already ours.

### Timeslice conversions

- [`tsl2hour()`](https://optimal2050.github.io/timescales/r/reference/timeslice_conversions.md),
  [`tsl2yday()`](https://optimal2050.github.io/timescales/r/reference/timeslice_conversions.md),
  [`tsl2month()`](https://optimal2050.github.io/timescales/r/reference/timeslice_conversions.md),
  [`hour2HOUR()`](https://optimal2050.github.io/timescales/r/reference/timeslice_conversions.md),
  [`yday2YDAY()`](https://optimal2050.github.io/timescales/r/reference/timeslice_conversions.md),
  [`tsl2dtm()`](https://optimal2050.github.io/timescales/r/reference/timeslice_datetime.md)
  and
  [`dtm2tsl()`](https://optimal2050.github.io/timescales/r/reference/timeslice_datetime.md)
  read a timeframe off a timeslice, and convert between timeslices and
  datetimes. They move here from energyRt, where they parsed the label
  text with regular expressions.
- Each takes the calendar the timeslices belong to – as an object or by
  name, `tsl2hour(tsl, "d365_h24")`. The calendar is what replaces the
  guessing: the answer is a join against
  [`calendar_leaftable()`](https://optimal2050.github.io/timescales/r/reference/calendar_leaftable.md)
  when the calendar holds the timeframe,
  [`calendar_map()`](https://optimal2050.github.io/timescales/r/reference/calendar_map.md)
  when it does not, and the timeslice’s instant when no token claims it.
- A timeframe is available when it is a function of the calendar’s
  timeslices. `tsl2hour(tsl, "m12")` is an error naming the reason – a
  month spans 24 hours, so there is no single one to return – rather
  than a `NULL`.
- This reads vocabularies the regular expressions could not: `m12a`
  (`"JAN"`..`"DEC"`), `wd7` (`"MON"`..`"SUN"`), `q4`, `s4`, `hp3`, and
  any token added with
  [`register_calendar_token()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_token.md).
  It also fixes a wrong answer: `h168` labels hours of the *week* as
  `"h000"`..`"h167"`, which a pattern for `h` plus digits read as hours
  of the day.
- [`as_timeframe()`](https://optimal2050.github.io/timescales/r/reference/as_timeframe.md)
  is the verb underneath, and now accepts timeslice labels and integers
  as well as datetimes – so
  `as_timeframe(0:23, "HOUR", format = "token")` gives `"h00"`..`"h23"`,
  and a `calendar` argument selects that calendar’s own spelling over
  the canonical one.
- `year` is required for the weekday-derived timeframes (`WDAY`,
  `MWEEK`, `DAYTYPE`, `WHOUR`, and `YEAR`), whose value depends on which
  year the timeslices fall in. `MONTH`, `YDAY`, `QUARTER`, `SEASON`,
  `WEEK` and `MDAY` are the same in every year and need no year.
- Sampled calendars are handled throughout. A calendar filtered to a few
  representative days holds a SUBSET of its parent’s timeslices, and its
  labels keep the meaning they had in the parent: `tsl2yday("d015_h00")`
  is day 15, not the first day the calendar happens to hold. The number
  is read from the timeframe’s full vocabulary (`meta$tokens`, or
  inferred from the labels for a hand-built calendar) rather than from
  the calendar’s own member list.
- [`tsl2dtm()`](https://optimal2050.github.io/timescales/r/reference/timeslice_datetime.md)
  dates a sampled calendar’s timeslices against its parent, because
  [`expand_calendar()`](https://optimal2050.github.io/timescales/r/reference/expand_calendar.md)
  leaves a filtered calendar’s grid unlabelled. A timeframe that no
  crosswalk can reach falls back to the timeslice’s instant, so a
  sampled calendar still resolves `MONTH`.

### Calendars and rules

- New rule `"share"`: share within parent. Each source timeslice’s value
  over its parent-timeslice total, keyed by the *source* calendar –
  `recast_calendar(x, cal, to = "YDAY", rule = "share")` gives each
  hour’s share within its day, summing to 1 per parent. The parent is
  `to` (a calendar or timeframe name, `"ANNUAL"` included), or the new
  `parent=` argument (default: `from` pruned to its second-finest
  timeframe); the source timeslices must nest within it. `"logshare"` is
  the same computation with a log-scale display intent. Mirrored in
  geoscales.

- The calendar figures’ data fills accept both share rules: every row is
  coloured by each timeslice’s share within the row above it (ANNUAL by
  its share of the year), legend “Share” – `"share"` on a fixed linear
  0..1 scale, `"logshare"` on a fixed log10 percent scale.

- [`summary()`](https://rdrr.io/r/base/summary.html) output now prints
  with its formatted view from user code: the local `print` binding S7
  leaves in the namespace had captured the `S3method()` registration of
  `print.summary_Calendar`, so the method was invisible outside the
  package. Registered against base’s `print` in `.onLoad` (same fix in
  geoscales).

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
- [`recast()`](https://rdrr.io/pkg/multiscales/man/recast.html) is an S7
  generic dispatching on the scale object, so pipelines chain across
  packages: `x |> recast(cal_a, cal_b) |> recast(gs, to = "country")`.
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
  / [`recast()`](https://rdrr.io/pkg/multiscales/man/recast.html), three
  vignettes, pkgdown site, CI.

## timescales 0.0.0.9000

- Initial scaffolding. Successor to `timeslices`; code migration in
  progress.
