# Navigation, queries and subsetting (the geoscales mirror) ------------------

test_that("calendar_timeframes / rank / timeslices", {
  cal <- calendar("q4_h24")
  expect_equal(calendar_timeframes(cal), c("QUARTER", "HOUR"))
  expect_equal(calendar_rank(cal, "QUARTER"), 1L)
  expect_equal(calendar_rank(cal, "HOUR"), 2L)
  expect_true(is.na(calendar_rank(cal, "NOPE")))
  expect_equal(calendar_timeslices(cal, "QUARTER"), sprintf("Q%d", 1:4))
  expect_equal(length(calendar_timeslices(cal)), 96L)
  expect_error(calendar_timeslices(cal, "ANNUAL"), "root")
})

test_that("calendar_family lists immediate parent-child pairs", {
  fam <- calendar_family(calendar("q4_h24"))
  expect_named(fam, c("parent_timeframe", "parent", "child_timeframe",
                      "child"))
  expect_equal(nrow(fam), 96L)   # 4 quarters x 24 hours
  expect_setequal(unique(fam$parent), sprintf("Q%d", 1:4))
  # restricting to a step
  fam2 <- calendar_family(calendar("m12_md365_h24"), parent = "MDAY")
  expect_setequal(unique(fam2$parent_timeframe), "MDAY")
  # single-timeframe calendar has no pairs
  expect_equal(nrow(calendar_family(calendar("m12"))), 0L)
})

test_that("children / parents / descendants / ancestors are consistent", {
  cal <- calendar("m12_md365_h24")
  ch <- calendar_children(cal, "MONTH", "m02")
  expect_equal(length(ch), 28L)          # Feb days (365-day design)
  expect_true(all(grepl("^d", ch)))
  # MDAY labels repeat across months (ragged family): the parents of a
  # reused label are ALL months containing it -- d31 exists only in the
  # seven 31-day months
  expect_equal(calendar_parents(cal, "MDAY", "d31"),
               c("m01", "m03", "m05", "m07", "m08", "m10", "m12"))
  expect_equal(length(calendar_parents(cal, "MDAY", "d01")), 12L)
  # descendants reach the finest level
  d <- calendar_descendants(cal, "MONTH", "m02")
  expect_named(d, c("timeframe", "label"))
  expect_equal(sum(d$timeframe == "MDAY"), 28L)
  expect_equal(sum(d$timeframe == "HOUR"), 24L)
  # ancestors of an hour
  a <- calendar_ancestors(cal, "HOUR", "h13")
  expect_setequal(unique(a$timeframe), c("MONTH", "MDAY"))
  # boundaries error clearly
  expect_error(calendar_children(cal, "HOUR", "h00"), "finest")
  expect_error(calendar_parents(cal, "MONTH", "m01"), "coarsest")
  expect_error(calendar_children(cal, "MONTH", "nope"), "unknown label")
})

test_that("calendar_share normalizes globally and within parents", {
  s <- calendar_share(calendar("m12"), "MONTH")
  expect_equal(sum(s$share), 1, tolerance = 1e-9)
  expect_equal(s$MONTH, sprintf("m%02d", 1:12))
  expect_equal(s$share[1], 31 / 365, tolerance = 1e-9)

  sw <- calendar_share(calendar("q4_h24"), "HOUR", within = "QUARTER")
  expect_named(sw, c("QUARTER", "HOUR", "share"))
  for (q in sprintf("Q%d", 1:4)) {
    expect_equal(sum(sw$share[sw$QUARTER == q]), 1, tolerance = 1e-9)
  }
  expect_error(calendar_share(calendar("q4_h24"), "QUARTER",
                              within = "HOUR"), "coarser")
})

test_that("filter_calendar keeps raw shares and sets year_fraction", {
  cal <- calendar("s4_h24")
  win <- filter_calendar(cal, "SEASON", "WIN")
  expect_s3_class(win, "timescales::Calendar")
  lv <- S7::prop(win, "leaftable")
  expect_equal(nrow(lv), 24L)
  expect_setequal(unique(lv$SEASON), "WIN")
  yf <- S7::prop(win, "meta")$year_fraction
  expect_equal(yf, sum(lv$share), tolerance = 1e-12)
  expect_equal(yf, 90 / 365, tolerance = 1e-9)
  # vocabulary subset to survivors
  expect_equal(S7::prop(win, "members")$SEASON, "WIN")
  # `[` sugar is the same operation
  win2 <- cal["SEASON", "WIN"]
  expect_identical(S7::prop(win2, "leaftable"), lv)
  expect_error(filter_calendar(cal, "SEASON", "nope"), "unknown label")
})
