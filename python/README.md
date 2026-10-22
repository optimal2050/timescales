# timescales (Python)

Python binding of the R package
[timescales](https://github.com/optimal2050/timescales): calendars and
timeslices for modeling, built on
[nestedscales](https://github.com/optimal2050/nestedscales). A calendar is a
nested partition of a model year (months, days, hours, weeks, seasons, fiscal
years, representative hours); data is converted between calendars through
the datetime grid of a year.

```python
import pyarrow as pa
import timescales as ts

m12, q4 = ts.calendar("m12"), ts.calendar("q4")
d = pa.table({"timeslice": ts.calendar_timeslices(m12),
              "energy": [float(i) for i in range(1, 13)]})
ts.recast_calendar(d, m12, q4, year=2021, rule="sum")

cal = ts.calendar("d365_h24")
ts.datetime_to_timeslice(ts.base_calendar(2021)["datetime"][:3], cal)
ts.tsl2month(["d032_h00"], cal)
```

## Scope

Ported: tokens and the 43-design catalog, `calendar()` /
`calendar_build()` / `calendar_from_leaftable()`, navigation and queries,
`filter_calendar()` / `prune_calendar()`, the datetime engine
(`base_calendar`, `expand_calendar`, `datetime_to_timeslice`,
`as_timeframe`), `calendar_map()` / `calendar_map_between()`,
`recast_calendar()` (including the share rules), `recast_to_timebase()` /
`recast_from_timebase()`, `join_calendar()`, and the timeslice conversions
(`tsl2*`, `dtm2tsl`, `hour2HOUR`, `yday2YDAY`). Plotting (`calendar_plot`,
`geom_calendar`, wall layouts) stays in R.

Function names match R. As agreed for the whole stack, R's `from`/`to`
arguments are `source`/`target` (R renames them in its next release), and
the `clear_*` functions take `name`. Error and warning messages are R's.

Datetimes are pyarrow timestamps (or numpy, pandas, polars, Python
datetimes); fields are read in the array's time zone with lubridate's
conventions. Data may be pyarrow, pandas, polars or a lazy pyarrow
Dataset / polars LazyFrame, and results come back in the caller's type.

`as_calendar()` restores a Calendar from a scale reopened with
`nestedscales.open_scale_dataset()`.

## Provenance

The R package is the original implementation. This Python binding was
translated from it with the AI coding assistant Claude Code, function by
function, and is checked against results generated from the R sources
(see Verification below). Human review and contributions are very
welcome; issues and pull requests go to
<https://github.com/optimal2050/timescales>.

## Verification

* `specs/golden/` -- the language-neutral cases the R suite also replays;
* `specs/json/` -- a broad set written by `tools/specs/make_json_goldens.R`
  from the R sources (with nestedscales as submitted to CRAN): every catalog
  calendar, datetime labelling across leap years, fiscal anchors, UTC
  offsets and time zones, crosswalks, every recast rule, navigation, joins
  and conversions, with warning and error text.

```sh
python -m venv .venv
.venv/Scripts/python -m pip install -e "../../nestedscales/python" -e ".[test]" pyyaml
.venv/Scripts/python -m pytest -q
Rscript tools/specs/make_json_goldens.R      # from the repository root
```
