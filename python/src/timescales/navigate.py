"""Navigation, queries and subsetting on a Calendar (port of R/navigate.R)."""
from __future__ import annotations

import hashlib
from collections.abc import Sequence

import nestedscales as ns
import pyarrow as pa
import pyarrow.compute as pc

from ._utils import _as_list, _check_calendar, _check_timeframe, _preview, _stop
from .calendar_class import Calendar

_FAMILY = pa.schema([("parent_timeframe", pa.string()), ("parent", pa.string()),
                     ("child_timeframe", pa.string()), ("child", pa.string())])


def calendar_timeframes(x: Calendar, finest: bool = False) -> list[str] | str:
    """Timeframes, coarsest first (or only the finest)."""
    _check_calendar(x, "calendar")
    return ns.scale_frames(x, finest=finest)


def calendar_rank(x: Calendar, timeframe: str | Sequence[str]):
    _check_calendar(x, "calendar")
    return ns.scale_rank(x, timeframe)


def calendar_timeslices(x: Calendar, timeframe: str | None = None,
                        qualified: bool = False) -> list[str]:
    """Leaf timeslice IDs, or the labels at one timeframe. `qualified=True`
    gives the node IDs at that timeframe (the leaves of the pruned
    calendar)."""
    _check_calendar(x, "calendar")
    if timeframe is None:
        return x.leaftable["timeslice"].to_pylist()
    _check_leaf_timeframe(x, timeframe)
    if qualified:
        from .base import prune_calendar

        return prune_calendar(x, timeframe).leaftable["timeslice"].to_pylist()
    return list(x.members[timeframe])


def calendar_leaftable(x: Calendar) -> pa.Table:
    _check_calendar(x, "calendar")
    return ns.scale_leaftable(x)


def _check_leaf_timeframe(cal: Calendar, timeframe: object,
                          arg: str = "timeframe") -> None:
    _check_timeframe(cal, timeframe, arg)
    if not all(t in cal.frames for t in _as_list(timeframe)):
        _stop("`%s` must be one of the calendar's timeframes; the ANNUAL root has "
              "no labels", arg)


def calendar_ancestry(x: Calendar) -> pa.Table:
    """Every (coarser, finer) label pair sharing a timeslice, all pairs."""
    _check_calendar(x, "calendar")
    out = ns.scale_ancestry(x)
    return out.rename_columns(["parent_timeframe", "parent", "child_timeframe",
                               "child"])


def calendar_family(x: Calendar, parent: str | None = None,
                    child: str | None = None) -> pa.Table:
    """Adjacent-timeframe parent/child pairs, in leaftable order."""
    _check_calendar(x, "calendar")
    tfs = list(x.frames)
    pairs = list(zip(tfs[:-1], tfs[1:], strict=True))
    if parent is not None:
        _check_leaf_timeframe(x, parent, "parent")
        pairs = [p for p in pairs if p[0] == parent]
    if child is not None:
        _check_leaf_timeframe(x, child, "child")
        pairs = [p for p in pairs if p[1] == child]
    rows = []
    for a, b in pairs:
        for pa_, ch in dict.fromkeys(zip(x.leaftable[a].to_pylist(),
                                         x.leaftable[b].to_pylist(), strict=True)):
            rows.append((a, pa_, b, ch))
    cols = list(zip(*rows, strict=True)) if rows else [(), (), (), ()]
    return pa.Table.from_arrays([pa.array(c, pa.string()) for c in cols],
                                schema=_FAMILY)


def _related(cal: Calendar, timeframe: str, label: object, target: str) -> list:
    _check_calendar(cal, "calendar")
    _check_leaf_timeframe(cal, timeframe)
    _check_leaf_timeframe(cal, target, "target")
    labels = _as_list(label)
    known = set(cal.members[timeframe])
    unknown = [v for v in dict.fromkeys(labels) if v not in known]
    if unknown:
        _stop("unknown label(s) at timeframe '%s': %s", timeframe, _preview(unknown))
    return ns.scale_children(cal, timeframe, labels, target=target)


def _index(x: Calendar, timeframe: str) -> int:
    tfs = list(x.frames)
    if timeframe not in tfs:
        _check_leaf_timeframe(x, timeframe)
    return tfs.index(timeframe)


def calendar_children(x: Calendar, timeframe: str, label: object,
                      target: str | None = None) -> list[str]:
    """Labels one timeframe finer (or at `target`) within `label`."""
    tfs = calendar_timeframes(x)
    i = _index(x, timeframe)
    if target is None:
        if i == len(tfs) - 1:
            _stop("'%s' is the finest timeframe; it has no children", timeframe)
        target = tfs[i + 1]
    return _related(x, timeframe, label, target)


def calendar_parents(x: Calendar, timeframe: str, label: object,
                     target: str | None = None) -> list[str]:
    """Labels one timeframe coarser (or at `target`) containing `label`."""
    tfs = calendar_timeframes(x)
    i = _index(x, timeframe)
    if target is None:
        if i == 0:
            _stop("'%s' is the coarsest timeframe; it has no parents", timeframe)
        target = tfs[i - 1]
    return _related(x, timeframe, label, target)


