# calendar_layout() — no ggplot2 required -------------------------------------

test_that("calendar_layout returns the contracted columns and geometry", {
  d <- calendar_layout(calendar("m12_h24"))
  expect_named(d, c("timeframe", "label", "timeslice", "rank", "xmin", "xmax",
                    "ymin", "ymax", "share", "weight", "order", "within"))
  expect_true(all(d$xmin >= 0 - 1e-12 & d$xmax <= 1 + 1e-12))
  expect_true(all(d$xmax > d$xmin))

  # Bands: ANNUAL rank 0 on top, then MONTH, HOUR
  expect_equal(unique(d$timeframe), c("ANNUAL", "MONTH", "HOUR"))
  expect_equal(unique(d$rank), 0:2)
  ann <- d[d$timeframe == "ANNUAL", ]
  expect_gt(ann$ymin, max(d$ymin[d$timeframe == "HOUR"]))

  # Segment counts: 1 / 12 / 288
  expect_equal(as.vector(table(d$timeframe)[c("ANNUAL", "MONTH", "HOUR")]),
               c(1L, 12L, 288L))

  # Every full-coverage row spans 0 -> 1 and its shares sum to 1
  for (tf in unique(d$timeframe)) {
    r <- d[d$timeframe == tf, ]
    expect_equal(min(r$xmin), 0, tolerance = 1e-12, info = tf)
    expect_equal(max(r$xmax), 1, tolerance = 1e-9, info = tf)
    expect_equal(sum(r$share), 1, tolerance = 1e-9, info = tf)
  }
})

test_that("calendar_layout `within` restarts per parent", {
  d <- calendar_layout(calendar("q4_h24"))
  hr <- d[d$timeframe == "HOUR", ]
  expect_equal(nrow(hr), 96L)
  expect_equal(hr$within, rep(1:24, 4))
  # month widths are day-weighted, not uniform
  mo <- calendar_layout(calendar("m12"))
  mw <- mo[mo$timeframe == "MONTH", ]
  expect_equal(mw$xmax - mw$xmin, c(31, 28, 31, 30, 31, 30,
                                    31, 31, 30, 31, 30, 31) / 365,
               tolerance = 1e-9)
})

test_that("calendar_layout handles irregular calendars and annual = FALSE", {
  d <- calendar_layout(calendar("m12_md365"))
  expect_equal(sum(d$timeframe == "MDAY"), 365L)
  expect_equal(sum(d$timeframe == "MONTH"), 12L)

  d2 <- calendar_layout(calendar("m12"), annual = FALSE)
  expect_false("ANNUAL" %in% d2$timeframe)
  expect_equal(max(d2$ymax), 0.9)
})

test_that("calendar_layout orders rows chronologically regardless of input
           row order", {
  df <- data.frame(
    MONTH = c("m03", "m01", "m02"),
    share = c(31, 31, 28) / 90,
    weight = c(31, 31, 28)
  )
  cal <- calendar_from_leaftable(df, timeframes = "MONTH",
                              members = list(MONTH = c("m01", "m02", "m03")))
  d <- calendar_layout(cal, annual = FALSE)
  expect_equal(d$label, c("m01", "m02", "m03"))
  expect_equal(d$xmin[1], 0, tolerance = 1e-12)
})

# Rendering — guarded ----------------------------------------------------------

test_that("autoplot / plot / calendar_autoplot return ggplot objects", {
  skip_if_not_installed("ggplot2")
  cal <- calendar("q4_h24")
  p1 <- calendar_autoplot(cal)
  p2 <- ggplot2::autoplot(cal)
  p3 <- plot(cal)
  expect_s3_class(p1, "ggplot")
  expect_s3_class(p2, "ggplot")
  expect_s3_class(p3, "ggplot")
})

test_that("calendar_autoplot fill styles and binning work", {
  skip_if_not_installed("ggplot2")
  cal <- calendar("m12_h24")
  for (f in c("order", "share", "weight")) {
    expect_s3_class(calendar_autoplot(cal, fill = f), "ggplot")
  }
  expect_s3_class(calendar_autoplot(cal, color_pattern = "global"), "ggplot")

  # d365_h24: the HOUR row (8760 segments) must be binned to <= max_segments
  p <- calendar_autoplot(calendar("d365_h24"), max_segments = 1000)
  hr <- p$data[p$data$timeframe == "HOUR", ]
  expect_lte(nrow(hr), 1000L)
  # binned rows carry no timeslice ids (mutes labels)
  expect_true(all(is.na(hr$timeslice)))
})

test_that("calendar_plot renders with and without data", {
  skip_if_not_installed("ggplot2")
  expect_s3_class(calendar_plot(calendar("m12_h24")), "ggplot")

  cal <- calendar("m12")
  x <- data.frame(timeslice = sprintf("m%02d", 1:12), load = 1:12 * 1.0)
  p <- calendar_plot(cal, x)
  expect_s3_class(p, "ggplot")

  # facet path: 3-level calendar puts the coarsest level in facets
  p3 <- calendar_plot(calendar("m12_md365_h24"))
  expect_s3_class(p3, "ggplot")
  expect_true(".facet" %in% names(p3$data))
})

test_that("calendar_plot validates inputs", {
  skip_if_not_installed("ggplot2")
  cal <- calendar("m12")
  expect_error(calendar_plot(cal, data.frame(a = 1)), "no column named")
  expect_error(
    calendar_plot(cal, data.frame(timeslice = "nope", v = 1)),
    "matched"
  )
  expect_error(calendar_plot(cal, x_tf = "HOUR"), "not timeframes")
})

