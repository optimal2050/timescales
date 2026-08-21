# Hourly weather sample: three cities, year 2019

NASA MERRA-2 reanalysis extracted for Helsinki, Lima, and Sydney — a
high-latitude / equatorial / southern-hemisphere contrast, used by the
visualization vignette
([`vignette("visualization")`](https://optimal2050.github.io/timescales/r/articles/visualization.md))
to demonstrate mapping datetimes onto calendars, calendar heatmaps and
wall calendars, profiles/ribbons/duration curves, and recasting across
resolutions.

## Usage

``` r
merra2_cities
```

## Format

A `data.frame` with 26,280 rows (3 cities x 8,760 hours) and 5 columns:

- `city`:

  `"Helsinki"`, `"Lima"`, or `"Sydney"`.

- `datetime`:

  POSIXct, UTC; hourly instants of 2019 stamped at 30 minutes past the
  hour (the MERRA-2 hourly-mean convention).

- `T10M`:

  Air temperature at 10 m, degrees C.

- `W50M`:

  Wind speed at 50 m, m/s.

- `SWGDN`:

  Surface incoming shortwave irradiance, W/m2.

## Source

NASA MERRA-2 reanalysis, Global Modeling and Assimilation Office (GMAO),
extracted with the `merra2ools` package
(<https://github.com/optimal2050/merra2ools>); subset built by
`data-raw/merra2_cities.R`.

## Examples

``` r
head(merra2_cities)
#>       city            datetime T10M W50M SWGDN
#> 1 Helsinki 2019-01-01 00:30:00    1 14.0     0
#> 2 Helsinki 2019-01-01 01:30:00    2 12.6     0
#> 3 Helsinki 2019-01-01 02:30:00    2 11.5     0
#> 4 Helsinki 2019-01-01 03:30:00    3 11.0     0
#> 5 Helsinki 2019-01-01 04:30:00    3 10.8     0
#> 6 Helsinki 2019-01-01 05:30:00    3 10.7     0
with(subset(merra2_cities, city == "Helsinki"), range(T10M))
#> [1] -11  29
```
