# Supported aggregation rules

Each rule defines behaviour in **both** directions of the instant grid,
so aggregation and disaggregation are one operation (the geoscales split
of extensive vs intensive quantities):

## Usage

``` r
RECAST_RULES
```

## Format

A character vector of length 5.

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

## Examples

``` r
RECAST_RULES
#> [1] "weighted_mean" "sum"           "mean"          "copy"         
#> [5] "sd"           
```
