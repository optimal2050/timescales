"""calendar_map() / calendar_map_between() -- the crosswalk tables (port of
R/map.R).

* `calendar_map(x, source, target)` -- between two timeframes of ONE
  calendar, derived by nestedscales from the calendar's leaftable;
* `calendar_map_between(source, target, year)` -- between TWO calendars:
  the source -> datetime grid -> target route collapsed into one row per
  (year, source timeslice, target timeslice), memoised.
"""
from __future__ import annotations

from collections.abc import Sequence
from typing import Any

import nestedscales as ns
import numpy as np
import pyarrow as pa
import pyarrow.compute as pc

from ._utils import (
    _calendar_name,
    _check_calendar,
    _check_timeframe,
    _preview,
    _stop,
)
from .calendar_class import Calendar
from .expand import _datetime_to_timeslice, _model_year_us, _years, default_step

_MAP_CACHE: dict[tuple, pa.Table] = {}
_MAP_REGISTRY: dict[str, pa.Table] = {}


def calendar_map(x: Calendar, source: str, target: str, weight: str | None = None,
                 **kwargs: Any) -> pa.Table:
    """Crosswalk between two timeframes of one calendar."""
    if isinstance(source, Calendar) or isinstance(target, Calendar):
        _stop("`source` and `target` are timeframe names of `x`; for the map "
              "between two calendars use `calendar_map_between()`")
    _check_calendar(x, "x")
    _check_timeframe(x, source, "source")
    _check_timeframe(x, target, "target")
    return ns.scale_map(x, source, target, weight=weight, **kwargs)


def calendar_map_between(source: Calendar, target: Calendar, year: Any,
                         by: object = None, tz: str = "UTC") -> pa.Table:
    """Crosswalk between two calendars over the datetime grid of `year`(s).

    Columns `year`, `<source name>`, `<target name>`, `n_from` (grid points
    of the source timeslice), `n_overlap`, `w` (the source share falling in
    the pair). A null target marks grid points the target does not cover.
    """
    _check_calendar(source, "source")
    _check_calendar(target, "target")
    s_nm = _calendar_name(source, arg="source")
    t_nm = _calendar_name(target, arg="target")
    if s_nm == t_nm:
        _stop('`source` and `target` have the same name ("%s"); the map\'s label '
              "columns are named by the calendars -- rename one", s_nm)
    years = _years(year)
    if not years:
        _stop("`year` must be one or more integers")
    if by is None:
        by = default_step(list(dict.fromkeys([*source.frames, *target.frames])))
    reg = _MAP_REGISTRY.get("%s->%s" % (s_nm, t_nm))
    if reg is not None:
        return reg
    ck = (s_nm, t_nm, tuple(years), str(by), tz)
    if ck in _MAP_CACHE:
        return _MAP_CACHE[ck]

    share = dict(zip(source.leaftable["timeslice"].to_pylist(),
                     source.leaftable["share"].to_pylist(), strict=True))
    parts = []
    for y in years:
        us = _model_year_us(source, y, by, tz)
        valid = np.ones(us.shape, dtype=bool)
        s_from = _datetime_to_timeslice(us, valid, tz, source)
        s_to = _datetime_to_timeslice(us, valid, tz, target)
        ok = pc.is_valid(s_from)
        d = pa.table({"from": s_from.filter(ok), "to": s_to.filter(ok)})
        if d.num_rows == 0:
            continue
        d = d.append_column("one", pa.array(np.ones(d.num_rows, np.int64)))
        g = d.group_by(["from", "to"], use_threads=False).aggregate([("one", "sum")])
        g = g.append_column("year", pa.array(np.full(g.num_rows, y, np.int32)))
        parts.append(g)
    if not parts:
        _stop("the grid produced no overlap between `source` and `target`")
    m = pa.concat_tables(parts)
    m = m.rename_columns(["n_overlap" if c == "one_sum" else c
                          for c in m.column_names])
    fr, n_ov, yr = m["from"].to_pylist(), m["n_overlap"].to_pylist(), \
        m["year"].to_pylist()
    tot: dict = {}
    for a, n, y in zip(fr, n_ov, yr, strict=True):
        tot[(y, a)] = tot.get((y, a), 0) + n
    n_from = [tot[(y, a)] for a, y in zip(fr, yr, strict=True)]
    w = [share[a] * n / nf for a, n, nf in zip(fr, n_ov, n_from, strict=True)]
    out = pa.table({"year": m["year"], s_nm: m["from"], t_nm: m["to"],
                    "n_from": pa.array(n_from, pa.int64()),
                    "n_overlap": m["n_overlap"], "w": pa.array(w, pa.float64())})
    _MAP_CACHE[ck] = out
    return out


def register_calendar_map(x: Calendar | str, source: str, target: str,
                          map: Any) -> str:
    """Register a direct crosswalk between two timeframes of one calendar."""
    if not isinstance(x, str):
        _check_calendar(x, "x")
    return ns.register_scale_map(x, source, target, map)


def _map_name_of(z: Any, arg: str) -> str:
    if isinstance(z, str) and z != "":
        return z
    _check_calendar(z, arg)
    return _calendar_name(z, arg=arg)


def register_calendar_map_between(source: Calendar | str, target: Calendar | str,
                                  map: Any) -> str:
    """Register a direct crosswalk between two calendars; `map=None` removes
    it. Needs columns `year`, the two calendar names, `n_from`, `n_overlap`,
    `w`."""
    s_nm, t_nm = _map_name_of(source, "source"), _map_name_of(target, "target")
    key = "%s->%s" % (s_nm, t_nm)
    if map is None:
        _MAP_REGISTRY.pop(key, None)
        return key
    if isinstance(map, (str, bytes, int, float)):
        _stop("`map` must be a data.frame (see `calendar_map_between()`) or NULL")
    t = ns.backend_pull(map)
    miss = [c for c in ["year", s_nm, t_nm, "n_from", "n_overlap", "w"]
            if c not in t.column_names]
    if miss:
        _stop("`map` is missing column(s): %s", _preview(miss))
    _MAP_REGISTRY[key] = t
    return key


def get_calendar_map(x: Calendar | str, source: str, target: str) -> pa.Table | None:
    if not isinstance(x, str):
        _check_calendar(x, "x")
    return ns.get_scale_map(x, source, target)


def get_calendar_map_between(source: Calendar | str,
                             target: Calendar | str) -> pa.Table | None:
    return _MAP_REGISTRY.get("%s->%s" % (_map_name_of(source, "source"),
                                         _map_name_of(target, "target")))


def list_calendar_maps() -> pa.Table:
    keys = [*sorted(_MAP_REGISTRY), *ns.list_scale_maps()["key"].to_pylist()]
    parts = [k.split(":", 1)[-1].split("->", 1) for k in keys]
    return pa.table({"key": pa.array(keys, pa.string()),
                     "source": pa.array([p[0] for p in parts], pa.string()),
                     "target": pa.array([p[1] if len(p) > 1 else None for p in parts],
                                        pa.string())})


def clear_calendar_maps(registry: bool = False,
                        name: str | Sequence[str] | None = None) -> None:
    """Drop the memo cache; with `registry=True` also the registered maps
    (the named keys only, when `name` is given)."""
    _MAP_CACHE.clear()
    if registry:
        if name is None:
            _MAP_REGISTRY.clear()
            ns.clear_scale_maps()
        else:
            for k in [name] if isinstance(name, str) else name:
                _MAP_REGISTRY.pop(k, None)
            ns.clear_scale_maps(name)
