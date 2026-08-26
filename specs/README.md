# Specs and golden tests (cross-language)

Language-agnostic input/output pairs and named calendars. All three language
implementations (R, C++, Python) load fixtures from this directory and must
reproduce identical results.

## Layout

```
specs/
├── calendars/            # named calendars in YAML (ENTSO-E, fiscal year, ...)
└── golden/               # input → expected-output pairs
    ├── 001-basic-nesting/
    │   ├── input.yaml
    │   └── expected.csv
    └── ...
```

Generated and re-verified by the R implementation:
`Rscript tools/specs/make_goldens.R` writes the files (byte-stable), and
`tests/testthat/test-specs-golden.R` re-runs every case against them.
When you change observable behaviour, regenerate the goldens in the same
PR — the diff is the review artifact.
