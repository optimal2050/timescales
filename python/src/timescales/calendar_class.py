"""Calendar -- the time-dimension NestedScale (port of R/calendar-class.R).

A Calendar is a nested partition of a (model) year: a leaftable with one
row per leaf timeslice (a column per timeframe plus `timeslice`, `share`,
`weight`), the timeframes coarsest first, and their member labels. Meta:
`name`, `desc`, `year_start` ({month, day}), `utc_offset_minutes`,
`year_fraction`, `tokens`, `alignment`, and the sample bookkeeping.
"""
from __future__ import annotations

import math
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from typing import Any

import pyarrow as pa
from nestedscales import (
    NestedScale,
    backend_pull,
    empty_aliases,
    empty_attributes,
    scale_alias_property,
    scale_vocab,
)

from ._utils import _stop

_RESERVED = ("slice", "timeslice", "share", "weight")


class Calendar(NestedScale):
    """A nested time partition of a model year; key column `timeslice`."""

    _r_package = "timescales"
    timeframes = scale_alias_property("frames")

    def __init__(self, leaftable: Any, timeframes: Sequence[str] | str,
                 members: Mapping[str, Sequence[str]], meta: Mapping | None = None
                 ) -> None:
        meta = dict(meta or {})
        lt = leaftable if isinstance(leaftable, pa.Table) else backend_pull(leaftable)
        have = [c for c in ("share", "weight") if c in lt.column_names and (
            pa.types.is_floating(lt.schema.field(c).type)
            or pa.types.is_integer(lt.schema.field(c).type))]
        if meta.get("weights") is None and have:
            meta["weights"] = have
        if meta.get("default_weight") is None and "share" in have:
            meta["default_weight"] = "share"
        for k, v in (("leaftable", lt), ("frames", timeframes),
                     ("members", dict(members)), ("key", "timeslice"),
                     ("meta", meta), ("attributes", empty_attributes()),
                     ("aliases", empty_aliases())):
            object.__setattr__(self, k, v)
        self._construct()

    def _errors(self) -> list[str]:
        return [*super()._errors(), *_validate_calendar(self)]

    def __repr__(self) -> str:
        return "<Calendar[%s] leaf=%d>" % ("/".join(self.frames),
                                           self.leaftable.num_rows)

    def __str__(self) -> str:
        return _format_calendar(self)

    def __getitem__(self, idx: tuple) -> Calendar:
        """`x[timeframe, labels]` is `filter_calendar(x, timeframe, labels)`."""
        from .navigate import filter_calendar

        if not isinstance(idx, tuple) or len(idx) != 2:
            _stop("subset a calendar as `x[timeframe, labels]`")
        return filter_calendar(self, idx[0], idx[1])


@scale_vocab.register(Calendar)
def _(x: Calendar) -> dict[str, str]:
    return {"object": "Calendar", "frame": "timeframe", "frames": "timeframes",
            "unit": "timeslice", "units": "timeslices", "atoms": "timebase",
            "register_rule": "register_calendar_rule()",
            "register_map": "register_calendar_map_between()"}


