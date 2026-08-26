# =========================================================================== #
# Invariant expectations -- the named contracts of the conversion core.
#
# Each expectation states ONE mathematical fact about join/recast that must
# hold on every fixture, rule and backend; test-properties.R sweeps them
# over the grid. Identical file in geoscales (package-agnostic).
# =========================================================================== #

# `sum` conserves totals (per id-group when `by` is given).
expect_conserves <- function(x, out, cols, by = NULL, tol = 1e-9) {
  x <- as.data.frame(x); out <- as.data.frame(out)
  for (cc in cols) {
    if (is.null(by)) {
      expect_equal(sum(out[[cc]], na.rm = TRUE), sum(x[[cc]], na.rm = TRUE),
                   tolerance = tol,
                   label = sprintf("sum(%s) conserved", cc))
    } else {
      a <- tapply(x[[cc]], x[[by]], sum, na.rm = TRUE)
      b <- tapply(out[[cc]], out[[by]], sum, na.rm = TRUE)
      expect_equal(as.numeric(b[names(a)]), as.numeric(a), tolerance = tol,
                   label = sprintf("sum(%s) conserved per %s", cc, by))
    }
  }
  invisible(out)
}

# mean / weighted_mean results lie inside the source envelope.
expect_within_envelope <- function(x, out, cols, tol = 1e-9) {
  x <- as.data.frame(x); out <- as.data.frame(out)
  for (cc in cols) {
    lo <- min(x[[cc]], na.rm = TRUE) - tol
    hi <- max(x[[cc]], na.rm = TRUE) + tol
    v <- out[[cc]][!is.na(out[[cc]])]
    expect_true(all(v >= lo & v <= hi),
                label = sprintf("%s within source envelope", cc))
  }
  invisible(out)
}

# weighted_mean and mean must DISAGREE on a fixture with non-uniform
# shares/weights -- pins the 0.1.0 "weighted_mean == mean" defect class.
expect_weighting_matters <- function(wm_out, mean_out, cols) {
  wm_out <- as.data.frame(wm_out); mean_out <- as.data.frame(mean_out)
  for (cc in cols) {
    expect_false(isTRUE(all.equal(wm_out[[cc]], mean_out[[cc]])),
                 label = sprintf("weighted_mean(%s) != mean(%s)", cc, cc))
  }
}

.inv_sort <- function(d, key) {
  d <- as.data.frame(d)
  d <- d[do.call(order, d[intersect(key, names(d))]), , drop = FALSE]
  rownames(d) <- NULL
  d
}

# down-then-up equals the original (for `sum`).
expect_round_trip <- function(orig, back, cols, key, tol = 1e-9) {
  o <- .inv_sort(orig, key); b <- .inv_sort(back, key)
  expect_equal(b[c(intersect(key, names(b)), cols)],
               o[c(intersect(key, names(o)), cols)],
               tolerance = tol, ignore_attr = TRUE,
               label = "round trip (down then up)")
}

# route composition (`from_base(to_base(x))`) equals the fused recast.
expect_composition_identity <- function(via, fused, cols, key, tol = 1e-9) {
  v <- .inv_sort(via, key); f <- .inv_sort(fused, key)
  expect_equal(v[c(intersect(key, names(v)), cols)],
               f[c(intersect(key, names(f)), cols)],
               tolerance = tol, ignore_attr = TRUE,
               label = "route composition == fused recast")
}

# an EAGER result is completed over the full target vocabulary.
expect_completion <- function(out, vocab, key) {
  out <- as.data.frame(out)
  expect_setequal(unique(as.character(out[[key]])), vocab)
}

# the join contract: row count preserved (no silent fan-out), the input's
# own columns untouched, everything added is namespaced by the object.
expect_join_contract <- function(x, out, name) {
  x <- as.data.frame(x); out <- as.data.frame(out)
  expect_identical(nrow(out), nrow(x))
  expect_true(all(names(x) %in% names(out)),
              label = "input columns survive the join")
  for (cc in names(x)) {
    expect_equal(out[[cc]], x[[cc]], ignore_attr = TRUE,
                 label = sprintf("input column %s untouched", cc))
  }
  added <- setdiff(names(out), names(x))
  ok <- added == name | startsWith(added, paste0(name, "."))
  expect_true(all(ok),
              label = sprintf("added columns namespaced under '%s'", name))
  invisible(out)
}
