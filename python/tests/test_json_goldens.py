"""Replay specs/json/*.json, written by tools/specs/make_json_goldens.R from
the R sources: construction, datetimes, grids and maps, recast, navigation,
conversions -- results, warnings and error messages."""
import datetime as dt
import json
import math
import warnings
from pathlib import Path

import nestedscales as ns
import pyarrow as pa
import pytest

import timescales as ts

JSON = Path(__file__).resolve().parents[2] / "specs" / "json"
TOPICS = ["construct", "datetime", "grid", "recast", "navigate", "convert"]
CASES = [(t, i, c) for t in TOPICS
         for i, c in enumerate(json.loads((JSON / ("%s.json" % t)).read_text(
             encoding="utf-8"))["cases"])]

# R still spells these from/to; translate until the R rename lands.
R_ARGS = {"from": "source", "to": "target"}
R_MESSAGE = [("`from`", "`source`"), ("`to`", "`target`")]


def r_message(m):
    for a, b in R_MESSAGE:
        m = m.replace(a, b)
    return m


def parse_iso(s):
    if s is None:
        return None
    return dt.datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc)


def build_cal(spec):
    args = spec.get("args") or {}
    if isinstance(args, list):
        args = {}
    x = ts.calendar(spec["name"], **args)
    if spec.get("filter"):
        tf, labels = spec["filter"]
        x = ts.filter_calendar(x, tf, labels)
    if spec.get("prune"):
        x = ts.prune_calendar(x, spec["prune"])
    return x


def build_table(spec):
    cols = {}
    for name, vals in spec["columns"].items():
        ty = spec["types"][name]
        if ty == "string":
            cols[name] = pa.array(vals, pa.string())
        elif ty == "datetime":
            cols[name] = pa.array([parse_iso(v) for v in vals],
                                  pa.timestamp("s", tz="UTC"))
        else:
            cols[name] = pa.array(vals, pa.float64())
    return pa.table(cols)


def decode(a):
    if isinstance(a, dict):
        if "calendar" in a:
            return build_cal(a["calendar"])
        if "table" in a:
            return build_table(a["table"])
        if "datetime" in a:
            vals = a["datetime"] if isinstance(a["datetime"], list) else [a["datetime"]]
            arr = pa.array([parse_iso(v) for v in vals], pa.timestamp("s", tz="UTC"))
            tz = a.get("tz")
            return arr.cast(pa.timestamp("s", tz=tz)) if tz else arr
    return a


def call_args(args):
    if isinstance(args, list):
        return [decode(v) for v in args], {}
    pos = [decode(v) for k, v in args.items() if k.isdigit()]
    kw = {R_ARGS.get(k, k): decode(v) for k, v in args.items() if not k.isdigit()}
    return pos, kw


def norm(v):
    if isinstance(v, float):
        return None if math.isnan(v) else float("%.10g" % v)
    if isinstance(v, bool):
        return float(v)
    if isinstance(v, int):
        return float(v)
    if isinstance(v, dt.datetime):
        return v.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    if isinstance(v, dict):
        return {k: norm(z) for k, z in v.items()}
    if isinstance(v, (list, tuple)):
        return [norm(z) for z in v]
    return v


def rows(t):
    if not isinstance(t, pa.Table):
        t = ns.backend_pull(t)
    return [tuple(sorted((k, norm(v)) for k, v in r.items())) for r in t.to_pylist()]


def describe(x):
    lt = ts.calendar_leaftable(x)
    m = x.meta
    small = lt.num_rows <= 400
    sub = lt if small else pa.concat_tables([lt.slice(0, 30),
                                             lt.slice(lt.num_rows - 30)])
    return {
        "frames": list(x.frames), "members": {k: list(v) for k, v in x.members.items()},
        "n": lt.num_rows, "share_sum": sum(lt["share"].to_pylist()),
        "weight_sum": sum(lt["weight"].to_pylist()), "name": m.get("name"),
        "parent_name": m.get("parent_name"),
        "year_fraction": m.get("year_fraction", 1),
        "tokens": m.get("tokens"), "alignment": m.get("alignment"),
        "year_start": m.get("year_start"),
        "utc_offset_minutes": m.get("utc_offset_minutes"),
        "coverage_class": m.get("coverage_class"), "regularity": m.get("regularity"),
        "coverage": m.get("coverage"), "leaftable": sub, "leaftable_complete": small}


def compare(got, want, ordered):
    kind, value = want["kind"], want["value"]
    if kind == "calendar":
        d = describe(got)
        lt_want = value.pop("leaftable")
        lt_got = d.pop("leaftable")
        if not value.get("tokens"):
            value["tokens"] = d["tokens"] = None if not d["tokens"] else d["tokens"]
        assert norm({k: d[k] for k in value}) == norm(value)
        assert rows(lt_got) == [tuple(sorted((k, norm(v)) for k, v in r.items()))
                                for r in lt_want]
    elif kind == "table":
        have = rows(got)
        exp = [tuple(sorted((k, norm(v)) for k, v in r.items())) for r in value]
        if ordered:
            assert have == exp
        else:
            assert sorted(have, key=repr) == sorted(exp, key=repr)
    else:
        if isinstance(got, pa.Array):
            got = got.to_pylist()
        if isinstance(got, dict):
            got = list(got.values())
        vals = value if isinstance(value, list) else [value]
        assert norm(list(got)) == norm(vals)


def label(c):
    return "%s:%s(%s)" % (c[0], c[2]["fn"], c[1])


@pytest.mark.parametrize("case", CASES, ids=[label(c) for c in CASES])
def test_json_golden(case):
    _, _, c = case
    fn = getattr(ts, c["fn"])
    pos, kw = call_args(c["args"])
    with warnings.catch_warnings(record=True) as rec:
        warnings.simplefilter("always")
        if c["error"]:
            with pytest.raises(ns.NestedScalesError) as e:
                fn(*pos, **kw)
            assert str(e.value) == r_message(c["message"])
            return
        got = fn(*pos, **kw)
    assert [str(w.message) for w in rec] == [r_message(w) for w in c["warnings"]]
    compare(got, c["value"], c["ordered"])
