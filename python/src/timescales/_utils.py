"""Internal utilities (port of R/utils.R).

Errors and warnings are nestedscales' classes, so one `except` catches a
failure anywhere in the stack.
"""
from __future__ import annotations

import warnings
from collections.abc import Iterable

from nestedscales import NestedScalesError, NestedScalesWarning


def _stop(msg: str, *args: object) -> None:
    raise NestedScalesError(msg % args if args else msg)


def _warn(msg: str, *args: object) -> None:
    warnings.warn(msg % args if args else msg, NestedScalesWarning, stacklevel=3)


def _preview(x: Iterable[object], n: int = 3) -> str:
    x = [str(v) for v in x]
    if len(x) <= n:
        return ", ".join(x)
    return "%s, ... (%d total)" % (", ".join(x[:n]), len(x))


def _as_list(x: object) -> list:
    """A string or a sequence as a list (a bare string is one element)."""
    if x is None:
        return []
    if isinstance(x, str):
        return [x]
    if hasattr(x, "to_pylist"):
        return x.to_pylist()
    return list(x)


def _check_calendar(x: object, arg: str = "calendar") -> None:
    from .calendar_class import Calendar

    if not isinstance(x, Calendar):
        _stop("`%s` must be a Calendar object", arg)


def _calendar_name(cal, require: bool = True, arg: str = "calendar") -> str:
    nm = cal.meta.get("name") or ""
    if require and not (isinstance(nm, str) and nm != ""):
        _stop("`%s` has no name; conversion and attach need a named calendar -- set "
              "meta$name, or build it with calendar()/calendar_build(), which name "
              "automatically", arg)
    return nm


def _check_timeframe(cal, timeframe: object, arg: str = "timeframe") -> None:
    tfs = list(cal.frames)
    bad = [t for t in _as_list(timeframe) if t not in [*tfs, "ANNUAL"]]
    if bad:
        _stop('`%s` must be "ANNUAL" or one of the calendar\'s timeframes (%s); '
              "got %s", arg, ", ".join(tfs), _preview(bad))
