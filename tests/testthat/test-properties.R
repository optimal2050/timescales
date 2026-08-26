# =========================================================================== #
# Property sweep: the invariant contracts of recast/join over the rule x
# direction x na_action grid (helper-invariants.R states the contracts,
# helper-fixtures.R the fixtures). One-off regression tests stay in their
# topic files; THIS file is the systematic net.
# =========================================================================== #

# ---- recast: conservation / envelope grid --------------------------------- #

# @covers recast_calendar depth=P
test_that("sum conserves and completes across the direction grid", {
  m12 <- .month_cal(); q4 <- .quarter_cal(); mh <- .month_hour_cal()
  x_m <- fx_tbl(m12, ids = c("A", "B"))
  # up, down, within-hierarchy to a timeframe, and to the root
  up <- recast_calendar(x_m, m12, q4, year = 2021, rule = "sum", by = "day")
  expect_conserves(x_m, up, "energy", by = "id")
  expect_completion(up, calendar_leaftable(q4)$timeslice, "timeslice")

  down <- recast_calendar(x_m, m12, .quarter_cal(), year = 2021,
                          rule = "sum", by = "day")
  x_h <- fx_tbl(mh)
  to_tf <- recast_calendar(x_h, mh, "MONTH", year = 2021, rule = "sum")
  expect_conserves(x_h, to_tf, "energy")
  expect_completion(to_tf, sprintf("m%02d", 1:12), "timeslice")

  root <- recast_calendar(x_h, mh, "ANNUAL", year = 2021, rule = "sum")
  expect_conserves(x_h, root, "energy")
  expect_identical(nrow(as.data.frame(root)), 1L)
})

# @covers recast_calendar depth=P
test_that("sum round-trips down-then-up per id group", {
  m12 <- .month_cal(); q4 <- .quarter_cal()
  x_q <- fx_tbl(q4, values = list(energy = c(120, 90, 60, 95)),
                ids = c("A", "B"))
  down <- recast_calendar(x_q, q4, m12, year = 2021, rule = "sum",
                          by = "day")
  back <- recast_calendar(down, m12, q4, year = 2021, rule = "sum",
                          by = "day")
  expect_round_trip(x_q, back, "energy", key = c("id", "timeslice"))
})

# @covers recast_calendar depth=P
test_that("mean and weighted_mean stay in the envelope; weighting matters", {
  # months have unequal day shares (31/28/31 inside Q1), so on m12 -> q4
  # weighted_mean and mean MUST disagree -- pins the 0.1.0 defect class
  m12 <- .month_cal(); q4 <- .quarter_cal()
  x <- fx_tbl(m12, values = list(v = c(10, 2, 7, 100, 3, 8,
                                       50, 1, 9, 40, 6, 11)))
  for (r in c("mean", "weighted_mean")) {
    up <- recast_calendar(x, m12, q4, year = 2021, rule = r, by = "day")
    expect_within_envelope(x, up, "v")
  }
  # on a DAILY grid a plain mean is day-weighted already; the two rules
  # diverge when the grid is coarser than the shares (one point per month)
  wm <- recast_calendar(x, m12, q4, year = 2021, rule = "weighted_mean",
                        by = "month")
  mn <- recast_calendar(x, m12, q4, year = 2021, rule = "mean",
                        by = "month")
  expect_weighting_matters(wm, mn, "v")
  # identity recast returns the values unchanged for intensive rules
  idm <- recast_calendar(x, m12, m12, year = 2021, rule = "weighted_mean",
                         by = "day")
  expect_equal(.inv_sort(idm, "timeslice")$v,
               .inv_sort(x, "timeslice")$v, tolerance = 1e-9)
})

