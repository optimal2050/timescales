# Package index

## Calendars

Construct and inspect Calendar objects.

- [`Calendar()`](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
  : Calendar (S7 class)
- [`calendar_from_leaves()`](https://optimal2050.github.io/timescales/r/reference/calendar_from_leaves.md)
  : Build a Calendar from a flat table of leaf timeslices
- [`calendar_build()`](https://optimal2050.github.io/timescales/r/reference/calendar_build.md)
  [`calendar()`](https://optimal2050.github.io/timescales/r/reference/calendar_build.md)
  : Build a Calendar from token names
- [`prune_calendar()`](https://optimal2050.github.io/timescales/r/reference/prune_calendar.md)
  : Derive a coarser calendar by truncating the hierarchy at a timeframe

## Navigation and subsetting

Query the timeframe hierarchy and subset calendars.

- [`calendar_timeframes()`](https://optimal2050.github.io/timescales/r/reference/calendar_queries.md)
  [`calendar_rank()`](https://optimal2050.github.io/timescales/r/reference/calendar_queries.md)
  [`calendar_timeslices()`](https://optimal2050.github.io/timescales/r/reference/calendar_queries.md)
  : Calendar hierarchy queries
- [`calendar_family()`](https://optimal2050.github.io/timescales/r/reference/calendar_family.md)
  : Immediate parent-child pairs of a Calendar hierarchy
- [`calendar_children()`](https://optimal2050.github.io/timescales/r/reference/calendar_navigate.md)
  [`calendar_parents()`](https://optimal2050.github.io/timescales/r/reference/calendar_navigate.md)
  [`calendar_descendants()`](https://optimal2050.github.io/timescales/r/reference/calendar_navigate.md)
  [`calendar_ancestors()`](https://optimal2050.github.io/timescales/r/reference/calendar_navigate.md)
  : Navigate a Calendar hierarchy
- [`calendar_share()`](https://optimal2050.github.io/timescales/r/reference/calendar_share.md)
  : Duration shares at a timeframe
- [`filter_calendar()`](https://optimal2050.github.io/timescales/r/reference/filter_calendar.md)
  [`` `[`( ``*`<Calendar>`*`)`](https://optimal2050.github.io/timescales/r/reference/filter_calendar.md)
  [`` `[`( ``*`<timescales::Calendar>`*`)`](https://optimal2050.github.io/timescales/r/reference/filter_calendar.md)
  : Filter a Calendar to selected labels

## Catalog and data

The built-in calendar designs and sample data.

- [`calendar_catalog()`](https://optimal2050.github.io/timescales/r/reference/calendar_catalog.md)
  : The calendar catalog
- [`calendars`](https://optimal2050.github.io/timescales/r/reference/calendars.md)
  : Pre-built calendars from the catalog
- [`merra2_cities`](https://optimal2050.github.io/timescales/r/reference/merra2_cities.md)
  : Hourly weather sample: three cities, year 2019

## Tokens

Reusable label vocabularies for one timeframe.

- [`register_token()`](https://optimal2050.github.io/timescales/r/reference/register_token.md)
  [`get_token()`](https://optimal2050.github.io/timescales/r/reference/register_token.md)
  [`list_tokens()`](https://optimal2050.github.io/timescales/r/reference/register_token.md)
  : Register or look up a calendar token

## Timeframes

The atomic units underneath every calendar.

- [`CORE_TIMEFRAMES`](https://optimal2050.github.io/timescales/r/reference/CORE_TIMEFRAMES.md)
  : Core timeframe identifiers
- [`as_timeframe()`](https://optimal2050.github.io/timescales/r/reference/as_timeframe.md)
  : Extract timeframe values from datetime vectors

## Conversions

Move data between datetimes and calendars, and between calendars.

- [`instant_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/instant_to_timeslice.md)
  : Map datetimes to calendar timeslice IDs
- [`instant_to_slice()`](https://optimal2050.github.io/timescales/r/reference/instant_to_slice.md)
  : Deprecated alias of instant_to_timeslice()
- [`expand_calendar()`](https://optimal2050.github.io/timescales/r/reference/expand_calendar.md)
  : Enumerate the instants of one or more model years mapped to
  timeslices
- [`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md)
  : Recast values from one calendar to another
- [`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md)
  : Recast data between scales
- [`join_calendar()`](https://optimal2050.github.io/timescales/r/reference/join_calendar.md)
  : Attach a calendar's timeframe columns to timeslice-keyed data
- [`base_calendar()`](https://optimal2050.github.io/timescales/r/reference/base_calendar.md)
  : Enumerate the base instant grid for one or more years

## Visualization

Draw calendar structures and data on calendars.

- [`calendar_layout()`](https://optimal2050.github.io/timescales/r/reference/calendar_layout.md)
  : Icicle layout of a calendar's structure
- [`calendar_autoplot()`](https://optimal2050.github.io/timescales/r/reference/calendar_autoplot.md)
  [`autoplot.Calendar()`](https://optimal2050.github.io/timescales/r/reference/calendar_autoplot.md)
  [`plot(`*`<Calendar>`*`)`](https://optimal2050.github.io/timescales/r/reference/calendar_autoplot.md)
  : Plot a calendar's structure as an icicle
- [`calendar_plot()`](https://optimal2050.github.io/timescales/r/reference/calendar_plot.md)
  : Heatmap of data on a calendar
- [`geom_calendar()`](https://optimal2050.github.io/timescales/r/reference/geom_calendar.md)
  [`geom_calendar_tile()`](https://optimal2050.github.io/timescales/r/reference/geom_calendar.md)
  [`theme_calendar()`](https://optimal2050.github.io/timescales/r/reference/geom_calendar.md)
  : Calendar layers for ggplot2

## Rules and registries

Aggregation and alignment semantics, and their registries.

- [`RECAST_RULES`](https://optimal2050.github.io/timescales/r/reference/RECAST_RULES.md)
  : Supported aggregation rules
- [`ALIGNMENT_RULES`](https://optimal2050.github.io/timescales/r/reference/ALIGNMENT_RULES.md)
  : Supported alignment rules
- [`register_rule()`](https://optimal2050.github.io/timescales/r/reference/register_rule.md)
  : Register how a parameter should be recast
- [`get_rule()`](https://optimal2050.github.io/timescales/r/reference/get_rule.md)
  : Look up a registered rule
- [`list_rules()`](https://optimal2050.github.io/timescales/r/reference/list_rules.md)
  : List registered rules
- [`clear_rules()`](https://optimal2050.github.io/timescales/r/reference/clear_rules.md)
  : Clear the rule registry
- [`register_conversion()`](https://optimal2050.github.io/timescales/r/reference/register_conversion.md)
  [`get_conversion()`](https://optimal2050.github.io/timescales/r/reference/register_conversion.md)
  [`list_conversions()`](https://optimal2050.github.io/timescales/r/reference/register_conversion.md)
  [`clear_conversions()`](https://optimal2050.github.io/timescales/r/reference/register_conversion.md)
  : Register a pairwise calendar conversion override

## Deprecated

- [`calendar_recast()`](https://optimal2050.github.io/timescales/r/reference/timescales-deprecated.md)
  [`calendar_join()`](https://optimal2050.github.io/timescales/r/reference/timescales-deprecated.md)
  [`calendar_at_level()`](https://optimal2050.github.io/timescales/r/reference/timescales-deprecated.md)
  : Deprecated timescales functions

## Package

- [`timescales`](https://optimal2050.github.io/timescales/r/reference/timescales-package.md)
  [`timescales-package`](https://optimal2050.github.io/timescales/r/reference/timescales-package.md)
  : timescales: Nested Timeframes and Calendars for Modeling
