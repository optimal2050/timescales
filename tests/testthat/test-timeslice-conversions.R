# Timeslice label conversions: reading a timeframe off a timeslice.
#
# The point of these functions is that they JOIN against the calendar instead
# of parsing the label text, so the tests check both that the numbers are right
# and that the label text is never read.

# Reference implementation: the regex these functions replace. Correct for
# <letter><digits> labels on a day/hour calendar, which is the range where the
# new code must agree with it exactly.
.ref_hour <- function(tsl) as.integer(sub("^.*_h", "", tsl))
.ref_yday <- function(tsl) as.integer(sub("^d", "", sub("_h.*$", "", tsl)))

test_that("tsl2hour/tsl2yday reproduce the regex they replace, exactly", {
  cal <- calendar("d365_h24")
  tsl <- calendar_timeslices(cal)
  expect_equal(length(tsl), 8760L)
  expect_equal(tsl2hour(tsl, cal), .ref_hour(tsl))
  expect_equal(tsl2yday(tsl, cal), .ref_yday(tsl))
})

test_that("a calendar name works in place of the object", {
  expect_identical(tsl2hour("d100_h20", "d365_h24"),
                   tsl2hour("d100_h20", calendar("d365_h24")))
  expect_equal(tsl2hour("d100_h20", "d365_h24"), 20L)
  expect_equal(tsl2yday("d100_h20", "d365_h24"), 100L)
})

test_that("labels already at the requested timeframe resolve to themselves", {
  expect_equal(tsl2hour(c("h00", "h20"), "d365_h24"), c(0L, 20L))
  expect_equal(tsl2yday(c("d001", "d365"), "d365_h24"), c(1L, 365L))
})

test_that("an unknown label gives NA, not an error or a guess", {
  expect_true(is.na(tsl2hour("nonsense", "d365_h24")))
  expect_equal(tsl2hour(c("d001_h05", NA, "zzz"), "d365_h24"),
               c(5L, NA, NA))
})

# -- the crosswalk tier -------------------------------------------------------

test_that("a timeframe the calendar lacks resolves through the crosswalk", {
  # MONTH is not a timeframe of d365_h24; calendar_map_between() supplies it.
  expect_false("MONTH" %in% calendar_timeframes(calendar("d365_h24")))
  expect_equal(tsl2month(c("d001_h00", "d100_h20", "d365_h23"), "d365_h24"),
               c(1L, 4L, 12L))
})

test_that("the crosswalk tier generalises beyond MONTH", {
  cal <- "d365_h24"
  expect_equal(as_timeframe("d001_h00", "SEASON", calendar = cal,
                            format = "token"), "WIN")
  expect_equal(as_timeframe("d100_h20", "QUARTER", calendar = cal), 2L)
  expect_equal(as_timeframe("d001_h00", "WEEK", calendar = cal), 1L)
})

test_that("MONTH is read directly when the calendar holds it", {
  expect_true("MONTH" %in% calendar_timeframes(calendar("m12")))
  expect_equal(tsl2month(c("m01", "m04", "m12"), "m12"), c(1L, 4L, 12L))
})

# -- availability: the rule that makes the wrappers honest --------------------

test_that("a timeframe finer than the calendar is refused, not guessed", {
  # A month spans 24 hours, so there is no single hour to return.
  expect_error(tsl2hour("m01", "m12"), "not available")
  expect_error(tsl2hour("m01", "m12"), "HOUR")
  expect_error(as_timeframe("m01", "YDAY", calendar = "m12"), "not available")
})

test_that("a timeframe with no token resolves through the instant", {
  # MDAY, MWEEK and SECOND have no token, so no crosswalk target exists. The
  # timeslice still names an instant, and every timeframe is readable from one.
  cal <- "d365_h24"
  expect_equal(as_timeframe("d100_h20", "MDAY", calendar = cal), 10L)
  expect_equal(as_timeframe("d100_h20", "SECOND", calendar = cal), 0L)
  expect_equal(as_timeframe("d001_h00", "MWEEK", calendar = cal, year = 2021),
               1L)
  # and that route agrees with reading the datetime directly
  expect_equal(as_timeframe("d100_h20", "MDAY", calendar = cal),
               as.integer(as_timeframe(tsl2dtm("d100_h20", cal, 2021), "MDAY")))
})

test_that("the calendar is required rather than inferred from the label", {
  expect_error(as_timeframe("d001_h00", "HOUR"), "required")
})

# -- year dependence ----------------------------------------------------------

test_that("weekday-derived timeframes require a year", {
  for (tf in c("WDAY", "DAYTYPE", "WHOUR")) {
    expect_error(as_timeframe("d001_h00", tf, calendar = "d365_h24"),
                 "`year` must be given", info = tf)
  }
})

test_that("weekday-derived timeframes differ by year, which is why", {
  a <- as_timeframe("d001_h00", "WDAY", calendar = "d365_h24", year = 2021)
  b <- as_timeframe("d001_h00", "WDAY", calendar = "d365_h24", year = 2022)
  expect_false(identical(a, b))
})