def _validate_calendar(self: Calendar) -> list[str]:
    """R's Calendar validator, which S7 runs after the NestedScale one."""
    errs: list[str] = []
    lt, tfs, members, meta = self.leaftable, list(self.frames), self.members, self.meta
    cols = lt.column_names
    missing = [c for c in ("timeslice", "share", "weight") if c not in cols]
    if missing:
        errs.append("`leaftable` missing columns: %s" % ", ".join(missing))
    if not tfs or not all(isinstance(t, str) and t != "" for t in tfs):
        errs.append("`timeframes` must be a non-empty character vector")
    elif len(set(tfs)) != len(tfs):
        errs.append("`timeframes` must be unique")
    elif any(t in _RESERVED for t in tfs):
        errs.append("`timeframes` must not use the reserved names slice, timeslice, "
                    "share, weight")
    else:
        miss = [t for t in tfs if t not in cols]
        if miss:
            errs.append("`leaftable` missing timeframe columns: %s" % ", ".join(miss))
    if not isinstance(members, Mapping):
        errs.append("`members` must be a list")
    elif not errs:
        miss = [t for t in tfs if t not in members]
        if miss:
            errs.append("`members` missing entries for: %s" % ", ".join(miss))
        for t in [t for t in tfs if t in members]:
            lv = members[t]
            if (len(lv) == 0 or not all(isinstance(v, str) and v != "" for v in lv)
                    or len(set(lv)) != len(lv)):
                errs.append('`members[["%s"]]` must be a unique non-empty character '
                            "vector" % t)
                continue
            if set(lt[t].to_pylist()) != set(lv):
                errs.append('`members[["%s"]]` must contain exactly the values present '
                            "in `leaftable$%s`" % (t, t))
    if "timeslice" in cols:
        sid = lt["timeslice"].to_pylist()
        if (not pa.types.is_string(lt.schema.field("timeslice").type)
                or any(v is None or v == "" for v in sid) or len(set(sid)) != len(sid)):
            errs.append("`leaftable$timeslice` must be a unique non-empty character "
                        "vector")
    for c, rule in (("share", "> 0"), ("weight", ">= 0")):
        if c not in cols:
            continue
        v = lt[c].to_pylist()
        if any(z is None or not math.isfinite(z) or
               (z <= 0 if c == "share" else z < 0) for z in v):
            errs.append("`leaftable$%s` must be finite numeric values %s" % (c, rule))
    yf = meta.get("year_fraction", 1)
    if not isinstance(yf, (int, float)) or not math.isfinite(yf) or yf <= 0:
        errs.append("`meta$year_fraction` must be a single finite numeric > 0")
    elif "share" in cols and all(z is not None and math.isfinite(z)
                                 for z in lt["share"].to_pylist()):
        tot = sum(lt["share"].to_pylist())
        if abs(tot - yf) > 1e-9:
            errs.append("sum(`leaftable$share`) (%s) must equal `meta$year_fraction` "
                        "(%s)" % (_g(tot), _g(yf)))
    cov = meta.get("coverage")
    if cov is not None:
        if not isinstance(cov, Mapping) or not all(k in ("share", "weight")
                                                   for k in cov):
            errs.append('`meta$coverage` must be a named numeric over "share"/"weight"')
        elif any(not math.isfinite(v) or v <= 0 or v > 1 for v in cov.values()):
            errs.append("`meta$coverage` values must lie in (0, 1]")
        elif meta.get("parent_totals") is not None:
            pt = meta["parent_totals"]
            for w in [k for k in cov if k in pt and k in cols]:
                got = sum(z for z in lt[w].to_pylist() if z is not None) / pt[w]
                if abs(got - cov[w]) > 1e-8:
                    errs.append('`meta$coverage["%s"]` (%.6g) does not match the '
                                "leaftable (%.6g)" % (w, cov[w], got))
        pn = meta.get("parent_name")
        if pn is not None and not isinstance(pn, str):
            errs.append("`meta$parent_name` must be a single string")
    ys = meta.get("year_start")
    if ys is not None:
        if not isinstance(ys, Mapping) or ys.get("month") is None or \
                ys.get("day") is None:
            errs.append("`meta$year_start` must be `list(month = , day = )`")
        else:
            if not 1 <= int(ys["month"]) <= 12:
                errs.append("`meta$year_start$month` must be an integer in 1:12")
            if not 1 <= int(ys["day"]) <= 31:
                errs.append("`meta$year_start$day` must be an integer in 1:31")
    uom = meta.get("utc_offset_minutes")
    if uom is not None and (not isinstance(uom, (int, float)) or
                            not math.isfinite(uom) or abs(uom - round(uom)) > 1e-10):
        errs.append("`meta$utc_offset_minutes` must be a single integer (minutes)")
    return errs


def _g(x: float) -> str:
    """R's `%g`."""
    return "%g" % x


