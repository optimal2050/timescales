"""What the R goldens do not reach: backends, the store, registries, the
recast generic, time zones."""
import datetime as dt

import nestedscales as ns
import pyarrow as pa
import pyarrow.dataset as ds
import pytest
from nestedscales import NestedScalesError

import timescales as ts


@pytest.fixture(autouse=True)
def _clean():
    ts.clear_calendar_rules()
    ts.clear_calendar_conversions()
    ts.clear_calendar_maps(registry=True)
    yield
    ts.clear_calendar_rules()
    ts.clear_calendar_conversions()
    ts.clear_calendar_maps(registry=True)


def m12_data():
    return pa.table({"timeslice": ts.calendar_timeslices(ts.calendar("m12")),
                     "v": [float(i) for i in range(1, 13)]})


def test_backends_round_trip_their_type(tmp_path):
    pd = pytest.importorskip("pandas")
    pl = pytest.importorskip("polars")
    m12, q4 = ts.calendar("m12"), ts.calendar("q4")
    ref = ts.recast_calendar(m12_data(), m12, q4, 2021, rule="sum")
    got_pd = ts.recast_calendar(m12_data().to_pandas(), m12, q4, 2021, rule="sum")
    assert isinstance(got_pd, pd.DataFrame)
    assert got_pd["v"].tolist() == ref["v"].to_pylist()
    got_pl = ts.recast_calendar(pl.from_arrow(m12_data()), m12, q4, 2021, rule="sum")
    assert isinstance(got_pl, pl.DataFrame)
    lazy = ts.recast_calendar(pl.from_arrow(m12_data()).lazy(), m12, q4, 2021,
                              rule="sum")
    assert isinstance(lazy, pl.LazyFrame)
    ds.write_dataset(m12_data(), tmp_path, format="ipc")
    got_ds = ts.recast_calendar(ds.dataset(tmp_path, format="ipc"), m12, q4, 2021,
                                rule="sum", collect=True)
    assert got_ds.equals(ref)


def test_store_round_trip_and_as_calendar(tmp_path):
    cal = ts.calendar("fy04_q4_h24")
    d = pa.table({"timeslice": ts.calendar_timeslices(cal)[:10],
                  "v": [1.0] * 10})
    ns.write_scale_dataset(d, cal, tmp_path / "s")
    back = ts.as_calendar(ns.open_scale_dataset(tmp_path / "s").scale)
    assert isinstance(back, ts.Calendar) and back == cal
    assert back.meta["year_start"] == {"month": 4, "day": 1}
    with pytest.raises(NestedScalesError, match="must be a NestedScale"):
        ts.as_calendar("q4")


def test_registries():
    ts.register_calendar_rule("load", "weighted")
    assert ts.get_calendar_rule("load") == {"rule": "weighted_mean"}
    assert ns.get_scale_rule("load", scope="calendar")["rule"] == "weighted_mean"
    assert ts.list_calendar_rules().column_names == ["param", "rule"]
    out = ts.recast_calendar(pa.table({"timeslice": ["Q1", "Q2", "Q3", "Q4"],
                                       "load": [1.0, 2, 3, 4]}),
                             ts.calendar("q4"), ts.calendar("s4"), 2021)
    assert out.num_rows == 4
    ts.clear_calendar_rules("load")
    assert ts.get_calendar_rule("load") is None

    seen = {}

    def conv(x, source, target, **kw):
        seen.update(kw)
        return "custom"

    ts.register_calendar_conversion("m12", "q4", conv)
    assert ts.recast_calendar(m12_data(), ts.calendar("m12"), ts.calendar("q4"), 2021,
                              rule="sum") == "custom"
    assert seen["year"] == 2021
    assert ts.list_calendar_conversions()["key"].to_pylist() == ["m12->q4"]
    ts.clear_calendar_conversions("m12->q4")
    assert ts.get_calendar_conversion("m12", "q4") is None


def test_registered_map_between_short_circuits():
    m = ts.calendar_map_between(ts.calendar("m12"), ts.calendar("q4"), 2021)
    ts.register_calendar_map_between("m12", "q4", m)
    assert ts.get_calendar_map_between(ts.calendar("m12"), "q4").equals(m)
    assert "m12->q4" in ts.list_calendar_maps()["key"].to_pylist()
    with pytest.raises(NestedScalesError, match="missing column"):
        ts.register_calendar_map_between("m12", "q4", pa.table({"x": [1]}))


def test_recast_generic_dispatches_on_calendar():
    a = ns.recast(m12_data(), ts.calendar("m12"), ts.calendar("q4"), 2021, rule="sum")
    b = ts.recast_calendar(m12_data(), ts.calendar("m12"), ts.calendar("q4"), 2021,
                           rule="sum")
    assert a.equals(b)


def test_time_zones_and_python_datetimes():
    berlin = dt.timezone(dt.timedelta(hours=2))
    # 00:30 in Berlin summer time is 22:30 UTC the day before
    x = [dt.datetime(2021, 7, 1, 0, 30, tzinfo=berlin)]
    assert ts.datetime_to_timeslice(x, ts.calendar("d365_h24")) == ["d181_h22"]
    # pyarrow stores the instant (22:30 UTC); fields read in the array's zone
    utc = dt.datetime(2021, 6, 30, 22, 30, tzinfo=dt.timezone.utc)
    arr = pa.array([utc], pa.timestamp("s", tz="Europe/Berlin"))
    assert ts.as_timeframe(arr, "HOUR") == [0]
    assert ts.as_timeframe([dt.date(2021, 1, 1)], "WDAY", format="token") == ["FRI"]


def test_grid_steps():
    assert ts.base_calendar(2021, by="month").num_rows == 12
    assert ts.base_calendar(2021, by="15 min").num_rows == 365 * 96
    with pytest.raises(NestedScalesError, match="unsupported `by`"):
        ts.base_calendar(2021, by="fortnight")


def test_print_and_summary():
    cal = ts.filter_calendar(ts.calendar("m12_h24"), "MONTH", ["m01", "m02"])
    assert str(cal).startswith("Calendar: m12_h24[MONTH:m01+m02]")
    sm = ts.calendar_summary(cal)
    assert sm.sampled and sm.n_timeslices == 48
    assert "SAMPLED:" in str(sm)
    assert str(sm).splitlines()[0] == (
        "<summary of Calendar 'm12_h24[MONTH:m01+m02]' >")
    assert cal["HOUR", "h00"].leaftable.num_rows == 2


def test_rows_are_nested_by_default():
    lt = ts.calendar_build("q4", "h24").leaftable
    assert lt["timeslice"].to_pylist()[:3] == ["Q1_h00", "Q1_h01", "Q1_h02"]
    df = {"Q": ["Q1", "Q2", "Q1", "Q2"], "H": ["a", "a", "b", "b"],
          "share": [0.25] * 4}
    given = ts.calendar_from_leaftable(df, timeframes=["Q", "H"], row_order="given")
    assert given.leaftable["timeslice"].to_pylist() == ["Q1_a", "Q2_a", "Q1_b", "Q2_b"]
