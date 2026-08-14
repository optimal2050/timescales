# The calendar catalog ---------------------------------------------------------

test_that("calendar_catalog() lists 37 designs with consistent metadata", {
  cat_df <- calendar_catalog()
  expect_equal(nrow(cat_df), 37L)
  expect_named(cat_df, c("id", "tokens", "timeframes", "n_timeslices",
                         "coverage", "regularity", "desc"))
  expect_true(all(cat_df$coverage %in%
                    c("complete", "truncated", "representative")))
  expect_true(all(cat_df$regularity %in% c("regular", "irregular")))
})

test_that("every catalog id builds with the advertised timeslice count and
           shares summing to 1", {
  cat_df <- calendar_catalog()
  for (i in seq_len(nrow(cat_df))) {
    cal <- calendar(cat_df$id[i])
    leaves <- S7::prop(cal, "leaves")
    expect_equal(nrow(leaves), cat_df$n_timeslices[i], info = cat_df$id[i])
    expect_equal(sum(leaves$share), 1, tolerance = 1e-9,
                 info = cat_df$id[i])
  }
})

test_that("well-known timeslice counts hold", {
  expected <- c(d365 = 365L, d365_h24 = 8760L, d366_h24 = 8784L,
                m12 = 12L, m12_h24 = 288L, q4_h24 = 96L, s4_h24 = 96L,
                m12_md365 = 365L, m12_md365_h24 = 8760L,
                m12_md360 = 360L, w52_h168 = 8736L, wd7_h24 = 168L,
                wk2_h24 = 48L, hp3 = 3L, s4_hp3 = 12L)
  cat_df <- calendar_catalog()
  got <- stats::setNames(cat_df$n_timeslices, cat_df$id)[names(expected)]
  expect_equal(got, expected)
})

test_that("catalog calendars carry coverage/regularity metadata", {
  meta <- S7::prop(calendar("q4_h24"), "meta")
  expect_equal(meta$coverage, "representative")
  expect_equal(meta$regularity, "regular")
  meta2 <- S7::prop(calendar("m12_md365"), "meta")
  expect_equal(meta2$coverage, "truncated")
  expect_equal(meta2$regularity, "irregular")
})

test_that("shares are duration-proportional (the timeslices fix)", {
  expect_equal(S7::prop(calendar("m12"), "leaves")$share[1], 31 / 365,
               tolerance = 1e-12)
  s4 <- S7::prop(calendar("s4"), "leaves")
  expect_equal(s4$share[s4$SEASON == "WIN"], 90 / 365, tolerance = 1e-12)
  wk2 <- S7::prop(calendar("wk2"), "leaves")
  expect_equal(wk2$share, c(5, 2) / 7, tolerance = 1e-12)
  hp3 <- S7::prop(calendar("hp3"), "leaves")
  expect_equal(hp3$share, c(12, 8, 4) / 24, tolerance = 1e-12)
})

# The m12_md* family (non-Cartesian) -------------------------------------------

test_that("m12_md365 has ragged months and drops Feb 29", {
  md <- calendar("m12_md365")
  lv <- S7::prop(md, "leaves")
  expect_equal(nrow(lv), 365L)
  expect_equal(sum(lv$MONTH == "m02"), 28L)
  expect_equal(sum(lv$MONTH == "m01"), 31L)
  expect_equal(instant_to_timeslice(lubridate::ymd("2020-02-29"), md),
               NA_character_)
  expect_equal(instant_to_timeslice(lubridate::ymd("2021-03-15"), md),
               "m03_d15")
})

test_that("m12_md366 covers Feb 29; m12_md360 drops day 31", {
  md366 <- calendar("m12_md366")
  expect_equal(instant_to_timeslice(lubridate::ymd("2020-02-29"), md366),
               "m02_d29")
  md360 <- calendar("m12_md360")
  expect_equal(instant_to_timeslice(lubridate::ymd("2021-01-31"), md360),
               NA_character_)
  expect_equal(instant_to_timeslice(lubridate::ymd("2021-01-30"), md360),
               "m01_d30")
})

test_that("m12_md365_h24 nests hours inside ragged days", {
  cal <- calendar("m12_md365_h24")
  expect_equal(nrow(S7::prop(cal, "leaves")), 8760L)
  dtm <- lubridate::ymd_h("2021-02-28 13", tz = "UTC")
  expect_equal(instant_to_timeslice(dtm, cal), "m02_d28_h13")
})

# SEASON / DAYTYPE / HOURTYPE axes ---------------------------------------------

test_that("new type axes extract from datetimes", {
  # 2021-01-15 = Friday, 2021-01-16 = Saturday
  expect_equal(as_timeframe(lubridate::ymd("2021-01-15"), "SEASON",
                            format = "token"), "WIN")
  expect_equal(as_timeframe(lubridate::ymd("2021-07-14"), "SEASON",
                            format = "token"), "SUM")
  expect_equal(as_timeframe(lubridate::ymd("2021-01-15"), "DAYTYPE",
                            format = "token"), "WORKDAY")
  expect_equal(as_timeframe(lubridate::ymd("2021-01-16"), "DAYTYPE",
                            format = "token"), "WEEKEND")
  expect_equal(as_timeframe(lubridate::ymd_h("2021-01-15 18", tz = "UTC"),
                            "HOURTYPE", format = "token"), "PEAK")
  expect_equal(as_timeframe(lubridate::ymd_h("2021-01-15 03", tz = "UTC"),
                            "HOURTYPE", format = "token"), "NIGHT")
  expect_equal(as_timeframe(lubridate::ymd_h("2021-01-15 12", tz = "UTC"),
                            "HOURTYPE", format = "token"), "DAY")
})

test_that("type-axis calendars map instants to composite timeslices", {
  dtm <- lubridate::ymd_h(c("2021-01-15 03", "2021-01-16 18"), tz = "UTC")
  expect_equal(instant_to_timeslice(dtm, calendar("s4_hp3")),
               c("WIN_NIGHT", "WIN_PEAK"))
  expect_equal(instant_to_timeslice(dtm, calendar("wk2_h24")),
               c("WORKDAY_h03", "WEEKEND_h18"))
})

test_that("recast conserves across catalog calendars (m12 -> s4)", {
  x <- data.frame(timeslice = sprintf("m%02d", 1:12), v = rep(1, 12))
  out <- recast_calendar(x, calendar("m12"), calendar("s4"), year = 2021,
                rule = "sum", by = "day")
  expect_equal(sum(out$v), 12, tolerance = 1e-10)
  expect_setequal(out$timeslice, c("WIN", "SPR", "SUM", "FAL"))
})

# The shipped dataset ----------------------------------------------------------

test_that("the calendars dataset matches the catalog", {
  expect_true(exists("calendars"))
  expect_equal(names(calendars), calendar_catalog()$id)
  # spot deep-equality against a fresh build
  expect_equal(S7::prop(calendars$q4_h24, "leaves"),
               S7::prop(calendar("q4_h24"), "leaves"))
  expect_equal(S7::prop(calendars$m12_md365, "leaves"),
               S7::prop(calendar("m12_md365"), "leaves"))
})
