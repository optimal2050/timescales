# Builds data/calendars.rda: every calendar in the catalog, pre-constructed.
#
# Run from the package root:
#   Rscript data-raw/calendars.R
#
# The objects are exactly what `calendar(id)` returns — lean S7 Calendars
# with no caches — so the dataset is a convenience, not a separate source
# of truth. Rebuild whenever the catalog or the token definitions change.

devtools::load_all(".", quiet = TRUE)

ids <- names(.CALENDAR_CATALOG)
calendars <- stats::setNames(lapply(ids, calendar), ids)

stopifnot(
  length(calendars) == nrow(calendar_catalog()),
  vapply(calendars, function(x) S7::S7_inherits(x, Calendar), logical(1))
)

if (!dir.exists("data")) dir.create("data")
save(calendars, file = "data/calendars.rda", compress = "xz", version = 2)
cat("Wrote data/calendars.rda:",
    round(file.size("data/calendars.rda") / 1024), "KB,",
    length(calendars), "calendars\n")