test_that("day-derived timeframes are the same in every year", {
  tsl <- c("d001_h00", "d100_h20", "d365_h23")
  for (tf in c("MONTH", "QUARTER", "SEASON", "WEEK")) {
    v <- lapply(c(2021L, 2022L, 2025L), function(y)
      as_timeframe(tsl, tf, calendar = "d365_h24", year = y))
    expect_equal(v[[2]], v[[1]], info = tf)
    expect_equal(v[[3]], v[[1]], info = tf)
  }
})

# -- the invariant that makes the whole thing trustworthy ---------------------

test_that("reading the label agrees with reading the instant", {
  # The two routes to a timeframe -- parse-free lookup from the label, and
  # lubridate from the datetime -- must give the same number for every one of
  # the calendar's 8760 timeslices.
  cal <- calendar("d365_h24")
  grid <- expand_calendar(cal, year = 2021)
  for (tf in c("HOUR", "YDAY", "MONTH", "QUARTER", "SEASON", "WEEK", "MDAY")) {
    expect_equal(
      as_timeframe(grid$timeslice, tf, calendar = cal, year = 2021),
      as.integer(as_timeframe(grid$datetime, tf)),
      info = tf
    )
  }
})

test_that("WDAY agrees once both sides use the same week start", {
  # Token vocabularies (wd7) are ISO/Monday-first; lubridate defaults to
  # Sunday-first. The numbers agree only when the datetime side is told so.
  cal <- calendar("d365_h24")
  grid <- expand_calendar(cal, year = 2021)
  expect_equal(
    as_timeframe(grid$timeslice, "WDAY", calendar = cal, year = 2021),
    as.integer(as_timeframe(grid$datetime, "WDAY", week_start = 1))
  )
  # ... and that the default convention really does differ, so the line above
  # is a fact about the package rather than a coincidence.
  expect_false(identical(
    as.integer(as_timeframe(grid$datetime[1], "WDAY")),
    as.integer(as_timeframe(grid$datetime[1], "WDAY", week_start = 1))
  ))
})

# -- vocabularies: the cases the old regex could not read --------------------

test_that("non-numeric label vocabularies resolve", {
  expect_equal(tsl2month(c("JAN", "MAR", "DEC"), "m12a"), c(1L, 3L, 12L))
  expect_equal(as_timeframe(c("MON", "SUN"), "WDAY", calendar = "wd7"),
               c(1L, 7L))
  expect_equal(as_timeframe(c("Q1", "Q4"), "QUARTER", calendar = "q4"),
               c(1L, 4L))
})

test_that("hour-of-week is not read as hour-of-day", {
  # h168 labels hours of the WEEK as h000..h167. A regex for "h" + digits
  # returns 167 as if it were an hour of the day; the calendar knows better.
  cal <- calendar("h168")
  expect_equal(as_timeframe("h167", "WHOUR", calendar = cal), 167L)
  # The old regex read "h167" as hour 167. Hour-of-week does determine
  # hour-of-day, so the right answer exists and it is 23, not 167.
  expect_equal(tsl2hour("h167", cal), 23L)
  expect_equal(tsl2hour(c("h000", "h024"), cal), c(0L, 0L))
})

test_that("integer to token honours the calendar's own vocabulary", {
  expect_equal(hour2HOUR(c(0, 20, 23)), c("h00", "h20", "h23"))
  expect_equal(yday2YDAY(c(1, 100, 365)), c("d001", "d100", "d365"))
  expect_equal(as_timeframe(c(1, 3), "MONTH", format = "token"),
               c("m01", "m03"))
  expect_equal(as_timeframe(c(1, 3), "MONTH", format = "token",
                            calendar = calendar("m12a")), c("JAN", "MAR"))
})

test_that("integer and label conversions invert each other", {
  cal <- calendar("d365_h24")
  tsl <- calendar_timeslices(cal)
  expect_equal(hour2HOUR(tsl2hour(tsl, cal)),
               as_timeframe(tsl, "HOUR", calendar = cal, format = "token"))
  expect_equal(yday2YDAY(tsl2yday(tsl, cal)),
               as_timeframe(tsl, "YDAY", calendar = cal, format = "token"))
})

# -- the datetime round trip --------------------------------------------------

test_that("tsl2dtm inverts dtm2tsl", {
  cal <- calendar("d365_h24")
  grid <- expand_calendar(cal, year = 2021)
  expect_equal(dtm2tsl(grid$datetime, cal), grid$timeslice)
  expect_equal(tsl2dtm(grid$timeslice, cal, year = 2021), grid$datetime)
})

test_that("tsl2dtm returns the instant a coarse timeslice starts at", {
  expect_equal(as.character(tsl2dtm(c("m01", "m12"), "m12", year = 2021)),
               c("2021-01-01", "2021-12-01"))
})

test_that("tsl2dtm accepts one year per element", {
  d <- tsl2dtm(c("d001_h00", "d001_h00"), "d365_h24", year = c(2021, 2022))
  expect_equal(format(d, "%Y"), c("2021", "2022"))
  expect_error(tsl2dtm("d001_h00", "d365_h24", year = c(2021, 2022)),
               "length 1 or length")
})

