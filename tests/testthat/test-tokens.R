test_that("list_tokens() includes the built-in set", {
  toks <- list_tokens()
  expect_true(all(c("d360", "d364", "d365", "d366",
                    "m12", "m12a", "q4",
                    "w52", "w53", "wd7",
                    "h24", "h168", "min60") %in% toks))
})

test_that("get_token() returns timeframe + expand", {
  d365 <- get_token("d365")
  expect_equal(d365$timeframe, "YDAY")
  df <- d365$expand()
  expect_equal(nrow(df), 365)
  expect_equal(df$label[1], "d001")
  expect_equal(df$label[365], "d365")
  expect_equal(sum(df$share), 1)
})

test_that("month tokens have day-weighted shares", {
  m12 <- get_token("m12")$expand()
  expect_equal(m12$label, sprintf("m%02d", 1:12))
  # share should equal days-in-month / 365
  expect_equal(m12$share[1], 31 / 365)
  expect_equal(m12$share[2], 28 / 365)
  expect_equal(sum(m12$share), 1)

  m12a <- get_token("m12a")$expand()
  expect_equal(m12a$label, c("JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                             "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"))
  expect_equal(m12a$share, m12$share)
})

test_that("get_token() errors on unknown token", {
  expect_error(get_token("totally_made_up"), "Unknown token")
})

test_that("register_token() adds and can be retrieved", {
  register_token("my_d2", "YDAY", function() {
    data.frame(label = c("first_half", "second_half"),
               share = c(0.5, 0.5))
  })
  on.exit(rm("my_d2", envir = timescales:::.TOKEN_REGISTRY), add = TRUE)
  expect_true("my_d2" %in% list_tokens())
  expect_equal(get_token("my_d2")$timeframe, "YDAY")
})

test_that("register_token() rejects bad expand functions", {
  expect_error(
    register_token("bad", "YDAY", function() {
      data.frame(label = c("a", "a"), share = c(0.5, 0.5))  # duplicate
    }),
    "expand"
  )
  expect_error(
    register_token("bad", "YDAY", function() {
      data.frame(label = c("a", "b"), share = c(0.6, 0.5))  # sum > 1
    }),
    "share"
  )
})

# calendar_build -------------------------------------------------------------

test_that("calendar_build('d365', 'h24') yields the expected leaf count", {
  cal <- calendar_build("d365", "h24")
  expect_equal(cal@timeframes, c("YDAY", "HOUR"))
  expect_equal(nrow(cal@leaves), 365 * 24)
  expect_equal(cal@meta$name, "d365_h24")
  # share sums to 1
  expect_equal(sum(cal@leaves$share), 1, tolerance = 1e-9)
})

test_that("calendar_build('m12', 'h24') uses day-weighted month shares", {
  cal <- calendar_build("m12", "h24")
  expect_equal(nrow(cal@leaves), 12 * 24)
  # Sum of share over m01 leaves = 31 / 365
  jan_share <- sum(cal@leaves$share[cal@leaves$MONTH == "m01"])
  expect_equal(jan_share, 31 / 365, tolerance = 1e-10)
})

test_that("calendar_build rejects duplicate timeframes", {
  expect_error(calendar_build("d365", "d364"), "Duplicate timeframes")
})

test_that("calendar_build requires at least one token", {
  expect_error(calendar_build(), "at least one token")
})

# calendar (name-based) ------------------------------------------------------

test_that("calendar('d365_h24') == calendar_build('d365','h24')", {
  c1 <- calendar("d365_h24")
  c2 <- calendar_build("d365", "h24", name = "d365_h24")
  expect_equal(nrow(c1@leaves), nrow(c2@leaves))
  expect_equal(c1@timeframes, c2@timeframes)
  expect_equal(sum(c1@leaves$share), sum(c2@leaves$share), tolerance = 1e-12)
})

test_that("calendar() handles single-token names", {
  cal <- calendar("d365")
  expect_equal(cal@timeframes, "YDAY")
  expect_equal(nrow(cal@leaves), 365)
})

test_that("calendar() reports unknown tokens with helpful message", {
  expect_error(calendar("d365_blarg"), "Unknown token")
})

test_that("calendar() recognises year-qualified prefix", {
  cal <- calendar("y_d365_h24")
  expect_true(isTRUE(cal@meta$year_qualified))
  expect_equal(nrow(cal@leaves), 365 * 24)
})

# Round-trip with recast() ---------------------------------------------------

test_that("calendar() result works with recast()", {
  cal_m <- calendar("m12")
  cal_q <- calendar("q4")
  x <- data.frame(slice = sprintf("m%02d", 1:12),
                  load  = seq(100, 210, length.out = 12))
  out <- recast(x, from = cal_m, to = cal_q, year = 2021,
                rule = "weighted_mean", by = "day")
  expect_equal(out$slice, sprintf("Q%d", 1:4))
  v <- x$load
  expected_q1 <- (31 * v[1] + 28 * v[2] + 31 * v[3]) / 90
  expect_equal(out$load[1], expected_q1, tolerance = 1e-10)
})
