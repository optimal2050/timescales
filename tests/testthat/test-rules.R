# Rule and conversion registries ----------------------------------------------

test_that("CALENDAR_RULES and ALIGNMENT_RULES expose the documented sets", {
  expect_equal(CALENDAR_RULES,
               c("weighted_mean", "sum", "mean", "copy", "sd", "share",
                 "logshare"))
  expect_equal(ALIGNMENT_RULES,
               c("exact", "drop_last", "drop_feb29", "repeat_last"))
})

test_that("register_calendar_rule / get_calendar_rule / list_calendar_rules / clear_calendar_rules round-trip", {
  on.exit(clear_calendar_rules(), add = TRUE)
  register_calendar_rule("cap", "sum")
  register_calendar_rule("eff", "weighted_mean")

  expect_equal(get_calendar_rule("cap")$rule, "sum")
  expect_equal(get_calendar_rule("eff")$rule, "weighted_mean")
  expect_null(get_calendar_rule("unregistered"))

  lst <- list_calendar_rules()
  expect_true(all(c("cap", "eff") %in% lst$param))

  clear_calendar_rules("cap")
  expect_null(get_calendar_rule("cap"))
  expect_equal(get_calendar_rule("eff")$rule, "weighted_mean")

  clear_calendar_rules()
  expect_equal(nrow(list_calendar_rules()), 0L)
})

test_that("register_calendar_rule validates input", {
  expect_error(register_calendar_rule("", "sum"), "non-empty")
  expect_error(register_calendar_rule("x", "not_a_rule"))
})

test_that("conversion registry round-trips and NULL removes", {
  on.exit(clear_calendar_conversions(), add = TRUE)
  fn <- function(x, from, to, ...) x
  register_calendar_conversion("a", "b", fn)

  expect_identical(get_calendar_conversion("a", "b"), fn)
  expect_null(get_calendar_conversion("b", "a"))
  expect_true("a->b" %in% list_calendar_conversions()$key)

  register_calendar_conversion("a", "b", NULL)
  expect_null(get_calendar_conversion("a", "b"))
})

test_that("register_calendar_conversion validates input", {
  expect_error(register_calendar_conversion("", "b", identity), "non-empty")
  expect_error(register_calendar_conversion("a", "b", 42), "function")
})