# @covers recast_calendar depth=P
test_that("copy carries constants and rejects non-constants; sd aggregates only", {
  mh <- .month_hour_cal()
  x <- fx_tbl(mh, values = list(flag = 7))
  up <- recast_calendar(x, mh, "MONTH", year = 2021, rule = "copy")
  expect_true(all(as.data.frame(up)$flag == 7))
  x2 <- fx_tbl(mh)                          # non-constant per month
  expect_error(recast_calendar(x2, mh, "MONTH", year = 2021, rule = "copy"),
               "copy")
  sd_up <- recast_calendar(x2, mh, "MONTH", year = 2021, rule = "sd")
  expect_true(all(as.data.frame(sd_up)$energy >= 0))
})

# @covers recast_calendar depth=P
test_that("na_action grid behaves identically for every aggregating rule", {
  m12 <- .month_cal()
  d360 <- calendar_build("d360")             # Dec 27-31 uncovered by `to`
  x <- fx_tbl(m12, values = list(v = 1))
  for (r in c("sum", "mean", "weighted_mean")) {
    expect_warning(
      dropped <- recast_calendar(x, m12, d360, year = 2021, rule = r,
                                 by = "day", na_action = "drop"),
      "not covered")
    expect_false(anyNA(as.data.frame(dropped)$timeslice))
    expect_error(
      recast_calendar(x, m12, d360, year = 2021, rule = r, by = "day",
                      na_action = "error"),
      "not covered")
    kept <- recast_calendar(x, m12, d360, year = 2021, rule = r,
                            by = "day", na_action = "keep")
    expect_true(anyNA(as.data.frame(kept)$timeslice))
    if (r == "sum") expect_conserves(x, kept, "v")
  }
  # a MISSING SOURCE slice is the other path: NA values + a warning,
  # identically for every rule (na_action does not apply to it)
  q4 <- .quarter_cal()
  x2 <- fx_tbl(m12); x2 <- x2[x2$timeslice != "m01", ]
  for (r in c("sum", "mean", "weighted_mean")) {
    expect_warning(
      out <- recast_calendar(x2, m12, q4, year = 2021, rule = r,
                             by = "day"),
      "missing from")
    out <- as.data.frame(out)
    expect_true(is.na(out$energy[out$timeslice == "Q1"]))
    expect_false(anyNA(out$energy[out$timeslice != "Q1"]))
  }
})

# ---- routes: composition identity ----------------------------------------- #

# @covers recast_to_timebase recast_from_timebase depth=P
test_that("timebase composition equals the fused recast, per rule, with ids", {
  m12 <- .month_cal(); q4 <- .quarter_cal()
  x <- fx_tbl(m12, values = list(energy = NULL, level = 5), ids = c("A", "B"))
  for (r in c("sum", "mean", "weighted_mean")) {
    base <- recast_to_timebase(x, m12, year = 2021, by = "day", rule = r)
    via <- recast_from_timebase(base, q4, rule = r, by = "day")
    fused <- recast_calendar(x, m12, q4, year = 2021, rule = r, by = "day")
    expect_composition_identity(via, fused, c("energy", "level"),
                                key = c("id", "timeslice"))
  }
  # attach_weight = FALSE still composes for the unweighted rules
  base0 <- recast_to_timebase(x, m12, year = 2021, by = "day",
                              rule = "sum", attach_weight = FALSE)
  expect_false("weight" %in% names(base0))
  via0 <- recast_from_timebase(base0, q4, rule = "sum", by = "day")
  fused0 <- recast_calendar(x, m12, q4, year = 2021, rule = "sum",
                            by = "day")
  expect_composition_identity(via0, fused0, c("energy", "level"),
                              key = c("id", "timeslice"))
})

# ---- join: the contract over key modes ------------------------------------ #

