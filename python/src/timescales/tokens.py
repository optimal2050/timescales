"""Token registry (port of R/tokens.R).

A token is a named recipe for one timeframe's labels and per-label shares
(a fraction of a year, summing to 1): `d365` -> YDAY d001..d365, `h24` ->
HOUR h00..h23. Tokens compose into a calendar as a Cartesian product.
"""
from __future__ import annotations

from collections.abc import Callable, Sequence
from typing import Any

from ._utils import _stop
from .timeframes import CORE_TIMEFRAMES, DAYTYPE_LABELS, HOURTYPE_LABELS, SEASON_LABELS

MONTH_LENGTHS_365 = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
MONTH_LENGTHS_366 = (31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
MONTH_LENGTHS_360 = (30,) * 12
_QUARTER_DAYS_365 = (90, 91, 92, 92)
_MONTH_ABBR = ("JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP",
               "OCT", "NOV", "DEC")
_WDAY_ABBR_MONFIRST = ("MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN")

#: Alignment rules: how real instants beyond a vocabulary map onto it.
ALIGNMENT_RULES = ("exact", "drop_last", "drop_feb29", "repeat_last")

Expansion = dict[str, list]


def _padded(prefix: str, width: int, start: int, count: int) -> Callable[[], Expansion]:
    return lambda: {"label": ["%s%0*d" % (prefix, width, i)
                              for i in range(start, start + count)],
                    "share": [1 / count] * count}


def _enum(labels: Sequence[str], shares: Sequence[float] | None = None
          ) -> Callable[[], Expansion]:
    n = len(labels)
    return lambda: {"label": list(labels),
                    "share": list(shares) if shares is not None else [1 / n] * n}


def _days(labels: Sequence[str], days: Sequence[int]) -> Callable[[], Expansion]:
    return lambda: {"label": list(labels), "share": [d / 365 for d in days]}


_BUILTIN_TOKENS: dict[str, dict] = {
    "d360": {"timeframe": "YDAY", "alignment": "drop_last",
             "expand": _padded("d", 3, 1, 360)},
    "d364": {"timeframe": "YDAY", "alignment": "drop_last",
             "expand": _padded("d", 3, 1, 364)},
    "d365": {"timeframe": "YDAY", "alignment": "drop_feb29",
             "expand": _padded("d", 3, 1, 365)},
    "d366": {"timeframe": "YDAY", "expand": _padded("d", 3, 1, 366)},
    "m12": {"timeframe": "MONTH",
            "expand": _days(["m%02d" % i for i in range(1, 13)], MONTH_LENGTHS_365)},
    "m12a": {"timeframe": "MONTH", "expand": _days(_MONTH_ABBR, MONTH_LENGTHS_365)},
    "q4": {"timeframe": "QUARTER",
           "expand": _days(["Q%d" % i for i in range(1, 5)], _QUARTER_DAYS_365)},
    "s4": {"timeframe": "SEASON",
           "expand": _enum(SEASON_LABELS, [d / 365 for d in (90, 92, 92, 91)])},
    "w52": {"timeframe": "WEEK", "alignment": "repeat_last",
            "expand": _padded("w", 2, 1, 52)},
    "w53": {"timeframe": "WEEK", "expand": _padded("w", 2, 1, 53)},
    "wd7": {"timeframe": "WDAY", "expand": _enum(_WDAY_ABBR_MONFIRST)},
    "wk2": {"timeframe": "DAYTYPE", "expand": _enum(DAYTYPE_LABELS, [5 / 7, 2 / 7])},
    "hp3": {"timeframe": "HOURTYPE",
            "expand": _enum(HOURTYPE_LABELS, [12 / 24, 8 / 24, 4 / 24])},
    "h24": {"timeframe": "HOUR", "expand": _padded("h", 2, 0, 24)},
    "h168": {"timeframe": "WHOUR", "expand": _padded("h", 3, 0, 168)},
    "min60": {"timeframe": "MINUTE", "expand": _padded("min", 2, 0, 60)},
}

_TOKEN_REGISTRY: dict[str, dict] = dict(_BUILTIN_TOKENS)
_VOCAB_CACHE: dict[tuple, str | None] = {}


def register_calendar_token(name: str, timeframe: str,
                            expand: Callable[[], Any],
                            alignment: str | None = None) -> str:
    """Register a token: `expand()` returns `{"label": [...], "share": [...]}`
    (or a table with those columns) with unique labels and shares summing
    to 1."""
    if not isinstance(name, str) or name == "":
        _stop("`name` must be a single non-empty character string")
    if timeframe not in CORE_TIMEFRAMES:
        _stop("`timeframe` must be one of CORE_TIMEFRAMES")
    if not callable(expand):
        _stop("`expand` must be a function")
    if alignment is not None:
        from .rules import _match_arg

        alignment = _match_arg(alignment, ALIGNMENT_RULES, "alignment")
    test = _expansion(expand)
    lab, sh = test.get("label"), test.get("share")
    if (lab is None or sh is None or any(v is None for v in lab)
            or len(set(lab)) != len(lab)
            or not all(isinstance(z, (int, float)) and z > 0 for z in sh)
            or abs(sum(sh) - 1) > 1e-9):
        _stop("`expand()` must return a data.frame(label, share) with unique "
              "labels and share summing to 1")
    entry = {"timeframe": timeframe, "expand": expand}
    if alignment is not None:
        entry["alignment"] = alignment
    _TOKEN_REGISTRY[name] = entry
    _VOCAB_CACHE.clear()
    return name


def _expansion(expand: Callable[[], Any]) -> Expansion:
    out = expand()
    if hasattr(out, "to_pydict"):
        out = out.to_pydict()
    elif hasattr(out, "to_dict") and not isinstance(out, dict):
        out = {k: list(v) for k, v in out.to_dict("list").items()}
    return {"label": list(out["label"]), "share": [float(z) for z in out["share"]]}


def get_calendar_token(name: str) -> dict:
    """A token's definition: `timeframe`, `expand`, and optional `alignment`."""
    if name not in _TOKEN_REGISTRY:
        _stop("Unknown token: '%s'. Use list_calendar_tokens() to see available "
              "tokens.", name)
    return _TOKEN_REGISTRY[name]


def token_expand(name: str) -> Expansion:
    return _expansion(get_calendar_token(name)["expand"])


def list_calendar_tokens() -> list[str]:
    return sorted(_TOKEN_REGISTRY)


def valuation_vocab(calendar: Any, timeframe: str,
                    labels: Sequence[str | None]) -> list[str]:
    """The FULL vocabulary a timeframe's labels are numbered in.

    A sampled calendar holding d015, d105, ... still reads d015 as day 15,
    so positions are taken in the token's vocabulary, not the subset.
    """
    labels = list(dict.fromkeys(v for v in labels if v is not None))
    if not labels:
        return labels
    tok = (calendar.meta.get("tokens") or {}).get(timeframe)
    if tok is None or tok not in _TOKEN_REGISTRY:
        tok = infer_token(labels, timeframe)
    if tok is None:
        return labels
    return token_expand(tok)["label"]


def infer_token(labels: Sequence[str | None], timeframe: str) -> str | None:
    """The smallest registered token whose vocabulary holds every label."""
    labels = list(dict.fromkeys(v for v in labels if v is not None))
    if not labels:
        return None
    key = (timeframe, len(labels), labels[0], labels[-1])
    if key in _VOCAB_CACHE:
        return _VOCAB_CACHE[key]
    best, best_n = None, float("inf")
    want = set(labels)
    for nm in list_calendar_tokens():
        entry = _TOKEN_REGISTRY[nm]
        if entry["timeframe"] != timeframe:
            continue
        vocab = token_expand(nm)["label"]
        if not want <= set(vocab):
            continue
        if set(vocab) == want:
            best = nm
            break
        if len(vocab) < best_n:
            best, best_n = nm, len(vocab)
    _VOCAB_CACHE[key] = best
    return best


def complete_calendar(cal: Any) -> Any:
    """The full calendar a sampled one was drawn from, inferred from tokens."""
    from .construct import calendar

    toks = [infer_token(list(cal.members[tf]), tf) for tf in cal.frames]
    if any(t is None for t in toks):
        return None
    try:
        out = calendar("_".join(toks))
    except ValueError:
        return None
    if (out.meta.get("name") or "") == (cal.meta.get("name") or ""):
        return None
    return out
