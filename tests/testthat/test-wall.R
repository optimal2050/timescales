# calendar_weekdays() / calendar_wall_layout() / calendar_wall_plot() --------

test_that("calendar_weekdays maps a real year onto the day layer", {
  wd <- calendar_weekdays(calendar("m12_md365"), 2021)
  expect_named(wd, c("timeslice", "date", "MONTH", "mday", "wday", "wrow",
                     "wyear"))
  expect_equal(nrow(wd), 365L)
  jan1 <- wd[wd$date == as.Date("2021-01-01"), ]
  expect_equal(as.character(jan1$wday), "FRI")   # 2021-01-01 was a Friday
  expect_equal(jan1$wrow, 1L)
  expect_equal(jan1$wyear, 1L)
  # week rows break on Monday: Sun Jan 3 still week 1, Mon Jan 4 week 2
  expect_equal(wd$wrow[wd$date == as.Date("2021-01-03")], 1L)
  expect_equal(wd$wrow[wd$date == as.Date("2021-01-04")], 2L)
})

test_that("week_start is fully custom and rotates the vocabulary", {
  wd <- calendar_weekdays(calendar("m12_md365"), 2021, week_start = "SUN")
  expect_equal(levels(wd$wday)[1], "SUN")
  # Friday is column 6 in a Sunday-start week
  expect_equal(as.integer(wd$wday[wd$date == as.Date("2021-01-01")]), 6L)
  # Sunday Jan 3 OPENS week 2 under a Sunday start
  expect_equal(wd$wrow[wd$date == as.Date("2021-01-03")], 2L)
  expect_error(calendar_weekdays(calendar("d365"), 2021,
                                 week_start = "XXX"),
               "week_start")
})

test_that("fiscal calendars anchor the weekday table to April", {
  wd <- calendar_weekdays(calendar("fy04_d365"), 2021)
  expect_equal(min(wd$date, na.rm = TRUE), as.Date("2021-04-01"))
  expect_equal(max(wd$date, na.rm = TRUE), as.Date("2022-03-31"))
  expect_equal(wd$wyear[wd$date == as.Date("2021-04-01")], 1L)
  expect_gt(wd$wyear[wd$date == as.Date("2022-03-31")], 50L)
  # month facets first-appear in fiscal order, from real dates
  expect_equal(head(levels(wd$MONTH), 3), c("m04", "m05", "m06"))
  expect_equal(utils::tail(levels(wd$MONTH), 1), "m03")
})

test_that("leap handling: d366 covers Feb 29; d365 warns it away", {
  wd366 <- calendar_weekdays(calendar("d366"), 2020)
  expect_true(as.Date("2020-02-29") %in% wd366$date)
  # d365 in a leap year: all 365 labels get real dates (Feb 29 skipped)
  wd365 <- calendar_weekdays(calendar("d365"), 2020)
  expect_false(as.Date("2020-02-29") %in% wd365$date)
  expect_equal(sum(!is.na(wd365$date)), 365L)
  # d366's last label has no date in a non-leap year -> NA + warning
  expect_warning(wd_n <- calendar_weekdays(calendar("d366"), 2021),
                 "no real date")
  expect_equal(sum(is.na(wd_n$date)), 1L)
})

test_that("wall layout: weekday vs sequence arrangements", {
  lay <- calendar_wall_layout(calendar("m12_md365"), year = 2021)
  expect_named(lay, c("timeslice", "MONTH", "label", "col", "row", "wday",
                      "date"))
  expect_equal(range(lay$col), c(1L, 7L))
  expect_false(any(is.na(lay$date)))

  seq_lay <- calendar_wall_layout(calendar("m12_md365"),
                                  arrange = "sequence")
  expect_true(all(is.na(seq_lay$date)))
  expect_equal(seq_lay$col[seq_lay$label == 8][1], 1L)   # day 8 opens row 2
  expect_equal(seq_lay$row[seq_lay$label == 8][1], 2L)

  # md360: 30-day months, no day 31, 5 exact rows in sequence mode
  m360 <- calendar_wall_layout(calendar("m12_md360"),
                               arrange = "sequence")
  expect_equal(max(m360$label), 30L)
  expect_equal(max(m360$row), 5L)

  # d365 sequence mode uses the 365-day month template
  d365 <- calendar_wall_layout(calendar("d365"), arrange = "sequence")
  expect_equal(as.vector(table(d365$MONTH)[c("m01", "m02")]), c(31L, 28L))
})

