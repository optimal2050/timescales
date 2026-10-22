# Supported aggregation rules

Each rule defines behaviour in **both** directions of the instant grid,
so aggregation and disaggregation are one operation (the geoscales split
of extensive vs intensive quantities):

## Usage

``` r
CALENDAR_RULES
```

## Format

A character vector of length 7.

## Details

- `weighted_mean`:

  Down: copy. Up: mean weighted by the declared `leaves$share` of each
  source timeslice. For intensive quantities (load, price, efficiency).
  The default.

- `sum`:

  Down: split equally across the timeslice's grid instants. Up: sum.
  Conserves totals; for extensive quantities (energy, cost).

- `mean`:

  Down: copy. Up: plain mean over instants — a time-weighted mean, since
  the grid is uniform. Differs from `weighted_mean` exactly when
  declared shares differ from real-time coverage.

- `copy`:

  Down: copy. Up: the common value, erroring if it is not constant. For
  timeslice-invariant scalars.

- `sd`:

  Up: standard deviation over instants — the spread of the fine signal
  within each target timeslice. Aggregation-only; going finer it
  degenerates to 0/NA.

- `share`:

  Share within parent: each source timeslice's value divided by the
  total over its parent timeslice. Unlike every other rule the result
  stays keyed by the **source** calendar's timeslices – `target` (or
  `parent=`) names the parent calendar or timeframe – so it cannot be
  mixed with other rules in one call. For building profile shares and
  distribution keys; requires the source timeslices to nest within the
  parent's. The two share rules mix freely with each other, being one
  computation.

- `logshare`:

  The same computation as `share` – the values ARE shares – but figures
  draw it on a fixed log10 percent scale (0.01%..100%), where `share`
  gets a fixed linear 0..1 scale. Use it when sibling counts differ by
  orders of magnitude and the linear scale flattens the crowded groups.

## Examples

``` r
CALENDAR_RULES
#> [1] "weighted_mean" "sum"           "mean"          "copy"         
#> [5] "sd"            "share"         "logshare"     
```
