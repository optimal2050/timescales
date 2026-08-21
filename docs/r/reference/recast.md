# Recast data between scales

The pipeline verb of the \*scales family: convert `x` between two
resolutions of one dimension, dispatching on the scale object given as
`from` – a
[Calendar](https://optimal2050.github.io/timescales/r/reference/Calendar.md)
here; a `Geoscale` when the geoscales package is loaded (which registers
its own method). This lets one verb chain across dimensions:

## Usage

``` r
recast(x, from, ...)
```

## Arguments

- x:

  The data to convert, in any supported backend.

- from:

  The source scale object (here: the source
  [Calendar](https://optimal2050.github.io/timescales/r/reference/Calendar.md)).

- ...:

  Passed to the dispatched worker; for the Calendar method the arguments
  of
  [`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md)
  (`to`, `year`, `key`, `values`, `rule`, `by`, `tz`, `na_action`,
  `collect`).

## Value

The converted data (see the worker's documentation).

## Details

    x |>
      recast(cal_hourly, cal_monthly, year = 2021) |>
      recast(gs, to = "country")

The explicit per-package workers remain available:
[`recast_calendar()`](https://optimal2050.github.io/timescales/r/reference/recast_calendar.md)
and
[`geoscales::recast_geoscale()`](https://optimal2050.github.io/geoscales/r/reference/recast_geoscale.html).
