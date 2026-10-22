# =========================================================================== #
# make_json_goldens.R -- broad cross-language goldens for the Python port.
#
# Usage (from the package root):
#   Rscript tools/specs/make_json_goldens.R [path/to/nestedscales]
#
# Loads timescales from SOURCE on top of nestedscales loaded from SOURCE
# (default ../nestedscales; its R code is the version submitted to CRAN).
# Writes specs/json/<topic>.json: each case is a call (function, calendars,
# data, arguments) and its result, with every warning and error message.
# Complements specs/golden/ (the small hand-picked set the R suite replays).
# =========================================================================== #

args <- commandArgs(trailingOnly = TRUE)
ns_path <- if (length(args)) args[[1]] else file.path("..", "nestedscales")
suppressMessages({
  pkgload::load_all(ns_path, quiet = TRUE, export_all = FALSE)
  pkgload::load_all(".", quiet = TRUE, export_all = FALSE)
})
out_dir <- file.path("specs", "json")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

vec <- function(x) I(as.character(x))
iso <- function(x) {
  s <- format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  s[is.na(x)] <- NA
  I(s)
}
rows <- function(df) {
  df <- as.data.frame(df)
  for (c in names(df)) {
    if (inherits(df[[c]], "POSIXct")) df[[c]] <- as.character(iso(df[[c]]))
    if (is.factor(df[[c]])) df[[c]] <- as.character(df[[c]])
  }
  if (nrow(df) == 0L) return(I(list()))
  lapply(seq_len(nrow(df)), function(i) as.list(df[i, , drop = FALSE]))
}
tab <- function(df) list(
  columns = lapply(df, function(c) {
    if (inherits(c, "POSIXct")) iso(c)
    else if (is.character(c)) vec(c) else I(as.numeric(c))
  }),
  types = lapply(df, function(c) {
    if (inherits(c, "POSIXct")) "datetime"
    else if (is.character(c)) "string" else "double"
  })
)

# A calendar spec: list(name = , args = list(...), filter = list(tf, labels),
# prune = tf) -- rebuilt identically by every binding.
cal <- function(name, ..., filter = NULL, prune = NULL) {
  list(name = name, args = list(...), filter = filter, prune = prune)
}
build_cal <- function(spec) {
  x <- do.call(calendar, c(list(spec$name), spec$args))
  if (!is.null(spec$filter)) {
    x <- filter_calendar(x, spec$filter[[1]], unlist(spec$filter[[2]]))
  }
  if (!is.null(spec$prune)) x <- prune_calendar(x, spec$prune)
  x
}

describe <- function(x) {
  lt <- calendar_leaftable(x)
  m <- S7::prop(x, "meta")
  small <- nrow(lt) <= 400L
  list(
    frames = vec(calendar_timeframes(x)),
    members = lapply(S7::prop(x, "members"), vec),
    n = nrow(lt), share_sum = sum(lt$share), weight_sum = sum(lt$weight),
    name = m[["name"]], parent_name = m[["parent_name"]],
    year_fraction = m[["year_fraction"]] %||% 1,
    tokens = if (!is.null(m$tokens)) as.list(m$tokens),
    alignment = if (!is.null(m$alignment)) as.list(m$alignment),
    year_start = m$year_start, utc_offset_minutes = m$utc_offset_minutes,
    coverage_class = m[["coverage_class"]], regularity = m[["regularity"]],
    coverage = if (!is.null(m[["coverage"]])) as.list(m[["coverage"]]),
    leaftable = rows(if (small) lt else rbind(utils::head(lt, 30), utils::tail(lt, 30))),
    leaftable_complete = small
  )
}

encode <- function(v) {
  if (S7::S7_inherits(v, Calendar)) return(list(kind = "calendar", value = describe(v)))
  if (is.data.frame(v)) return(list(kind = "table", value = rows(v)))
  if (inherits(v, "POSIXct")) return(list(kind = "datetime", value = iso(v)))
  if (is.character(v)) return(list(kind = "character", value = vec(v)))
  if (is.numeric(v) || is.logical(v)) return(list(kind = "numeric", value = I(as.numeric(v))))
  if (is.list(v)) return(list(kind = "list", value = v))
  stop("cannot encode ", class(v)[1])
}

