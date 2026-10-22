"""The base grid and within-calendar aggregation (port of R/base-calendar.R)."""
from __future__ import annotations

import numpy as np
import pyarrow as pa

from ._dt import grid_us, instants_array
from ._utils import _stop
from .calendar_class import Calendar
from .construct import make_timeslice_ids

_BASE_CACHE: dict[tuple, pa.Table] = {}


def base_calendar(years: object, by: object = "hour", tz: str = "UTC") -> pa.Table:
    """The datetime grid of whole Gregorian years: columns `datetime`, `year`.

    Each year runs [Jan 1 00:00, next Jan 1) local time in `tz`, in absolute
    steps of `by` ("hour", "15 min", "day", ...). Cached.
    """
    ys = [years] if isinstance(years, (int, np.integer)) else list(years)
    try:
        ys = [int(y) for y in ys]
    except (TypeError, ValueError):
        ys = []
    if not ys:
        _stop("`years` must be one or more integers")
    key = (tuple(ys), str(by), tz)
    if key in _BASE_CACHE:
        return _BASE_CACHE[key]
    parts, yrs = [], []
    for y in ys:
        g = grid_us((y, 1, 1), (y + 1, 1, 1), by, tz)
        parts.append(g)
        yrs.append(np.full(g.shape, y, dtype=np.int32))
    us = np.concatenate(parts)
    out = pa.table({"datetime": instants_array(us, None, tz),
                    "year": pa.array(np.concatenate(yrs))})
    _BASE_CACHE[key] = out
    return out


def prune_calendar(x: Calendar, timeframe: str) -> Calendar:
    """Collapse to `timeframe` (or the single "ANNUAL" root), summing share
    and weight; renamed `"name@TF"`."""
    if not isinstance(x, Calendar):
        _stop("`x` must be a Calendar object")
    if not isinstance(timeframe, str):
        _stop("`timeframe` must be a single character string")
    lt, tfs, members, meta = x.leaftable, list(x.frames), x.members, x.meta
    base = meta.get("name") or ""
    if timeframe == "ANNUAL":
        root = pa.table({"ANNUAL": ["ANNUAL"], "timeslice": ["ANNUAL"],
                         "share": [float(sum(lt["share"].to_pylist()))],
                         "weight": [float(sum(lt["weight"].to_pylist()))]})
        m = dict(meta)
        m["name"] = base + "@ANNUAL" if base else "ANNUAL"
        if base:
            m["parent_name"] = base
        m.pop("tokens", None)
        m.pop("alignment", None)
        return Calendar(leaftable=root, timeframes=["ANNUAL"],
                        members={"ANNUAL": ["ANNUAL"]}, meta=m)
    if timeframe not in tfs:
        _stop('`timeframe` must be "ANNUAL" or one of the x\'s timeframes: %s',
              ", ".join(tfs))
    keep = tfs[:tfs.index(timeframe) + 1]
    keys = list(zip(*(lt[t].to_pylist() for t in keep), strict=True))
    share, weight = lt["share"].to_pylist(), lt["weight"].to_pylist()
    agg: dict[tuple, list[float]] = {}
    for k, s, w in zip(keys, share, weight, strict=True):
        a = agg.setdefault(k, [0.0, 0.0])
        a[0] += s
        a[1] += w
    pos = [{v: i for i, v in enumerate(members[t])} for t in keep]
    groups = sorted(agg, key=lambda k: tuple(p[v] for p, v in zip(pos, k,
                                                                    strict=True)))
    cols = {t: [g[i] for g in groups] for i, t in enumerate(keep)}
    cols["share"] = [agg[g][0] for g in groups]
    cols["weight"] = [agg[g][1] for g in groups]
    cols["timeslice"] = make_timeslice_ids([cols[t] for t in keep])
    m = dict(meta)
    m["name"] = base + "@" + timeframe if base else timeframe
    if base:
        m["parent_name"] = base
    if meta.get("tokens") is not None:
        m["tokens"] = {k: v for k, v in meta["tokens"].items() if k in keep}
    if meta.get("alignment") is not None:
        a = {k: v for k, v in meta["alignment"].items() if k in keep}
        if a:
            m["alignment"] = a
        else:
            m.pop("alignment", None)
    return Calendar(leaftable=pa.table(cols), timeframes=keep,
                    members={t: members[t] for t in keep}, meta=m)
