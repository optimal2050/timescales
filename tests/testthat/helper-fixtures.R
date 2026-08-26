# =========================================================================== #
# Canonical test fixtures, shared by every test file.
#
# The .month_cal()/.quarter_cal()/.month_hour_cal() trio moved here from the
# head of test-recast.R (2026-08 testing system) so join/backend/property
# files stop re-deriving catalog calendars. Names kept, so existing call
# sites are untouched.
# =========================================================================== #

.month_cal <- function() {
  days <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
  calendar_from_leaftable(
    data.frame(MONTH = sprintf("m%02d", 1:12),
               share = days / 365, weight = days),
    timeframes = "MONTH", name = "m12"
  )
}

.quarter_cal <- function() {
  q_days <- c(90, 91, 92, 92)  # non-leap
  calendar_from_leaftable(
    data.frame(QUARTER = sprintf("Q%d", 1:4),
               share = q_days / 365, weight = q_days),
    timeframes = "QUARTER", name = "q4"
  )
}

.month_hour_cal <- function() {
  days <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
  names(days) <- sprintf("m%02d", 1:12)
  df <- expand.grid(
    MONTH = sprintf("m%02d", 1:12),
    HOUR  = sprintf("h%02d", 0:23),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  df$share  <- days[df$MONTH] / 365 / 24
  df$weight <- days[df$MONTH] / 24
  calendar_from_leaftable(df, timeframes = c("MONTH", "HOUR"), name = "m12_h24")
}

# A fiscal calendar (April-anchored) straight from the catalog.
.fiscal_cal <- function() calendar("fy04_m12")

# A standard keyed value table on `cal`'s timeslices: `values` named numeric
# columns are recycled over the slices; optional `ids` replicates the block
# per id (panel shape). Totals are then known:
# sum(col) = sum(values[[col]]) * length(ids %||% 1).
fx_tbl <- function(cal, values = list(energy = NULL), ids = NULL) {
  sl <- calendar_leaftable(cal)$timeslice
  base <- data.frame(timeslice = sl, stringsAsFactors = FALSE)
  for (nm in names(values)) {
    v <- values[[nm]]
    base[[nm]] <- if (is.null(v)) as.numeric(seq_along(sl)) else
      rep_len(as.numeric(v), length(sl))
  }
  if (is.null(ids)) return(base)
  out <- do.call(rbind, lapply(ids, function(id) {
    b <- base
    b$id <- id
    b
  }))
  rownames(out) <- NULL
  out
}
