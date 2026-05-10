# Documentation (unified Quarto site + pkgdown for R reference)

This directory will host the Quarto-based documentation site that covers all
language flavours of `timescales`.

## Planned layout

```
docs/
├── _quarto.yml
├── index.qmd
├── concepts/             # language-agnostic concept docs
├── r/                    # R examples (.qmd with R chunks); pkgdown-built reference embedded here
├── python/               # Python examples (Phase 3)
├── cpp/                  # C++ examples + Doxygen-rendered API reference (Phase 2)
└── reference/            # auto-generated cross-language API index
```

While the repo is private, docs build in CI but are not deployed publicly.
GH Pages deployment is enabled at pre-release.
