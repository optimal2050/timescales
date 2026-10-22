"""recast_calendar() and the timebase halves (port of R/recast.R).

Every conversion routes source -> datetime grid -> target. The route is
collapsed into a crosswalk by `calendar_map_between()`, and the aggregation
is nestedscales' `recast_crosswalk()`, so NA semantics (including the
partial-source law) are the core's.
"""
from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Any, Literal

import nestedscales as ns
import numpy as np
import pyarrow as pa
import pyarrow.compute as pc

from ._dt import to_instants
from ._utils import _as_list, _calendar_name, _check_calendar, _preview, _stop, _warn
from .base import prune_calendar
from .calendar_class import Calendar
from .expand import _years, expand_calendar
from .map import calendar_map_between
from .rules import (
    CALENDAR_RULES,
    _match_arg,
    get_calendar_conversion,
    get_calendar_rule,
)

NaAction = Literal["drop", "error", "keep"]

# R reserves `.ts_*`; Python's working names are `__ts_*` (Acero reads a
# leading dot as a nested field path), so both are refused.
_TS_COLS = (".ts_parent", ".ts_tot", ".ts_to", ".ts_n_from", ".ts_n_overlap",
            ".ts_w", ".ts_f")
_KEEP_NULLS = pc.ScalarAggregateOptions(skip_nulls=False, min_count=0)
_NULL = pa.scalar(None, pa.float64())


def _check_ts_cols(schema: pa.Schema) -> None:
    clash = [c for c in schema.names if c in _TS_COLS or c.startswith("__ts_")]
    if clash:
        _stop("`x` uses reserved column name(s): %s", _preview(clash))


def _values_for(schema: pa.Schema, key: str, drop: Sequence[str],
                values: Any) -> list[str]:
    if values is None:
        out = [c for c in schema.names if c != key and c not in drop and (
            pa.types.is_integer(schema.field(c).type)
            or pa.types.is_floating(schema.field(c).type))]
        if not out:
            _stop("no numeric value columns found in `x`; specify `values=`")
        return out
    values = _as_list(values)
    miss = [v for v in values if v not in schema.names]
    if miss:
        _stop("value column(s) not in `x`: %s", _preview(miss))
    return values


def _rules_for(values: Sequence[str], rule: str | None) -> dict[str, str]:
    out = {}
    for v in values:
        if rule is not None:
            out[v] = _match_arg(rule, CALENDAR_RULES, "rule")
            continue
        reg = get_calendar_rule(v)
        if reg is None:
            _stop('no aggregation rule for value column `%s`; pass `rule=` or '
                  'register one with register_calendar_rule("%s", ...)', v, v)
        out[v] = reg["rule"]
    return out


def _named_or_temp(cal: Calendar, temp: str) -> Calendar:
    if _calendar_name(cal, require=False):
        return cal
    return _renamed(cal, temp)


def _renamed(cal: Calendar, name: str) -> Calendar:
    meta = dict(cal.meta)
    meta["name"] = name
    return Calendar(leaftable=cal.leaftable, timeframes=cal.frames,
                    members=cal.members, meta=meta)


def _distinct_keys(t: pa.Table, key: str) -> list[str]:
    return [k for k in pc.unique(pc.cast(t[key], pa.string())).to_pylist()
            if k is not None]


def _r_str(v: Any) -> str:
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    return "NA" if v is None else str(v)


def _missing_preview(t: pa.Table, id_cols: Sequence[str], key: str,
                     grid: Sequence[str]) -> tuple[int, list[str]]:
    """(count, the leading ones in R's report order) of grid sources absent
    from an identifier group."""
    rows = list(zip(*(t[c].to_pylist() for c in id_cols),
                    pc.cast(t[key], pa.string()).to_pylist(), strict=True))
    groups: dict[str, set] = {}
    for r in rows:
        groups.setdefault("\r".join(_r_str(v) for v in r[:-1]), set()).add(r[-1])
    missing: dict[str, None] = {}
    for g in sorted(groups):
        for k in grid:
            if k not in groups[g]:
                missing[k] = None
    return len(missing), list(missing)