# @covers join_calendar depth=P
test_that("join contract holds across key modes and options", {
  m12 <- .month_cal()
  x <- fx_tbl(m12)
  names(x)[1] <- "m12"                       # existing <name> column mode
  j1 <- expect_join_contract(x, join_calendar(x, m12, meta = TRUE), "m12")
  expect_true(all(c("m12.share", "m12.weight") %in% names(j1)))

  x2 <- fx_tbl(m12)                          # inferred label-key mode
  j2 <- join_calendar(x2, m12, meta = TRUE)
  expect_equal(sum(j2$m12.share), 1, tolerance = 1e-9)

  # explicit key that is neither `timeslice` nor `datetime`
  x3 <- data.frame(slice_id = calendar_leaftable(m12)$timeslice, v = 1:12)
  j3 <- join_calendar(x3, m12, key = "slice_id", meta = TRUE)
  expect_join_contract(x3, j3, "m12")

  # as_factor governs the requested MEMBERSHIP columns
  jf <- join_calendar(x2, m12, timeframes = "MONTH", as_factor = TRUE)
  expect_s3_class(jf$m12.MONTH, "factor")
  expect_equal(levels(jf$m12.MONTH), sprintf("m%02d", 1:12))
  jc <- join_calendar(x2, m12, timeframes = "MONTH", as_factor = FALSE)
  expect_type(jc$m12.MONTH, "character")
})

# @covers join_calendar depth=P
test_that("join edge shapes: duplicate keys, NA keys, zero rows, idempotence", {
  m12 <- .month_cal()
  # duplicate key rows: a plain left join, row count preserved
  dup <- fx_tbl(m12)[c(1, 1, 2), ]
  expect_join_contract(dup, join_calendar(dup, m12), "m12")

  # NA in the key column: kept as a row, label NA, with the unknown warning
  nax <- fx_tbl(m12)
  nax$timeslice[1] <- NA_character_
  jn <- suppressWarnings(join_calendar(nax, m12))
  expect_identical(nrow(jn), nrow(nax))
  expect_true(is.na(jn$m12[1]))

  # a repeated bare join REUSES the existing <name> column (a no-op);
  # re-adding the same derived columns refuses to overwrite
  x <- fx_tbl(m12)
  j1 <- join_calendar(x, m12)
  expect_identical(join_calendar(j1, m12), j1)
  jm <- join_calendar(x, m12, meta = TRUE)
  expect_error(join_calendar(jm, m12, meta = TRUE),
               "overwrit|exist|collid")
})

# ---- parity sync: axes previously tested on one sibling only -------------- #

# @covers recast_calendar depth=P
test_that("explicit key=, tz=, and a vector year work on recast_calendar", {
  m12 <- .month_cal(); q4 <- .quarter_cal()

  x <- fx_tbl(m12); names(x)[1] <- "slice_id"
  out <- recast_calendar(x, m12, q4, year = 2021, key = "slice_id",
                         rule = "sum", by = "day")
  expect_conserves(x, out, "energy")

  # a tz shift relabels the grid but conserves the totals
  o1 <- recast_calendar(fx_tbl(m12), m12, q4, year = 2021, rule = "sum",
                        by = "day", tz = "UTC")
  o2 <- recast_calendar(fx_tbl(m12), m12, q4, year = 2021, rule = "sum",
                        by = "day", tz = "Asia/Kolkata")
  expect_equal(sum(as.data.frame(o2)$energy),
               sum(as.data.frame(o1)$energy), tolerance = 1e-9)

  # a vector year is refused by design -- multi-year goes through the
  # timebase route, where the year column of `x` drives the grid
  expect_error(recast_calendar(fx_tbl(m12), m12, q4, year = 2021:2022,
                               rule = "sum", by = "day"),
               "single integer")
  x2y <- rbind(cbind(fx_tbl(m12), year = 2021L),
               cbind(fx_tbl(m12, values = list(energy = 2)), year = 2022L))
  base <- recast_to_timebase(x2y, m12, by = "day", rule = "sum")
  out2 <- recast_from_timebase(base, q4, rule = "sum", by = "day")
  expect_conserves(x2y, out2, "energy", by = "year")
  expect_setequal(unique(as.data.frame(out2)$year), c(2021L, 2022L))
})
