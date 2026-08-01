# Contributing to timescales

Thanks for your interest! `timescales` is part of the optimal2050
modeling stack and is developed alongside its spatial companion
[`geoscales`](https://github.com/optimal2050/geoscales).

> **Note**: this repository is **private during pre-release**. Until the
> first public pre-release, contributions are limited to invited
> collaborators.

## Languages and phases

- **Phase 1 (current)** — pure R implementation.
- **Phase 2** — C++17 core under `cpp/`; R bindings via Rcpp in `src/`.
- **Phase 3** — Python bindings under `python/` via nanobind +
  scikit-build-core.

A single semantic version (in `VERSION`) drives all language artifacts.

## Development workflow (R)

``` r

# from the repo root
devtools::load_all()
devtools::test()
devtools::document()
devtools::check()
```

Style: follow `tidyverse` style; 2-space indent; snake_case function
names.

## Cross-language consistency

Language-agnostic input/output pairs live under `specs/golden/`. Each
language implementation must reproduce them identically. When you change
observable behaviour, update both the spec and the per-language tests in
the same PR.

## Commit & PR conventions

- Conventional Commits style is encouraged but not enforced (`feat:`,
  `fix:`, `docs:`, `refactor:`, `test:`, `chore:`).
- Open PRs against `main`. CI must pass.
- Reference related `geoscales` PRs in the description when changes
  affect both packages.

## License

By contributing you agree that your contributions are licensed under the
Apache License, Version 2.0. See
[LICENSE](https://optimal2050.github.io/timescales/r/LICENSE) and
[NOTICE](https://optimal2050.github.io/timescales/r/NOTICE).
