"""Calendar constructors (ports of R/calendar-construct.R and
R/calendar-build.R).

* `calendar_from_leaftable()` -- any weighted leaf table with a hierarchy;
* `calendar_build("d365", "h24")` -- a Cartesian product of tokens;
* `calendar("d365_h24")` -- by catalog id or token string.
"""
from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Any

import pyarrow as pa
import pyarrow.compute as pc
from nestedscales import backend_pull

from ._utils import _as_list, _stop
from .calendar_class import Calendar
from .catalog import CALENDAR_CATALOG, _calendar_m12_mday
from .tokens import get_calendar_token, list_calendar_tokens, token_expand

_DEFAULT_YS = {"month": 1, "day": 1}


def _strings(col: Any) -> list:
    return pc.cast(col, pa.string()).to_pylist()


def make_timeslice_ids(cols: Sequence[Sequence[str]]) -> list[str]:
    """Composite IDs: a row's timeframe labels joined with "_"."""
    if len(cols) == 1:
        return list(cols[0])
    return ["_".join(r) for r in zip(*cols, strict=True)]


def calendar_from_leaftable(leaftable: Any, timeframes: Sequence[str] | str,
                            members: Mapping[str, Sequence[str]] | None = None,
                            name: str = "", desc: str = "",
                            year_start: Mapping | None = None,
                            utc_offset_minutes: int = 0, year_fraction: float = 1,
                            row_order: str = "nested", **meta: Any) -> Calendar:
    """Build a Calendar from a table with one row per leaf timeslice.

    `timeslice` defaults to the timeframe labels joined with "_", `weight`
    to `share * 8760`, and `members` to first-appearance order. Extra
    keyword arguments become meta entries.
    """
    lt = leaftable if isinstance(leaftable, pa.Table) else backend_pull(leaftable)
    timeframes = _as_list(timeframes)
    if not timeframes or not all(isinstance(t, str) for t in timeframes):
        _stop("`timeframes` must be a non-empty character vector")
    missing = [t for t in timeframes if t not in lt.column_names]
    if missing:
        _stop("`leaftable` is missing timeframe columns: %s", ", ".join(missing))
    if "leaves" in meta or "levels" in meta:
        _stop("arguments `leaves`/`levels` were renamed `leaftable`/`members` "
              "(2026-08 lattice); update the call")
    for t in timeframes:
        lt = lt.set_column(lt.column_names.index(t), t,
                           pc.cast(lt[t], pa.string()))
    if "timeslice" not in lt.column_names:
        ids = make_timeslice_ids([lt[t].to_pylist() for t in timeframes])
        lt = lt.append_column("timeslice", pa.array(ids, pa.string()))
    else:
        lt = lt.set_column(lt.column_names.index("timeslice"), "timeslice",
                           pc.cast(lt["timeslice"], pa.string()))
    if "share" not in lt.column_names:
        _stop("`leaftable` is missing required column `share`")
    if "weight" not in lt.column_names:
        lt = lt.append_column("weight", pc.multiply(
            pc.cast(lt["share"], pa.float64()), 8760.0))
    if members is None:
        members = {t: list(dict.fromkeys(lt[t].to_pylist())) for t in timeframes}
    else:
        if not isinstance(members, Mapping):
            _stop("`members` must be a named list (one entry per timeframe)")
        members = dict(members)
        for t in timeframes:
            if t not in members:
                members[t] = list(dict.fromkeys(lt[t].to_pylist()))
    if _check_row_order(row_order) == "nested":
        lt = lt.take(pa.array(_nested_row_order(lt, timeframes, members), pa.int64()))
    m = {"name": str(name), "desc": str(desc),
         "year_start": dict(year_start or _DEFAULT_YS),
         "utc_offset_minutes": int(utc_offset_minutes),
         "year_fraction": float(year_fraction)}
    for k, v in meta.items():  # R's modifyList(): NULL removes the entry
        if v is None:
            m.pop(k, None)
        else:
            m[k] = v
    return Calendar(leaftable=lt, timeframes=timeframes, members=members, meta=m)


def _nested_row_order(table: pa.Table, frames: Sequence[str],
                      members: Mapping[str, Sequence[str]]) -> list[int]:
    """Row order by each frame, coarsest first, in member order; unassigned
    (null) codes last, ties in their given order (R: `.nested_row_order()`)."""
    keys = []
    for f in frames:
        pos = {m: i for i, m in enumerate(members[f])}
        keys.append([pos.get(v) for v in table[f].to_pylist()])
    return sorted(range(table.num_rows), key=lambda r: tuple(
        (1, 0) if k[r] is None else (0, k[r]) for k in keys))


def _check_row_order(row_order: str) -> str:
    if row_order not in ("nested", "given"):
        _stop("`row_order` should be one of: nested, given")
    return row_order


def _nontrivial_year_start(ys: Mapping | None) -> bool:
    return ys is not None and not (int(ys["month"]) == 1 and int(ys["day"]) == 1)


def _rotate_fiscal(exp: dict, tf: str, year_start: Mapping) -> dict:
    n = len(exp["label"])
    if tf == "MONTH" and n == 12:
        start = int(year_start["month"])
    elif tf == "QUARTER" and n == 4:
        start = (int(year_start["month"]) - 1) // 3 + 1
    else:
        start = 1
    if start <= 1:
        return exp
    order = [*range(start - 1, n), *range(start - 1)]
    return {k: [v[i] for i in order] for k, v in exp.items()}


