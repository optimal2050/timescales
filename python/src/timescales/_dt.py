"""Datetime plumbing: instants as int64 microseconds since the epoch (UTC),
calendar fields computed in a time zone with numpy.

R's POSIXct carries a time zone and lubridate reads fields in it; here a
datetime array is a `pyarrow.timestamp` with a time zone, and its fields are
read in that zone. Local offsets come from `zoneinfo`, so no pyarrow time
zone database is needed (it is not bundled on Windows).
"""
from __future__ import annotations

import calendar as _cal
import datetime as _datetime
import re
from functools import lru_cache
from typing import Any

import numpy as np
import pyarrow as pa
import pyarrow.compute as pc

from ._utils import _stop

US = 1_000_000
_STEP_UNITS = {"sec": 1, "secs": 1, "second": 1, "seconds": 1,
               "min": 60, "mins": 60, "minute": 60, "minutes": 60,
               "hour": 3600, "hours": 3600, "day": 86400, "days": 86400,
               "DSTday": 86400, "week": 604800, "weeks": 604800}


_MONTH_UNITS = {"month": 1, "months": 1, "quarter": 3, "quarters": 3, "year": 12,
                "years": 12}


def _parse_by(by: object) -> tuple[int, str]:
    """`seq.POSIXt`'s `by` as (count, unit): "hour", "15 min", "month"."""
    if isinstance(by, (int, float)) and not isinstance(by, bool):
        return int(by), "sec"
    m = re.fullmatch(r"\s*(?:(\d+)\s+)?([A-Za-z]+)\s*", str(by))
    if not m or (m.group(2) not in _STEP_UNITS and m.group(2) not in _MONTH_UNITS):
        _stop('unsupported `by`: "%s"; use e.g. "hour", "15 min", "day", "month"', by)
    return int(m.group(1) or 1), m.group(2)


def step_seconds(by: object) -> int:
    """A fixed step in seconds ("hour", "15 min", "2 days", or seconds)."""
    n, unit = _parse_by(by)
    if unit in _MONTH_UNITS:
        _stop('`by` = "%s" is a calendar step, not a fixed number of seconds', by)
    return n * _STEP_UNITS[unit]


