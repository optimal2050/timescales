"""Replay specs/golden/*: the language-neutral cases written by
tools/specs/make_goldens.R (a port of its `run_spec_op()`)."""
import csv
import math
import warnings
from pathlib import Path

import pyarrow as pa
import pytest
import yaml

import timescales as ts

SPECS = Path(__file__).resolve().parents[2] / "specs"
CASES = sorted(p for p in (SPECS / "golden").iterdir() if p.is_dir())


def load_structure(name):
    y = yaml.safe_load((SPECS / "calendars" / ("%s.yaml" % name)).read_text())
    rows = y["leaftable"]
    cols = {k: [r[k] for r in rows] for k in rows[0]}
    for c in ("share", "weight"):
        cols[c] = [float(v) for v in cols[c]]
    tfs = y["timeframes"] if isinstance(y["timeframes"], list) else [y["timeframes"]]
    return ts.calendar_from_leaftable(pa.table(cols), timeframes=tfs, name=y["name"],
                                      year_fraction=sum(cols["share"]))


def run_spec_op(spec):
    rows = spec.get("input") or []
    x = pa.Table.from_pylist(rows) if rows else pa.table({})
    p = spec["params"]
    src = load_structure(spec["structure"])
    op = spec["op"]
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        if op == "recast":
            out = ts.recast_calendar(x, src, load_structure(p["to"]), year=p["year"],
                                     rule=p["rule"], by=p.get("by"),
                                     na_action=p.get("na_action", "drop"))
        elif op == "recast_to_frame":
            out = ts.recast_calendar(x, src, p["to_timeframe"], year=p["year"],
                                     rule=p["rule"], by=p.get("by"))
        elif op == "join":
            tfs = p.get("timeframes")
            out = ts.join_calendar(x, src, timeframes=tfs, meta=bool(p.get("meta")),
                                   as_factor=False)
        elif op == "filter":
            out = ts.calendar_leaftable(ts.filter_calendar(src, p["timeframe"],
                                                           p["labels"]))
        elif op == "prune":
            out = ts.calendar_leaftable(ts.prune_calendar(src, p["timeframe"]))
        else:
            raise AssertionError("unknown op " + op)
    return out


def norm(v):
    if v is None or v == "NA":
        return None
    try:
        f = float(v)
    except (TypeError, ValueError):
        return str(v)
    return None if math.isnan(f) else f


def same(a, b):
    if isinstance(a, float) and isinstance(b, float):
        return math.isclose(a, b, rel_tol=1e-12, abs_tol=1e-12)
    return a == b


@pytest.mark.parametrize("case", CASES, ids=[c.name for c in CASES])
def test_spec_golden(case):
    spec = yaml.safe_load((case / "input.yaml").read_text())
    with (case / "expected.csv").open(newline="") as fh:
        expected = list(csv.DictReader(fh))
    got = run_spec_op(spec)
    cols = list(expected[0].keys())
    assert got.column_names == cols or sorted(got.column_names) == sorted(cols)
    key = [c for c in ("id", "timeslice") if c in cols] or [cols[0]]
    rows = sorted(got.to_pylist(), key=lambda r: tuple(str(r[k]) for k in key))
    want = sorted(expected, key=lambda r: tuple(str(r[k]) for k in key))
    assert len(rows) == len(want)
    for r, w in zip(rows, want, strict=True):
        for c in cols:
            assert same(norm(r[c]), norm(w[c])), (c, r, w)
