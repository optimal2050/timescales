"""Timeslice label conversions and the datetime round trip (port of
R/timeslices.R).

Every conversion is a JOIN against a table the package already builds --
the leaftable when the calendar holds the timeframe, `calendar_map_between()`
when it does not -- never a parse of the label text.
"""
from __future__ import annotations

from typing import Any

import pyarrow as pa

from ._dt import to_instants
from ._utils import _as_list, _calendar_name, _check_calendar, _stop
from .calendar_class import Calendar
from .construct import calendar
from .expand import _datetime_to_timeslice, _years, expand_calendar
from .map import calendar_map_between
from .navigate import calendar_timeslices
from .timeframes import (
    as_timeframe,
    match_timeframe,
    timeframe_vocab,
    vocab_value,
)
from .tokens import complete_calendar, valuation_vocab

_DEFAULT_TIMEFRAME_TOKEN = {"YDAY": "d365", "MONTH": "m12", "QUARTER": "q4",
                            "SEASON": "s4", "WEEK": "w53", "WDAY": "wd7",
                            "DAYTYPE": "wk2", "HOURTYPE": "hp3", "HOUR": "h24",
                            "WHOUR": "h168", "MINUTE": "min60"}
_YEAR_DEPENDENT = ("YEAR", "WDAY", "MWEEK", "DAYTYPE", "WHOUR")
_DEFAULT_MAP_YEAR = 2021


def _as_calendar(x: Any, arg: str = "calendar") -> Calendar:
    if x is None:
        _stop("`%s` is required: the timeframe is read from the calendar, not "
              "guessed from the label text", arg)
    if isinstance(x, str) and x != "":
        return calendar(x)
    _check_calendar(x, arg)
    return x


def _resolve_map_year(year: Any, timeframe: str) -> int:
    if year is not None:
        ys = _years(year)
        if len(ys) != 1:
            _stop("`year` must be a single integer")
        return ys[0]
    if timeframe in _YEAR_DEPENDENT:
        _stop("%s depends on which year the timeslices fall in, so `year` must be "
              "given; it is weekday-derived, unlike MONTH or YDAY", timeframe)
    return _DEFAULT_MAP_YEAR


def _resolve_timeframe(x: list, cal: Calendar, tf: str, year: Any) -> dict:
    own = list(cal.frames)
    if tf in own:
        lt = cal.leaftable
        vocab = timeframe_vocab(cal, tf)
        pos = {k: i for i, k in enumerate(lt["timeslice"].to_pylist())}
        col = lt[tf].to_pylist()
        vset = set(vocab)
        lab = [col[pos[v]] if v in pos else (v if v in vset else None) for v in x]
        return {"label": lab, "vocab": valuation_vocab(cal, tf, vocab), "value": None}
    tok = _DEFAULT_TIMEFRAME_TOKEN.get(tf)
    if tok is None:
        return _derive_via_instant(x, cal, tf, _resolve_map_year(year, tf))
    target = calendar(tok)
    s_nm = _calendar_name(cal, arg="calendar")
    t_nm = _calendar_name(target)
    yr = _resolve_map_year(year, tf)
    try:
        m = calendar_map_between(cal, target, year=yr)
    except ValueError:
        return _derive_via_instant(x, cal, tf, yr)
    src = m[s_nm].to_pylist()
    if len(set(src)) != len(src):
        _stop('%s is not available for calendar "%s": its timeslices each span '
              'several %s values, so there is no single answer. "%s" holds %s',
              tf, s_nm, tf, s_nm, ", ".join(own))
    lookup = dict(zip(src, m[t_nm].to_pylist(), strict=True))
    return {"label": [lookup.get(v) for v in x],
            "vocab": valuation_vocab(target, tf, timeframe_vocab(target, tf)),
            "value": None}


def _as_timeframe_character(x: Any, timeframe: str, format: str = "numeric",
                            calendar: Any = None, year: Any = None,
                            **_: Any) -> list:
    tf = match_timeframe(timeframe)
    cal = _as_calendar(calendar)
    labels = [None if v is None else str(v) for v in _as_list(x)]
    res = _resolve_timeframe(labels, cal, tf, year)
    if res["value"] is not None:
        return as_timeframe(res["value"], tf, format=format)
    if format == "token":
        return res["label"]
    return vocab_value(res["label"], res["vocab"], tf)


def tsl2hour(tsl: Any, calendar: Any) -> list:
    """Hour of day (0-23) of each timeslice."""
    return as_timeframe(_strs(tsl), "HOUR", calendar=calendar)