def recast_calendar(x: Any, source: Calendar, target: Calendar | str, year: int,
                    key: str | None = None, values: Any = None,
                    rule: str | None = None, by: object = None, tz: str = "UTC",
                    na_action: NaAction = "drop", parent: Calendar | str | None = None,
                    collect: bool | None = None) -> Any:
    """Recast timeslice data from one calendar to another (or to a timeframe
    of the same calendar) through the datetime grid of `year`.

    Columns other than the key and the values are identifiers. `rule` is one
    of `CALENDAR_RULES`, or None to use `register_calendar_rule()`. Rule
    "share" keeps the source key and returns shares within `parent`.
    """
    na_action = _match_arg(na_action, ("drop", "error", "keep"), "na_action")
    bk = ns.backend_of(x, "x")
    if key is None:
        key = "timeslice"
    schema = ns.backend_schema(x, bk)
    if key not in schema.names:
        _stop("`x` has no column named `%s`; pass `key=`", key)
    _check_ts_cols(schema)
    _check_calendar(source, "source")
    if isinstance(target, str):
        target = prune_calendar(source, target)
    else:
        _check_calendar(target, "target")
    years = _years(year)
    if len(years) != 1:
        _stop("`year` must be a single integer")
    year = years[0]
    source_orig, target_orig = source, target

    s_name, t_name = source.meta.get("name"), target.meta.get("name")
    if s_name and t_name:
        fn = get_calendar_conversion(s_name, t_name)
        if fn is not None:
            return fn(x, source, target, year=year, key=key, values=values,
                      rule=rule, by=by, tz=tz, na_action=na_action)

    source = _named_or_temp(source, ".from")
    target = _named_or_temp(target, ".to")
    s_nm, t_nm = _calendar_name(source), _calendar_name(target)
    if s_nm == t_nm:
        t_nm = s_nm + "..to"
        target = _renamed(target, t_nm)

    tfs = list(source.frames)
    values = _values_for(schema, key, tfs, values)
    id_cols = [c for c in schema.names if c != key and c not in values
               and c not in tfs]
    rules = _rules_for(values, rule)

    t = ns.backend_scan(x, bk, [*id_cols, key, *values])
    src_keys = _distinct_keys(t, key)
    known = set(source.leaftable["timeslice"].to_pylist())
    unknown = [k for k in src_keys if k not in known]
    if unknown:
        _warn("%d code(s) in `x$%s` are not timeslices of `source` and were "
              "ignored: %s", len(unknown), key, _preview(unknown))

    is_share = [r in ("share", "logshare") for r in rules.values()]
    if any(is_share):
        if not all(is_share):
            _stop('rule "share" keeps the output keyed by `source` and cannot be '
                  "mixed with other rules in one call; recast the columns "
                  "separately")
        return _recast_share(t, bk, source_orig, target_orig, parent, year, key,
                             values, id_cols, by, tz, na_action, collect)
    if parent is not None:
        _stop('`parent` applies to rule "share" only')

    m = calendar_map_between(source, target, year, by=by, tz=tz)
    m = m.take(pc.sort_indices(m, sort_keys=[("year", "ascending"),
                                             (s_nm, "ascending"),
                                             (t_nm, "ascending")]))
    uncovered = pc.is_null(m[t_nm])
    if na_action == "error":
        n_bad = pc.sum(m.filter(uncovered)["n_overlap"]).as_py() or 0
        if n_bad > 0:
            _stop("%d grid point(s) are not covered by both calendars; use "
                  'na_action = "drop" or "keep"', n_bad)
    any_unc = bool(pc.any(uncovered).as_py())
    if any_unc and na_action == "drop":
        unc = m.filter(uncovered)
        src_set = set(src_keys)
        affected = [k for k in dict.fromkeys(unc[s_nm].to_pylist()) if k in src_set]
        _warn("%d grid point(s) are not covered by `target`; the share of %d source "
              "timeslice(s) falling on them is dropped; use na_action = \"keep\" "
              "to conserve totals", pc.sum(unc["n_overlap"]).as_py(), len(affected))
        m = m.filter(pc.invert(uncovered))

    grid = list(dict.fromkeys(m[s_nm].to_pylist()))
    if id_cols:
        n_missing, shown = _missing_preview(t, id_cols, key, grid)
    else:
        present = set(src_keys)
        shown = [k for k in grid if k not in present]
        n_missing = len(shown)
    if n_missing:
        _warn("%d source timeslice(s) present on the grid but missing from `x` "
              "(e.g. %s); produced NAs", n_missing,
              _preview_total(shown, n_missing))

    keep_na = na_action == "keep" and any_unc
    # a lazy caller gets the observed target groups only, as in R
    lazy_out = bk.lazy and not collect
    targets = None if lazy_out else [*target.leaftable["timeslice"].to_pylist(),
                                     *([None] if keep_na else [])]
    res = ns.recast_crosswalk(
        t, m.drop_columns(["year"]), source=s_nm, target=t_nm, key=key,
        values=values, rule=rules, ids=id_cols, targets=targets,
        unit="timeslice")
    out = res.rename_columns([key if c == t_nm else c for c in res.column_names])
    return ns.backend_restore(out, bk, collect)


