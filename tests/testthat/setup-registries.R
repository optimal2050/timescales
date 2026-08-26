# Registry hygiene for the whole suite: start clean, end clean, so no test
# depends on what another file registered (rules / conversions / maps).
# Individual tests still register-and-clear locally where the registry IS
# the thing under test. (The token registry has no clear_* by design -- it
# holds the built-in vocabulary; tests register uniquely-named tokens.)
clear_calendar_rules()
clear_calendar_conversions()
clear_calendar_maps()
withr::defer(
  {
    clear_calendar_rules()
    clear_calendar_conversions()
    clear_calendar_maps()
  },
  teardown_env()
)
