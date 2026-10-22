"""Datetime -> timeslice, and the model-year grid (port of the first part of
R/recast.R)."""
from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Any

import numpy as np
import pyarrow as pa
import pyarrow.compute as pc

from ._dt import (
    US,
    Fields,
    grid_us,
    instants_array,
    to_instants,
)
from ._utils import _check_calendar, _stop
from .base import base_calendar
from .calendar_class import Calendar
from .construct import _nontrivial_year_start
from .rules import _match_arg
from .timeframes import TIMEFRAME_FORMATTERS, extract
from .tokens import ALIGNMENT_RULES, valuation_vocab

_FULL_CARDINALITY = {"QUARTER": 4, "MONTH": 12, "HOUR": 24, "WHOUR": 168,
                     "MINUTE": 60, "SECOND": 60, "SEASON": 4, "DAYTYPE": 2,
                     "HOURTYPE": 3}
_ZERO_BASED = ("HOUR", "MINUTE", "SECOND", "WHOUR")
_WDAY_MONFIRST = ("MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN")


def _resolve_alignment(alignment: Any, meta_align: Mapping | None,
                       tf: str) -> str | None:
    if alignment is not None:
        if isinstance(alignment, str):
            return _match_arg(alignment, ALIGNMENT_RULES, "alignment")
        a = alignment.get(tf)
        if a is not None:
            return _match_arg(a, ALIGNMENT_RULES, "alignment")
    if meta_align:
        return meta_align.get(tf)
    return None


def _anchor_days(f: Fields, ys: Mapping) -> np.ndarray:
    """Days since the epoch of each instant's fiscal-year anchor."""
    m, d = int(ys["month"]), int(ys["day"])
    years = f.year
    uniq = np.unique(years)
    this = {int(y): np.datetime64("%04d-%02d-%02d" % (y, m, d)) for y in uniq}
    prev = {int(y): np.datetime64("%04d-%02d-%02d" % (y - 1, m, d)) for y in uniq}
    a = np.array([this[int(y)] for y in years], dtype="datetime64[D]")
    before = f.dates() < a
    if before.any():
        a[before] = np.array([prev[int(y)] for y in years[before]],
                             dtype="datetime64[D]")
    return a.astype(np.int64)


def _feb29_between(anchor_days: np.ndarray, days: np.ndarray) -> np.ndarray:
    """Feb 29s in [anchor, date)."""
    ya = anchor_days.astype("datetime64[D]").astype("datetime64[Y]").astype(
        np.int64) + 1970
    cnt = np.zeros(anchor_days.shape, dtype=np.int64)
    for off in (0, 1):
        yy = ya + off
        leap = ((yy % 4 == 0) & (yy % 100 != 0)) | (yy % 400 == 0)
        if not leap.any():
            continue
        cand = np.full(yy.shape, np.iinfo(np.int64).max, dtype=np.int64)
        cand[leap] = np.array(["%04d-02-29" % y for y in yy[leap]],
                              dtype="datetime64[D]").astype(np.int64)
        cnt += ((cand >= anchor_days) & (cand < days) & leap).astype(np.int64)
    return cnt


def _fmt(tf: str, vals: np.ndarray, ok: np.ndarray) -> np.ndarray:
    out = np.full(vals.shape, None, dtype=object)
    if ok.any():
        out[ok] = TIMEFRAME_FORMATTERS[tf]([int(z) for z in vals[ok]])
    return out


def _tf_labels(f: Fields, tf: str, vocab: Sequence[str], align: str | None,
               ys: Mapping | None) -> np.ndarray:
    n = f.valid.shape[0]
    if tf == "ANNUAL":
        return np.full(n, "ANNUAL", dtype=object)
    K = len(vocab)
    vset = set(vocab)
    if tf in ("YDAY", "YEAR") and _nontrivial_year_start(ys):
        anchor = _anchor_days(f, ys)
        if tf == "YEAR":
            v = (anchor.astype("datetime64[D]").astype("datetime64[Y]")
                 .astype(np.int64) + 1970).astype(float)
        else:
            v = (f.days - anchor + 1).astype(float)
        v[~f.valid] = np.nan
    else:
        v = np.trunc(extract(f, tf))
    ok = ~np.isnan(v)

    if tf == "YEAR":
        tok = _fmt("YEAR", v, ok)
        return np.array([t if t in vset else None for t in tok], dtype=object)

    if tf == "YDAY" and align == "drop_feb29":
        is29 = f.valid & (f.month == 2) & (f.mday == 29)
        anchor = (_anchor_days(f, ys) if _nontrivial_year_start(ys) else
                  f.dates().astype("datetime64[Y]").astype("datetime64[D]")
                  .astype(np.int64))
        v = v - _feb29_between(anchor, f.days)
        v[is29] = np.nan
        ok = ~np.isnan(v)

    zero = tf in _ZERO_BASED
    ordv = v + 1 if zero else v.copy()
    over = ok & (ordv > K)
    if over.any():
        if align == "exact":
            _stop('alignment "exact": %d grid point(s) fall outside the %s '
                  "vocabulary (%d labels)", int(over.sum()), tf, K)
        elif align == "repeat_last":
            ordv[over] = K
        else:
            ordv[over] = np.nan
    ok_ord = ~np.isnan(ordv)
    v_fmt = ordv - 1 if zero else ordv

    if tf == "WDAY":
        tok = np.array([_WDAY_MONFIRST[int(z) - 1] if ok_ else None
                        for z, ok_ in zip(f.wday_mon.tolist(), f.valid.tolist(),
                                          strict=True)], dtype=object)
    else:
        tok = _fmt(tf, v_fmt, ok_ord)
    out = np.array([t if t is not None and t in vset else None for t in tok],
                   dtype=object)
    need = np.array([o is None for o in out]) & ok_ord
    if need.any() and _FULL_CARDINALITY.get(tf) == K:
        idx = ordv[need].astype(np.int64) - 1
        out[need] = np.array(vocab, dtype=object)[idx]
    return out