def grid_us(start: tuple[int, int, int], end: tuple[int, int, int], by: object,
            tz: str) -> np.ndarray:
    """Instants from local midnight `start` up to (excluding) `end`, as
    `seq.POSIXt(by=)`: fixed steps are absolute; month/quarter/year steps
    advance the month field from `start` (overflowing days roll forward)."""
    s_us = local_midnight_us(*start, tz)
    e_us = local_midnight_us(*end, tz)
    n, unit = _parse_by(by)
    if unit not in _MONTH_UNITS:
        return np.arange(s_us, e_us, n * _STEP_UNITS[unit] * US, dtype=np.int64)
    step = n * _MONTH_UNITS[unit]
    out, k = [], 0
    y0, m0, d0 = start
    while True:
        mm = m0 - 1 + k * step
        first = _datetime.date(y0 + mm // 12, mm % 12 + 1, 1)
        day = first + _datetime.timedelta(days=d0 - 1)
        u = local_midnight_us(day.year, day.month, day.day, tz)
        if u >= e_us:
            break
        out.append(u)
        k += 1
    return np.array(out, dtype=np.int64)


@lru_cache(maxsize=64)
def _zone(tz: str):
    from zoneinfo import ZoneInfo

    return ZoneInfo(tz)


def _is_utc(tz: str | None) -> bool:
    return tz is None or tz.upper() in ("UTC", "GMT", "Z", "ETC/UTC", "+00:00")


def local_midnight_us(year: int, month: int, day: int, tz: str) -> int:
    """The instant of local midnight on a date, in UTC microseconds."""
    if _is_utc(tz):
        return _cal.timegm((year, month, day, 0, 0, 0)) * US
    dt = _datetime.datetime(year, month, day, tzinfo=_zone(tz))
    return int(dt.timestamp()) * US


def utc_offset_us(us: np.ndarray, tz: str | None) -> np.ndarray:
    """Each instant's offset from UTC in the zone, in microseconds."""
    if _is_utc(tz):
        return np.zeros(us.shape, dtype=np.int64)
    zone = _zone(tz)
    secs = us // US
    uniq, inv = np.unique(secs // 900, return_inverse=True)  # offsets change on 15'
    offs = np.array([
        int(_datetime.datetime.fromtimestamp(int(q) * 900, zone)
            .utcoffset().total_seconds())
        for q in uniq], dtype=np.int64)
    return offs[inv] * US


def to_instants(x: Any) -> tuple[np.ndarray, np.ndarray, str]:
    """A datetime-like input as (UTC microseconds, validity mask, tz).

    Accepts pyarrow timestamp/date arrays, numpy datetime64, pandas/polars
    datetime series, Python datetimes/dates, and lists of them. Naive values
    are UTC; dates are UTC midnight (as R's `as.POSIXct(<Date>)`).
    """
    if isinstance(x, (pa.Array, pa.ChunkedArray)):
        arr = x
    elif isinstance(x, np.ndarray) and np.issubdtype(x.dtype, np.datetime64):
        arr = pa.array(x)
    elif type(x).__module__.split(".")[0] in ("pandas", "polars"):
        arr = pa.array(x.to_arrow() if hasattr(x, "to_arrow") else x)
    else:
        vals = [x] if isinstance(x, (_datetime.date, str)) else list(x)
        if vals and all(isinstance(v, str) or v is None for v in vals):
            _stop("datetimes are required, not character labels")
        vals = [v if v is None or isinstance(v, _datetime.datetime) else
                (_datetime.datetime(v.year, v.month, v.day) if isinstance(
                    v, _datetime.date) else v) for v in vals]
        aware = [v for v in vals if v is not None and v.tzinfo is not None]
        if aware:
            vals = [None if v is None else (v if v.tzinfo else v.replace(
                tzinfo=_datetime.timezone.utc)).astimezone(_datetime.timezone.utc)
                for v in vals]
            arr = pa.array(vals, pa.timestamp("us", tz="UTC"))
        else:
            arr = pa.array(vals, pa.timestamp("us"))
    if isinstance(arr, pa.ChunkedArray):
        arr = arr.combine_chunks()
    ty = arr.type
    if pa.types.is_date(ty):
        arr = pc.cast(pc.cast(arr, pa.date32()), pa.timestamp("s"))
        ty = arr.type
    if pa.types.is_dictionary(ty):
        _stop("datetimes are required, not character labels")
    if not pa.types.is_timestamp(ty):
        _stop("datetimes are required; got %s", ty)
    tz = ty.tz or "UTC"
    us = pc.cast(arr, pa.timestamp("us", tz=ty.tz)).cast(pa.int64())
    valid = np.asarray(pc.is_valid(us).to_numpy(zero_copy_only=False), dtype=bool)
    vals = np.asarray(pc.fill_null(us, 0).to_numpy(zero_copy_only=False),
                      dtype=np.int64)
    return vals, valid, tz


def instants_array(us: np.ndarray, valid: np.ndarray | None, tz: str,
                   unit: str = "s") -> pa.Array:
    """UTC microseconds back to a pyarrow timestamp array in `tz`."""
    mask = None if valid is None else ~valid
    div = {"s": US, "ms": 1000, "us": 1}[unit]
    return pa.array(us // div, pa.int64(), mask=mask).cast(
        pa.timestamp(unit, tz=tz))


class Fields:
    """Calendar fields of instants in a zone (plus a fixed minute shift)."""

    def __init__(self, us: np.ndarray, valid: np.ndarray, tz: str,
                 shift_minutes: int = 0) -> None:
        self.valid = valid
        local = us + utc_offset_us(us, tz) + int(shift_minutes) * 60 * US
        self.local_us = local
        secs = np.floor_divide(local, US)
        self.frac = (local - secs * US) / US
        self.days = np.floor_divide(secs, 86400)
        sod = secs - self.days * 86400
        d = self.days.astype("datetime64[D]")
        self.year = d.astype("datetime64[Y]").astype(np.int64) + 1970
        mon = d.astype("datetime64[M]")
        self.month = mon.astype(np.int64) % 12 + 1
        self.mday = (d - mon).astype(np.int64) + 1
        self.yday = (d - d.astype("datetime64[Y]")).astype(np.int64) + 1
        self.hour = sod // 3600
        self.minute = (sod % 3600) // 60
        self.second = sod % 60
        # 1970-01-01 was a Thursday: Monday-first 1..7
        self.wday_mon = (self.days + 3) % 7 + 1

    def wday(self, week_start: int | None = None) -> np.ndarray:
        """lubridate::wday(): Sunday = 1 by default, else `week_start` = 1."""
        ws = 7 if week_start is None else int(week_start)
        return (self.wday_mon - ws) % 7 + 1

    def dates(self) -> np.ndarray:
        return self.days.astype("datetime64[D]")


def masked(values: np.ndarray, valid: np.ndarray) -> pa.Array:
    """A numpy vector as a pyarrow array, null where `valid` is False."""
    return pa.array(values, mask=~valid)
