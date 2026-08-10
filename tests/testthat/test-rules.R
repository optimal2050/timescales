# Rule and conversion registries ----------------------------------------------

test_that("RECAST_RULES and ALIGNMENT_RULES expose the documented sets", {
  expect_equal(RECAST_RULES, c("weighted_mean", "sum", "mean", "copy", "sd"))
  expect_equal(ALIGNMENT_RULES,
               c("exact", "drop_last", "drop_feb29", "repeat_last"))
})

test_that("register_rule / get_rule / list_rules / clear_rules round-trip", {
  on.exit(clear_rules(), add = TRUE)
  register_rule("cap", "sum")
  register_rule("eff", "weighted_mean")

  expect_equal(get_rule("cap")$rule, "sum")
  expect_equal(get_rule("eff")$rule, "weighted_mean")
  expect_null(get_rule("unregistered"))

  lst <- list_rules()
  expect_true(all(c("cap", "eff") %in% lst$param))

  clear_rules("cap")
  expect_null(get_rule("cap"))
  expect_equal(get_rule("eff")$rule, "weighted_mean")

  clear_rules()
  expect_equal(nrow(list_rules()), 0L)
})

test_that("register_rule validates input", {
  expect_error(register_rule("", "sum"), "non-empty")
  expect_error(register_rule("x", "not_a_rule"))
})

test_that("conversion registry round-trips and NULL removes", {
  on.exit(clear_conversions(), add = TRUE)
  fn <- function(x, from, to, ...) x
  register_conversion("a", "b", fn)

  expect_identical(get_conversion("a", "b"), fn)
  expect_null(get_conversion("b", "a"))
  expect_true("a->b" %in% list_conversions()$key)

  register_conversion("a", "b", NULL)
  expect_null(get_conversion("a", "b"))
})

test_that("register_conversion validates input", {
  expect_error(register_conversion("", "b", identity), "non-empty")
  expect_error(register_conversion("a", "b", 42), "function")
})
