"""timescales: calendars and timeslices for modeling.

Python binding of the R package of the same name, built on nestedscales.
Function names match R; the source/target arguments are `source`/`target`
(R: `from`/`to` until the 0.2.0 rename).
"""
from .base import base_calendar, prune_calendar
from .calendar_class import Calendar, CalendarSummary, calendar_summary
from .catalog import calendar_catalog
from .construct import as_calendar, calendar, calendar_build, calendar_from_leaftable
from .expand import datetime_to_timeslice, expand_calendar
from .join import join_calendar
from .map import (
    calendar_map,
    calendar_map_between,
    clear_calendar_maps,
    get_calendar_map,
    get_calendar_map_between,
    list_calendar_maps,
    register_calendar_map,
    register_calendar_map_between,
)
from .navigate import (
    calendar_ancestors,
    calendar_ancestry,
    calendar_children,
    calendar_coverage,
    calendar_descendants,
    calendar_family,
    calendar_leaftable,
    calendar_parents,
    calendar_rank,
    calendar_share,
    calendar_timeframes,
    calendar_timeslices,
    filter_calendar,
)
from .recast import recast_calendar, recast_from_timebase, recast_to_timebase
from .rules import (
    ALIGNMENT_RULES,
    CALENDAR_RULES,
    clear_calendar_conversions,
    clear_calendar_rules,
    get_calendar_conversion,
    get_calendar_rule,
    list_calendar_conversions,
    list_calendar_rules,
    register_calendar_conversion,
    register_calendar_rule,
)
from .timeframes import CORE_TIMEFRAMES, as_timeframe
from .timeslices import (
    dtm2tsl,
    hour2HOUR,
    tsl2dtm,
    tsl2hour,
    tsl2month,
    tsl2yday,
    yday2YDAY,
)
from .tokens import get_calendar_token, list_calendar_tokens, register_calendar_token

try:  # the generic lives in nestedscales; re-exported as in R
    from nestedscales import recast
except ImportError:  # pragma: no cover
    recast = None

__version__ = "0.7.0"

__all__ = [
    "ALIGNMENT_RULES", "CALENDAR_RULES", "CORE_TIMEFRAMES", "Calendar",
    "CalendarSummary", "as_calendar", "as_timeframe", "base_calendar", "calendar",
    "calendar_ancestors", "calendar_ancestry", "calendar_build", "calendar_catalog",
    "calendar_children", "calendar_coverage", "calendar_descendants",
    "calendar_family", "calendar_from_leaftable", "calendar_leaftable", "calendar_map",
    "calendar_map_between", "calendar_parents", "calendar_rank", "calendar_share",
    "calendar_summary", "calendar_timeframes", "calendar_timeslices",
    "clear_calendar_conversions", "clear_calendar_maps", "clear_calendar_rules",
    "datetime_to_timeslice", "dtm2tsl", "expand_calendar", "filter_calendar",
    "get_calendar_conversion", "get_calendar_map", "get_calendar_map_between",
    "get_calendar_rule", "get_calendar_token", "hour2HOUR", "join_calendar",
    "list_calendar_conversions", "list_calendar_maps", "list_calendar_rules",
    "list_calendar_tokens", "prune_calendar", "recast", "recast_calendar",
    "recast_from_timebase", "recast_to_timebase", "register_calendar_conversion",
    "register_calendar_map", "register_calendar_map_between", "register_calendar_rule",
    "register_calendar_token", "tsl2dtm", "tsl2hour", "tsl2month", "tsl2yday",
    "yday2YDAY",
]
