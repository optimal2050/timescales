# Backend contract: identical numbers on every supported input format;
# eager classes come back, lazy inputs stay lazy -----------------------------

.bk_x <- function() {
  data.frame(timeslice = rep(sprintf("m%02d", 1:12), 2),
             energy = as.numeric(c(1:12, 2 * (1:12))),
             city = rep(c("A", "B"), each = 12))
}

.bk_ref <- function() {
  recast_calendar(.bk_x(), calendar_build("m12"), calendar_build("q4"),
                  year = 2021, rule = "sum", by = "day")
}

test_that("tibble in, tibble out, same numbers", {
  skip_if_not_installed("tibble")
  ref <- .bk_ref()
  out <- recast_calendar(tibble::as_tibble(.bk_x()),
                         calendar_build("m12"), calendar_build("q4"),
                         year = 2021, rule = "sum", by = "day")
  expect_s3_class(out, "tbl_df")
  expect_equal(as.data.frame(out), ref)
})

test_that("data.table in, data.table out, same numbers", {
  skip_if_not_installed("data.table")
  ref <- .bk_ref()
  out <- recast_calendar(data.table::as.data.table(.bk_x()),
                         calendar_build("m12"), calendar_build("q4"),
                         year = 2021, rule = "sum", by = "day")
  expect_s3_class(out, "data.table")
  expect_equal(as.data.frame(out)[order(as.data.frame(out)$city,
                                        as.data.frame(out)$timeslice), ],
               ref[order(ref$city, ref$timeslice), ],
               ignore_attr = TRUE)
})

test_that("arrow in: lazy query out; collect = TRUE materialises", {
  skip_if_not_installed("arrow")
  ref <- .bk_ref()
  tab <- arrow::arrow_table(.bk_x())
  q <- recast_calendar(tab, calendar_build("m12"), calendar_build("q4"),
                       year = 2021, rule = "sum", by = "day")
  expect_false(is.data.frame(q))          # uncollected query
  got <- as.data.frame(dplyr::collect(q))
  got <- got[order(got$city, got$timeslice), ]
  ref2 <- ref[!is.na(ref$energy), ]       # lazy result: observed groups
  ref2 <- ref2[order(ref2$city, ref2$timeslice), ]
  expect_equal(got[, c("timeslice", "city", "energy")],
               ref2[, c("timeslice", "city", "energy")],
               ignore_attr = TRUE)
  # collect = TRUE returns a materialised, completed frame
  full <- recast_calendar(tab, calendar_build("m12"), calendar_build("q4"),
                          year = 2021, rule = "sum", by = "day",
                          collect = TRUE)
  expect_true(is.data.frame(full))
  expect_equal(as.data.frame(full), ref, ignore_attr = TRUE)
})

test_that("dtplyr in: lazy out; same numbers on collect", {
  skip_if_not_installed("dtplyr")
  skip_if_not_installed("data.table")
  ref <- .bk_ref()
  lz <- dtplyr::lazy_dt(data.table::as.data.table(.bk_x()))
  q <- recast_calendar(lz, calendar_build("m12"), calendar_build("q4"),
                       year = 2021, rule = "sum", by = "day")
  got <- as.data.frame(dplyr::collect(q))
  got <- got[order(got$city, got$timeslice), ]
  ref2 <- ref[order(ref$city, ref$timeslice), ]
  expect_equal(got[, c("timeslice", "city", "energy")],
               ref2[, c("timeslice", "city", "energy")],
               ignore_attr = TRUE)
})

test_that("join_calendar works on an arrow table", {
  skip_if_not_installed("arrow")
  cal <- calendar("m12_h24")
  xt <- data.frame(
    datetime = seq(as.POSIXct("2021-01-01", tz = "UTC"),
                   by = "hour", length.out = 48),
    v = 1)
  # some arrow builds mangle POSIXct at ingestion; the datetime route
  # cannot work there and the defect is arrow's, not ours
  rt <- as.data.frame(dplyr::collect(arrow::arrow_table(xt)))$datetime
  skip_if_not(identical(format(rt[1], "%Y"), "2021"),
              "arrow timestamp roundtrip is broken on this install")
  q <- join_calendar(arrow::arrow_table(xt), cal)
  expect_false(is.data.frame(q))
  got <- as.data.frame(dplyr::collect(q))
  expect_identical(sort(unique(got$m12_h24)),
                   sort(unique(datetime_to_timeslice(xt$datetime, cal))))
})

test_that("recast_to_timebase keeps the backend contract too", {
  skip_if_not_installed("tibble")
  m12 <- calendar_build("m12")
  x <- tibble::as_tibble(
    data.frame(timeslice = sprintf("m%02d", 1:12), energy = 1:12))
  g <- recast_to_timebase(x, m12, year = 2021, rule = "sum", by = "day")
  expect_s3_class(g, "tbl_df")
  expect_equal(sum(g$energy), 78, tolerance = 1e-9)
})
