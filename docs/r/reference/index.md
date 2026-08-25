# Package index

## Calendars

Construct and inspect Calendar objects.

- [`Calendar()`](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
  : Calendar (S7 class)
- [`calendar_from_leaftable()`](https://optimal2050.github.io/timescales/r/reference/calendar_from_leaftable.md)
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
- [`calendar_leaftable()`](https://optimal2050.github.io/timescales/r/reference/calendar_leaftable.md)
  : The leaftable of a Calendar
- [`calendar_family()`](https://optimal2050.github.io/timescales/r/reference/calendar_family.md)
  : Immediate parent-child pairs of a Calendar hierarchy
- [`calendar_ancestry()`](https://optimal2050.github.io/timescales/r/reference/calendar_ancestry.md)
  : All ancestor-descendant pairs of a Calendar hierarchy
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
- [`calendar_coverage()`](https://optimal2050.github.io/timescales/r/reference/calendar_coverage.md)
  : Coverage of a sampled Calendar

## Catalog and data

The built-in calendar designs and sample data.

- [`calendar_catalog()`](https://optimal2050.github.io/timescales/r/reference/calendar_catalog.md)
  : The calendar catalog
- [`calendars`](https://optimal2050.github.io/timescales/r/reference/calendars.md)
  : Pre-built calendars from the catalog
- [`merra2_cities`](https://optimal2050.github.io/timescales/r/reference/merra2_cities.md)
  : Hourly weather sample: twelve cities, year 2019

## Tokens

Reusable label vocabularies for one timeframe.

- [`register_calendar_token()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_token.md)
  [`get_calendar_token()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_token.md)
  [`list_calendar_tokens()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_token.md)
  : Register or look up a calendar token

## Timeframes

The atomic units underneath every calendar.

- [`CORE_TIMEFRAMES`](https://optimal2050.github.io/timescales/r/reference/CORE_TIMEFRAMES.md)
  : Core timeframe identifiers
- [`as_timeframe()`](https://optimal2050.github.io/timescales/r/reference/as_timeframe.md)
  : Extract timeframe values from datetime vectors

## Conversions

Move data between datetimes and calendars, and between calendars.

- [`datetime_to_timeslice()`](https://optimal2050.github.io/timescales/r/reference/datetime_to_timeslice.md)
  : Map datetimes to calendar timeslice IDs
- [`expand_calendar()`](https://optimal2050.github.io/timescales/r/reference/expand_calendar.md)
  : Enumerate the base grid of one or more model years mapped to
  timeslices
- [`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md)
  : Recast values from one calendar to another
- [`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md)
  : Recast data between scales
- [`recast_to_timebase()`](https://optimal2050.github.io/timescales/r/reference/recast_to_timebase.md)
  [`recast_from_timebase()`](https://optimal2050.github.io/timescales/r/reference/recast_to_timebase.md)
  : Recast timeslice data down to the base grid, and back
- [`calendar_map()`](https://optimal2050.github.io/timescales/r/reference/calendar_map.md)
  : Crosswalk between two calendars over the base grid
- [`register_calendar_map()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_map.md)
  : Register / look up a direct calendar crosswalk
- [`get_calendar_map()`](https://optimal2050.github.io/timescales/r/reference/get_calendar_map.md)
  : Look up one registered crosswalk
- [`list_calendar_maps()`](https://optimal2050.github.io/timescales/r/reference/list_calendar_maps.md)
  : List the registered crosswalks
- [`clear_calendar_maps()`](https://optimal2050.github.io/timescales/r/reference/clear_calendar_maps.md)
  : Clear the crosswalk cache (and optionally the registered maps)
- [`join_calendar()`](https://optimal2050.github.io/timescales/r/reference/join_calendar.md)
  : Attach a calendar to a dataset
- [`base_calendar()`](https://optimal2050.github.io/timescales/r/reference/base_calendar.md)
  : Enumerate the base instant grid for one or more years

## Visualization

Draw calendar structures and data on calendars.

- [`calendar_layout()`](https://optimal2050.github.io/timescales/r/reference/calendar_layout.md)
  : Icicle layout of a calendar's structure
- [`calendar_autoplot()`](https://optimal2050.github.io/timescales/r/reference/calendar_autoplot.md)
  [`autoplot(`*`<Calendar>`*`)`](https://optimal2050.github.io/timescales/r/reference/calendar_autoplot.md)
  [`plot(`*`<Calendar>`*`)`](https://optimal2050.github.io/timescales/r/reference/calendar_autoplot.md)
  : Plot a calendar's structure as an icicle
- [`calendar_plot()`](https://optimal2050.github.io/timescales/r/reference/calendar_plot.md)
  : Heatmap of data on a calendar
- [`calendar_wall_plot()`](https://optimal2050.github.io/timescales/r/reference/calendar_wall_plot.md)
  : Wall-calendar figure
- [`calendar_wall_layout()`](https://optimal2050.github.io/timescales/r/reference/calendar_wall_layout.md)
  : Wall-calendar tile layout
- [`calendar_weekdays()`](https://optimal2050.github.io/timescales/r/reference/calendar_weekdays.md)
  : Weekdays of a calendar's day layer in a given model year
- [`geom_calendar()`](https://optimal2050.github.io/timescales/r/reference/geom_calendar.md)
  [`geom_calendar_tile()`](https://optimal2050.github.io/timescales/r/reference/geom_calendar.md)
  [`theme_calendar()`](https://optimal2050.github.io/timescales/r/reference/geom_calendar.md)
  : Calendar layers for ggplot2
- [`calendar_breaks()`](https://optimal2050.github.io/timescales/r/reference/calendar_breaks.md)
  : Thinned discrete breaks that keep the end values

## Rules and registries

Aggregation and alignment semantics, and their registries.

- [`CALENDAR_RULES`](https://optimal2050.github.io/timescales/r/reference/CALENDAR_RULES.md)
  : Supported aggregation rules
- [`ALIGNMENT_RULES`](https://optimal2050.github.io/timescales/r/reference/ALIGNMENT_RULES.md)
  : Supported alignment rules
- [`register_calendar_rule()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_rule.md)
  : Register how a parameter should be recast
- [`get_calendar_rule()`](https://optimal2050.github.io/timescales/r/reference/get_calendar_rule.md)
  : Look up a registered rule
- [`list_calendar_rules()`](https://optimal2050.github.io/timescales/r/reference/list_calendar_rules.md)
  : List registered rules
- [`clear_calendar_rules()`](https://optimal2050.github.io/timescales/r/reference/clear_calendar_rules.md)
  : Clear the rule registry
- [`register_calendar_conversion()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_conversion.md)
  [`get_calendar_conversion()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_conversion.md)
  [`list_calendar_conversions()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_conversion.md)
  [`clear_calendar_conversions()`](https://optimal2050.github.io/timescales/r/reference/register_calendar_conversion.md)
  : Register a pairwise calendar conversion override

## Package

- [`timescales`](https://optimal2050.github.io/timescales/r/reference/timescales-package.md)
  [`timescales-package`](https://optimal2050.github.io/timescales/r/reference/timescales-package.md)
  : timescales: Nested Timeframes and Calendars for Modeling