run <- function(expr) {
  w <- character()
  r <- withCallingHandlers(
    tryCatch(list(error = FALSE, value = expr),
             error = function(e) list(error = TRUE, message = conditionMessage(e))),
    warning = function(cnd) {
      w <<- c(w, conditionMessage(cnd))
      invokeRestart("muffleWarning")
    })
  if (!r$error) r$value <- encode(r$value)
  c(r, list(warnings = vec(w)))
}

# A call: function name, positional arguments (calendar specs are marked),
# named arguments. Arguments are encoded so a binding can rebuild them.
enc_arg <- function(a) {
  if (is.list(a) && !is.null(a$name) && identical(names(a)[1], "name")) {
    return(list(calendar = a))
  }
  if (is.data.frame(a)) return(list(table = tab(a)))
  if (inherits(a, "POSIXct")) return(list(datetime = iso(a), tz = attr(a, "tzone")))
  a
}
dec_arg <- function(a) {
  if (is.list(a) && !is.null(a$name) && identical(names(a)[1], "name")) {
    return(build_cal(a))
  }
  a
}
cases <- list()
call <- function(topic, fn, ..., ordered = TRUE) {
  a <- list(...)
  r <- run(do.call(get(fn), lapply(a, dec_arg)))
  cases[[topic]][[length(cases[[topic]]) + 1L]] <<- c(
    list(fn = fn, args = lapply(a, enc_arg), ordered = ordered), r)
}
utc <- function(...) as.POSIXct(c(...), tz = "UTC")

# ---- construction ----------------------------------------------------------- #

for (id in calendar_catalog()$id) call("construct", "calendar", id)
call("construct", "calendar", "y_d365_h24")
call("construct", "calendar", "wd7_h24_min60")
call("construct", "calendar", "m12a_h24", year_start = list(month = 7L, day = 1L))
call("construct", "calendar", "q4", utc_offset_minutes = 330L)
call("construct", "calendar", "zz9")
call("construct", "calendar_build", "s4", "wk2", "hp3", name = "sea_day_hour")
call("construct", "calendar_build", "m12", "q4")
call("construct", "calendar_catalog")
call("construct", "filter_calendar", cal("m12_h24"), "MONTH", c("m01", "m07"))
call("construct", "filter_calendar", cal("d365_h24"), "YDAY",
     sprintf("d%03d", c(15, 105, 196, 288)))
call("construct", "filter_calendar", cal("m12_h24", filter = list("MONTH", "m01")),
     "HOUR", c("h00", "h12"))
call("construct", "filter_calendar", cal("m12"), "MONTH", "m13")
for (tf in c("ANNUAL", "MONTH", "MDAY")) {
  call("construct", "prune_calendar", cal("m12_md365_h24"), tf)
}
call("construct", "prune_calendar", cal("fy04_q4_h24"), "QUARTER")

# ---- datetimes --------------------------------------------------------------- #

dts <- utc("2020-01-01 00:00:00", "2020-02-28 23:00:00", "2020-02-29 00:30:00",
           "2020-03-01 05:00:00", "2020-12-30 12:00:00", "2020-12-31 23:00:00",
           "2021-01-01 00:00:00", "2021-03-31 23:59:59", "2021-04-01 00:00:00",
           "2021-06-15 17:45:10", "2021-09-30 22:00:00", "2021-12-26 03:00:00",
           "2021-12-31 23:00:00", "2022-01-03 08:00:00", NA)
