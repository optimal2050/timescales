# calendar_map(): the A -> base -> B crosswalk table -------------------------

test_that("m12 -> q4 crosswalk has the hand-computed overlaps", {
  m12 <- calendar_build("m12")
  q4  <- calendar_build("q4")
  mp <- calendar_map(m12, q4, year = 2021)
  expect_named(mp, c("year", "m12", "q4", "n_from", "n_overlap", "w"))
  # months nest in quarters: one row per month, all overlap
  expect_equal(nrow(mp), 12L)
  expect_true(all(mp$n_overlap == mp$n_from))
  expect_equal(mp$q4[mp$m12 == "m01"], "Q1")
  expect_equal(mp$q4[mp$m12 == "m07"], "Q3")
  # January 2021 has 31 days on the daily grid
  expect_equal(mp$n_from[mp$m12 == "m01"], 31L)
  # weights sum to the year fraction (all shares accounted for)
  expect_equal(sum(mp$w), 1, tolerance = 1e-9)
})

test_that("a multi-year map carries the year column per year", {
  m12 <- calendar_build("m12")
  q4  <- calendar_build("q4")
  mp <- calendar_map(m12, q4, year = 2020:2021)
  expect_setequal(unique(mp$year), 2020:2021)
  # leap February differs between the years
  expect_equal(mp$n_from[mp$year == 2020 & mp$m12 == "m02"], 29L)
  expect_equal(mp$n_from[mp$year == 2021 & mp$m12 == "m02"], 28L)
})

test_that("maps are cached by (names, years, by, tz)", {
  clear_calendar_maps()
  m12 <- calendar_build("m12")
  q4  <- calendar_build("q4")
  a <- calendar_map(m12, q4, year = 2021)
  b <- calendar_map(m12, q4, year = 2021)
  expect_identical(a, b)   # cache hit returns the same object
})

test_that("unnamed calendars are refused with a clear message", {
  m12 <- calendar_build("m12")
  anon <- calendar_from_leaftable(
    S7::prop(m12, "leaftable"), timeframes = S7::prop(m12, "timeframes"))
  expect_error(calendar_map(anon, calendar_build("q4"), year = 2021),
               "no name")
  expect_error(calendar_map(m12, m12, year = 2021), "same name")
})

test_that("a registered direct map short-circuits the grid", {
  clear_calendar_maps(registry = TRUE)
  m12 <- calendar_build("m12")
  q4  <- calendar_build("q4")
  fake <- calendar_map(m12, q4, year = 2021)
  fake$w <- fake$w * 2          # recognisably not the derived map
  register_calendar_map(m12, q4, fake)
  got <- calendar_map(m12, q4, year = 1999)   # any year: registry wins
  expect_identical(got, fake)
  register_calendar_map(m12, q4, NULL)        # removal restores the grid
  got2 <- calendar_map(m12, q4, year = 2021)
  expect_false(isTRUE(all.equal(got2$w, fake$w)))
  clear_calendar_maps(registry = TRUE)
})

test_that("register_calendar_map validates the shape", {
  expect_error(register_calendar_map("a", "b", data.frame(x = 1)),
               "missing column")
})
