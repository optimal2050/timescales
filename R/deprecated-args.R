# =============================================================================
# Renamed arguments
# =============================================================================
# `from`/`to` were renamed `source`/`target` in 0.7.0, the names nestedscales
# uses. The old names stay accepted as trailing arguments, with a soft
# deprecation (a warning only for direct calls, not for calls from another
# package), until the next release.
# =============================================================================

#' @noRd
.arg_renamed <- function(fn, old, new, both) {
  if (isTRUE(both)) {
    .stop("pass `%s` only; `%s` is its deprecated name", new, old)
  }
  lifecycle::deprecate_soft("0.7.0", sprintf("%s(%s)", fn, old),
                            sprintf("%s(%s)", fn, new),
                            user_env = rlang::caller_env(2))
}