for (id in c("d365_h24", "d366_h24", "d360_h24", "d364", "m12_md365_h24",
             "m12_md366", "w52_h168", "w53", "w52", "wd7_h24", "wk2_h24", "hp3",
             "s4_hp3", "q4", "m12a_hp3", "fy04_d365_h24", "fy04_q4", "fy04_m12",
             "y_d365_h24")) {
  call("datetime", "datetime_to_timeslice", dts, cal(id))
}
call("datetime", "datetime_to_timeslice", dts, cal("d365"))
call("datetime", "datetime_to_timeslice", dts, cal("d365_h24", utc_offset_minutes = 330L))
call("datetime", "datetime_to_timeslice", dts, cal("m12_h24", utc_offset_minutes = -300L))
call("datetime", "datetime_to_timeslice", dts, cal("d365_h24", filter = list(
  "YDAY", sprintf("d%03d", c(1, 59, 60, 365)))))
call("datetime", "datetime_to_timeslice", dts, cal("d360"), alignment = "repeat_last")
call("datetime", "datetime_to_timeslice", dts, cal("d360"), alignment = "exact")
call("datetime", "datetime_to_timeslice", dts, cal("w52"), alignment = "drop_last")
call("datetime", "datetime_to_timeslice",
     as.POSIXct(c("2021-03-28 01:30:00", "2021-10-31 02:30:00", "2021-07-01 00:00:00"),
                tz = "Europe/Berlin"), cal("d365_h24"))
for (tf in CORE_TIMEFRAMES) {
  call("datetime", "as_timeframe", dts, tf)
  call("datetime", "as_timeframe", dts, tf, format = "token")
}
call("datetime", "as_timeframe", dts, "WDAY", week_start = 1)
call("datetime", "as_timeframe", dts, "MWEEK", week_start = 1)
call("datetime", "as_timeframe", dts, "WDAY", format = "token", week_start = 1)
call("datetime", "as_timeframe", c(0, 5, 23, NA), "HOUR", format = "token")
call("datetime", "as_timeframe", c(1, 3, 12), "MONTH", format = "token",
     calendar = cal("m12a"))
call("datetime", "as_timeframe", dts, "FORTNIGHT")

# ---- grids and maps -------------------------------------------------------- #

call("grid", "base_calendar", 2020L, by = "day")
call("grid", "base_calendar", c(2020L, 2021L), by = "month")
call("grid", "base_calendar", 2021L, by = "6 hours")
call("grid", "expand_calendar", cal("q4"), 2020L, by = "day")
call("grid", "expand_calendar", cal("fy04_m12"), 2021L, by = "day")
call("grid", "expand_calendar", cal("m12_h24", utc_offset_minutes = 120L), 2021L)
call("grid", "expand_calendar", cal("s4"), c(2020L, 2021L), by = "week")
pairs <- list(c("m12", "q4"), c("q4", "m12"), c("d365_h24", "m12_h24"),
              c("w52", "m12"), c("w53", "m12"), c("d360", "m12"), c("m12", "d360"),
              c("fy04_q4", "q4"), c("s4", "m12"), c("wd7_h24", "hp3"),
              c("m12_md365", "d365"), c("m12a_h24", "s4_hp3"), c("m12", "m12"))
for (p in pairs) {
  for (y in list(2020L, 2021L)) {
    call("grid", "calendar_map_between", cal(p[1]), cal(p[2]), y, ordered = FALSE)
  }
}
call("grid", "calendar_map_between", cal("m12"), cal("q4"), c(2020L, 2021L),
     by = "day", ordered = FALSE)
call("grid", "calendar_map", cal("m12_h24"), "MONTH", "HOUR", ordered = FALSE)
call("grid", "calendar_map", cal("m12_md365_h24"), "MDAY", "MONTH", ordered = FALSE)
call("grid", "calendar_map", cal("m12"), cal("q4"), "MONTH")

# ---- recast ------------------------------------------------------------------- #

lt_of <- function(id) calendar_leaftable(calendar(id))
d_m12 <- data.frame(timeslice = lt_of("m12")$timeslice, v = 1:12,
                    p = c(5, 5, 5, 6, 6, 6, 7, 7, 7, 8, 8, 8))
d_m12_ids <- rbind(cbind(d_m12, id = "A"), cbind(transform(d_m12, v = v * 2), id = "B"))
d_m12_na <- d_m12; d_m12_na$v[2] <- NA
d_q4 <- data.frame(timeslice = c("Q1", "Q2", "Q3", "Q4"), v = c(90, 91, 92, 92),
                   p = c(1, 2, 3, 4))