test_that("the stack view returns a ggplot with one plane per timeframe", {
  skip_if_not_installed("ggplot2")
  p <- calendar_autoplot(calendar("s4_hp3"), type = "stack")
  expect_s3_class(p, "ggplot")
  # ANNUAL + SEASON + HOURTYPE planes; 1 + 4 + 12 segments
  expect_equal(length(unique(p$data$tf)), 3L)
  expect_equal(length(unique(p$data$id)), 1L + 4L + 12L)
  # annual = FALSE drops the root plane
  p2 <- calendar_autoplot(calendar("s4_hp3"), type = "stack",
                          annual = FALSE)
  expect_equal(length(unique(p2$data$tf)), 2L)
})

test_that("stack views, rotation and direction all render", {
  skip_if_not_installed("ggplot2")
  cal <- calendar("s4_hp3")
  for (vw in c("top-down", "cabinet", "military", "isometric",
               "perspective")) {
    expect_s3_class(calendar_autoplot(cal, type = "stack", view = vw),
                    "ggplot")
  }
  p <- calendar_autoplot(cal, type = "stack", angle = 30, ratio = 0.4,
                         rotate = 15, direction = "down")
  expect_s3_class(p, "ggplot")
  # painter order: rows sorted by plane height (lower planes first)
  expect_true(!is.unsorted(p$data$z))
})

test_that("stack frames, connectors and border styling render", {
  skip_if_not_installed("ggplot2")
  cal <- calendar("s4_hp3")
  base_n <- length(ggplot2::ggplot_build(
    calendar_autoplot(cal, type = "stack"))$plot$layers)
  # frame = one polygon per plane; connectors = one segment layer
  p <- calendar_autoplot(cal, type = "stack", frame = TRUE,
                         connectors = TRUE)
  expect_equal(length(ggplot2::ggplot_build(p)$plot$layers),
               base_n + 3 + 1)
  # per-plane border colours land on the polygon layers
  p2 <- calendar_autoplot(cal, type = "stack",
                          colour = c("grey20", "red", "white"))
  cols <- unlist(lapply(p2$layers, function(l) l$aes_params$colour))
  expect_true(all(c("grey20", "red", "white") %in% cols))
  expect_s3_class(calendar_autoplot(cal, type = "stack",
                                    frame = "steelblue"), "ggplot")
  # frame_fill alone activates the sheets
  p3 <- calendar_autoplot(cal, type = "stack", frame_fill = "#6FA8DC26")
  expect_equal(length(ggplot2::ggplot_build(p3)$plot$layers), base_n + 3)
})

test_that("stack value fill recasts data onto every plane", {
  skip_if_not_installed("ggplot2")
  cal <- calendar("s4_hp3")
  ts <- calendar_timeslices(cal, "HOURTYPE", qualified = TRUE)
  x <- data.frame(timeslice = ts, v = 1)    # one unit per leaf timeslice
  p <- calendar_autoplot(cal, type = "stack", data = x, z = "v",
                         rule = "sum", year = 2019)
  expect_s3_class(p, "ggplot")
  d <- p$data
  expect_true(all(is.finite(d$.z)))
  # the ANNUAL plane carries the conserved total (12 leaves x 1)
  expect_equal(unique(d$.z[d$tf == "ANNUAL"]), 12)
  # the SEASON planes split it 3 hourtypes each
  seas <- unique(d[d$tf == "SEASON", c("timeslice", ".z")])
  expect_equal(sum(seas$.z), 12)
  expect_true(all(seas$.z == 3))
  # errors are explicit
  expect_error(calendar_autoplot(cal, type = "stack", data = x,
                                 rule = "sum", year = 2019),
               "`z` must name")
  expect_error(calendar_autoplot(cal, type = "stack", data = x, z = "v",
                                 rule = "sum"),
               "needs `year =`")
})

test_that("stack labels draw member names of chosen timeframes", {
  skip_if_not_installed("ggplot2")
  cal <- calendar("s4_hp3")
  p <- calendar_autoplot(cal, type = "stack", labels = "SEASON")
  lyrs <- ggplot2::ggplot_build(p)$plot$layers
  txt <- NULL
  for (l in lyrs) if (".label" %in% names(l$data)) txt <- l$data
  expect_setequal(txt$.label, c("WIN", "SPR", "SUM", "FAL"))
  expect_error(calendar_autoplot(cal, type = "stack", labels = "nope"),
               "unknown")
})

test_that("stack palette = NULL leaves the fill scale to the caller", {
  skip_if_not_installed("ggplot2")
  cal <- calendar("s4_hp3")
  p <- calendar_autoplot(cal, type = "stack", palette = NULL)
  expect_length(p$scales$scales, 0)
  p2 <- calendar_autoplot(cal, type = "stack")
  expect_length(p2$scales$scales, 1)
})

test_that("icicle data fill recasts values onto every band", {
  skip_if_not_installed("ggplot2")
  cal <- calendar("s4_hp3")
  ts <- calendar_timeslices(cal, "HOURTYPE", qualified = TRUE)
  x <- data.frame(timeslice = ts, v = 1)
  p <- calendar_autoplot(cal, data = x, z = "v", rule = "sum", year = 2019)
  expect_s3_class(p, "ggplot")
  d <- p$data
  expect_true(all(is.finite(d$.fill)))
  expect_equal(d$.fill[d$timeframe == "ANNUAL"], 12)
  expect_equal(sum(d$.fill[d$timeframe == "SEASON"]), 12)
  expect_error(calendar_autoplot(cal, data = x, z = "v", rule = "sum"),
               "needs `year =`")
})
