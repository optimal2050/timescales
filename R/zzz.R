# Package load hooks.

.onLoad <- function(libname, pkgname) {
  # S7 methods on foreign generics (print, format) need explicit
  # registration — S7 objects are not S4-backed
  S7::methods_register()

  # Register autoplot on ggplot2's generic without importing ggplot2
  # (Suggests-only). Both class strings are needed: an S7 object's class()
  # carries the package-qualified name first. try() so a ggplot2 API change
  # can never break package load. (Pattern: geoscales/R/zzz.R.)
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    for (cls in c("Calendar", "timescales::Calendar")) {
      try(registerS3method("autoplot", cls, autoplot.Calendar,
                           envir = asNamespace("ggplot2")),
          silent = TRUE)
      try(registerS3method("fortify", cls, fortify.Calendar,
                           envir = asNamespace("ggplot2")),
          silent = TRUE)
    }
  }
  invisible()
}
