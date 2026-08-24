# Builds data/merra2_cities.rda: a 12-city hourly weather sample used
# across the vignettes and the README (and, via the locid bridge, by the
# geoscales documentation).
#
# Provenance: NASA MERRA-2 reanalysis (GMAO), hourly year 2019, extracted
# with the merra2ools package from its local MERRA-2 store (not shippable:
# ~300 GB). This script re-ships the full 12-city extract that the
# predecessor timeslices package built in its data-raw/SAMPLES.R;
# regenerating from scratch requires merra2ools + the local store:
#
#   loc <- merra2ools::closest_locid(lon, lat)   # per city
#   merra2ools::get_merra2_subset(loc, from = "2019-01-01 00",
#                                 to = "2019-12-31 23")
#
# MERRA-2 data are produced by NASA's Global Modeling and Assimilation
# Office and are in the public domain.
#
# Run from the package root: Rscript data-raw/merra2_cities.R

src <- "c:/Users/admin/Documents/R/timeslices/data/merra2_cities.rda"
stopifnot(file.exists(src))
e <- new.env()
load(src, envir = e)
full <- as.data.frame(e$merra2_cities)

merra2_cities <- data.frame(
  city        = full$city,
  locid       = as.integer(full$locid),  # MERRA-2 grid-cell id (geo bridge)
  datetime    = full$UTC,                # instants at :30 past each hour, UTC
  T10M        = full$T10M,               # air temperature at 10 m, degC
  W10M        = full$W10M,               # wind speed at 10 m, m/s
  W50M        = full$W50M,               # wind speed at 50 m, m/s
  WDIR        = full$WDIR,               # wind direction, degrees
  SWGDN       = full$SWGDN,              # surface incoming shortwave, W/m2
  ALBEDO      = full$ALBEDO,             # surface albedo, fraction
  PRECTOTCORR = full$PRECTOTCORR,        # corrected total precipitation
  RHOA        = full$RHOA,               # air density, kg/m3
  stringsAsFactors = FALSE
)
merra2_cities <- merra2_cities[order(merra2_cities$city,
                                     merra2_cities$datetime), ]
rownames(merra2_cities) <- NULL
attr(merra2_cities, "consistency_check") <- NULL

stopifnot(nrow(merra2_cities) == 12 * 8760,
          length(unique(merra2_cities$city)) == 12,
          "Reykjavik" %in% merra2_cities$city,
          !anyNA(merra2_cities$datetime),
          !anyNA(merra2_cities$locid))

if (!dir.exists("data")) dir.create("data")
save(merra2_cities, file = "data/merra2_cities.rda", compress = "xz",
     version = 2)
cat("Wrote data/merra2_cities.rda:",
    round(file.size("data/merra2_cities.rda") / 1024), "KB,",
    nrow(merra2_cities), "rows,",
    length(unique(merra2_cities$city)), "cities\n")
