
<!-- README.md is generated from README.Rmd. Edit THIS file, then knit:
     devtools::build_readme()  (or knitr::knit("README.Rmd"))          -->

# timescales

<!-- badges: start -->

[![R-CMD-check](https://github.com/optimal2050/timescales/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/optimal2050/timescales/actions/workflows/R-CMD-check.yaml)
[![test-coverage](https://github.com/optimal2050/timescales/actions/workflows/test-coverage.yaml/badge.svg)](https://github.com/optimal2050/timescales/actions/workflows/test-coverage.yaml)
[![lint](https://github.com/optimal2050/timescales/actions/workflows/lint.yaml/badge.svg)](https://github.com/optimal2050/timescales/actions/workflows/lint.yaml)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

> Nested timeframes and calendars for optimization and simulation
> models.

`timescales` is the **time-domain** package of the optimal2050 modeling
stack and the successor to
[`timeslices`](https://github.com/optimal2050/timeslices). Its companion
package [`geoscales`](https://github.com/optimal2050/geoscales) covers
the spatial dimension.

This is a **multi-language** project. The R package is the current focus
(Phase 1); a C++ core (Phase 2) and a Python port (Phase 3) are planned.

## Quick demo

A **Calendar** is a named slicing of the year — 43 curated designs ship
pre-built in the `calendars` catalog, from `d365_h24` down to
typical-period compressions and April-anchored fiscal years
(`calendar("m12")` builds any of them fresh). Inside: one leaftable row
per timeslice, with duration-proportional shares:

``` r
library(timescales)

cal <- calendars$m12
cal
#> Calendar: m12 
#> Timeframes (1):
#>   - MONTH (12) [token: m12]
#> Leaf timeslices: 12
#> year_fraction: 1
#> year_start: month=1, day=1
#> utc_offset_minutes: 0
head(cal@leaftable, 3)
#>   MONTH      share weight timeslice
#> 1   m01 0.08493151    744       m01
#> 2   m02 0.07671233    672       m02
#> 3   m03 0.08493151    744       m03
```

Key your data by its timeslices and the calendar decorates the table —
`join_calendar()` attaches the label and share/weight columns under the
calendar’s own name:

``` r
monthly <- data.frame(
  timeslice = cal@leaftable$timeslice,
  load = c(120, 118, 105, 92, 85, 88, 95, 100, 98, 90, 105, 122)
)

monthly |> join_calendar(cal, meta = TRUE) |> head(3)
#>   timeslice load m12  m12.share m12.weight
#> 1       m01  120 m01 0.08493151        744
#> 2       m02  118 m02 0.07671233        672
#> 3       m03  105 m03 0.08493151        744
```

Converting between two calendars is one verb, with one rule per value
column and conserved totals:

``` r
monthly |>
  recast_calendar(from = cal, to = calendar("q4"),
                  year = 2025, rule = "weighted_mean", by = "day")
#>   timeslice      load
#> 1        Q1 114.21111
#> 2        Q2  88.29670
#> 3        Q3  97.66304
#> 4        Q4 105.67391
```

Datetime data lands on a calendar as one ggplot2 layer
(`geom_calendar()`), and the same day-level story draws as a wall
calendar:

``` r
library(ggplot2)
x <- data.frame(
  t = as.POSIXct("2021-01-01", tz = "UTC") + 3600 * (0:8759),
  v = sin((1:8760) / 1394) + sin((1:8760) %% 24 / 3.8)
)
ggplot(x) +
  geom_calendar(calendar = calendars$d365_h24, datetime = "t", z = "v") +
  scale_fill_viridis_c(option = "H") +
  scale_x_discrete(breaks = calendar_breaks(10)) +
  scale_y_discrete(breaks = calendar_breaks()) +
  labs(x = "day of year", y = "hour", fill = NULL,
       title = "A year of hourly data on the d365_h24 calendar") +
  theme_calendar()
```

<img src="man/figures/README-demo-heatmap-1.png" alt="" width="100%" />

``` r
set.seed(42)
daily <- data.frame(
  timeslice = calendars$m12_md365@leaftable$timeslice,
  v = cumsum(rnorm(365))
)
calendar_wall_plot(calendar("m12_md365"), daily, z = "v", year = 2021) +
  scale_fill_viridis_c(option = "G") +
  labs(fill = NULL, title = "The same year as a wall calendar")
```

<img src="man/figures/README-demo-wall-1.png" alt="" width="100%" />

See `vignette("timescales")` for the 5-minute tour, and the
[visualization
article](https://optimal2050.github.io/timescales/r/articles/visualization.html)
for heatmaps, profiles, ribbons, and duration curves on real weather
data.

## Documentation

- **[Project site](https://optimal2050.github.io/timescales/)** — entry
  point for all language flavours
- **[R reference and
  articles](https://optimal2050.github.io/timescales/r/)**

## Status

🚧 In development — pre-1.0, APIs may still change between minor
versions. Feedback and issues are welcome.

## Installation

``` r
# From GitHub
remotes::install_github("optimal2050/timescales")
```

Or via [r-universe](https://optimal2050.r-universe.dev/):

``` r
install.packages("timescales", repos = "https://optimal2050.r-universe.dev")
```

## Repository layout

    timescales/
    ├── DESCRIPTION, NAMESPACE, R/, man/, tests/, vignettes/   # R package (root)
    ├── inst/include/timescales/                               # C++ headers (Phase 2)
    ├── src/                                                   # Rcpp glue (Phase 2)
    ├── cpp/                                                   # standalone C++ core (Phase 2)
    ├── python/                                                # Python package (Phase 3)
    ├── docs/                                                  # unified Quarto site
    ├── specs/                                                 # cross-language golden tests
    ├── benchmark/                                             # cross-language benchmarks
    └── .github/workflows/                                     # CI

## License

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
