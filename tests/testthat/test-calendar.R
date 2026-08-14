# Helper: a regular monthly calendar (12 months, share = days/365)
.month_df <- function() {
  days <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
  data.frame(
    MONTH  = sprintf("m%02d", 1:12),
    share  = days / 365,
    weight = days,
    stringsAsFactors = FALSE
  )
}

test_that("calendar_from_leaves builds a minimal Calendar", {
  cal <- calendar_from_leaves(.month_df(), timeframes = "MONTH",
                              name = "m12", desc = "12 months")
  expect_s7_class(cal, Calendar)
  expect_equal(cal@timeframes, "MONTH")
  expect_equal(nrow(cal@leaves), 12)
  expect_equal(cal@meta$name, "m12")
  expect_equal(cal@meta$year_fraction, 1)
  expect_setequal(cal@levels$MONTH, sprintf("m%02d", 1:12))
})

test_that("calendar_from_leaves auto-generates timeslice IDs when missing", {
  df <- .month_df()
  cal <- calendar_from_leaves(df, timeframes = "MONTH")
  expect_equal(cal@leaves$timeslice, sprintf("m%02d", 1:12))
})

test_that("calendar_from_leaves preserves user-supplied timeslice IDs", {
  df <- .month_df()
  df$timeslice <- paste0("S", seq_len(12))
  cal <- calendar_from_leaves(df, timeframes = "MONTH")
  expect_equal(cal@leaves$timeslice, paste0("S", seq_len(12)))
})

test_that("calendar_from_leaves handles a 2-level hierarchy", {
  df <- expand.grid(
    MONTH = sprintf("m%02d", 1:12),
    HOUR  = sprintf("h%02d", 0:23),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  days <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
  names(days) <- sprintf("m%02d", 1:12)
  df$share  <- days[df$MONTH] / 365 / 24
  df$weight <- days[df$MONTH]

  cal <- calendar_from_leaves(df, timeframes = c("MONTH", "HOUR"),
                              name = "m12_h24")
  expect_equal(nrow(cal@leaves), 12 * 24)
  expect_equal(cal@timeframes, c("MONTH", "HOUR"))
  expect_setequal(cal@levels$HOUR, sprintf("h%02d", 0:23))
  # auto-generated composite timeslice IDs
  expect_true(all(grepl("^m\\d{2}_h\\d{2}$", cal@leaves$timeslice)))
})

test_that("calendar_from_leaves enforces sum(share) == year_fraction", {
  df <- .month_df()
  df$share <- df$share * 2  # now sums to 2, not 1
  expect_error(
    calendar_from_leaves(df, timeframes = "MONTH"),
    "year_fraction"
  )
})

test_that("calendar_from_leaves rejects missing timeframe columns", {
  df <- .month_df()
  expect_error(
    calendar_from_leaves(df, timeframes = c("MONTH", "HOUR")),
    "missing timeframe columns"
  )
})

test_that("calendar_from_leaves rejects non-positive share", {
  df <- .month_df()
  df$share[1] <- 0
  expect_error(
    calendar_from_leaves(df, timeframes = "MONTH"),
    "share"
  )
})

test_that("calendar_from_leaves rejects duplicate timeslice IDs", {
  df <- .month_df()
  df$timeslice <- rep("dup", 12)
  expect_error(
    calendar_from_leaves(df, timeframes = "MONTH"),
    "timeslice"
  )
})

test_that("calendar_from_leaves accepts custom year_start and offset", {
  df <- .month_df()
  cal <- calendar_from_leaves(
    df, timeframes = "MONTH",
    year_start = list(month = 4L, day = 1L),
    utc_offset_minutes = 60L
  )
  expect_equal(cal@meta$year_start$month, 4L)
  expect_equal(cal@meta$utc_offset_minutes, 60L)
})

test_that("Calendar print method runs without error", {
  cal <- calendar_from_leaves(.month_df(), timeframes = "MONTH",
                              name = "m12")
  expect_output(print(cal), "Calendar:")
  expect_output(print(cal), "Timeframes")
  expect_output(print(cal), "Leaf timeslices")
})
