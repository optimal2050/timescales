# timescales

<!-- badges: start -->
[![R-CMD-check](https://github.com/optimal2050/timescales/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/optimal2050/timescales/actions/workflows/R-CMD-check.yaml)
[![test-coverage](https://github.com/optimal2050/timescales/actions/workflows/test-coverage.yaml/badge.svg)](https://github.com/optimal2050/timescales/actions/workflows/test-coverage.yaml)
[![lint](https://github.com/optimal2050/timescales/actions/workflows/lint.yaml/badge.svg)](https://github.com/optimal2050/timescales/actions/workflows/lint.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

> Nested timeframes and calendars for optimization and simulation models.

`timescales` is the **time-domain** package of the optimal2050 modeling stack and
the successor to [`timeslices`](https://github.com/optimal2050/timeslices). Its
companion package [`geoscales`](https://github.com/optimal2050/geoscales) covers
the spatial dimension.

This is a **multi-language** project. The R package is the current focus
(Phase 1); a C++ core (Phase 2) and a Python port (Phase 3) are planned.

## Documentation

- **[Project site](https://optimal2050.github.io/timescales/)** — entry point
  for all language flavours
- **[R reference and articles](https://optimal2050.github.io/timescales/r/)**

## Status

🚧 In development — pre-1.0, APIs may still change between minor
versions. Feedback and issues are welcome.

## Installation

```r
# From GitHub
remotes::install_github("optimal2050/timescales")
```

Or via [r-universe](https://optimal2050.r-universe.dev/):

```r
install.packages("timescales", repos = "https://optimal2050.r-universe.dev")
```

## Repository layout

```
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
```

## License

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