d_m12h <- data.frame(timeslice = lt_of("m12_h24")$timeslice,
                     v = seq_len(288) / 10)
RULES <- c("sum", "mean", "weighted_mean", "copy", "sd")
for (r in RULES) {
  call("recast", "recast_calendar", d_m12, cal("m12"), cal("q4"), 2021L, rule = r,
       values = c("v", "p"))
  call("recast", "recast_calendar", d_m12_ids, cal("m12"), cal("q4"), 2020L, rule = r,
       values = "v")
  call("recast", "recast_calendar", d_q4, cal("q4"), cal("m12"), 2021L, rule = r)
  call("recast", "recast_calendar", d_m12, cal("m12"), cal("d360"), 2021L, rule = r,
       values = "v", na_action = "keep")
  call("recast", "recast_calendar", d_m12h, cal("m12_h24"), "MONTH", 2021L, rule = r)
  call("recast", "recast_calendar", d_m12_na, cal("m12"), cal("s4"), 2021L, rule = r,
       values = "v")
}
for (na in c("drop", "keep", "error")) {
  call("recast", "recast_calendar", d_m12, cal("m12"), cal("d360"), 2020L,
       rule = "sum", values = "v", na_action = na)
  call("recast", "recast_calendar", d_m12, cal("m12"), cal("w52"), 2021L,
       rule = "sum", values = "v", na_action = na)
}
call("recast", "recast_calendar", d_m12[1:5, ], cal("m12"), cal("q4"), 2021L,
     rule = "sum", values = "v")
call("recast", "recast_calendar", rbind(d_m12, data.frame(timeslice = "m13", v = 1,
     p = 1)), cal("m12"), cal("q4"), 2021L, rule = "sum")
call("recast", "recast_calendar", d_m12, cal("m12"), cal("q4"), 2021L, values = "v")
call("recast", "recast_calendar", d_m12, cal("m12"), cal("m12"), 2021L, rule = "sum")
call("recast", "recast_calendar", d_m12h, cal("m12_h24"), "MONTH", 2021L,
     rule = "share")
call("recast", "recast_calendar", d_m12h, cal("m12_h24"), cal("m12_h24"), 2021L,
     rule = "share")
call("recast", "recast_calendar", d_m12, cal("m12"), cal("q4"), 2021L,
     rule = "logshare", values = "v")
call("recast", "recast_calendar", d_m12, cal("m12"), cal("s4"), 2021L,
     rule = "share", values = "v")
call("recast", "recast_calendar", d_m12, cal("m12"), cal("q4"), 2021L,
     rule = "sum", values = "v", parent = "MONTH")
d_tb <- data.frame(timeslice = c("Q1", "Q2", "Q3", "Q4"), v = c(9, 18, 27, 36),
                   year = 2021)
call("recast", "recast_to_timebase", d_tb, cal("q4"), rule = "sum", by = "day",
     ordered = FALSE)
call("recast", "recast_to_timebase", d_tb[, 1:2], cal("q4"), year = 2020L,
     rule = "mean", by = "month", ordered = FALSE)
dt_rows <- data.frame(datetime = base_calendar(2021L, by = "day")$datetime[1:120],
                      v = 1:120, weight = rep(c(1, 2), 60))
call("recast", "recast_from_timebase", dt_rows, cal("m12"), rule = "sum")
call("recast", "recast_from_timebase", dt_rows, cal("m12"), rule = "weighted_mean")
call("recast", "recast_from_timebase", dt_rows, cal("q4"), year = 2021L, rule = "sd")
call("recast", "recast_from_timebase", dt_rows, cal("d360", filter = list(
  "YDAY", sprintf("d%03d", 1:60))), year = 2021L, rule = "sum")
call("recast", "recast_from_timebase", dt_rows, cal("d360", filter = list(
  "YDAY", sprintf("d%03d", 1:60))), year = 2021L, rule = "sum", na_action = "keep")

