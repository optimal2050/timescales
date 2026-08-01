# Documentation

This directory **is** the published site: GitHub Pages serves it from the
`docs/` folder on `main`, so everything here is committed — including the built
pkgdown output under `r/`.

## Current layout

```
docs/
├── .nojekyll        # keep Jekyll away from pkgdown's *_files/ figure dirs
├── index.qmd        # landing page source (rendered with Quarto)
├── index.html       # ... and its rendered output, committed
├── styles.css       # landing page styling only
└── r/               # pkgdown site (see ../_pkgdown.yml, destination: docs/r)
```

| URL | What |
|---|---|
| `optimal2050.github.io/timescales/` | landing page, links every language |
| `optimal2050.github.io/timescales/r/` | R reference and articles |

## Rebuilding

```r
pkgdown::build_site()          # -> docs/r/
```
```sh
quarto render docs/index.qmd   # -> docs/index.html
```

Commit the result.

There is deliberately **no CI deploy yet** — the site is built locally and
committed, matching the companion `geoscales` repo. Add a `pkgdown.yaml`
workflow once the repo is public. `timescales` has no optional article
dependencies, so its build is straightforward; `geoscales` is the one that
needs `Config/Needs/website` proven first.

## Planned layout (Phases 2 and 3)

Language sections sit beside `r/`, so no existing URL moves:

```
docs/
├── _quarto.yml           # a real Quarto project, once concepts/ exists
├── concepts/             # language-agnostic concept docs
├── r/                    # pkgdown (as today)
├── python/               # Python examples (Phase 3)
├── cpp/                  # C++ examples + Doxygen-rendered API reference (Phase 2)
└── reference/            # auto-generated cross-language API index
```