_CONSTRUCTION_ARGS = ("leaftable", "timeframes", "members", "name", "desc",
                      "row_order",
                      "year_start", "utc_offset_minutes", "year_fraction",
                      "tokens", "alignment")


def calendar_build(*tokens: str, name: str | None = None, desc: str = "",
                   year_start: Mapping | None = None, utc_offset_minutes: int = 0,
                   year_fraction: float = 1, **meta: Any) -> Calendar:
    """A calendar as the Cartesian product of tokens, coarsest first.

    Shares are `year_fraction` times the product of the token shares; the
    rows run in nested, chronological order: coarsest timeframe first.
    A nontrivial `year_start` rotates the MONTH/QUARTER member order.
    """
    if not tokens:
        _stop("`calendar_build()` requires at least one token name as a positional "
              "argument")
    if not all(isinstance(t, str) for t in tokens):
        _stop("Token arguments must be single character strings")
    defs = [get_calendar_token(t) for t in tokens]
    tfs = [d["timeframe"] for d in defs]
    dup = [t for i, t in enumerate(tfs) if t in tfs[:i]]
    if dup:
        _stop("Duplicate timeframes among tokens: %s", ", ".join(dup))
    bad = [k for k in meta if k in _CONSTRUCTION_ARGS]
    if bad:
        _stop("Named argument(s) %s collide with construction arguments; rename "
              "the meta entr%s", ", ".join("`%s`" % b for b in bad),
              "ies" if len(bad) > 1 else "y")
    year_start = dict(year_start or _DEFAULT_YS)
    exps = [token_expand(t) for t in tokens]
    if _nontrivial_year_start(year_start):
        exps = [_rotate_fiscal(e, tf, year_start)
                for e, tf in zip(exps, tfs, strict=True)]

    # expand.grid (the first factor varies fastest); calendar_from_leaftable()
    # then puts the rows in nested (chronological) order
    n_rows = 1
    for e in exps:
        n_rows *= len(e["label"])
    cols: dict[str, list] = {}
    share = [float(year_fraction)] * n_rows
    rep = 1
    for e, tf in zip(exps, tfs, strict=True):
        k = len(e["label"])
        idx = [(r // rep) % k for r in range(n_rows)]
        cols[tf] = [e["label"][i] for i in idx]
        share = [s * e["share"][i] for s, i in zip(share, idx, strict=True)]
        rep *= k
    cols["share"] = share
    cols["weight"] = [s * 8760 for s in share]
    members = {tf: list(e["label"]) for e, tf in zip(exps, tfs, strict=True)}
    alignment = {tf: d["alignment"] for d, tf in zip(defs, tfs, strict=True)
                 if d.get("alignment") is not None}
    return calendar_from_leaftable(
        pa.table(cols), timeframes=tfs, members=members,
        name="_".join(tokens) if name is None else name, desc=desc,
        year_start=year_start, utc_offset_minutes=utc_offset_minutes,
        year_fraction=year_fraction, tokens=dict(zip(tfs, tokens, strict=True)),
        alignment=alignment or None, **meta)


def calendar(name: str, **kwargs: Any) -> Calendar:
    """A calendar by catalog id (`"m12_md365_h24"`) or token string
    (`"d365_h24"`); a `y_` prefix marks a year-qualified calendar."""
    if not isinstance(name, str) or name == "":
        _stop("`name` must be a single non-empty character string")
    parsed = name[2:] if name.startswith("y_") else name
    entry = CALENDAR_CATALOG.get(parsed)
    if entry is not None:
        cal = _calendar_from_catalog(entry, name=name, **kwargs)
    else:
        toks = parsed.split("_")
        unknown = [t for t in toks if t not in list_calendar_tokens()]
        if unknown:
            _stop("Unknown token(s) in '%s': %s. Use list_calendar_tokens() to see "
                  "available tokens and calendar_catalog() for the named designs, "
                  "or register_calendar_token() to add custom tokens.",
                  name, ", ".join(unknown))
        cal = calendar_build(*toks, name=name, **kwargs)
    if name.startswith("y_"):
        cal = _with_meta(cal, year_qualified=True)
    return cal


def _with_meta(cal: Calendar, **changes: Any) -> Calendar:
    meta = dict(cal.meta)
    meta.update(changes)
    return Calendar(leaftable=cal.leaftable, timeframes=cal.frames,
                    members=cal.members, meta=meta)


def _calendar_from_catalog(entry: dict, name: str, **kwargs: Any) -> Calendar:
    for f in ("year_start", "utc_offset_minutes"):
        if entry.get(f) is not None and kwargs.get(f) is None:
            kwargs[f] = entry[f]
    if entry.get("month_lengths") is not None:
        cal = _calendar_m12_mday(entry["month_lengths"], "h24" in entry["tokens"],
                                 entry["tokens"], name=name, **kwargs)
    else:
        cal = calendar_build(*entry["tokens"], name=name, **kwargs)
    return _with_meta(cal, coverage_class=entry["coverage_class"],
                      regularity=entry["regularity"])


def as_calendar(x: Any) -> Calendar:
    """A Calendar from a NestedScale holding one (e.g. a scale reopened from a
    `nestedscales` store, which records no class)."""
    import nestedscales as ns

    if isinstance(x, Calendar):
        return x
    if not ns.scale_is(x):
        _stop("`x` must be a NestedScale or Calendar object")
    return Calendar(leaftable=x.leaftable, timeframes=x.frames, members=x.members,
                    meta=x.meta)
