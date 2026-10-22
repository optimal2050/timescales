"""Timeframe extraction from datetimes (port of R/timeframes.R).

Fields follow lubridate's conventions: WDAY is Sunday-first unless
`week_start` is given, WEEK is `(yday - 1) %/% 7 + 1` (not ISO), WHOUR is
Monday-first.
"""
from __future__ import annotations

from collections.abc import Sequence
from typing import Any, Literal

import numpy as np

from ._dt import Fields, to_instants
from ._utils import _as_list, _calendar_name, _check_calendar, _stop

CORE_TIMEFRAMES = ("YEAR", "QUARTER", "MONTH", "MDAY", "YDAY", "HOUR", "MINUTE",
                   "SECOND", "WDAY", "WHOUR", "MWEEK", "WEEK", "SEASON",
                   "DAYTYPE", "HOURTYPE")

SEASON_LABELS = ("WIN", "SPR", "SUM", "FAL")
DAYTYPE_LABELS = ("WORKDAY", "WEEKEND")
HOURTYPE_LABELS = ("DAY", "NIGHT", "PEAK")
_WDAY_SUNFIRST = ("SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT")
_WDAY_MONFIRST = ("MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN")
_SEASON_OF_MONTH = np.array([0, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 1])

#: First integer of each timeframe's vocabulary; None = absolute, not ordinal.
TIMEFRAME_ORIGIN = {"YEAR": None, "QUARTER": 1, "MONTH": 1, "MDAY": 1, "YDAY": 1,
                    "HOUR": 0, "MINUTE": 0, "SECOND": 0, "WDAY": 1, "WHOUR": 0,
                    "MWEEK": 1, "WEEK": 1, "SEASON": 1, "DAYTYPE": 1,
                    "HOURTYPE": 1}


def extract(f: Fields, tf: str, week_start: int | None = None) -> np.ndarray:
    """The numeric value of a timeframe (float; NaN where the instant is NA)."""
    if tf == "YEAR":
        v = f.year
    elif tf == "QUARTER":
        v = (f.month - 1) // 3 + 1
    elif tf == "MONTH":
        v = f.month
    elif tf == "MDAY":
        v = f.mday
    elif tf == "YDAY":
        v = f.yday
    elif tf == "HOUR":
        v = f.hour
    elif tf == "MINUTE":
        v = f.minute
    elif tf == "SECOND":
        v = f.second + f.frac
    elif tf == "WDAY":
        v = f.wday(week_start)
    elif tf == "WEEK":
        v = (f.yday - 1) // 7 + 1
    elif tf == "WHOUR":
        v = (f.wday_mon - 1) * 24 + f.hour
    elif tf == "SEASON":
        v = _SEASON_OF_MONTH[f.month]
    elif tf == "DAYTYPE":
        v = np.where(f.wday_mon <= 5, 1, 2)
    elif tf == "HOURTYPE":
        h = f.hour
        v = np.where((h >= 17) & (h <= 20), 3, np.where((h >= 22) | (h <= 5), 2, 1))
    elif tf == "MWEEK":
        w = f.wday(week_start)
        w1 = (w - 1 - (f.mday - 1)) % 7 + 1
        v = (f.mday + w1 - 2) // 7 + 1
    else:
        _stop("Unsupported timeframe: '%s'. Must be one of: %s", tf,
              ", ".join(CORE_TIMEFRAMES))
    out = np.asarray(v, dtype=float)
    out[~f.valid] = np.nan
    return out


def _fmt(prefix: str, width: int) -> Any:
    return lambda x: [None if z is None else "%s%0*d" % (prefix, width, z) for z in x]


def _enum(labels: Sequence[str]) -> Any:
    return lambda x: [None if z is None or not 1 <= z <= len(labels)
                      else labels[z - 1] for z in x]


#: Canonical token formatters, numbers to labels.
TIMEFRAME_FORMATTERS = {
    "YEAR": _fmt("y", 4), "QUARTER": _fmt("Q", 1), "MONTH": _fmt("m", 2),
    "MDAY": _fmt("d", 2), "YDAY": _fmt("d", 3), "HOUR": _fmt("h", 2),
    "MINUTE": _fmt("min", 2), "SECOND": _fmt("sec", 2), "WDAY": _enum(_WDAY_SUNFIRST),
    "WHOUR": _fmt("h", 3), "SEASON": _enum(SEASON_LABELS),
    "DAYTYPE": _enum(DAYTYPE_LABELS), "HOURTYPE": _enum(HOURTYPE_LABELS),
    "MWEEK": _fmt("mw", 2), "WEEK": _fmt("w", 2)}


def _ints(v: np.ndarray) -> list:
    """Floats to Python ints (truncated like R's as.integer), NaN to None."""
    return [None if z != z else int(z) for z in v.tolist()]


