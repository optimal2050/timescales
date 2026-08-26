# Contributing to timescales

> Stack-wide conventions (naming, style, git policy, API
> principles) are unified in
> [optimal2050 CONVENTIONS.md](https://github.com/optimal2050/.github/blob/main/CONVENTIONS.md);
> this file covers the workflow of this repo.

Thanks for your interest! `timescales` is part of the optimal2050 modeling
stack and is developed alongside its spatial companion
[`geoscales`](https://github.com/optimal2050/geoscales).

> The repository is public and contributions are welcome — issues, ideas,
> and pull requests alike. The package is pre-1.0, so APIs may still move;
> open an issue first for larger changes.

## Languages and phases

- **Phase 1 (current)** — pure R implementation.
- **Phase 2** — C++17 core under `cpp/`; R bindings via Rcpp in `src/`.
- **Phase 3** — Python bindings under `python/` via nanobind + scikit-build-core.

A single semantic version (in `VERSION`) drives all language artifacts.

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

## Development workflow (R)

```r
# from the repo root
devtools::load_all()
devtools::test()                                # fast tier (default)
Sys.setenv(SCALES_TEST_TIER = "full"); devtools::test()  # backend sweep
devtools::document()
devtools::check()
```

Testing system: see `tests/README.md` (tiers, `@covers` tags, harnesses)
and `dev/TESTING.md` (recipes and traps). New behaviour lands with tests;
coverage gaps show in `tests/coverage/matrix-summary.md`
(`Rscript tools/coverage/build_matrix.R`).

Style: follow `tidyverse` style; 2-space indent; snake_case function names.

## Cross-language consistency

Language-agnostic input/output pairs live under `specs/golden/`. Each language
implementation must reproduce them identically. When you change observable
behaviour, update both the spec and the per-language tests in the same PR.

## Commit & PR conventions

- Conventional Commits style is encouraged but not enforced
  (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`).
- Open PRs against `main`. CI must pass.
- Reference related `geoscales` PRs in the description when changes affect both
  packages.

## License

By contributing you agree that your contributions are licensed under the
Apache License, Version 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