def tsl2yday(tsl: Any, calendar: Any) -> list:
    """Day of year of each timeslice."""
    return as_timeframe(_strs(tsl), "YDAY", calendar=calendar)


def tsl2month(tsl: Any, calendar: Any, year: Any = None) -> list:
    """Month (1-12) of each timeslice."""
    return as_timeframe(_strs(tsl), "MONTH", calendar=calendar, year=year)


def hour2HOUR(x: Any, calendar: Any = None) -> list:  # noqa: N802 (R name)
    """Hours (0-23) as HOUR labels."""
    return as_timeframe(_nums(x), "HOUR", format="token", calendar=calendar)


def yday2YDAY(x: Any, calendar: Any = None) -> list:  # noqa: N802 (R name)
    """Days of year as YDAY labels."""
    return as_timeframe(_nums(x), "YDAY", format="token", calendar=calendar)


def _strs(x: Any) -> list:
    return [None if v is None else str(v) for v in _as_list(x)] or [""]


def _nums(x: Any) -> list:
    vals = [x] if isinstance(x, (int, float)) else _as_list(x)
    return [None if v is None else float(v) for v in vals]


def tsl2dtm(tsl: Any, calendar: Any, year: Any, tz: str = "UTC",
            alignment: Any = None) -> pa.Array:
    """The instant each timeslice starts at, in `year` (one, or one per
    timeslice). A sampled calendar is dated against its parent."""
    cal = _as_calendar(calendar)
    tsl = [None if v is None else str(v) for v in _as_list(tsl)]
    years = _years(year)
    if not years:
        _stop("`year` must be one or more integers")
    if len(years) not in (1, len(tsl)):
        _stop("`year` must be length 1 or length(tsl) (%d), not %d", len(tsl),
              len(years))
    grid = expand_calendar(cal, list(dict.fromkeys(years)), tz=tz,
                           alignment=alignment)
    i = _grid_match(tsl, years, grid)
    out = grid["datetime"].combine_chunks().take(pa.array(i, pa.int64()))
    if any(v is None for v in i) and not all(v is None for v in tsl):
        ref = _reference_calendar(cal)
        if ref is not None:
            rgrid = expand_calendar(ref, list(dict.fromkeys(years)), tz=tz,
                                    alignment=alignment)
            j = _grid_match(tsl, years, rgrid)
            alt = rgrid["datetime"].combine_chunks().take(pa.array(j, pa.int64()))
            return pa.array([a if a is not None else b for a, b in zip(
                out.to_pylist(), alt.to_pylist(), strict=True)], out.type)
    return out


def _grid_match(tsl: list, years: list[int], grid: pa.Table) -> list:
    gts, gy = grid["timeslice"].to_pylist(), grid["year"].to_pylist()
    if len(years) == 1:
        first: dict = {}
        for k, v in enumerate(gts):
            first.setdefault(v, k)
        return [first.get(v) for v in tsl]
    first = {}
    for k, key in enumerate(zip(gy, gts, strict=True)):
        first.setdefault(key, k)
    return [first.get((y, v)) for y, v in zip(years, tsl, strict=True)]


def dtm2tsl(dtm: Any, calendar: Any, alignment: Any = None) -> list:
    """The timeslice each datetime falls in."""
    cal = _as_calendar(calendar)
    us, valid, tz = to_instants(dtm)
    return _datetime_to_timeslice(us, valid, tz, cal, alignment).to_pylist()


def _derive_via_instant(x: list, cal: Calendar, tf: str, year: int) -> dict:
    dtm = tsl2dtm(x, cal, year=year).to_pylist()
    have = set(calendar_timeslices(cal))
    known = [v is not None and v in have for v in x]
    if any(known) and all(d is None for d, k in zip(dtm, known, strict=True) if k):
        parent = cal.meta.get("parent_name")
        if parent:
            dtm = tsl2dtm(x, calendar(parent), year=year).to_pylist()
    if any(known) and all(d is None for d, k in zip(dtm, known, strict=True) if k):
        _stop('cannot place calendar "%s"\'s timeslices on a timeline, so %s cannot '
              "be derived from them", _calendar_name(cal, require=False), tf)
    return {"label": None, "vocab": None,
            "value": pa.array(dtm, pa.timestamp("s", tz="UTC"))}


def _reference_calendar(cal: Calendar) -> Calendar | None:
    own = _calendar_name(cal, require=False)
    parent = cal.meta.get("parent_name")
    if parent and parent != own:
        try:
            return calendar(parent)
        except ValueError:
            pass
    return complete_calendar(cal)


