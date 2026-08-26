# =========================================================================== #
# Backend contract, all entry points x all backends, via
# expect_backend_contract() (helper-backends.R). The dtplyr/arrow columns of
# the sweep run at tier `full`; two explicit lazy smoke tests keep one cell
# of each engine alive at `fast`.
#
# arrow cells that would ingest a POSIXct column are skipped: arrow 25.0.0
# corrupts POSIXct at ingestion (recorded trap; see .claude/CLAUDE.md).
# =========================================================================== #

# @covers recast_calendar depth=B backends=data.frame,tibble,data.table,dtplyr,arrow
test_that("recast_calendar honours the backend contract", {
  m12 <- .month_cal(); q4 <- .quarter_cal()
  x <- fx_tbl(m12, ids = c("A", "B"))
  expect_backend_contract(
    x,
    function(d, collect = NULL) recast_calendar(
      d, m12, q4, year = 2021, rule = "sum", by = "day", collect = collect),
    key_cols = c("id", "timeslice"), value_cols = "energy")
  expect_backend_rejects(function(d, collect = NULL) recast_calendar(
    d, m12, q4, year = 2021, rule = "sum", by = "day"))
})

# @covers recast_to_timebase depth=B backends=data.frame,tibble,data.table,dtplyr
test_that("recast_to_timebase honours the backend contract", {
  m12 <- .month_cal()
  x <- fx_tbl(m12)
  expect_backend_contract(
    x,
    function(d, collect = NULL) recast_to_timebase(
      d, m12, year = 2021, by = "day", rule = "weighted_mean",
      collect = collect),
    key_cols = c("datetime", "timeslice"), value_cols = "energy",
    skip = c(arrow = "arrow 25.0.0 corrupts POSIXct at ingestion"))
  expect_backend_rejects(function(d, collect = NULL) recast_to_timebase(
    d, m12, year = 2021, by = "day", rule = "sum"))
})

# @covers recast_from_timebase depth=B backends=data.frame,tibble,data.table,dtplyr
test_that("recast_from_timebase honours the backend contract", {
  m12 <- .month_cal(); q4 <- .quarter_cal()
  base <- recast_to_timebase(fx_tbl(m12), m12, year = 2021, by = "day",
                             rule = "sum")
  expect_backend_contract(
    base,
    function(d, collect = NULL) recast_from_timebase(
      d, q4, rule = "sum", by = "day", collect = collect),
    key_cols = "timeslice", value_cols = "energy",
    skip = c(arrow = "arrow 25.0.0 corrupts POSIXct at ingestion"))
  expect_backend_rejects(function(d, collect = NULL) recast_from_timebase(
    d, q4, rule = "sum", by = "day"))
})

# @covers join_calendar depth=B backends=data.frame,tibble,data.table,dtplyr,arrow
test_that("join_calendar honours the backend contract", {
  m12 <- .month_cal()
  x <- fx_tbl(m12)                       # timeslice-keyed: no POSIXct
  expect_backend_contract(
    x,
    function(d, collect = NULL) join_calendar(
      d, m12, timeframes = "MONTH", meta = TRUE, as_factor = FALSE,
      collect = collect),
    key_cols = "timeslice")
  expect_backend_rejects(function(d, collect = NULL) join_calendar(d, m12))
})

# ---- fast-tier lazy smokes (one live cell per engine below `full`) -------- #

test_that("arrow smoke: recast_calendar stays lazy, collects right", {
  skip_if_not_installed("arrow")
  m12 <- .month_cal(); q4 <- .quarter_cal()
  x <- fx_tbl(m12, ids = c("A", "B"))
  expect_backend_contract(
    x,
    function(d, collect = NULL) recast_calendar(
      d, m12, q4, year = 2021, rule = "sum", by = "day", collect = collect),
    key_cols = c("id", "timeslice"), value_cols = "energy",
    backends = "arrow")
})

test_that("dtplyr smoke: join_calendar stays lazy, collects right", {
  skip_if_not_installed("dtplyr")
  skip_if_not_installed("data.table")
  m12 <- .month_cal()
  x <- fx_tbl(m12)
  expect_backend_contract(
    x,
    function(d, collect = NULL) join_calendar(
      d, m12, meta = TRUE, as_factor = FALSE, collect = collect),
    key_cols = "timeslice",
    backends = "dtplyr")
})
