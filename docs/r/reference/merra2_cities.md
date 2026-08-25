# Hourly weather sample: twelve cities, year 2019

NASA MERRA-2 reanalysis extracted for twelve cities across every
populated continent and both hemispheres: Beijing, Cape Town, Dakar,
Delhi, Helsinki, Honolulu, Jakarta, Lima, Lisbon, Reykjavik, Sydney, and
Tokyo. Used by the README and the visualization vignette
([`vignette("visualization")`](https://optimal2050.github.io/timescales/r/articles/visualization.md))
to demonstrate mapping datetimes onto calendars, calendar heatmaps and
wall calendars, profiles/ribbons/duration curves, and recasting across
resolutions — and, through `locid`, shared with the geoscales
documentation as the time half of "the same data on time and geo
scales".

## Usage

``` r
merra2_cities
```

## Format

A `data.frame` with 105,120 rows (12 cities x 8,760 hours) and 11
columns:

- `city`:

  City name.

- `locid`:

  Integer id of the MERRA-2 grid cell the city falls in (the join key to
  the MERRA-2 grid, e.g. via the `merra2ools` package's `locid` table —
  the bridge to the space dimension).

- `datetime`:

  POSIXct, UTC; hourly instants of 2019 stamped at 30 minutes past the
  hour (the MERRA-2 hourly-mean convention).

- `T10M`:

  Air temperature at 10 m, degrees C.

- `W10M`, `W50M`:

  Wind speed at 10 m / 50 m, m/s.

- `WDIR`:

  Wind direction, degrees.

- `SWGDN`:

  Surface incoming shortwave irradiance, W/m2.

- `ALBEDO`:

  Surface albedo, fraction.

- `PRECTOTCORR`:

  Bias-corrected total precipitation.

- `RHOA`:

  Air density, kg/m3.

## Source

NASA MERRA-2 reanalysis, Global Modeling and Assimilation Office (GMAO)
— a public-domain dataset; extracted with the `merra2ools` package
(<https://github.com/optimal2050/merra2ools>); subset built by
`data-raw/merra2_cities.R`.

## Examples

``` r
head(merra2_cities)
#>      city  locid            datetime T10M W10M W50M WDIR SWGDN ALBEDO
#> 1 Beijing 150235 2019-01-01 00:30:00  -10  4.9  6.8  140    79   0.18
#> 2 Beijing 150235 2019-01-01 01:30:00   -9  5.9  7.0  150   211   0.16
#> 3 Beijing 150235 2019-01-01 02:30:00   -6  6.2  7.1  160   331   0.15
#> 4 Beijing 150235 2019-01-01 03:30:00   -3  5.9  6.9  160   411   0.14
#> 5 Beijing 150235 2019-01-01 04:30:00   -2  5.7  6.8  160   444   0.14
#> 6 Beijing 150235 2019-01-01 05:30:00   -1  5.4  6.4  160   416   0.14
#>   PRECTOTCORR RHOA
#> 1           0 1.34
#> 2           0 1.34
#> 3           0 1.32
#> 4           0 1.31
#> 5           0 1.30
#> 6           0 1.30
with(subset(merra2_cities, city == "Reykjavik"), range(W50M))
#> [1]  0.1 22.6
```
