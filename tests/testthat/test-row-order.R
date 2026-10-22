# Leaftable rows are in nested (chronological) order by default --------------

test_that("built calendars run coarsest-first, in member order", {
  lt <- calendar_leaftable(calendar_build("q4", "h24"))
  expect_identical(lt$timeslice[1:3], c("Q1_h00", "Q1_h01", "Q1_h02"))
  expect_identical(lt$timeslice[25], "Q2_h00")
})

test_that("row_order = 'given' keeps the rows as supplied", {
  df <- data.frame(Q = c("Q1", "Q2", "Q1", "Q2"), H = c("a", "a", "b", "b"),
                   share = rep(0.25, 4))
  nested <- calendar_from_leaftable(df, timeframes = c("Q", "H"))
  given <- calendar_from_leaftable(df, timeframes = c("Q", "H"),
                                   row_order = "given")
  expect_identical(calendar_leaftable(nested)$timeslice,
                   c("Q1_a", "Q1_b", "Q2_a", "Q2_b"))
  expect_identical(calendar_leaftable(given)$timeslice,
                   c("Q1_a", "Q2_a", "Q1_b", "Q2_b"))
})
