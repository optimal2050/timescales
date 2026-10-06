# Convert between timeslices and datetimes

`dtm2tsl()` labels instants with the timeslice they fall in. `tsl2dtm()`
goes back, returning the instant each timeslice STARTS at – which is
what a real datetime axis on a plot needs.

## Usage

``` r
tsl2dtm(tsl, calendar, year, tz = "UTC", alignment = NULL)

dtm2tsl(dtm, calendar, alignment = NULL)
```

## Arguments

- tsl:

  Character vector of timeslice labels.

- calendar:

  A
  [`Calendar`](https://optimal2050.github.io/timescales/r/reference/Calendar.md),
  or the name of one (`"d365_h24"`).

- year:

  A single year, or one per element of `tsl`.

- tz:

  Time zone for the generated instants.

- alignment:

  How real instants beyond the calendar's vocabulary map onto it; see
  [`ALIGNMENT_RULES`](https://optimal2050.github.io/timescales/r/reference/ALIGNMENT_RULES.md).
  `NULL` uses the calendar's own.

- dtm:

  A `POSIXct`, `POSIXlt` or `Date` vector.

## Value

`tsl2dtm()` a `POSIXct` vector, `NA` where a label is unknown.
`dtm2tsl()` a character vector of timeslice labels.

## Details

Timeslice labels carry no year, so `tsl2dtm()` needs one. Pass a single
year for the whole vector, or one year per element when the rows span
several.

## Examples

``` r
tsl2dtm(c("d001_h00", "d100_h20"), "d365_h24", year = 2021)
#> [1] "2021-01-01 00:00:00 UTC" "2021-04-10 20:00:00 UTC"
dtm2tsl(as.POSIXct("2021-04-10 20:00", tz = "UTC"), "d365_h24")
#> [1] "d100_h20"
```
