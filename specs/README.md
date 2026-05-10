# Specs and golden tests (cross-language)

Language-agnostic input/output pairs and named calendars. All three language
implementations (R, C++, Python) load fixtures from this directory and must
reproduce identical results.

## Planned layout

```
specs/
├── calendars/            # named calendars in YAML (ENTSO-E, fiscal year, ...)
└── golden/               # input → expected-output pairs
    ├── 001-basic-nesting/
    │   ├── input.yaml
    │   └── expected.csv
    └── ...
```

When you change observable behaviour, update the spec and per-language tests in
the same PR.
