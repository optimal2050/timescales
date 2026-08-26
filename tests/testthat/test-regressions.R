# =========================================================================== #
# Regression pins migrated from dev/review-core-plan.md "Reproductions"
# (the 0.1.0 defects the conversion core was rewritten to fix), updated to
# the 0.5.0 API. The sum-inflation reproduction (#3) already lives in
# test-recast.R ("sum conserves totals -- the 0.1.0 defect").
# =========================================================================== #

test_that("every catalog calendar converts a covered datetime (no silent NA)", {
  # 0.1.0: m12a and h168 labels diverged from the formatter, so those
  # calendars silently converted NOTHING. The fix made the conversion
  # vocabulary-aware; this sweeps the whole catalog against it.
  d <- lubridate::ymd_h("2021-03-15 14", tz = "UTC")   # covered by all designs
  for (id in names(calendars)) {
    expect_false(is.na(datetime_to_timeslice(d, calendars[[id]])),
                 label = sprintf("calendar %s converts 2021-03-15", id))
  }
})

test_that("m12a converts datetimes (the silent-NA calendar defect)", {
  d <- lubridate::ymd_h("2021-03-15 14", tz = "UTC")
  expect_false(is.na(datetime_to_timeslice(d, calendar_build("m12a"))))
  expect_equal(datetime_to_timeslice(d, calendar_build("m12")), "m03")
})

test_that("weighted_mean reads the shares (the weighted_mean == mean defect)", {
  m <- .month_cal(); q <- .quarter_cal()
  xm <- data.frame(timeslice = sprintf("m%02d", 1:12),
                   load = seq(100, 210, length.out = 12))
  wm <- recast_calendar(xm, m, q, year = 2021, rule = "weighted_mean",
                        by = "month")
  mn <- recast_calendar(xm, m, q, year = 2021, rule = "mean", by = "month")
  expect_false(identical(wm$load, mn$load))
})

test_that("d360/d364/d365 tokens expand to their full day count", {
  # 0.1.0: d360/d364 had no slot for the tail ydays
  expect_length(get_calendar_token("d360")$expand()$label, 360)
  expect_length(get_calendar_token("d364")$expand()$label, 364)
  expect_length(get_calendar_token("d365")$expand()$label, 365)
})

test_that("the energyRt bridge contract holds end to end", {
  skip_if_not_installed("energyRt")
  skip_if_not_installed("data.table")
  cal <- calendar_build("q4", "h24", name = "q4_h24")
  lv <- calendar_leaftable(cal)
  tfs <- calendar_timeframes(cal)
  lv$ANNUAL <- "ANNUAL"
  # contract: timeframes coarsest-first, then `timeslice`, then `share` LAST
  tt <- data.table::as.data.table(lv[, c("ANNUAL", tfs, "timeslice",
                                         "share")])
  ec <- energyRt::newCalendar(name = "q4_h24", timetable = tt,
                              year_fraction = 1)
  expect_identical(nrow(ec@timeslice_share), 101L)   # 1 + 4 + 96
})