def _preview_total(first: Sequence[str], total: int, n: int = 3) -> str:
    if total <= n:
        return ", ".join(first[:total])
    return "%s, ... (%d total)" % (", ".join(first[:n]), total)


def _share_parent(source: Calendar, target: Calendar,
                  parent: Calendar | str | None) -> Calendar:
    if parent is not None:
        if isinstance(parent, str):
            parent = prune_calendar(source, parent)
        _check_calendar(parent, "parent")
        if target != source and target != parent:
            _stop("conflicting parents: `target` and `parent` name different "
                  'calendars; for rule "share" pass the parent once')
        return parent
    if target != source:
        return target
    tfs = list(source.frames)
    if len(tfs) < 2:
        _stop("`source` has a single timeframe and no coarser parent; pass "
              "`parent=`")
    return prune_calendar(source, tfs[-2])


def _recast_share(t: pa.Table, bk: Any, source: Calendar, target: Calendar,
                  parent: Any, year: int, key: str, values: Sequence[str],
                  id_cols: Sequence[str], by: object, tz: str, na_action: str,
                  collect: bool | None) -> Any:
    parent = _share_parent(source, target, parent)
    src = _named_or_temp(source, ".from")
    par = _named_or_temp(parent, ".parent")
    s_nm, p_nm = _calendar_name(src), _calendar_name(par)
    if s_nm == p_nm:
        p_nm = p_nm + "..parent"
        par = _renamed(par, p_nm)
    m = calendar_map_between(src, par, year, by=by, tz=tz)
    mem = list(dict.fromkeys(zip(m[s_nm].to_pylist(), m[p_nm].to_pylist(),
                                 strict=True)))
    n_par: dict = {}
    for a, b in mem:
        if b is not None:
            n_par[a] = n_par.get(a, 0) + 1
    split = sorted(k for k, n in n_par.items() if n > 1)
    if split:
        _stop('rule "share": %d timeslice(s) of `source` straddle more than one '
              "parent timeslice (%s); the source must nest within the parent",
              len(split), _preview(split))
    orphans = [a for a, b in mem if b is None]
    if orphans:
        if na_action == "error":
            _stop("%d timeslice(s) of `source` are not covered by the parent; use "
                  'na_action = "drop" or "keep"', len(orphans))
        if na_action == "drop":
            _warn("%d timeslice(s) of `source` are not covered by the parent and "
                  'get NA shares (%s). Use na_action = "keep" to treat them as one '
                  "group.", len(orphans), _preview(orphans))
            mem = [p for p in mem if p[1] is not None]
    id_cols = list(id_cols)
    jmem = pa.table({key: pa.array([a for a, _ in mem], pa.string()),
                     "__ts_parent": pa.array([b for _, b in mem], pa.string())})
    xq = t.select([*id_cols, key, *values])
    xq = xq.set_column(xq.column_names.index(key), key,
                       pc.cast(xq[key], pa.string()))
    joined = xq.join(jmem, keys=key, join_type="inner")
    grp = [*id_cols, "__ts_parent"]
    tot = joined.select([*grp, *values]).group_by(grp).aggregate(
        [(v, "sum", _KEEP_NULLS) for v in values])
    tot = tot.rename_columns([("__ts_tot_" + c[:-4]) if c.endswith("_sum")
                              and c[:-4] in values else c for c in tot.column_names])
    from nestedscales.recast import _join_na

    res = _join_na(joined, tot, grp)
    for v in values:
        tt = pc.cast(res["__ts_tot_" + v], pa.float64())
        res = res.set_column(res.column_names.index(v), v, pc.if_else(
            pc.not_equal(tt, 0), pc.divide(pc.cast(res[v], pa.float64()), tt), _NULL))
    res = res.select([key, *id_cols, *values])
    if bk.lazy and not collect:
        return ns.backend_restore(res, bk, collect)
    from nestedscales.recast import _recast_complete

    idc = ns.backend_distinct(t, id_cols) if id_cols else pa.table({})
    out = _recast_complete(res, idc, source.leaftable["timeslice"].to_pylist(), key,
                           id_cols, values)
    return ns.backend_restore(out, bk, collect)