def match_timeframe(timeframe: object, arg: str = "timeframe") -> str:
    if not isinstance(timeframe, str):
        _stop("`%s` must be a single character string", arg)
    tf = timeframe.upper()
    if tf not in CORE_TIMEFRAMES:
        _stop('unsupported %s: "%s". Must be one of: %s', arg, timeframe,
              ", ".join(CORE_TIMEFRAMES))
    return tf


def _is_numberlike(x: Any) -> bool:
    if isinstance(x, (int, float)) and not isinstance(x, bool):
        return True
    if isinstance(x, np.ndarray):
        return np.issubdtype(x.dtype, np.number)
    vals = [z for z in _as_list(x) if z is not None] if not isinstance(
        x, (str, bytes)) else [x]
    return bool(vals) and all(isinstance(z, (int, float)) and not isinstance(z, bool)
                              for z in vals)


def _is_stringlike(x: Any) -> bool:
    if isinstance(x, str):
        return True
    try:
        import pyarrow as pa

        if isinstance(x, (pa.Array, pa.ChunkedArray)):
            t = x.type
            return pa.types.is_string(t) or pa.types.is_large_string(t) or \
                pa.types.is_dictionary(t)
    except ImportError:  # pragma: no cover
        pass
    vals = [z for z in _as_list(x) if z is not None]
    return bool(vals) and all(isinstance(z, str) for z in vals)


def as_timeframe(x: Any, timeframe: str,
                 format: Literal["numeric", "token"] = "numeric",
                 **kwargs: Any) -> list:
    """Read one timeframe off datetimes, timeslice labels, or numbers.

    * datetimes: the field in the datetimes' time zone (`week_start=` for
      WDAY/MWEEK);
    * timeslice labels: read from `calendar=` (a Calendar or a name) by a
      join, never by parsing the label text; `year=` for the weekday-derived
      timeframes;
    * numbers: `format="token"` spells them with the calendar's vocabulary
      (`calendar=`) or the canonical formatter.
    """
    if format not in ("numeric", "token"):
        _stop("`format` should be one of: numeric, token")
    if _is_stringlike(x):
        from .timeslices import _as_timeframe_character

        return _as_timeframe_character(x, timeframe, format, **kwargs)
    if _is_numberlike(x):
        return _as_timeframe_numeric(x, timeframe, format, kwargs.get("calendar"))
    us, valid, tz = to_instants(x)
    tf = timeframe.upper()
    if tf not in CORE_TIMEFRAMES:
        _stop("Unsupported timeframe: '%s'. Must be one of: %s", timeframe,
              ", ".join(CORE_TIMEFRAMES))
    f = Fields(us, valid, tz)
    v = extract(f, tf, kwargs.get("week_start"))
    if format == "numeric":
        return [None if z != z else (z if tf == "SECOND" else int(z))
                for z in v.tolist()]
    if tf == "WDAY":
        # the label names the day; `week_start` changes only the numbering
        return [_WDAY_MONFIRST[int(z) - 1] if ok else None
                for z, ok in zip(f.wday_mon.tolist(), valid.tolist(), strict=True)]
    return TIMEFRAME_FORMATTERS[tf](_ints(v))


def _as_timeframe_numeric(x: Any, timeframe: str, format: str,
                          calendar: Any = None) -> list:
    tf = match_timeframe(timeframe)
    vals = [x] if isinstance(x, (int, float)) else _as_list(x)
    if format == "numeric":
        return vals
    if calendar is not None:
        from .timeslices import _as_calendar

        cal = _as_calendar(calendar)
        return value_vocab(vals, timeframe_vocab(cal, tf), tf)
    return TIMEFRAME_FORMATTERS[tf]([None if v is None or v != v else int(v)
                                     for v in vals])


def vocab_value(labels: Sequence[str | None], vocab: Sequence[str],
                timeframe: str) -> list:
    """Labels to numbers by position in a vocabulary."""
    origin = TIMEFRAME_ORIGIN[timeframe]
    if origin is None:
        _stop("%s values are absolute rather than ordinal, so a label carries no "
              "position in a vocabulary", timeframe)
    pos = {v: i for i, v in enumerate(vocab)}
    return [None if lab not in pos else pos[lab] + origin for lab in labels]


def timeframe_vocab(calendar: Any, timeframe: str) -> list[str]:
    _check_calendar(calendar, "calendar")
    if timeframe not in calendar.members:
        _stop('calendar "%s" has no %s timeframe; it holds: %s',
              _calendar_name(calendar, require=False), timeframe,
              ", ".join(calendar.members))
    return list(calendar.members[timeframe])


def value_vocab(values: Sequence[Any], vocab: Sequence[str],
                timeframe: str) -> list:
    """Numbers to labels by position in a vocabulary (out of range: None)."""
    origin = TIMEFRAME_ORIGIN[timeframe]
    if origin is None:
        _stop("%s values are absolute rather than ordinal, so they carry no "
              "position in a vocabulary", timeframe)
    out = []
    for v in values:
        if v is None or v != v:
            out.append(None)
            continue
        i = int(v) - origin
        out.append(vocab[i] if 0 <= i < len(vocab) else None)
    return out