def _format_calendar(x: Calendar) -> str:
    meta = x.meta
    out = ["Calendar: %s " % (meta.get("name") or "<unnamed>")]
    if meta.get("desc"):
        out.append("Description: %s " % meta["desc"])
    out.append("Timeframes (%d):" % len(x.frames))
    toks, aln = meta.get("tokens") or {}, meta.get("alignment") or {}
    for t in x.frames:
        extras = ([("token: " + toks[t])] if t in toks else []) + \
            ([("alignment: " + aln[t])] if t in aln else [])
        out.append("  - %s (%d)%s" % (t, len(x.members[t]),
                                      " [%s]" % ", ".join(extras) if extras else ""))
    out.append("Leaf timeslices: %d" % x.leaftable.num_rows)
    out.append("year_fraction: %s" % _num(meta.get("year_fraction", 1)))
    ys = meta.get("year_start")
    if ys is not None:
        out.append("year_start: month=%d, day=%d" % (int(ys["month"]), int(ys["day"])))
    if meta.get("utc_offset_minutes") is not None:
        out.append("utc_offset_minutes: %s" % _num(meta["utc_offset_minutes"]))
    return "\n".join(out)


def _num(v: float) -> str:
    return str(int(v)) if float(v).is_integer() else "%.7g" % v


@dataclass(frozen=True)
class CalendarSummary:
    """The quantitative view of a calendar (R: `summary()` -> summary_Calendar)."""

    name: str
    desc: str
    timeframes: dict[str, int]
    n_timeslices: int
    year_fraction: float
    coverage: dict[str, float]
    sampled: bool
    parent_name: str | None
    coverage_class: str | None
    regularity: str | None
    share_range: tuple[float, float]
    weight_range: tuple[float, float]
    year_start: dict | None
    utc_offset_minutes: int | None

    def __str__(self) -> str:
        # R's cat() separates its arguments by a space, also before ">"
        out = ["<summary of Calendar%s >" % (" '%s'" % self.name if self.name
                                         else "")]
        if self.desc:
            out.append("  desc:          %s" % self.desc)
        out.append("  timeframes:     " + " / ".join(
            "%s (%d)" % kv for kv in self.timeframes.items()))
        out.append("  timeslices:     %d" % self.n_timeslices)
        out.append("  year_fraction:  %.6g" % self.year_fraction)
        if self.sampled:
            out.append("  SAMPLED:        " + ", ".join(
                "%s %.1f%%" % (k, 100 * c) for k, c in self.coverage.items())
                + (" of '%s'" % self.parent_name if self.parent_name else ""))
        if self.coverage_class is not None:
            out.append("  catalog:        %s%s" % (
                self.coverage_class,
                ", " + self.regularity if self.regularity else ""))
        out.append("  share range:    %.4g .. %.4g" % self.share_range)
        out.append("  weight range:   %.4g .. %.4g" % self.weight_range)
        if self.year_start is not None:
            out.append("  year_start:     month=%d, day=%d" % (
                int(self.year_start["month"]), int(self.year_start["day"])))
        if self.utc_offset_minutes is not None:
            out.append("  utc offset:     %s min" % _num(self.utc_offset_minutes))
        return "\n".join(out)


def calendar_summary(x: Calendar) -> CalendarSummary:
    """Per-weight coverage, ranges, and the catalog classification."""
    from ._utils import _check_calendar
    from .navigate import calendar_coverage

    _check_calendar(x, "x")
    meta, lt = x.meta, x.leaftable
    cov = calendar_coverage(x)
    sh, w = lt["share"].to_pylist(), lt["weight"].to_pylist()
    return CalendarSummary(
        name=meta.get("name") or "", desc=meta.get("desc") or "",
        timeframes={t: len(x.members[t]) for t in x.frames},
        n_timeslices=lt.num_rows, year_fraction=meta.get("year_fraction", 1),
        coverage=cov, sampled=any(c < 1 for c in cov.values()),
        parent_name=meta.get("parent_name"),
        coverage_class=meta.get("coverage_class"), regularity=meta.get("regularity"),
        share_range=(min(sh), max(sh)), weight_range=(min(w), max(w)),
        year_start=meta.get("year_start"),
        utc_offset_minutes=meta.get("utc_offset_minutes"))
