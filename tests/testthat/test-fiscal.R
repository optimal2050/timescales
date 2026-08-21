# fy04_* fiscal calendars (April-start: India, Japan) and the catalog's
# year_start/utc_offset_minutes entry fields ---------------------------------

test_that("fy04 catalog entries resolve with the fiscal anchor", {
  cal <- calendar("fy04_m12")
  expect_equal(S7::prop(cal, "meta")$year_start,
               list(month = 4L, day = 1L))
  cc <- calendar_catalog()
  expect_true(all(c("fy04_m12", "fy04_m12_h24", "fy04_q4", "fy04_q4_h24",
                    "fy04_d365", "fy04_d365_h24") %in% cc$id))
  expect_match(cc$desc[cc$id == "fy04_m12"], "fiscal year from m04")
})

test_that("members are fiscal-ordered while labels stay Gregorian", {
  cal <- calendar("fy04_m12")
  expect_equal(S7::prop(cal, "members")$MONTH,
               sprintf("m%02d", c(4:12, 1:3)))
  # leaftable rows follow the fiscal order, shares travel with labels
  lt <- S7::prop(cal, "leaftable")
  expect_equal(lt$MONTH[1], "m04")
  expect_equal(lt$share[lt$MONTH == "m02"], 28 / 365, tolerance = 1e-12)
  expect_equal(sum(lt$share), 1, tolerance = 1e-12)

  q <- calendar("fy04_q4")
  expect_equal(S7::prop(q, "members")$QUARTER, c("Q2", "Q3", "Q4", "Q1"))

  # April is m04 / Q2 -- Gregorian labels, always
  d <- lubridate::ymd("2021-04-15")
  expect_equal(datetime_to_timeslice(d, cal), "m04")
  expect_equal(datetime_to_timeslice(d, q), "Q2")
})

test_that("the fiscal model year spans April..March and anchors YEAR", {
  cal <- calendar("fy04_m12")
  g <- expand_calendar(cal, 2021, by = "day")
  expect_equal(nrow(g), 365L)
  expect_equal(as.Date(min(g$datetime)), as.Date("2021-04-01"))
  expect_equal(as.Date(max(g$datetime)), as.Date("2022-03-31"))
  expect_true(all(g$year == 2021L))   # FY 2021-22 -> 2021 (starting year)
  # January of 2022 belongs to model year 2021
  expect_equal(g$timeslice[as.Date(g$datetime) == as.Date("2022-01-15")],
               "m01")
})

test_that("fy04_d365 anchors YDAY and drops the following-year Feb 29", {
  d365 <- calendar("fy04_d365")
  expect_equal(datetime_to_timeslice(lubridate::ymd("2021-04-01"), d365),
               "d001")
  expect_equal(datetime_to_timeslice(lubridate::ymd("2022-03-31"), d365),
               "d365")
  # FY2023 contains 2024-02-29: dropped, and March days stay aligned
  expect_true(is.na(
    datetime_to_timeslice(lubridate::ymd("2024-02-29"), d365)))
  expect_equal(datetime_to_timeslice(lubridate::ymd("2024-03-31"), d365),
               "d365")
})

test_that("caller arguments override catalog entry fields", {
  # IST recipe: 2021-03-31 19:00 UTC = 2021-04-01 00:30 IST -> April
  ist <- calendar("fy04_m12", utc_offset_minutes = 330L)
  expect_equal(S7::prop(ist, "meta")$utc_offset_minutes, 330L)
  expect_equal(datetime_to_timeslice(
    as.POSIXct("2021-03-31 19:00:00", tz = "UTC"), ist), "m04")
  # ...and without the offset the same instant is still March
  expect_equal(datetime_to_timeslice(
    as.POSIXct("2021-03-31 19:00:00", tz = "UTC"), calendar("fy04_m12")),
    "m03")
  # year_start override wins over the entry
  jul <- calendar("fy04_d365", year_start = list(month = 7L, day = 1L))
  expect_equal(datetime_to_timeslice(lubridate::ymd("2021-07-01"), jul),
               "d001")
})

test_that("recasts between fy04 calendars conserve totals", {
  m <- calendar("fy04_m12")
  q <- calendar("fy04_q4")
  x <- data.frame(timeslice = S7::prop(m, "members")$MONTH,
                  energy = 1:12 * 10)
  out <- recast_calendar(x, m, q, year = 2021, rule = "sum")
  expect_equal(sum(out$energy), sum(x$energy), tolerance = 1e-9)
  # fiscal Q ordering in the completed output: Q2 first
  expect_equal(out$timeslice, c("Q2", "Q3", "Q4", "Q1"))
  # labels are Gregorian: Jan-Mar (of the FOLLOWING Gregorian year) is Q1,
  # last in fiscal order; Oct-Dec is Q4
  expect_equal(out$energy[out$timeslice == "Q1"],
               sum(x$energy[x$timeslice %in% c("m01", "m02", "m03")]),
               tolerance = 1e-9)
  expect_equal(out$energy[out$timeslice == "Q4"],
               sum(x$energy[x$timeslice %in% c("m10", "m11", "m12")]),
               tolerance = 1e-9)

  # fy04 -> plain m12: works, with the crosswalk window defined by `from`'s
  # fiscal year (Apr y .. Mar y+1) -- Jan-Mar values land on m01..m03 of the
  # single model-year group
  out2 <- recast_calendar(x, m, calendar("m12"), year = 2021, rule = "sum")
  expect_equal(sum(out2$energy), sum(x$energy), tolerance = 1e-9)
})

test_that("calendar_build appends named extras to meta and guards clashes", {
  cb <- calendar_build("m12", country = "IN", source = "CEA")
  expect_equal(S7::prop(cb, "meta")$country, "IN")
  expect_equal(S7::prop(cb, "meta")$source, "CEA")
  expect_error(calendar_build("m12", members = list()), "collide")
})

test_that("trivial year_start leaves every existing calendar untouched", {
  # rotation only activates for nontrivial anchors
  expect_equal(S7::prop(calendar("m12"), "members")$MONTH,
               sprintf("m%02d", 1:12))
  expect_equal(S7::prop(calendar("q4"), "members")$QUARTER,
               paste0("Q", 1:4))
})
