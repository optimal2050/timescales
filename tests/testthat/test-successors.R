# =========================================================================== #
# calendar_next() -- the successor chain.
#
# Counts come from the calendar's own shape, never from a previous run:
# `d365_h24` is YDAY (365) > HOUR (24 each) = 8760 leaves.
# =========================================================================== #

# @covers calendar_next depth=U

test_that("the whole frame is one cyclic chain", {
  cal <- calendar("d365_h24")
  a <- calendar_next(cal)
  expect_equal(nrow(a), 8760)
  expect_named(a, c("timeslice", "next_timeslice"))
  # chronological order, as the leaftable gives it
  expect_identical(a$timeslice, calendar_timeslices(cal, "HOUR",
                                                    qualified = TRUE))
  # each successor is the next row's slice, and the last closes the cycle
  expect_identical(a$next_timeslice[-nrow(a)], a$timeslice[-1])
  expect_identical(a$next_timeslice[nrow(a)], a$timeslice[1])
  expect_false(anyNA(a$next_timeslice))
})

test_that("`within` closes the cycle inside each group", {
  cal <- calendar("d365_h24")
  a <- calendar_next(cal, within = "YDAY")
  expect_equal(nrow(a), 8760)
  # the 24th hour of day 1 returns to its own first hour, not day 2's
  i <- which(a$timeslice == "d001_h23")
  expect_identical(a$next_timeslice[i], "d001_h00")
  # ... and day 2 starts a chain of its own
  j <- which(a$timeslice == "d002_h00")
  expect_identical(a$next_timeslice[j], "d002_h01")
  # every successor shares its slice's day: no edge leaves a group
  expect_true(all(substr(a$timeslice, 1, 4) ==
                  substr(a$next_timeslice, 1, 4)))
  # 365 cycles of 24 -> every slice is some slice's successor, exactly once
  expect_equal(length(unique(a$next_timeslice)), 8760)
})

test_that("wrap = FALSE opens each chain and leaves one NA per group", {
  cal <- calendar("d365_h24")
  expect_equal(sum(is.na(calendar_next(cal, within = "YDAY",
                                       wrap = FALSE)$next_timeslice)), 365)
  expect_equal(sum(is.na(calendar_next(cal, wrap = FALSE)$next_timeslice)), 1)
  # the open chain agrees with the closed one everywhere else
  w <- calendar_next(cal, within = "YDAY")
  o <- calendar_next(cal, within = "YDAY", wrap = FALSE)
  keep <- !is.na(o$next_timeslice)
  expect_identical(w$next_timeslice[keep], o$next_timeslice[keep])
})

test_that("a coarser timeframe chains its own slices", {
  cal <- calendar("d365_h24")
  a <- calendar_next(cal, timeframe = "YDAY")
  expect_equal(nrow(a), 365)
  expect_identical(a$timeslice[1:2], c("d001", "d002"))
  expect_identical(a$next_timeslice[1], "d002")
  expect_identical(a$next_timeslice[365], "d001")
})

test_that("`within` must be coarser, and ANNUAL means no confinement", {
  cal <- calendar("d365_h24")
  expect_error(calendar_next(cal, timeframe = "YDAY", within = "HOUR"),
               "COARSER")
  expect_error(calendar_next(cal, within = "HOUR"), "COARSER")
  expect_error(calendar_next(cal, within = "nope"), "must be")
  # the root is the whole year: confining a chain to it confines nothing
  expect_identical(calendar_next(cal, within = "ANNUAL"),
                   calendar_next(cal))
})

test_that("a group holding one timeslice is its own successor", {
  # keeping a single hour of each day leaves every YDAY group with one member.
  # It has nowhere else to go, so the cyclic answer is a self-loop and
  # `wrap = FALSE` says NA instead -- neither is a silent empty row.
  cal <- calendar("d365_h24")
  h <- calendar_timeslices(cal, "HOUR")[1]
  one <- filter_calendar(cal, "HOUR", h)

  a <- calendar_next(one, within = "YDAY")
  expect_equal(nrow(a), 365)
  expect_identical(a$next_timeslice, a$timeslice)

  b <- calendar_next(one, within = "YDAY", wrap = FALSE)
  expect_true(all(is.na(b$next_timeslice)))

  # unconfined, the same 365 slices chain into one cycle
  expect_equal(sum(calendar_next(one)$next_timeslice ==
                   calendar_next(one)$timeslice), 0)
})

test_that("repeated labels under different parents do not pool", {
  cal <- calendar("d365_h24")
  # HOUR labels repeat under every day. Grouping on the LABEL would make one
  # group of 24 and a 24-row answer; grouping on the path gives 8760.
  a <- calendar_next(cal, within = "YDAY")
  expect_equal(nrow(a), 8760)
  expect_false(any(duplicated(a$timeslice)))
})

test_that("the chain is a permutation when wrapped", {
  for (nm in c("d365_h24", "q4_h24")) {
    cal <- calendar(nm)
    a <- calendar_next(cal)
    # a closed chain visits every slice once as a successor
    expect_setequal(a$next_timeslice, a$timeslice)
  }
})