test_that("weekday arrangement without year falls back with a message", {
  expect_message(
    lay <- calendar_wall_layout(calendar("d365"), arrange = "weekday"),
    "falling back")
  expect_true(all(is.na(lay$date)))
})

test_that("calendars without a day timeframe error clearly", {
  expect_error(calendar_wall_layout(calendar("m12")),
               "day-resolution timeframe")
  expect_error(calendar_weekdays(calendar("q4_h24"), 2021),
               "day-resolution timeframe")
})

test_that("calendar_wall_plot assembles figures", {
  skip_if_not_installed("ggplot2")
  # plain calendar
  p1 <- calendar_wall_plot(calendar("m12_md365"), year = 2021)
  expect_s3_class(p1, "ggplot")

  # timeslice-keyed daily data on a fiscal wall: facets April-first
  cal <- calendar("fy04_d365")
  x <- data.frame(timeslice = S7::prop(cal, "leaftable")$timeslice,
                  v = seq_len(365) * 1.0)
  p2 <- calendar_wall_plot(cal, x, z = "v", year = 2021)
  expect_s3_class(p2, "ggplot")
  expect_equal(head(levels(p2$data$MONTH), 1), "m04")
  expect_true("value" %in% names(p2$data))
  # April 1 is d001 -> value 1
  expect_equal(p2$data$value[p2$data$timeslice == "d001"], 1)

  # datetime-keyed hourly data rolls up into day cells with `fun`
  calh <- calendar("d365_h24")
  h <- data.frame(
    datetime = as.POSIXct("2021-01-01 00:00", tz = "UTC") + 3600 * (0:47),
    v = rep(c(1, 3), each = 24))
  p3 <- calendar_wall_plot(calh, h, z = "v", year = 2021, fun = mean)
  expect_equal(p3$data$value[p3$data$timeslice == "d001"], 1)
  expect_equal(p3$data$value[p3$data$timeslice == "d002"], 3)

  # timeslice-keyed SUB-DAILY data rolls up too
  ht <- data.frame(
    timeslice = c("d001_h00", "d001_h12", "d002_h00"),
    v = c(2, 4, 10))
  p4 <- calendar_wall_plot(calh, ht, z = "v", year = 2021, fun = mean)
  expect_equal(p4$data$value[p4$data$timeslice == "d001"], 3)
  expect_equal(p4$data$value[p4$data$timeslice == "d002"], 10)

  # missing z errors; unknown codes warn
  expect_error(calendar_wall_plot(cal, x, year = 2021), "`z` must name")
  bad <- data.frame(timeslice = c("d001", "nope"), v = c(1, 2))
  expect_warning(calendar_wall_plot(cal, bad, z = "v", year = 2021),
                 "not timeslices")
})

test_that("calendar_breaks keeps the end values", {
  b <- calendar_breaks(4)
  x <- sprintf("h%02d", 0:23)
  got <- b(x)
  expect_equal(got[1], "h00")
  expect_equal(got[length(got)], "h23")
  expect_lte(length(got), 4L)
  # degenerate vocabularies survive
  expect_equal(calendar_breaks(6)(c("a", "b")), c("a", "b"))
  expect_equal(calendar_breaks(1)(c("a", "b")), c("a", "b"))  # floor n = 2
})

test_that("month facets carry the Gregorian year across a fiscal wall", {
  lay <- calendar_wall_layout(calendar("fy04_d365"), year = 2021)
  yr <- .wall_month_years(lay)
  expect_equal(unname(yr[c("m04", "m12")]), c(2021L, 2021L))
  expect_equal(unname(yr[c("m01", "m03")]), c(2022L, 2022L))
  # sequence mode has no dates -> all NA (labels stay year-free)
  seq_lay <- calendar_wall_layout(calendar("fy04_d365"),
                                  arrange = "sequence")
  expect_true(all(is.na(.wall_month_years(seq_lay))))
})