# ---- navigation, join, conversions ------------------------------------------- #

m <- cal("m12_h24")
call("navigate", "calendar_children", m, "MONTH", "m02")
call("navigate", "calendar_parents", m, "HOUR", "h05")
call("navigate", "calendar_descendants", cal("m12_md365_h24"), "MONTH", "m02")
call("navigate", "calendar_ancestors", cal("m12_md365_h24"), "HOUR", "h05")
call("navigate", "calendar_children", m, "HOUR", "h05")
call("navigate", "calendar_children", m, "MONTH", "m99")
call("navigate", "calendar_family", cal("m12_md365"), ordered = TRUE)
call("navigate", "calendar_ancestry", cal("q4_h24"), ordered = FALSE)
call("navigate", "calendar_share", cal("m12_md365"), "MONTH")
call("navigate", "calendar_share", cal("m12_md365"), "MDAY", within = "MONTH")
call("navigate", "calendar_timeslices", m, "MONTH", qualified = TRUE)
call("navigate", "calendar_coverage", cal("m12", filter = list("MONTH", c("m01", "m02"))))
call("navigate", "join_calendar", d_m12, cal("m12"), timeframes = TRUE, meta = TRUE,
     as_factor = FALSE)
call("navigate", "join_calendar", d_m12[c(3, 1, 2), ], cal("m12"))
call("navigate", "join_calendar", rbind(d_m12, data.frame(timeslice = "zz", v = 0,
     p = 0)), cal("m12"))
call("navigate", "join_calendar", data.frame(datetime = dts[!is.na(dts)], v = 1),
     cal("q4_h24"), timeframes = "QUARTER", as_factor = FALSE)
for (tf in c("HOUR", "YDAY", "MONTH", "QUARTER", "SEASON", "WEEK", "MDAY")) {
  call("convert", "as_timeframe", c("d001_h05", "d059_h23", "d365_h00", NA), tf,
       calendar = cal("d365_h24"))
  call("convert", "as_timeframe", c("d001_h05", "d365_h00"), tf, format = "token",
       calendar = cal("d365_h24"))
}
call("convert", "as_timeframe", c("d001_h05", "d365_h00"), "WDAY", calendar = cal("d365_h24"),
     year = 2021L)
call("convert", "as_timeframe", c("d001_h05", "d365_h00"), "WDAY",
     calendar = cal("d365_h24"))
call("convert", "as_timeframe", c("m01_h05", "m12_h23"), "HOUR", calendar = cal("m12_h24"))
call("convert", "as_timeframe", c("Q1", "Q3"), "MONTH", calendar = cal("q4"))
call("convert", "tsl2hour", c("d001_h05", "d200_h23"), cal("d365_h24"))
call("convert", "tsl2yday", c("d001_h05", "d200_h23"), "d365_h24")
call("convert", "tsl2month", c("d032_h00", "d365_h23"), cal("d365_h24"))
call("convert", "hour2HOUR", c(0, 13, 23))
call("convert", "yday2YDAY", c(1, 59, 366), calendar = cal("d365"))
call("convert", "tsl2dtm", c("m03", "m12", "zz"), cal("m12"), 2021L)
call("convert", "tsl2dtm", c("Q1", "Q4"), cal("fy04_q4"), 2021L)
call("convert", "tsl2dtm", c("d015_h03", "d105_h00"), cal("d365_h24", filter = list(
  "YDAY", sprintf("d%03d", c(15, 105)))), 2021L)
call("convert", "dtm2tsl", dts, "m12_h24")

for (topic in names(cases)) {
  jsonlite::write_json(
    list(generated_by = paste("timescales", packageVersion("timescales"), "+",
                              "nestedscales", packageVersion("nestedscales")),
         cases = cases[[topic]]),
    file.path(out_dir, paste0(topic, ".json")),
    auto_unbox = TRUE, digits = NA, null = "null", na = "null", pretty = FALSE)
  cat("wrote", file.path(out_dir, paste0(topic, ".json")), length(cases[[topic]]),
      "cases\n")
}
