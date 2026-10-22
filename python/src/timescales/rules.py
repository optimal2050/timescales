"""Recast rules and pairwise conversion overrides (port of R/rules.R).

Rules live in nestedscales' registry under the scope "calendar", which is
where the shared engine looks for a Calendar's rules.
"""
from __future__ import annotations

from collections.abc import Callable, Sequence

import nestedscales as ns
import pyarrow as pa

from ._utils import _stop
from .tokens import ALIGNMENT_RULES

CALENDAR_RULES = ("weighted_mean", "sum", "mean", "copy", "sd", "share", "logshare")

_CONVERSION_REGISTRY: dict[str, Callable] = {}

__all__ = ["ALIGNMENT_RULES", "CALENDAR_RULES"]


def _match_arg(value: object, choices: Sequence[str], arg: str) -> str:
    """R's `match.arg()`: exact, else a unique prefix."""
    if isinstance(value, str):
        if value in choices:
            return value
        hits = [c for c in choices if value and c.startswith(value)]
        if len(hits) == 1:
            return hits[0]
    _stop("`%s` should be one of: %s", arg, ", ".join(choices))


def register_calendar_rule(param: str, rule: str) -> dict:
    """Record the recast rule for a value column, for every calendar."""
    if not isinstance(param, str) or param == "":
        _stop("`param` must be a single non-empty string")
    rule = _match_arg(rule, CALENDAR_RULES, "rule")
    ns.register_scale_rule(param, rule, scope="calendar")
    return {"rule": rule}


def get_calendar_rule(param: str) -> dict | None:
    e = ns.get_scale_rule(param, scope="calendar")
    return None if e is None else {"rule": e["rule"]}


def list_calendar_rules() -> pa.Table:
    d = ns.list_scale_rules(scope="calendar")
    return d.select(["param", "rule"])


def clear_calendar_rules(name: str | Sequence[str] | None = None) -> None:
    """Remove calendar rules: the named value columns, or all of them."""
    ns.clear_scale_rules(name, scope="calendar")


def register_calendar_conversion(source: str, target: str,
                                 fun: Callable | None) -> str:
    """Register a custom conversion between two named calendars, consulted by
    `recast_calendar()` before the grid route. `fun=None` removes it."""
    for nm in (source, target):
        if not isinstance(nm, str) or nm == "":
            _stop("`source` and `target` must be single non-empty calendar names")
    key = "%s->%s" % (source, target)
    if fun is None:
        _CONVERSION_REGISTRY.pop(key, None)
        return key
    if not callable(fun):
        _stop("`fun` must be a function(x, source, target, ...) or NULL")
    _CONVERSION_REGISTRY[key] = fun
    return key


def get_calendar_conversion(source: str, target: str) -> Callable | None:
    return _CONVERSION_REGISTRY.get("%s->%s" % (source, target))


def list_calendar_conversions() -> pa.Table:
    return pa.table({"key": pa.array(sorted(_CONVERSION_REGISTRY), pa.string())})


def clear_calendar_conversions(name: str | Sequence[str] | None = None) -> None:
    """Remove conversions: the named keys ("a->b"), or all of them."""
    if name is None:
        _CONVERSION_REGISTRY.clear()
        return
    for k in [name] if isinstance(name, str) else name:
        _CONVERSION_REGISTRY.pop(k, None)
