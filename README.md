# timescales

> Nested timeframes and calendars for optimization and simulation models.

`timescales` is the **time-domain** package of the optimal2050 modeling stack and
the successor to [`timeslices`](https://github.com/optimal2050/timeslices). Its
companion package [`geoscales`](https://github.com/optimal2050/geoscales) covers
the spatial dimension.

This is a **multi-language** project. The R package is the current focus
(Phase 1); a C++ core (Phase 2) and a Python port (Phase 3) are planned.

## Status

🚧 Pre-release — APIs are unstable. Repository is private until first
pre-release.

## Installation

```r
# From GitHub (private during pre-release; requires access)
# remotes::install_github("optimal2050/timescales")
```

After pre-release, also via [r-universe](https://optimal2050.r-universe.dev/):

```r
# install.packages("timescales", repos = "https://optimal2050.r-universe.dev")
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