def _datetime_to_timeslice(us: np.ndarray, valid: np.ndarray, tz: str,
                           calendar: Calendar, alignment: Any = None) -> pa.Array:
    meta = calendar.meta
    offset = int(meta.get("utc_offset_minutes") or 0)
    f = Fields(us, valid, tz, shift_minutes=offset)
    labs = [_tf_labels(f, tf, valuation_vocab(calendar, tf, calendar.members[tf]),
                       _resolve_alignment(alignment, meta.get("alignment"), tf),
                       meta.get("year_start"))
            for tf in calendar.frames]
    any_na = np.zeros(us.shape, dtype=bool)
    for lab in labs:
        any_na |= np.array([z is None for z in lab], dtype=bool)
    keys = ["".join(r) if not na else None
            for r, na in zip(zip(*labs, strict=True), any_na.tolist(), strict=True)]
    lt = calendar.leaftable
    leaf_key = ["".join(r) for r in zip(*(lt[t].to_pylist() for t in calendar.frames),
                                        strict=True)]
    idx = pc.index_in(pa.array(keys, pa.string()),
                      value_set=pa.array(leaf_key, pa.string()))
    return lt["timeslice"].combine_chunks().take(idx)


def datetime_to_timeslice(dtm: Any, calendar: Calendar,
                          alignment: str | Mapping[str, str] | None = None) -> list:
    """The leaf timeslice each datetime falls in (None where none does).

    The calendar's `utc_offset_minutes` shifts the instants first;
    `year_start` anchors YDAY and YEAR. `alignment` overrides how instants
    beyond a vocabulary map (one rule, or a mapping per timeframe).
    """
    _check_calendar(calendar, "calendar")
    us, valid, tz = to_instants(dtm)
    return _datetime_to_timeslice(us, valid, tz, calendar, alignment).to_pylist()


def default_step(tfs: Sequence[str]) -> str:
    if "SECOND" in tfs:
        return "sec"
    if "MINUTE" in tfs:
        return "min"
    if "HOUR" in tfs or "WHOUR" in tfs:
        return "hour"
    return "day"


def _model_year_us(calendar: Calendar, year: int, by: object, tz: str) -> np.ndarray:
    meta = calendar.meta
    ys = meta.get("year_start") or {"month": 1, "day": 1}
    offset = int(meta.get("utc_offset_minutes") or 0)
    if not _nontrivial_year_start(ys) and offset == 0:
        g = base_calendar([year], by=by, tz=tz)["datetime"]
        return pc.cast(g, pa.int64()).to_numpy() * US
    m, d = int(ys["month"]), int(ys["day"])
    # the window is defined in calendar-local time; shift back to grid time
    return grid_us((year, m, d), (year + 1, m, d), by, tz) - offset * 60 * US


def _years(year: Any) -> list[int]:
    ys = [year] if isinstance(year, (int, np.integer)) else list(year)
    try:
        return [int(y) for y in ys]
    except (TypeError, ValueError):
        return []


def expand_calendar(x: Calendar, year: Any, by: object = None, tz: str = "UTC",
                    alignment: str | Mapping[str, str] | None = None) -> pa.Table:
    """The model year(s) as a datetime grid labelled with timeslices:
    columns `datetime`, `year`, `timeslice`."""
    if not isinstance(x, Calendar):
        _stop("`x` must be a Calendar object")
    years = _years(year)
    if not years:
        _stop("`year` must be one or more integers")
    if by is None:
        by = default_step(x.frames)
    parts = []
    for y in years:
        us = _model_year_us(x, y, by, tz)
        valid = np.ones(us.shape, dtype=bool)
        parts.append(pa.table({
            "datetime": instants_array(us, None, tz),
            "year": pa.array(np.full(us.shape, y, dtype=np.int32)),
            "timeslice": _datetime_to_timeslice(us, valid, tz, x, alignment)}))
    return pa.concat_tables(parts)
