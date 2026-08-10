# Builds data/merra2_cities.rda: a 3-city hourly weather sample for the
# weather-data vignette.
#
# Provenance: NASA MERRA-2 reanalysis (GMAO), hourly year 2019, extracted
# with the merra2ools package from its local MERRA-2 store (not shippable:
# ~300 GB). This script subsets the 12-city extract that the predecessor
# timeslices package built in its data-raw/SAMPLES.R; regenerating from
# scratch requires merra2ools + the local store:
#
#   loc <- merra2ools::closest_locid(lon, lat)   # per city
#   merra2ools::get_merra2_subset(loc, from = "2019-01-01 00",
#                                 to = "2019-12-31 23")
#
# Run from the package root: Rscript data-raw/merra2_cities.R

src <- "c:/Users/admin/Documents/R/timeslices/data/merra2_cities.rda"
stopifnot(file.exists(src))
e <- new.env()
load(src, envir = e)
full <- as.data.frame(e$merra2_cities)

cities <- c("Helsinki", "Lima", "Sydney")
keep <- full$city %in% cities

merra2_cities <- data.frame(
  city     = full$city[keep],
  datetime = full$UTC[keep],       # instants at :30 past each hour, UTC
  T10M     = full$T10M[keep],      # air temperature at 10 m, degC
  W50M     = full$W50M[keep],      # wind speed at 50 m, m/s
  SWGDN    = full$SWGDN[keep],     # surface incoming shortwave, W/m2
  stringsAsFactors = FALSE
)
merra2_cities <- merra2_cities[order(merra2_cities$city,
                                     merra2_cities$datetime), ]
rownames(merra2_cities) <- NULL
attr(merra2_cities, "consistency_check") <- NULL

stopifnot(nrow(merra2_cities) == 3 * 8760,
          !anyNA(merra2_cities$datetime))

if (!dir.exists("data")) dir.create("data")
save(merra2_cities, file = "data/merra2_cities.rda", compress = "xz",
     version = 2)
cat("Wrote data/merra2_cities.rda:",
    round(file.size("data/merra2_cities.rda") / 1024), "KB,",
    nrow(merra2_cities), "rows\n")
