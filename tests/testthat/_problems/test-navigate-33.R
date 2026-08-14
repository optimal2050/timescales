# Extracted from test-navigate.R:33

# test -------------------------------------------------------------------------
cal <- calendar("m12_md365_h24")
ch <- calendar_children(cal, "MONTH", "m02")
expect_equal(length(ch), 28L)
expect_true(all(grepl("^d", ch)))
expect_equal(calendar_parents(cal, "MDAY", ch[1]), "m02")
