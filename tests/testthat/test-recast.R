# Helpers --------------------------------------------------------------------

.month_cal <- function() {
  days <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
  calendar_from_leaves(
    data.frame(MONTH = sprintf("m%02d", 1:12),
               share = days / 365, weight = days),
    timeframes = "MONTH", name = "m12"
  )
}

.quarter_cal <- function() {
  q_days <- c(90, 91, 92, 92)  # non-leap
  calendar_from_leaves(
    data.frame(QUARTER = sprintf("Q%d", 1:4),
               share = q_days / 365, weight = q_days),
    timeframes = "QUARTER", name = "q4"
  )
}

.month_hour_cal <- function() {
  days <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
  names(days) <- sprintf("m%02d", 1:12)
  df <- expand.grid(
    MONTH = sprintf("m%02d", 1:12),
    HOUR  = sprintf("h%02d", 0:23),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  df$share  <- days[df$MONTH] / 365 / 24
  df$weight <- days[df$MONTH] / 24
  calendar_from_leaves(df, timeframes = c("MONTH", "HOUR"), name = "m12_h24")
}

# instant_to_slice -----------------------------------------------------------

test_that("instant_to_slice maps datetimes to slice IDs (single timeframe)", {
  cal <- .month_cal()
  dtm <- lubridate::ymd(c("2021-01-15", "2021-07-04", "2021-12-31"))
  expect_equal(instant_to_slice(dtm, cal), c("m01", "m07", "m12"))
})

test_that("instant_to_slice maps to composite slice IDs (two timeframes)", {
  cal <- .month_hour_cal()
  dtm <- lubridate::ymd_h(c("2021-01-15 00", "2021-07-04 13"), tz = "UTC")
  expect_equal(instant_to_slice(dtm, cal), c("m01_h00", "m07_h13"))
})

test_that("instant_to_slice returns NA for instants outside coverage", {
  # Calendar covers only Jan + Feb; July datetimes have no matching slice.
  df <- data.frame(MONTH = c("m01", "m02"),
                   share = c(31, 28) / 365, weight = c(31, 28))
  cal <- calendar_from_leaves(df, timeframes = "MONTH",
                              year_fraction = 59 / 365)
  out <- instant_to_slice(lubridate::ymd(c("2021-01-15", "2021-07-04")), cal)
  expect_equal(out, c("m01", NA_character_))
})

test_that("instant_to_slice rejects non-Calendar input", {
  expect_error(instant_to_slice(lubridate::ymd("2021-01-01"), list()),
               "Calendar")
})

# Vocabulary unification (the old silent-NA defects) --------------------------

test_that("enum vocabularies resolve positionally: m12a works", {
  cal <- calendar_build("m12a")
  dtm <- lubridate::ymd(c("2021-03-15", "2021-12-01"))
  expect_equal(instant_to_slice(dtm, cal), c("MAR", "DEC"))
})

test_that("h168 is hour-of-week (WHOUR), Monday-first", {
  cal <- calendar_build("h168")
  # 2021-03-15 is a Monday
  dtm <- lubridate::ymd_h(c("2021-03-15 00", "2021-03-15 14",
                            "2021-03-21 23"), tz = "UTC")
  expect_equal(instant_to_slice(dtm, cal), c("h000", "h014", "h167"))
})

test_that("wd7 maps weekday labels", {
  cal <- calendar_build("wd7")
  dtm <- lubridate::ymd(c("2021-03-15", "2021-03-21"))  # Mon, Sun
  expect_equal(instant_to_slice(dtm, cal), c("MON", "SUN"))
})

# Alignment rules -------------------------------------------------------------

test_that("d365 drops Feb 29 and shifts later ydays (drop_feb29)", {
  cal <- calendar_build("d365")
  dtm <- lubridate::ymd(c("2020-02-28", "2020-02-29", "2020-03-01",
                          "2020-12-31"))
  expect_equal(instant_to_slice(dtm, cal),
               c("d059", NA_character_, "d060", "d365"))
  # Non-leap years are untouched
  expect_equal(instant_to_slice(lubridate::ymd("2021-12-31"), cal), "d365")
})

test_that("d360 drops trailing days of the year (drop_last)", {
  cal <- calendar_build("d360")
  dtm <- lubridate::ymd(c("2021-12-26", "2021-12-27", "2021-12-31"))
  expect_equal(instant_to_slice(dtm, cal),
               c("d360", NA_character_, NA_character_))
})

test_that("w52 folds week 53 into w52 (repeat_last)", {
  cal <- calendar_build("w52")
  expect_equal(instant_to_slice(lubridate::ymd("2021-12-31"), cal), "w52")
})

test_that("alignment override 'exact' errors on uncovered instants", {
  cal <- calendar_build("d360")
  expect_error(
    instant_to_slice(lubridate::ymd("2021-12-31"), cal, alignment = "exact"),
    "exact"
  )
})

# year_start and utc_offset_minutes -------------------------------------------

test_that("year_start anchors YDAY to the fiscal year start", {
  cal <- calendar_build("d365", year_start = list(month = 7L, day = 1L))
  dtm <- lubridate::ymd(c("2021-07-01", "2021-07-02", "2022-06-30"))
  expect_equal(instant_to_slice(dtm, cal), c("d001", "d002", "d365"))
})

test_that("utc_offset_minutes shifts extraction into local time", {
  cal <- calendar_build("m12", utc_offset_minutes = -480L)  # UTC-8
  # 03:00 UTC on Jan 1 is still Dec 31 19:00 local
  dtm <- lubridate::ymd_h("2021-01-01 03", tz = "UTC")
  expect_equal(instant_to_slice(dtm, cal), "m12")
})

# expand_calendar ------------------------------------------------------------

test_that("expand_calendar enumerates a year at the right resolution", {
  cal <- .month_cal()
  grid <- expand_calendar(cal, year = 2021, by = "day")
  expect_named(grid, c("datetime", "year", "slice"))
  expect_equal(nrow(grid), 365)
  expect_setequal(unique(grid$slice), sprintf("m%02d", 1:12))
})

test_that("expand_calendar default resolution follows finest timeframe", {
  cal <- .month_hour_cal()
  grid <- expand_calendar(cal, year = 2021)  # default -> hourly
  expect_equal(nrow(grid), 365 * 24)
})

test_that("expand_calendar handles leap years correctly", {
  cal <- .month_cal()
  grid <- expand_calendar(cal, year = 2020, by = "day")
  expect_equal(nrow(grid), 366)
  # Feb 29 still maps to m02 because the calendar has m02
  feb29 <- grid$slice[grid$datetime == as.POSIXct("2020-02-29", tz = "UTC")]
  expect_equal(feb29, "m02")
})

test_that("expand_calendar spans multiple years", {
  cal <- .month_cal()
  grid <- expand_calendar(cal, year = 2019:2020, by = "day")
  expect_equal(nrow(grid), 365 + 366)
  expect_equal(unique(grid$year), c(2019L, 2020L))
})

test_that("expand_calendar honours year_start windows", {
  cal <- calendar_build("d365", year_start = list(month = 7L, day = 1L))
  grid <- expand_calendar(cal, year = 2021, by = "day")
  expect_equal(nrow(grid), 365)
  expect_equal(min(grid$datetime), as.POSIXct("2021-07-01", tz = "UTC"))
  expect_equal(grid$slice[1], "d001")
  expect_equal(grid$slice[365], "d365")
})

# recast: aggregation rules ---------------------------------------------------

test_that("recast aggregates monthly -> quarterly with day-weighted mean", {
  cal_m <- .month_cal()
  cal_q <- .quarter_cal()
  x <- data.frame(slice = sprintf("m%02d", 1:12),
                  load  = seq(100, 210, length.out = 12))
  out <- recast(x, from = cal_m, to = cal_q, year = 2021,
                rule = "weighted_mean", by = "day")
  expect_named(out, c("slice", "load"))
  expect_equal(out$slice, sprintf("Q%d", 1:4))

  # Q1 = (31*v1 + 28*v2 + 31*v3) / 90
  v <- x$load
  expected_q1 <- (31 * v[1] + 28 * v[2] + 31 * v[3]) / 90
  expect_equal(out$load[1], expected_q1, tolerance = 1e-10)
})

test_that("recast 'sum' conserves totals (the 0.1.0 defect)", {
  cal_m <- .month_cal()
  cal_q <- .quarter_cal()
  # one unit per month -> each quarter gets 3, total stays 12
  x <- data.frame(slice = sprintf("m%02d", 1:12), v = rep(1, 12))
  out <- recast(x, from = cal_m, to = cal_q, year = 2021,
                rule = "sum", by = "day")
  expect_equal(out$v, rep(3, 4))
  expect_equal(sum(out$v), sum(x$v))
})

test_that("recast 'sum' conserves through a two-level hierarchy", {
  cal  <- calendar_build("q4", "h24")
  x <- data.frame(slice = S7::prop(cal, "leaves")$slice, v = 1)
  out <- recast(x, from = cal, to = calendar_build("q4"), year = 2021,
                rule = "sum")
  expect_equal(sum(out$v), 96)  # was 8760 before the fix
  expect_equal(out$v, rep(24, 4))
})

test_that("recast 'weighted_mean' reads declared shares (differs from mean)", {
  # Equal *declared* shares even though months differ in real length
  cal_eq <- calendar_from_leaves(
    data.frame(MONTH = sprintf("m%02d", 1:12),
               share = rep(1 / 12, 12), weight = rep(730, 12)),
    timeframes = "MONTH", name = "m12eq"
  )
  cal_q <- .quarter_cal()
  # Asymmetric values: with 1:3 the two means coincide numerically for Q1
  v <- c(1, 10, 2, rep(0, 9))
  x <- data.frame(slice = sprintf("m%02d", 1:12), v = v)

  wm <- recast(x, cal_eq, cal_q, year = 2021, rule = "weighted_mean",
               by = "day")
  mn <- recast(x, cal_eq, cal_q, year = 2021, rule = "mean", by = "day")

  # weighted_mean: equal declared shares -> plain average of the months
  expect_equal(wm$v[1], mean(v[1:3]), tolerance = 1e-10)
  # mean: time-weighted by real month lengths
  expect_equal(mn$v[1], (31 * v[1] + 28 * v[2] + 31 * v[3]) / 90,
               tolerance = 1e-10)
  expect_false(isTRUE(all.equal(wm$v[1], mn$v[1])))
})

test_that("recast 'copy' returns the common value and rejects non-constant", {
  cal_m <- .month_cal()
  cal_q <- .quarter_cal()
  x_const <- data.frame(slice = sprintf("m%02d", 1:12), v = rep(7, 12))
  out <- recast(x_const, cal_m, cal_q, year = 2021, rule = "copy", by = "day")
  expect_equal(out$v, rep(7, 4))

  x_vary <- data.frame(slice = sprintf("m%02d", 1:12), v = 1:12 * 1.0)
  expect_error(
    recast(x_vary, cal_m, cal_q, year = 2021, rule = "copy", by = "day"),
    "not constant"
  )
})

test_that("recast 'sd' measures spread of the fine signal", {
  cal_m <- .month_cal()
  cal_q <- .quarter_cal()
  x <- data.frame(slice = sprintf("m%02d", 1:12), v = 1:12 * 1.0)
  out <- recast(x, cal_m, cal_q, year = 2021, rule = "sd", by = "day")
  expected_q1 <- stats::sd(c(rep(1, 31), rep(2, 28), rep(3, 31)))
  expect_equal(out$v[1], expected_q1, tolerance = 1e-10)
})

test_that("recast disaggregates: sum splits, weighted_mean copies", {
  cal_m <- .month_cal()
  cal_q <- .quarter_cal()
  xq <- data.frame(slice = sprintf("Q%d", 1:4), v = c(90, 91, 92, 92) * 1.0)

  down_sum <- recast(xq, cal_q, cal_m, year = 2021, rule = "sum", by = "day")
  # Q1's 90 split over its 90 days: January gets 31
  expect_equal(down_sum$v[1], 31, tolerance = 1e-10)
  expect_equal(sum(down_sum$v), sum(xq$v), tolerance = 1e-10)

  down_int <- recast(xq, cal_q, cal_m, year = 2021, rule = "weighted_mean",
                     by = "day")
  expect_equal(down_int$v[1:3], rep(90, 3), tolerance = 1e-10)
})

test_that("recast roundtrips identity on the same calendar", {
  cal <- .month_cal()
  x <- data.frame(slice = sprintf("m%02d", 1:12),
                  v = seq_len(12) * 1.5)
  out <- recast(x, from = cal, to = cal, year = 2021, by = "day")
  expect_equal(out$v, x$v, tolerance = 1e-10)
})

# recast: within-calendar aggregation and the ANNUAL root ---------------------

test_that("recast accepts a timeframe name for `to`", {
  cal <- calendar_build("q4", "h24")
  x <- data.frame(slice = S7::prop(cal, "leaves")$slice, v = 1)
  out <- recast(x, cal, to = "QUARTER", year = 2021, rule = "sum")
  expect_equal(out$slice, sprintf("Q%d", 1:4))
  expect_equal(sum(out$v), 96)
})

test_that("recast to = 'ANNUAL' aggregates to the root", {
  cal <- calendar_build("q4", "h24")
  x <- data.frame(slice = S7::prop(cal, "leaves")$slice, v = 1)
  out <- recast(x, cal, to = "ANNUAL", year = 2021, rule = "sum")
  expect_equal(out$slice, "ANNUAL")
  expect_equal(out$v, 96)
})

# recast: na_action -----------------------------------------------------------

test_that("na_action = 'drop' warns and loses uncovered share", {
  cal_m <- .month_cal()
  cal_d360 <- calendar_build("d360")  # Dec 27-31 uncovered
  x <- data.frame(slice = sprintf("m%02d", 1:12), v = rep(1, 12))
  expect_warning(
    out <- recast(x, cal_m, cal_d360, year = 2021, rule = "sum", by = "day"),
    "not covered by `to`"
  )
  expect_lt(sum(out$v, na.rm = TRUE), 12)
})

test_that("na_action = 'error' stops on uncovered instants", {
  cal_m <- .month_cal()
  cal_d360 <- calendar_build("d360")
  x <- data.frame(slice = sprintf("m%02d", 1:12), v = rep(1, 12))
  expect_error(
    recast(x, cal_m, cal_d360, year = 2021, rule = "sum", by = "day",
           na_action = "error"),
    "not covered"
  )
})

test_that("na_action = 'keep' conserves totals in an explicit NA row", {
  cal_m <- .month_cal()
  cal_d360 <- calendar_build("d360")
  x <- data.frame(slice = sprintf("m%02d", 1:12), v = rep(1, 12))
  out <- recast(x, cal_m, cal_d360, year = 2021, rule = "sum", by = "day",
                na_action = "keep")
  expect_true(anyNA(out$slice))
  expect_equal(sum(out$v, na.rm = TRUE), 12, tolerance = 1e-10)
})

# recast: registries ----------------------------------------------------------

test_that("recast consults the per-parameter rule registry", {
  on.exit(clear_rules(), add = TRUE)
  register_rule("energy", "sum")
  cal_m <- .month_cal()
  cal_q <- .quarter_cal()
  x <- data.frame(slice = sprintf("m%02d", 1:12),
                  energy = rep(1, 12),        # registered -> sum
                  load   = rep(5, 12))        # unregistered -> weighted_mean
  out <- recast(x, cal_m, cal_q, year = 2021, by = "day")
  expect_equal(sum(out$energy), 12)
  expect_equal(out$load, rep(5, 4))
})

test_that("a registered pairwise conversion short-circuits the grid route", {
  on.exit(clear_conversions(), add = TRUE)
  marker <- data.frame(slice = "override", v = -1)
  register_conversion("m12", "q4", function(x, from, to, ...) marker)
  out <- recast(data.frame(slice = "m01", v = 1),
                .month_cal(), .quarter_cal(), year = 2021)
  expect_identical(out, marker)
})

# recast: input validation ----------------------------------------------------

test_that("recast warns when source slices are missing from x", {
  cal_m <- .month_cal()
  cal_q <- .quarter_cal()
  x <- data.frame(slice = sprintf("m%02d", 1:6),  # only first half-year
                  load  = 1:6 * 1.0)
  expect_warning(
    recast(x, from = cal_m, to = cal_q, year = 2021, by = "day"),
    "missing from `x`"
  )
})

test_that("recast errors when key column missing", {
  cal_m <- .month_cal()
  cal_q <- .quarter_cal()
  x <- data.frame(month = sprintf("m%02d", 1:12), v = 1:12)
  expect_error(
    recast(x, from = cal_m, to = cal_q, year = 2021),
    "no column named"
  )
})

test_that("recast handles multiple value columns", {
  cal_m <- .month_cal()
  cal_q <- .quarter_cal()
  x <- data.frame(slice = sprintf("m%02d", 1:12),
                  a = 1:12 * 1.0,
                  b = 12:1 * 1.0)
  out <- recast(x, from = cal_m, to = cal_q, year = 2021, by = "day")
  expect_named(out, c("slice", "a", "b"))
  expect_equal(nrow(out), 4)
})

test_that("recast leap-year conservation: shares split over real instants", {
  cal_m <- .month_cal()
  cal_q <- .quarter_cal()
  x <- data.frame(slice = sprintf("m%02d", 1:12), v = rep(1, 12))
  out <- recast(x, cal_m, cal_q, year = 2020, rule = "sum", by = "day")
  expect_equal(sum(out$v), 12, tolerance = 1e-10)  # Feb has 29 grid days
})