def _no_share(rules: Mapping[str, str], where: str) -> None:
    if any(r in ("share", "logshare") for r in rules.values()):
        _stop('rule "share" is not supported by %s(); use recast_calendar() with '
              "a parent calendar or timeframe", where)


def recast_to_timebase(x: Any, calendar: Calendar, year: Any = None,
                       key: str | None = None, values: Any = None,
                       rule: str | None = None, by: object = None, tz: str = "UTC",
                       attach_weight: bool = True, collect: bool | None = None) -> Any:
    """Project timeslice data DOWN to the datetime grid: one row per grid
    point. `sum` columns are split equally over a timeslice's grid points; a
    `weight` column (share / points) is attached for the return trip."""
    bk = ns.backend_of(x, "x")
    _check_calendar(calendar, "calendar")
    schema = ns.backend_schema(x, bk)
    _check_ts_cols(schema)
    cal_nm = _calendar_name(calendar, require=False)
    if key is None:
        key = "timeslice" if "timeslice" in schema.names else (
            cal_nm if cal_nm and cal_nm in schema.names else "timeslice")
    if key not in schema.names:
        _stop("`x` has no column named `%s`; pass `key=`", key)
    for cc in ["datetime", *(["weight"] if attach_weight else [])]:
        if cc in schema.names:
            _stop("`x` already has a `%s` column; rename it first", cc)
    has_year = "year" in schema.names
    t = ns.backend_scan(x, bk)
    if year is None:
        if not has_year:
            _stop("`x` has no `year` column; pass `year=`")
        year = sorted(int(y) for y in pc.unique(t["year"]).to_pylist()
                      if y is not None)
    years = _years(year)
    tfs = list(calendar.frames)
    values = _values_for(schema, key, [*tfs, "year"], values)
    rules = _rules_for(values, rule)
    _no_share(rules, "recast_to_timebase")
    lt = calendar.leaftable
    known = set(lt["timeslice"].to_pylist())
    unknown = [k for k in _distinct_keys(t, key) if k not in known]
    if unknown:
        _warn("%d code(s) in `x$%s` are not timeslices of the calendar: %s",
              len(unknown), key, _preview(unknown))

    grid = expand_calendar(calendar, years, by=by, tz=tz)
    grid = grid.filter(pc.is_valid(grid["timeslice"]))
    ts, yr = grid["timeslice"].to_pylist(), grid["year"].to_pylist()
    cnt: dict = {}
    for a, y in zip(ts, yr, strict=True):
        cnt[(y, a)] = cnt.get((y, a), 0) + 1
    n_from = [cnt[(y, a)] for a, y in zip(ts, yr, strict=True)]
    share = dict(zip(lt["timeslice"].to_pylist(), lt["share"].to_pylist(),
                     strict=True))
    grid = grid.append_column("__ts_n_from", pa.array(n_from, pa.float64()))
    if attach_weight:
        grid = grid.append_column("weight", pa.array(
            [share[a] / n for a, n in zip(ts, n_from, strict=True)], pa.float64()))
    grid = grid.append_column("__ts_g", pa.array(np.arange(grid.num_rows)))
    grid = grid.rename_columns([key if c == "timeslice" else c
                                for c in grid.column_names])
    t = t.set_column(t.column_names.index(key), key, pc.cast(t[key], pa.string()))
    t = t.append_column("__ts_x", pa.array(np.arange(t.num_rows)))
    on = [key]
    if has_year:
        grid = grid.set_column(grid.column_names.index("year"), "year",
                               pc.cast(grid["year"], t.schema.field("year").type))
        on.append("year")
    out = t.join(grid, keys=on, join_type="inner")
    out = out.take(pc.sort_indices(out, sort_keys=[("__ts_x", "ascending"),
                                                   ("__ts_g", "ascending")]))
    for v in values:
        if rules[v] == "sum":
            out = out.set_column(out.column_names.index(v), v, pc.divide(
                pc.cast(out[v], pa.float64()), out["__ts_n_from"]))
    id_cols = [c for c in schema.names if c != key and c not in values
               and c not in tfs and c != "year"]
    keep = ["datetime", "year", *id_cols, *values, *(["weight"] if attach_weight
                                                       else [])]
    return ns.backend_restore(out.select(keep), bk, collect)


