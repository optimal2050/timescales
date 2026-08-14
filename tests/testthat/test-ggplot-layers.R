# join_calendar (no ggplot2 needed) -------------------------------------------

test_that("join_calendar attaches factor timeframe columns + share/weight", {
  cal <- calendar("m12_h24")
  x <- data.frame(timeslice = S7::prop(cal, "leaves")$timeslice, v = 1)
  j <- join_calendar(x, cal)
  expect_named(j, c("timeslice", "v", "MONTH", "HOUR", "share", "weight"))
  expect_true(is.factor(j$MONTH))
  expect_equal(levels(j$MONTH), sprintf("m%02d", 1:12))
  expect_equal(sum(j$share), 1, tolerance = 1e-9)
})

test_that("join_calendar warns on unknown keys and errors on no match", {
  cal <- calendar("m12")
  x <- data.frame(timeslice = c("m01", "nope"), v = 1:2)
  expect_warning(j <- join_calendar(x, cal), "not timeslices")
  expect_true(is.na(j$MONTH[2]))
  expect_error(join_calendar(data.frame(timeslice = "zzz", v = 1), cal),
               "no rows")
})

test_that("join_calendar subsets timeframes and validates names", {
  cal <- calendar("m12_h24")
  x <- data.frame(timeslice = S7::prop(cal, "leaves")$timeslice, v = 1)
  j <- join_calendar(x, cal, timeframes = "MONTH")
  expect_false("HOUR" %in% names(j))
  expect_error(join_calendar(x, cal, timeframes = "YDAY"),
               "not timeframes")
})

# geoms ------------------------------------------------------------------------

test_that("geom_calendar aggregates datetime data into tiles", {
  skip_if_not_installed("ggplot2")
  cal <- calendar("m12_h24")
  t <- seq(as.POSIXct("2021-01-01", tz = "UTC"),
           as.POSIXct("2021-12-31 23:00", tz = "UTC"), by = "hour")
  x <- data.frame(t = t, v = 1)
  p <- ggplot2::ggplot(x) +
    geom_calendar(calendar = cal, datetime = "t", z = "v")
  b <- ggplot2::ggplot_build(p)
  expect_equal(nrow(b$data[[1]]), 288L)
})

test_that("geom_calendar_tile works with explicit and plot data", {
  skip_if_not_installed("ggplot2")
  cal <- calendar("q4_h24")
  y <- data.frame(timeslice = S7::prop(cal, "leaves")$timeslice, v = 1:96)
  p1 <- ggplot2::ggplot(y) + geom_calendar_tile(calendar = cal, z = "v")
  p2 <- ggplot2::ggplot() +
    geom_calendar_tile(calendar = cal, z = "v", data = y)
  expect_equal(nrow(ggplot2::ggplot_build(p1)$data[[1]]), 96L)
  expect_equal(nrow(ggplot2::ggplot_build(p2)$data[[1]]), 96L)
})

test_that("by= preserves facet carriers through aggregation", {
  skip_if_not_installed("ggplot2")
  cal <- calendar("m12")
  y <- rbind(
    data.frame(timeslice = sprintf("m%02d", 1:12), v = 1, g = "A"),
    data.frame(timeslice = sprintf("m%02d", 1:12), v = 2, g = "B")
  )
  p <- ggplot2::ggplot(y) +
    geom_calendar_tile(calendar = cal, z = "v", by = "g") +
    ggplot2::facet_wrap(~g)
  b <- ggplot2::ggplot_build(p)
  expect_equal(nrow(b$data[[1]]), 24L)
  expect_equal(length(unique(b$data[[1]]$PANEL)), 2L)
})

test_that("geoms validate their column arguments", {
  skip_if_not_installed("ggplot2")
  cal <- calendar("m12")
  x <- data.frame(timeslice = sprintf("m%02d", 1:12), v = 1)
  p <- ggplot2::ggplot(x) +
    geom_calendar(calendar = cal, datetime = "nope", z = "v")
  expect_error(ggplot2::ggplot_build(p), "not found")
  p2 <- ggplot2::ggplot(x) +
    geom_calendar(calendar = cal, datetime = "timeslice", z = "v")
  expect_error(ggplot2::ggplot_build(p2), "POSIXct")
})

test_that("theme_calendar returns a theme", {
  skip_if_not_installed("ggplot2")
  expect_s3_class(theme_calendar(), "theme")
})
