# Package index

## Calendars

Construct and inspect Calendar objects.

- [`Calendar()`](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
  : Calendar (S7 class)
- [`calendar_from_leaves()`](https://optimal2050.github.io/timescales/r/reference/calendar_from_leaves.md)
  : Build a Calendar from a flat table of leaf slices
- [`calendar_build()`](https://optimal2050.github.io/timescales/r/reference/calendar_build.md)
  [`calendar()`](https://optimal2050.github.io/timescales/r/reference/calendar_build.md)
  : Build a Calendar from token names
- [`calendar_at_level()`](https://optimal2050.github.io/timescales/r/reference/calendar_at_level.md)
  : Derive a coarser calendar by truncating the hierarchy at a timeframe

## Catalog

The built-in calendar designs.

- [`calendar_catalog()`](https://optimal2050.github.io/timescales/r/reference/calendar_catalog.md)
  : The calendar catalog
- [`calendars`](https://optimal2050.github.io/timescales/r/reference/calendars.md)
  : Pre-built calendars from the catalog

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

- [`instant_to_slice()`](https://optimal2050.github.io/timescales/r/reference/instant_to_slice.md)
  : Map datetimes to calendar slice IDs
- [`expand_calendar()`](https://optimal2050.github.io/timescales/r/reference/expand_calendar.md)
  : Enumerate the instants of one or more model years mapped to slices
- [`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md)
  : Recast values from one calendar to another
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

## Package

- [`timescales`](https://optimal2050.github.io/timescales/r/reference/timescales-package.md)
  [`timescales-package`](https://optimal2050.github.io/timescales/r/reference/timescales-package.md)
  : timescales: Nested Timeframes and Calendars for Modeling