def _related_table(x: Calendar, timeframe: str, label: object,
                   targets: Sequence[str]) -> pa.Table:
    tf_col, lab_col = [], []
    for t in targets:
        labs = _related(x, timeframe, label, t)
        tf_col += [t] * len(labs)
        lab_col += labs
    return pa.table({"timeframe": pa.array(tf_col, pa.string()),
                     "label": pa.array(lab_col, pa.string())})


def calendar_descendants(x: Calendar, timeframe: str, label: object,
                         target: str | None = None) -> pa.Table:
    tfs = calendar_timeframes(x)
    i = _index(x, timeframe)
    j = len(tfs) - 1 if target is None else (
        tfs.index(target) if target in tfs else None)
    if j is None:
        _check_leaf_timeframe(x, target, "target")
    if j <= i:
        _stop("`target` must be finer than '%s'", timeframe)
    return _related_table(x, timeframe, label, tfs[i + 1:j + 1])


def calendar_ancestors(x: Calendar, timeframe: str, label: object,
                       target: str | None = None) -> pa.Table:
    tfs = calendar_timeframes(x)
    i = _index(x, timeframe)
    j = 0 if target is None else (tfs.index(target) if target in tfs else None)
    if j is None:
        _check_leaf_timeframe(x, target, "target")
    if j >= i:
        _stop("`target` must be coarser than '%s'", timeframe)
    return _related_table(x, timeframe, label, tfs[j:i])


def calendar_share(x: Calendar, timeframe: str,
                   within: str | None = None) -> pa.Table:
    """Each label's share of the year, or of its `within` parent."""
    _check_calendar(x, "calendar")
    _check_leaf_timeframe(x, timeframe)
    if within is None:
        return ns.scale_share(x, timeframe, weight="share")
    _check_leaf_timeframe(x, within, "within")
    tfs = list(x.frames)
    if tfs.index(within) >= tfs.index(timeframe):
        _stop("`within` ('%s') must be coarser than `timeframe` ('%s')",
              within, timeframe)
    out = ns.scale_share(x, timeframe, weight="share", within=within)
    rw = {v: i for i, v in enumerate(x.members[within])}
    rt = {v: i for i, v in enumerate(x.members[timeframe])}
    order = sorted(range(out.num_rows), key=lambda r: (
        rw[out[within][r].as_py()], rt[out[timeframe][r].as_py()]))
    return out.take(pa.array(order)).select([within, timeframe, "share"])


def _sample_meta(x: Calendar, kept: pa.Table, tag: str) -> dict:
    wts = ("share", "weight")
    meta = dict(x.meta)
    totals = meta.get("parent_totals")
    if totals is None:
        totals = {w: float(pc.sum(x.leaftable[w]).as_py()) for w in wts}
    cov = {w: float(pc.sum(kept[w]).as_py()) / totals[w] for w in wts}
    base = meta.get("parent_name") or meta.get("name") or ""
    meta.update(parent_totals=dict(totals), coverage=cov, parent_name=base,
                name=base + tag)
    return meta


def filter_calendar(x: Calendar, timeframe: str, labels: object) -> Calendar:
    """Keep the timeslices whose `timeframe` label is in `labels`.

    Shares are NOT renormalised: `year_fraction` becomes the kept share and
    the result is a sample of its root parent (`coverage`, `parent_totals`,
    `parent_name`, name `"parent[TF:labels]"`).
    """
    _check_calendar(x, "calendar")
    _check_leaf_timeframe(x, timeframe)
    labels = _as_list(labels)
    known = set(x.members[timeframe])
    unknown = [v for v in dict.fromkeys(labels) if v not in known]
    if unknown:
        _stop("unknown label(s) at timeframe '%s': %s", timeframe, _preview(unknown))
    keep = pc.is_in(x.leaftable[timeframe], value_set=pa.array(labels, pa.string()))
    n_keep = pc.sum(pc.cast(keep, pa.int64())).as_py() or 0
    if n_keep == 0:
        _stop("no timeslices left after filtering '%s' to %s", timeframe,
              _preview(labels))
    if n_keep == x.leaftable.num_rows:
        return x
    lt = x.leaftable.filter(keep)
    members = {}
    for tf in x.frames:
        seen = set(lt[tf].to_pylist())
        members[tf] = [v for v in x.members[tf] if v in seen]
    codes = list(dict.fromkeys(lt[timeframe].to_pylist()))
    if sum(len(c) for c in codes) + len(codes) <= 24:
        ident = "+".join(codes)
    else:  # R hashes with rlang::hash(), which is not reproducible here
        ident = "%d~%s" % (len(codes), hashlib.blake2b(
            "\n".join(sorted(codes)).encode(), digest_size=4).hexdigest())
    meta = _sample_meta(x, lt, "[%s:%s]" % (timeframe, ident))
    meta["year_fraction"] = float(pc.sum(lt["share"]).as_py())
    return Calendar(leaftable=lt, timeframes=x.frames, members=members, meta=meta)


def calendar_coverage(x: Calendar, weight: str | None = None):
    """Fraction of the root parent's share/weight this calendar keeps."""
    _check_calendar(x, "calendar")
    if weight is not None and weight not in ("share", "weight"):
        _stop('unknown weight `%s`; use "share" or "weight"', weight)
    return ns.scale_coverage(x, weight)