test_that("an unknown label gives NA from tsl2dtm", {
  expect_true(is.na(tsl2dtm("zzz", "d365_h24", year = 2021)))
})

# -- the label text is never read --------------------------------------------

test_that("no conversion parses the label text", {
  # This is the point of the rewrite, so it is asserted rather than assumed.
  forbidden <- c("str_extract", "str_sub", "str_replace", "grepl",
                 "regmatches", "substr", "substring", "cut")
  fns <- list(tsl2hour, tsl2yday, tsl2month, hour2HOUR, yday2YDAY,
              tsl2dtm, dtm2tsl,
              timescales:::.resolve_timeframe,
              timescales:::.vocab_value,
              timescales:::.value_vocab)
  src <- unlist(lapply(fns, function(f) deparse(body(f))))
  for (bad in forbidden) {
    expect_false(any(grepl(bad, src, fixed = TRUE)), info = bad)
  }
})

# -- sampled calendars --------------------------------------------------------
# A filtered calendar holds a SUBSET of its parent's timeslices. Its labels
# still mean what they meant in the parent, which is what these pin.

test_that("a label's number comes from the full vocabulary, not the subset", {
  s <- filter_calendar(calendar("d365_h24"), "YDAY",
                       c("d015", "d105", "d196", "d288"))
  # The calendar holds 4 days, so d015 is its FIRST YDAY member -- but it is
  # day 15 of the year, not day 1.
  expect_equal(calendar_timeslices(s, "YDAY")[1], "d015")
  expect_equal(tsl2yday("d015_h00", s), 15L)
  expect_equal(tsl2yday(c("d105_h00", "d288_h23"), s), c(105L, 288L))
  # HOUR is complete in this calendar, so it was never at risk
  expect_equal(tsl2hour("d015_h20", s), 20L)
})

test_that("derived timeframes work on a sampled calendar", {
  s <- filter_calendar(calendar("d365_h24"), "YDAY",
                       c("d015", "d105", "d196", "d288"))
  expect_equal(tsl2month(c("d015_h00", "d105_h00", "d288_h00"), s),
               c(1L, 4L, 10L))
})

test_that("a sampled calendar's timeslices are dated via its parent", {
  # expand_calendar() leaves a filtered calendar's grid unlabelled, so the
  # instants have to come from the parent the labels belong to.
  s <- filter_calendar(calendar("d365_h24"), "YDAY",
                       c("d015", "d105", "d196", "d288"))
  expect_equal(
    as.character(tsl2dtm(c("d015_h00", "d105_h12"), s, year = 2021)),
    c("2021-01-15", "2021-04-15 12:00:00")
  )
  # and the parent route does not invent an answer for an unknown label
  expect_true(is.na(tsl2dtm("zzz", s, year = 2021)))
})

test_that("a hand-built calendar with no token metadata still values labels", {
  # energyRt's calendars arrive as a leaftable with no `meta$tokens`, so the
  # vocabulary has to be inferred from the labels themselves.
  lt <- calendar_leaftable(calendar("d365_h24"))
  h <- calendar_from_leaftable(lt[, c("YDAY", "HOUR", "timeslice",
                                      "share", "weight")],
                               timeframes = c("YDAY", "HOUR"),
                               name = "handbuilt_d365_h24")
  expect_null(S7::prop(h, "meta")$tokens)
  expect_equal(tsl2hour("d100_h20", h), 20L)
  expect_equal(tsl2yday("d100_h20", h), 100L)
})

test_that("a hand-built SUBSET calendar is dated via its inferred complete form", {
  # This is the shape energyRt's sampled calendars arrive in: a leaftable
  # holding a few representative days, with no meta$tokens and no
  # meta$parent_name. The complete calendar has to be inferred from the labels.
  lt <- calendar_leaftable(calendar("d365_h24"))
  lt <- lt[lt$YDAY %in% c("d015", "d105"), , drop = FALSE]
  h <- calendar_from_leaftable(lt[, c("YDAY", "HOUR", "timeslice",
                                      "share", "weight")],
                               timeframes = c("YDAY", "HOUR"),
                               name = "handbuilt_subset",
                               year_fraction = sum(lt$share))
  expect_null(S7::prop(h, "meta")$tokens)
  expect_null(S7::prop(h, "meta")$parent_name)
  expect_equal(tsl2yday("d015_h00", h), 15L)
  expect_equal(tsl2hour("d105_h20", h), 20L)
  expect_equal(tsl2month(c("d015_h00", "d105_h00"), h), c(1L, 4L))
  expect_equal(as.character(tsl2dtm("d015_h00", h, year = 2021)), "2021-01-15")
})

test_that("a subset calendar still refuses what it does not determine", {
  lt <- calendar_leaftable(calendar("m12"))
  lt <- lt[lt$MONTH %in% c("m01", "m02", "m03"), , drop = FALSE]
  q <- calendar_from_leaftable(lt[, c("MONTH", "timeslice", "share", "weight")],
                               timeframes = "MONTH", name = "handbuilt_q1",
                               year_fraction = sum(lt$share))
  expect_equal(tsl2month(c("m01", "m03"), q), c(1L, 3L))
  expect_error(tsl2hour("m01", q))
})
