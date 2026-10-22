# =============================================================================
# Backend dispatch -- delegated to nestedscales
# =============================================================================
# data.frame / tibble / data.table / dtplyr / arrow in, the same class out,
# lazy inputs staying lazy unless collected. The implementation lives in
# `nestedscales`, which exports the quintet for exactly this. These are direct
# bindings rather than wrapper calls: they sit in the per-row path of every
# conversion, so an extra frame is not free.
#
# Verified byte-identical to the former local copies modulo the `.ts_`/`.ms_`
# prefix before they were removed.
# =============================================================================

# data.table dispatch: without this `[.data.table` falls through to
# `[.data.frame` and the joins break.
.datatable.aware <- TRUE

# Internal working columns referenced as bare symbols inside dplyr verbs
# (bare symbols, not `.data[[...]]`, because dtplyr and arrow mistranslate
# pronoun subsetting) -- declared so R CMD check knows they are data masks.
utils::globalVariables(c(".ts_to", ".ts_y", ".ts_f", ".ts_n_from",
                         ".ts_n_overlap", ".ts_w", ".ts_label",
                         ".ts_year"))

# NA for an unsupported input; callers raise their own error.
.ts_backend <- function(x) {
  tryCatch(nestedscales::backend_of(x), error = function(e) NA_character_)
}
.ts_is_lazy <- nestedscales::backend_is_lazy
.ts_lazy    <- nestedscales::backend_lazy
.ts_schema  <- nestedscales::backend_schema
.ts_pull    <- nestedscales::backend_pull
.ts_restore <- nestedscales::backend_restore

# No nestedscales counterpart: trivial over the schema.
#' @noRd
.ts_names <- function(x) names(.ts_schema(x))
