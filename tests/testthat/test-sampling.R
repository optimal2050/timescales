# =========================================================================== #
# Sample bookkeeping on filter_calendar() -- the port of geoscales'
# coverage / parent_totals / name-mangling convention (see geoscales
# tests/testthat/test-filter.R for the spatial original).
# =========================================================================== #

test_that("filter_calendar records coverage against the root parent", {
  cal <- calendar("s4_h24")
  lt <- calendar_leaftable(cal)
  win <- filter_calendar(cal, "SEASON", "WIN")

  m <- S7::prop(win, "meta")
  expect_equal(m$name, "s4_h24[SEASON:WIN]")
  expect_equal(m$parent_name, "s4_h24")
  expect_equal(m$parent_totals,
               c(share = sum(lt$share), weight = sum(lt$weight)))
  keep <- lt$SEASON == "WIN"
  expect_equal(unname(m[["coverage"]]["share"]),
               sum(lt$share[keep]) / sum(lt$share))
  # year_fraction invariant untouched
  expect_equal(m$year_fraction, sum(calendar_leaftable(win)$share))
  # the accessor: named over both built-in weights; scalar with weight=
  expect_equal(names(calendar_coverage(win)), c("share", "weight"))
  expect_equal(calendar_coverage(win, "share"),
               unname(m[["coverage"]]["share"]))
  # an unsampled calendar reports 1
  expect_equal(calendar_coverage(cal), c(share = 1, weight = 1))
})

test_that("filter-of-filter composes against the root, not the step", {
  cal <- calendar("s4_h24")
  two <- filter_calendar(cal, "SEASON", c("WIN", "SUM"))
  one <- filter_calendar(two, "SEASON", "WIN")
  direct <- filter_calendar(cal, "SEASON", "WIN")

  expect_equal(S7::prop(one, "meta")$parent_name, "s4_h24")
  expect_equal(calendar_coverage(one), calendar_coverage(direct))
  expect_equal(S7::prop(one, "meta")$name, "s4_h24[SEASON:WIN]")
  # two DIFFERENT samples of one parent never share a name (registry keys)
  expect_false(identical(S7::prop(two, "meta")$name,
                         S7::prop(direct, "meta")$name))
})

test_that("a filter that keeps everything is a true no-op", {
  cal <- calendar("s4_h24")
  all_of_it <- filter_calendar(cal, "SEASON",
                               calendar_timeslices(cal, "SEASON"))
  expect_identical(all_of_it, cal)
  expect_null(S7::prop(all_of_it, "meta")[["coverage"]])
})

test_that("tampered coverage is rejected by the validator", {
  win <- filter_calendar(calendar("s4_h24"), "SEASON", "WIN")
  m <- S7::prop(win, "meta")
  m$coverage <- c(share = 0.5, weight = 0.5)   # a lie
  expect_error(
    Calendar(leaftable  = S7::prop(win, "leaftable"),
             timeframes = S7::prop(win, "timeframes"),
             members    = S7::prop(win, "members"),
             meta       = m),
    "does not match the leaftable")
  m$coverage <- c(bogus = 0.5)
  expect_error(
    Calendar(leaftable  = S7::prop(win, "leaftable"),
             timeframes = S7::prop(win, "timeframes"),
             members    = S7::prop(win, "members"),
             meta       = m),
    "named numeric")
})

test_that("the catalog's coverage_class never collides with sampling", {
  # calendar() designs carry meta$coverage_class ("complete"/"truncated"/
  # "representative"); the sampling field is meta$coverage and reads must
  # never partial-match across the two
  cal <- calendar("m12_md365")
  expect_equal(S7::prop(cal, "meta")$coverage_class, "truncated")
  expect_null(S7::prop(cal, "meta")[["coverage"]])
  expect_equal(calendar_coverage(cal), c(share = 1, weight = 1))
})

test_that("prune of a filtered calendar keeps the bookkeeping consistent", {
  win <- filter_calendar(calendar("s4_h24"), "SEASON", "WIN")
  p <- prune_calendar(win, "SEASON")
  m <- S7::prop(p, "meta")
  expect_equal(m$name, "s4_h24[SEASON:WIN]@SEASON")
  expect_equal(m$parent_name, "s4_h24[SEASON:WIN]")   # immediate parent
  # shares/weights are summed by prune, so coverage still verifies
  expect_equal(calendar_coverage(p), calendar_coverage(win))
})

# --------------------------------------------------------------------------- #
# The new query twins

test_that("calendar_leaftable is the exported table accessor", {
  cal <- calendar("m12")
  expect_identical(calendar_leaftable(cal), S7::prop(cal, "leaftable"))
})

test_that("calendar_ancestry enumerates every ordered timeframe pair", {
  cal <- calendar("q4_h24")
  anc <- calendar_ancestry(cal)
  expect_named(anc, c("parent_timeframe", "parent",
                      "child_timeframe", "child"))
  expect_setequal(unique(anc$parent_timeframe), "QUARTER")
  expect_equal(nrow(anc[anc$child_timeframe == "HOUR", ]), 4 * 24)
  # single-frame calendars have no pairs
  expect_equal(nrow(calendar_ancestry(calendar("m12"))), 0L)
})

test_that("calendar_timeframes(finest = TRUE) returns the atom layer", {
  expect_equal(calendar_timeframes(calendar("q4_h24"), finest = TRUE),
               "HOUR")
})
