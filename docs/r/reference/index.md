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
  : Enumerate every instant in a year mapped to its calendar slice
- [`recast()`](https://optimal2050.github.io/timescales/r/reference/recast.md)
  : Recast values from one calendar to another

## Package

- [`timescales`](https://optimal2050.github.io/timescales/r/reference/timescales-package.md)
  [`timescales-package`](https://optimal2050.github.io/timescales/r/reference/timescales-package.md)
  : timescales: Nested Timeframes and Calendars for Modeling
