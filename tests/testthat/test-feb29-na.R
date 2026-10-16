# =========================================================================== #
# drop_feb29 calendars and missing datetimes.
# =========================================================================== #

test_that("an NA datetime labels as NA on a drop_feb29 calendar", {
  dtm <- as.POSIXct(c("2020-02-28 05:00", NA, "2020-03-01 05:00"), tz = "UTC")
  for (id in c("d365", "d365_h24", "fy04_d365_h24")) {
    got <- datetime_to_timeslice(dtm, calendar(id))
    expect_true(is.na(got[2]), label = id)
    expect_false(anyNA(got[c(1, 3)]), label = id)
  }
  # the NA does not shift its neighbours: Mar 1 2020 is still day 60 of d365
  expect_identical(datetime_to_timeslice(dtm, calendar("d365"))[3], "d060")
})