def recast_from_timebase(x: Any, calendar: Calendar, year: Any = None,
                         key: str | None = None, values: Any = None,
                         rule: str | None = None, by: object = None,
                         tz: str = "UTC", na_action: NaAction = "drop",
                         collect: bool | None = None) -> Any:
    """Aggregate datetime-keyed rows UP into the calendar's timeslices, per
    model year. `weighted_mean` uses a `weight` column when present."""
    na_action = _match_arg(na_action, ("drop", "error", "keep"), "na_action")
    bk = ns.backend_of(x, "x")
    _check_calendar(calendar, "calendar")
    schema = ns.backend_schema(x, bk)
    _check_ts_cols(schema)
    if key is None:
        key = "datetime"
    if key not in schema.names:
        _stop("`x` has no column named `%s`; pass `key=`", key)
    if "timeslice" in schema.names:
        _stop("`x` already has a `timeslice` column; rename it first")
    t = ns.backend_scan(x, bk)
    us, valid, tz_x = to_instants(t[key])
    if year is None:
        from ._dt import Fields

        yy = Fields(us, valid, tz_x).year[valid]
        year = list(range(int(yy.min()) - 1, int(yy.max()) + 2))
    years = _years(year)
    tfs = list(calendar.frames)
    values = _values_for(schema, key, [*tfs, "year", "weight"], values)
    rules = _rules_for(values, rule)
    _no_share(rules, "recast_from_timebase")
    has_weight = "weight" in schema.names

    grid = expand_calendar(calendar, years, by=by, tz=tz)
    g_us = pc.cast(pc.cast(grid["datetime"], pa.timestamp("us", tz=tz)),
                   pa.int64())
    gt = pa.table({"__ts_us": g_us, "__ts_year": grid["year"],
                   "__ts_to": grid["timeslice"]})
    t = t.append_column("__ts_us", pa.array(us, mask=~valid))
    joined = t.join(gt, keys="__ts_us", join_type="left outer")
    n_na = pc.sum(pc.cast(pc.is_null(joined["__ts_to"]), pa.int64())).as_py() or 0
    if n_na > 0:
        if na_action == "error":
            _stop("%d row(s) of `x` fall on datetimes the calendar does not cover; "
                  'use na_action = "drop" or "keep"', n_na)
        if na_action == "drop":
            _warn("%d row(s) of `x` fall on datetimes the calendar does not cover "
                  'and were dropped; use na_action = "keep" to conserve totals',
                  n_na)
            joined = joined.filter(pc.is_valid(joined["__ts_to"]))
    id_cols = [c for c in schema.names if c not in (key, "weight", "year")
               and c not in values and c not in tfs]
    grp = ["__ts_year", "__ts_to", *id_cols]
    cols: dict[str, Any] = {c: joined[c] for c in grp}
    specs: list = []
    for i, v in enumerate(values):
        val = pc.cast(joined[v], pa.float64())
        p = "__ts_v%d" % i
        cols[p] = val
        r = rules[v]
        if r in ("sum", "mean", "copy"):
            specs.append((p, "sum" if r == "sum" else "mean", _KEEP_NULLS))
        elif r == "weighted_mean":
            specs.append((p, "mean", _KEEP_NULLS))
            if has_weight:
                w = pc.cast(joined["weight"], pa.float64())
                cols[p + "w"] = w
                cols[p + "vw"] = pc.multiply(val, w)
                specs += [(p + "w", "sum", _KEEP_NULLS), (p + "vw", "sum", _KEEP_NULLS)]
        elif r == "sd":
            specs.append((p, "stddev", pc.VarianceOptions(ddof=1, skip_nulls=False,
                                                          min_count=0)))
        if r == "copy":
            specs += [(p, "max", _KEEP_NULLS), (p, "min", _KEEP_NULLS)]
    g = pa.table(cols).group_by(grp).aggregate(specs)
    res = g.select(grp)
    for i, v in enumerate(values):
        p, r = "__ts_v%d" % i, rules[v]
        if r == "sum":
            col = g[p + "_sum"]
        elif r == "sd":
            col = g[p + "_stddev"]
        elif r == "weighted_mean" and has_weight:
            col = pc.if_else(pc.greater(g[p + "w_sum"], 0),
                             pc.divide(g[p + "vw_sum"], g[p + "w_sum"]), g[p + "_mean"])
        else:
            col = g[p + "_mean"]
        if r == "copy":
            rng = pc.subtract(g[p + "_max"], g[p + "_min"])
            bad = pc.and_(pc.is_valid(rng), pc.greater(rng, 1e-9))
            if pc.any(pc.fill_null(bad, False)).as_py():
                _stop('rule "copy" for `%s`: values are not constant within a target '
                      "timeslice", v)
        res = res.append_column(v, pc.cast(col, pa.float64()))
    res = res.rename_columns([{"__ts_to": "timeslice", "__ts_year": "year"}.get(c, c)
                              for c in res.column_names])
    if bk.lazy and not collect:
        return ns.backend_restore(res.select(["timeslice", "year", *id_cols, *values]),
                                  bk, collect)
    if na_action != "keep":
        res = res.filter(pc.or_(pc.is_valid(res["year"]),
                                pc.is_valid(res["timeslice"])))
    res = res.select(["timeslice", "year", *id_cols, *values])
    pos = {k: i for i, k in enumerate(calendar.leaftable["timeslice"].to_pylist())}
    order = sorted(range(res.num_rows), key=lambda r: (
        res["year"][r].as_py() is None, res["year"][r].as_py() or 0,
        pos.get(res["timeslice"][r].as_py(), len(pos))))
    return ns.backend_restore(res.take(pa.array(order, pa.int64())), bk, collect)


@ns.recast.register(Calendar)
def _(scale: Calendar, x: Any, target: Any = None, year: Any = None,
      **kwargs: Any) -> Any:
    return recast_calendar(x, scale, target, year, **kwargs)
