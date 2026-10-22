"""The calendar catalog (port of R/catalog.R): 43 named designs.

Most entries are Cartesian token products; the six `m12_md*` designs are
non-Cartesian (February is short) and build through `_calendar_m12_mday()`.
"""
from __future__ import annotations

from typing import Any

import pyarrow as pa

from .tokens import (
    MONTH_LENGTHS_360,
    MONTH_LENGTHS_365,
    MONTH_LENGTHS_366,
    get_calendar_token,
    token_expand,
)


def _e(tokens: str | tuple, cov: str, reg: str, **kw: Any) -> dict:
    return {"tokens": (tokens,) if isinstance(tokens, str) else tuple(tokens),
            "coverage_class": cov, "regularity": reg, **kw}


_FY = {"month": 4, "day": 1}
T, C, R = "truncated", "complete", "representative"
REG, IRR = "regular", "irregular"

CALENDAR_CATALOG: dict[str, dict] = {
    "d360": _e("d360", T, REG), "d364": _e("d364", T, REG),
    "d365": _e("d365", T, REG), "d366": _e("d366", C, REG),
    "d360_h24": _e(("d360", "h24"), T, REG), "d364_h24": _e(("d364", "h24"), T, REG),
    "d365_h24": _e(("d365", "h24"), T, REG), "d366_h24": _e(("d366", "h24"), C, REG),
    "m12": _e("m12", C, REG), "m12a": _e("m12a", C, REG),
    "m12_h24": _e(("m12", "h24"), C, REG), "m12a_h24": _e(("m12a", "h24"), C, REG),
    "m12_md360": _e(("m12", "md360"), T, REG, month_lengths=MONTH_LENGTHS_360),
    "m12_md360_h24": _e(("m12", "md360", "h24"), T, REG,
                        month_lengths=MONTH_LENGTHS_360),
    "m12_md365": _e(("m12", "md365"), T, IRR, month_lengths=MONTH_LENGTHS_365),
    "m12_md365_h24": _e(("m12", "md365", "h24"), T, IRR,
                        month_lengths=MONTH_LENGTHS_365),
    "m12_md366": _e(("m12", "md366"), C, IRR, month_lengths=MONTH_LENGTHS_366),
    "m12_md366_h24": _e(("m12", "md366", "h24"), C, IRR,
                        month_lengths=MONTH_LENGTHS_366),
    "q4": _e("q4", C, REG), "s4": _e("s4", C, REG),
    "q4_h24": _e(("q4", "h24"), R, REG), "s4_h24": _e(("s4", "h24"), R, REG),
    "w52": _e("w52", T, REG), "w53": _e("w53", C, REG),
    "w52_h24": _e(("w52", "h24"), R, REG), "w53_h24": _e(("w53", "h24"), R, REG),
    "w52_h168": _e(("w52", "h168"), T, REG), "w53_h168": _e(("w53", "h168"), C, IRR),
    "wd7": _e("wd7", R, REG), "wd7_h24": _e(("wd7", "h24"), R, REG),
    "wk2": _e("wk2", R, REG), "wk2_h24": _e(("wk2", "h24"), R, REG),
    "fy04_m12": _e("m12", C, REG, year_start=_FY),
    "fy04_m12_h24": _e(("m12", "h24"), C, REG, year_start=_FY),
    "fy04_q4": _e("q4", C, REG, year_start=_FY),
    "fy04_q4_h24": _e(("q4", "h24"), R, REG, year_start=_FY),
    "fy04_d365": _e("d365", T, REG, year_start=_FY),
    "fy04_d365_h24": _e(("d365", "h24"), T, REG, year_start=_FY),
    "hp3": _e("hp3", R, REG), "d365_hp3": _e(("d365", "hp3"), R, REG),
    "m12a_hp3": _e(("m12a", "hp3"), R, REG), "s4_hp3": _e(("s4", "hp3"), R, REG),
    "q4_hp3": _e(("q4", "hp3"), R, REG),
}


def _catalog_timeframes(entry: dict) -> list[str]:
    if entry.get("month_lengths") is not None:
        return ["MONTH", "MDAY", *(["HOUR"] if "h24" in entry["tokens"] else [])]
    return [get_calendar_token(t)["timeframe"] for t in entry["tokens"]]


def _catalog_n_timeslices(entry: dict) -> int:
    if entry.get("month_lengths") is not None:
        n = sum(entry["month_lengths"])
        return n * 24 if "h24" in entry["tokens"] else n
    n = 1
    for t in entry["tokens"]:
        n *= len(token_expand(t)["label"])
    return n


def calendar_catalog() -> pa.Table:
    """The catalog: id, tokens, timeframes, n_timeslices, coverage_class,
    regularity, desc."""
    rows = []
    for cid, e in CALENDAR_CATALOG.items():
        tfs = _catalog_timeframes(e)
        n = _catalog_n_timeslices(e)
        ys = e.get("year_start")
        rows.append({
            "id": cid, "tokens": "+".join(e["tokens"]), "timeframes": "/".join(tfs),
            "n_timeslices": n, "coverage_class": e["coverage_class"],
            "regularity": e["regularity"],
            "desc": "%s calendar (%d timeslices; %s, %s%s)" % (
                "/".join(tfs), n, e["coverage_class"], e["regularity"],
                "" if ys is None else "; fiscal year from m%02d" % ys["month"])})
    return pa.Table.from_pylist(rows)


def _calendar_m12_mday(month_lengths: tuple, hour24: bool, tokens: tuple,
                       name: str = "", desc: str = "",
                       year_start: dict | None = None, utc_offset_minutes: int = 0,
                       year_fraction: float = 1.0) -> Any:
    from .construct import calendar_from_leaftable

    months = ["m%02d" % i for i in range(1, 13)]
    total = sum(month_lengths)
    mon, mday = [], []
    for m, n in zip(months, month_lengths, strict=True):
        mon += [m] * n
        mday += ["d%02d" % d for d in range(1, n + 1)]
    tfs = ["MONTH", "MDAY"]
    cols: dict[str, list] = {"MONTH": mon, "MDAY": mday}
    share = [year_fraction / total] * len(mon)
    if hour24:
        hours = ["h%02d" % h for h in range(24)]
        cols = {"MONTH": [v for v in mon for _ in range(24)],
                "MDAY": [v for v in mday for _ in range(24)],
                "HOUR": hours * total}
        tfs.append("HOUR")
        share = [year_fraction / (total * 24)] * (total * 24)
    cols["share"] = share
    members = {"MONTH": months,
               "MDAY": ["d%02d" % d for d in range(1, max(month_lengths) + 1)]}
    if hour24:
        members["HOUR"] = ["h%02d" % h for h in range(24)]
    return calendar_from_leaftable(
        pa.table(cols), timeframes=tfs, members=members, name=name, desc=desc,
        year_start=year_start or {"month": 1, "day": 1},
        utc_offset_minutes=utc_offset_minutes, year_fraction=year_fraction,
        tokens=dict(zip(tfs, tokens, strict=True)))
