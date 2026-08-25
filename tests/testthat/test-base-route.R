# recast_to_timebase() / recast_from_timebase(): the public halves of the route ------

test_that("recast_to_timebase conserves totals for extensive columns", {
  m12 <- calendar_build("m12")
  x <- data.frame(timeslice = sprintf("m%02d", 1:12), energy = 1:12)
  g <- recast_to_timebase(x, m12, year = 2021, rule = "sum", by = "day")
  expect_named(g, c("datetime", "year", "energy", "weight"))
  expect_equal(nrow(g), 365L)
  expect_equal(sum(g$energy), sum(x$energy), tolerance = 1e-9)
  # within one month the daily value is constant
  jan <- g[format(g$datetime, "%m") == "01", ]
  expect_equal(unique(round(jan$energy, 12)), round(1 / 31, 12))
})

test_that("recast_to_timebase repeats intensive columns and attaches weight", {
  m12 <- calendar_build("m12")
  x <- data.frame(timeslice = sprintf("m%02d", 1:12), price = 21:32)
  g <- recast_to_timebase(x, m12, year = 2021, rule = "weighted_mean", by = "day")
  jan <- g[format(g$datetime, "%m") == "01", ]
  expect_true(all(jan$price == 21))
  expect_equal(sum(g$weight), 1, tolerance = 1e-9)
  g2 <- recast_to_timebase(x, m12, year = 2021, by = "day",
                           rule = "weighted_mean", attach_weight = FALSE)
  expect_false("weight" %in% names(g2))
})

test_that("a year column in x drives a multi-year grid", {
  m12 <- calendar_build("m12")
  x <- rbind(
    data.frame(timeslice = sprintf("m%02d", 1:12), year = 2020L, v = 1),
    data.frame(timeslice = sprintf("m%02d", 1:12), year = 2021L, v = 2))
  g <- recast_to_timebase(x, m12, rule = "sum", by = "day")   # years from x
  expect_equal(nrow(g), 366L + 365L)
  expect_equal(sum(g$v), 12 * 3, tolerance = 1e-9)
})

test_that("recast_from_timebase aggregates the grid back into timeslices", {
  m12 <- calendar_build("m12")
  x <- data.frame(timeslice = sprintf("m%02d", 1:12), energy = 1:12)
  g <- recast_to_timebase(x, m12, year = 2021, rule = "sum", by = "day")
  back <- recast_from_timebase(g, m12, rule = "sum", by = "day")
  expect_equal(back$energy[match(sprintf("m%02d", 1:12), back$timeslice)],
               as.numeric(1:12), tolerance = 1e-9)
  expect_true(all(back$year == 2021L))
})

test_that("composition equals the fused recast_calendar()", {
  m12 <- calendar_build("m12")
  q4  <- calendar_build("q4")
  x <- data.frame(timeslice = sprintf("m%02d", 1:12),
                  energy = 1:12, price = seq(30, 41))
  for (r in c("sum", "mean", "weighted_mean")) {
    fused <- recast_calendar(x, m12, q4, year = 2021, rule = r, by = "day")
    g <- recast_to_timebase(x, m12, year = 2021, rule = r, by = "day")
    split2 <- recast_from_timebase(g, q4, rule = r, by = "day")
    m <- match(fused$timeslice, split2$timeslice)
    expect_equal(split2$energy[m], fused$energy, tolerance = 1e-9,
                 info = paste("rule", r, "energy"))
    expect_equal(split2$price[m], fused$price, tolerance = 1e-9,
                 info = paste("rule", r, "price"))
  }
})

test_that("from_base na_action handles uncovered datetimes", {
  d360 <- calendar_build("d360")
  g <- expand_calendar(calendar_build("d365"), 2021, by = "day")
  g$v <- 1
  expect_warning(res <- recast_from_timebase(g[, c("datetime", "v")], d360,
                                         rule = "sum", by = "day"),
                 "not cover")
  expect_equal(sum(res$v, na.rm = TRUE), 360)
  expect_error(recast_from_timebase(g[, c("datetime", "v")], d360,
                                rule = "sum", by = "day",
                                na_action = "error"), "not cover")
  res2 <- recast_from_timebase(g[, c("datetime", "v")], d360, rule = "sum",
                           by = "day", na_action = "keep")
  expect_equal(sum(res2$v, na.rm = TRUE), 365)
  expect_true(anyNA(res2$timeslice))
})
