"""join_calendar() -- attach a calendar to a dataset (port of R/join.R).

Adds a timeslice column NAMED AFTER THE CALENDAR, so several calendars can
sit side by side; optional `<name>.<TF>` and `<name>.share`/`.weight`
columns. Datetime-keyed data is labelled on the grid; timeslice-keyed data
is validated. Row order is kept.
"""
from __future__ import annotations

from collections.abc import Sequence
from typing import Any

import nestedscales as ns
import pyarrow as pa
import pyarrow.compute as pc

from ._dt import Fields, to_instants
from ._utils import _as_list, _calendar_name, _check_calendar, _preview, _stop, _warn
from .calendar_class import Calendar
from .expand import _years, expand_calendar


def join_calendar(x: Any, calendar: Calendar, key: str | None = None,
                  timeframes: bool | str | Sequence[str] | None = None,
                  meta: bool = False, as_factor: bool = True, year: Any = None,
                  by: object = None, tz: str = "UTC",
                  collect: bool | None = None) -> Any:
    """Attach `calendar`'s timeslice labels (and optionally timeframes,
    share, weight) to `x`, keyed by a timeslice or datetime column."""
    bk = ns.backend_of(x, "x")
    _check_calendar(calendar, "calendar")
    nm = _calendar_name(calendar)
    schema = ns.backend_schema(x, bk)
    lt, tfs = calendar.leaftable, list(calendar.frames)
    if key is None:
        for cand in (nm, "timeslice", "datetime"):
            if cand in schema.names:
                key = cand
                break
        else:
            _stop("`x` has no `%s`, `timeslice`, or `datetime` column; pass `key=`",
                  nm)
    if key not in schema.names:
        _stop("`x` has no column named `%s`; pass `key=`", key)
    kt = schema.field(key).type
    dtm_route = pa.types.is_timestamp(kt) or pa.types.is_date(kt)

    if timeframes is True:
        timeframes = tfs
    if timeframes is not None and timeframes is not False:
        timeframes = _as_list(timeframes)
        bad = [t for t in timeframes if t not in tfs]
        if bad:
            _stop("not timeframes of this calendar: %s", _preview(bad))
    else:
        timeframes = []
    new_cols = ([nm] if key != nm else []) + ["%s.%s" % (nm, t) for t in timeframes] \
        + (["%s.share" % nm, "%s.weight" % nm] if meta else [])
    clash = [c for c in new_cols if c in schema.names]
    if clash:
        _stop('attaching calendar "%s" would overwrite existing column(s): %s',
              nm, _preview(clash))
    if not new_cols:
        return x

    t = ns.backend_scan(x, bk)
    leaf_ts = lt["timeslice"].combine_chunks()
    if dtm_route:
        us, valid, _ = to_instants(t[key])
        if year is None:
            yy = Fields(us, valid, tz).year[valid]
            year = list(range(int(yy.min()) - 1, int(yy.max()) + 2))
        grid = expand_calendar(calendar, _years(year), by=by, tz=tz)
        g_us = pc.cast(pc.cast(grid["datetime"], pa.timestamp("us", tz=tz)),
                       pa.int64())
        pos = pc.index_in(pa.array(us, mask=~valid), value_set=g_us)
        label = grid["timeslice"].combine_chunks().take(pos)
    else:
        keys = pc.cast(t[key], pa.string())
        uniq = [k for k in pc.unique(keys).to_pylist() if k is not None]
        known = set(leaf_ts.to_pylist())
        if not any(k in known for k in uniq):
            _stop("no rows of `x` matched the calendar's timeslices; check `key=`")
        unknown = [k for k in uniq if k not in known]
        if unknown:
            _warn("%d code(s) in `x$%s` are not timeslices of the calendar: %s",
                  len(unknown), key, _preview(unknown))
        label = leaf_ts.take(pc.index_in(keys, value_set=leaf_ts))

    idx = pc.index_in(label, value_set=leaf_ts)
    out = t
    for tf in timeframes:
        col = lt[tf].combine_chunks()
        if as_factor:
            levels = list(calendar.members[tf])
            p = {v: i for i, v in enumerate(levels)}
            col = pa.DictionaryArray.from_arrays(
                pa.array([p[v] for v in col.to_pylist()], pa.int32()),
                pa.array(levels, pa.string()))
        out = out.append_column("%s.%s" % (nm, tf), col.take(idx))
    if meta:
        out = out.append_column("%s.share" % nm, lt["share"].combine_chunks().take(idx))
        out = out.append_column("%s.weight" % nm,
                                lt["weight"].combine_chunks().take(idx))
    if key != nm:
        out = out.append_column(nm, label)
    return ns.backend_restore(out, bk, collect)
